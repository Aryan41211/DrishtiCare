%% GRAD-CAM LESION ALIGNMENT - offline quantitative evaluation (read-only)
% Quantifies how the locked Day-7 5-class champion's Grad-CAM attention
% overlaps with doctor-annotated IDRiD lesion masks (MA/HE/EX/SE).
%
%   Model   : data/models/day7_pretrained_resnet18_5class_stage2.mat (LOCKED;
%             SHA-256 asserted identical to the baseline manifest before and
%             after the run - the model is loaded read-only, never trained).
%   Layer   : res5b_relu (same as gradcamExplain.m / predictSingleFundus.m).
%   Preproc : EXACT inference preprocessing of predictSingleFundus.m -
%             imread -> replicate-if-gray -> imresize(raw,[224 224]) ->
%             classify(net, img). Masks follow the SAME output-size resize
%             with 'nearest' (lesion_mask_to_model_grid.m) so image and mask
%             share one spatial mapping.
%   Metrics : saliency mass in lesion, pointing game, IoU of the FIXED
%             top-20%-of-pixels attention region (primary), plus the Day-8
%             T6-style top-20%-cumulative-mass region (secondary, kept only
%             for cross-study comparability). Thresholds are fixed a priori
%             and never tuned.
%   Correct-vs-incorrect: IDRiD 5-class grades do NOT exist for the
%             segmentation images (the grading CSVs cover IDRiD_001..413 /
%             001..103 only). A clearly-labelled PROXY split is reported
%             instead: referable-DR proxy GT = any lesion present (derived
%             from real annotations) vs model referable (grade >= Moderate).
%
%   OFFLINE ANALYSIS ONLY. No training, no model/threshold/production
%   changes, APTOS data untouched, no GPU required (ExecutionEnvironment
%   is forced to 'cpu').
%
%   Outputs -> data/analysis/gradcam_lesion_alignment/
%     dataset_audit.csv/.mat/.md, per_image_results.csv,
%     gradcam_lesion_alignment.mat, README.md, results_checkpoint.mat,
%     visual_examples/*.png, sanity_checks/*.png, run_log.txt

projRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
cd(projRoot);
addpath(genpath(fullfile(projRoot, 'src')));

tStart = tic;
outDir = fullfile(projRoot, 'data', 'analysis', 'gradcam_lesion_alignment');
if ~exist(outDir, 'dir'), mkdir(outDir); end
mkdirIfMissing(fullfile(outDir, 'visual_examples'));
mkdirIfMissing(fullfile(outDir, 'sanity_checks'));
if ~diaryOn(fullfile(outDir, 'run_log.txt'))
    warning('Could not open diary log; continuing without file log.');
end

fprintf('============================================================\n');
fprintf('  DRISHTICARE GRAD-CAM LESION ALIGNMENT (offline, CPU)\n');
fprintf('  Date: %s\n', char(datetime('now')));
fprintf('============================================================\n');

%% ---- 0. Fixed experiment configuration (decided BEFORE any evaluation) ----
CONFIG = struct();
CONFIG.modelPath = fullfile(projRoot, 'data', 'models', ...
    'day7_pretrained_resnet18_5class_stage2.mat');
CONFIG.expectedSha256 = 'DD152C917689146F6DEC4687B263EC5E5F237ECF60EC719A59F9FCEEFF737C1B';
CONFIG.featLayer   = 'res5b_relu';
CONFIG.topFracPx   = 0.20;  % PRIMARY attention rule: top 20% of pixels by rank
CONFIG.topFracMass = 0.20;  % SECONDARY (T6 comparability): top 20% of mass
CONFIG.rngSeed     = 42;    % deterministic example/sanity selection
CONFIG.nSanity     = 5;     % transformation sanity-check figures
CONFIG.checkpointEvery = 10;
CONFIG.gradeLabels = {'No DR', 'Mild', 'Moderate', 'Severe', 'Proliferative'};

%% ---- 1. Environment + model integrity (pre-run) ----
vs = ver;
assert(any(strcmpi({vs.Name}, 'Deep Learning Toolbox')), ...
    'Deep Learning Toolbox not available (required for gradCAM)');
dltIdx = find(strcmpi({vs.Name}, 'Deep Learning Toolbox'), 1);
fprintf('[ENV] Deep Learning Toolbox %s\n', vs(dltIdx).Version);
assert(exist('gradCAM', 'file') == 2, ...
    'built-in gradCAM not found - refusing to substitute a different method');
fprintf('[ENV] built-in gradCAM present; feature layer fixed to %s\n', ...
    CONFIG.featLayer);

shaBefore = sha256Hex(CONFIG.modelPath);
assert(strcmpi(shaBefore, CONFIG.expectedSha256), ...
    'Locked 5-class model SHA-256 does not match the baseline manifest! got=%s', shaBefore);
fprintf('[INTEGRITY] model SHA-256 pre-run OK (%s...)\n', shaBefore(1:16));

%% ---- 3. Load locked model (read-only) + class mapping ----
S5 = load(CONFIG.modelPath, 'trainedNet');   % read-only load, like T6
net = S5.trainedNet; clear S5;
inputSize = net.Layers(1).InputSize;
assert(isequal(inputSize(1:2), [224 224]), ...
    'Expected 224x224 model input, got %s', mat2str(inputSize));
outH = inputSize(1); outW = inputSize(2);
assert(any(strcmp({net.Layers.Name}, CONFIG.featLayer)), ...
    'Feature layer %s not present in the network', CONFIG.featLayer);
[gradeOf, classNamesRaw, classMapNote] = resolveClassMapping(net);
fprintf('[MODEL] input %dx%dx%d, layer %s, classes: %s\n', outH, outW, ...
    inputSize(3), CONFIG.featLayer, classMapNote);
expectedAttnPx = ceil(CONFIG.topFracPx * outH * outW);   % fixed attention size
fprintf('[MODEL] attention region (primary rule): top %d%% of pixels = %d px\n', ...
    round(CONFIG.topFracPx * 100), expectedAttnPx);

%% ---- 2. Phase-2 dataset audit ----
[audit, pairs] = audit_idrid_lesion_dataset(projRoot, outDir);
assert(audit.validPairs > 0, 'Audit found no valid image+mask pairs.');
validIdx = strcmp({pairs.status}, 'valid');
fprintf('[DATA] evaluating %d valid pairs (%d candidates, %d skipped with reasons)\n', ...
    audit.validPairs, audit.totalCandidates, audit.skipped);

%% ---- 4. Per-image inference + Grad-CAM + metrics (one image at a time) ----
nValid = nnz(validIdx);
validPos = find(validIdx);
perImage = cell(nValid, 1);
figCache = cell(nValid, 1);

% Deterministic sanity-check sample for Phase-5 alignment verification
rng(CONFIG.rngSeed, 'twister');
sanityOrder = randperm(nValid);
sanityPick = sanityOrder(1:min(CONFIG.nSanity, nValid));   % positions in valid list
fprintf('[PLAN] sanity-check images: %s\n', strjoin({pairs(validPos(sanityPick)).id}, ', '));

for v = 1:nValid
    pi = validPos(v);
    try
        [rec, cache] = scoreOneImage(pairs(pi), net, CONFIG, outH, outW, gradeOf);
    catch me
        rec = blankRecord(pairs(pi), CONFIG);
        rec.status = 'error';
        rec.errorMsg = me.message;
        fprintf('  [ERROR] %s: %s (logged; evaluation continues)\n', pairs(pi).id, me.message);
        perImage{v} = rec;
        figCache{v} = [];
        continue;
    end
    perImage{v} = rec;
    figCache{v} = cache;
    if mod(v, 10) == 0 || v == nValid
        fprintf('  [%2d/%2d] %s pred=%-13s p=%.3f | any-lesion: mass=%.3f pt=%d iou=%.3f\n', ...
            v, nValid, rec.id, rec.predictedGradeLabel, rec.confidence, ...
            rec.massInAll, rec.pointAll, rec.iouAll);
    end
    if mod(v, CONFIG.checkpointEvery) == 0
        save(fullfile(outDir, 'results_checkpoint.mat'), 'perImage', 'CONFIG', 'v', '-v7');
    end
end
recs = [perImage{:}];                          % 1xN struct array
    save(fullfile(outDir, 'results_checkpoint.mat'), 'perImage', 'CONFIG', 'v', '-v7');
    nScored = nnz(strcmp({recs.status}, 'scored'));
nError  = nnz(strcmp({recs.status}, 'error'));
fprintf('[RUN] scored=%d errors=%d (%.1f s)\n', nScored, nError, toc(tStart));

%% ---- 5. Aggregates (overall / per lesion type / by split) ----
scored   = strcmp({recs.status}, 'scored');
scored   = scored(:).';                                  % ensure row vector
nMaskMat = reshape([recs.nMaskPx], 4, []).';          % N x 4
nMaskMat = nMaskMat.';                                  % 4 x N (row per lesion type)
evalAny  = scored & ([recs.nMaskPxAll] > 0);          % combined-evaluable images
evalAny  = evalAny(:).';                              % ensure row vector
lesionTags = {'MA', 'HE', 'EX', 'SE'};

agg = struct();
agg.combined = poolStats([recs(evalAny).massInAll], [recs(evalAny).pointAll], ...
    [recs(evalAny).iouAll], [recs(evalAny).iouMassAll], ...
    [recs(evalAny).diceMassAll], [recs(evalAny).maskAreaFracAll]);
for t = 1:4
    selT = scored & (nMaskMat(t, :) > 0);             % images with that lesion
    selT = selT(:).';                                  % ensure row vector for 1xN recs
    agg.(lower(lesionTags{t})) = poolStats( ...
        arrayfun(@(r) r.massIn(t),      recs(selT)), ...
        arrayfun(@(r) r.point(t),       recs(selT)), ...
        arrayfun(@(r) r.iou(t),         recs(selT)), ...
        arrayfun(@(r) r.iouMass(t),     recs(selT)), ...
        arrayfun(@(r) r.diceMass(t),    recs(selT)), ...
        arrayfun(@(r) r.maskAreaFrac(t), recs(selT)));
end
for sname = {'train', 'test'}
    selS = evalAny & strcmp({recs.split}, sname{1});
    selS = selS(:).';
    agg.([sname{1} '_combined']) = poolStats( ...
        [recs(selS).massInAll], [recs(selS).pointAll], [recs(selS).iouAll], ...
        [recs(selS).iouMassAll], [recs(selS).diceMassAll], [recs(selS).maskAreaFracAll]);
end

%% ---- 6. Correct-vs-incorrect (proxy, clearly labelled) ----
% IDRiD 5-class grades do NOT exist for the segmentation images (grading CSVs
% cover IDRiD_001..413 / IDRiD_001..103; segmentation set is IDRiD_01..81).
% PROXY correctness: proxy GT = any doctor-annotated lesion present
% (referable-DR proxy, derived from real annotations, not invented grades);
% model referable = predicted grade >= Moderate. Reported as a screening-level
% proxy, NOT as grading accuracy.
proxyGtRef    = [recs(scored).proxyGtReferable];
proxyModelRef = [recs(scored).modelReferable];
proxy = struct();
proxy.TP = nnz(proxyGtRef & proxyModelRef);      % lesions present, model referable
proxy.FN = nnz(proxyGtRef & ~proxyModelRef);     % lesions present, model under-called
proxy.FP = nnz(~proxyGtRef & proxyModelRef);
proxy.TN = nnz(~proxyGtRef & ~proxyModelRef);
proxy.note = ['PROXY correctness: GT side = presence of doctor-annotated lesions ' ...
    '(referable-DR proxy). NOT an IDRiD 5-class grade.'];

selCorrect   = evalAny & [recs.proxyPredictionCorrect];
selIncorrect = evalAny & ~[recs.proxyPredictionCorrect];
selCorrect   = selCorrect(:).';
selIncorrect = selIncorrect(:).';
agg.proxyCorrect = poolStats([recs(selCorrect).massInAll], ...
    [recs(selCorrect).pointAll], [recs(selCorrect).iouAll], ...
    [recs(selCorrect).iouMassAll], [recs(selCorrect).diceMassAll], ...
    [recs(selCorrect).maskAreaFracAll]);
agg.proxyIncorrect = poolStats([recs(selIncorrect).massInAll], ...
    [recs(selIncorrect).pointAll], [recs(selIncorrect).iouAll], ...
    [recs(selIncorrect).iouMassAll], [recs(selIncorrect).diceMassAll], ...
    [recs(selIncorrect).maskAreaFracAll]);

predGrades = [recs(scored).predictedGrade];
predDist = histcounts(predGrades, -0.5:1:4.5);

blockedExact = struct();
blockedExact.status = 'NOT COMPUTABLE';
blockedExact.reason = ['IDRiD segmentation images (IDRiD_01..IDRiD_81) are a distinct ' ...
    'image set from the IDRiD Disease-Grading set (IDRiD_001..IDRiD_413 / 001..103). ' ...
    'No 5-class DR grade labels exist for the segmentation images (verified in this ' ...
    'run: the grading label CSVs contain zero two-digit image names), so an exact ' ...
    'correct-vs-incorrect 5-class split is NOT computable. A clearly-labelled ' ...
    'referable-DR PROXY split (GT = any lesion present, from real annotations) is ' ...
    'reported instead. Consistent with the Day-8 T6 finding (docs/validation/2026-09-08-task6-gradcam.md).'];
fprintf('\n===== CORRECT-vs-INCORRECT =====\n%s\n', blockedExact.reason);
fprintf('Proxy confusion (GT=any lesion): TP=%d FN=%d FP=%d TN=%d\n', ...
    proxy.TP, proxy.FN, proxy.FP, proxy.TN);

%% ---- 7. Visualizations ----
% 7a. Transformation sanity checks (Phase 5): original+GT vs model-input+GT
for k = 1:numel(sanityPick)
    vi = sanityPick(k); pi2 = validPos(vi);
    outPng = fullfile(outDir, 'sanity_checks', ...
        sprintf('sanity_transform_%s.png', pairs(pi2).id));
    renderSanityFigure(pairs(pi2), figCache{vi}, outPng);
    fprintf('[FIG] sanity check %s\n', pairs(pi2).id);
end

% 7b. Representative examples (Phase 9) - documented, deterministic criteria
examples = pickExamples(recs, evalAny, CONFIG.rngSeed);
for e = 1:numel(examples)
    vi = examples(e).validPos; pi2 = validPos(vi);
    outPng = fullfile(outDir, 'visual_examples', ...
        sprintf('%02d_example_%s_%s.png', e, examples(e).kind, recs(vi).id));
    renderExampleFigure(recs(vi), pairs(pi2), figCache{vi}, outPng, CONFIG);
    fprintf('[FIG] example %s (%s)\n', recs(vi).id, examples(e).kind);
end

%% ---- 8. Machine-readable results (per-image CSV + MAT) ----
nRecs = numel(recs);
ids = {recs.id}'; splits = {recs.split}'; paths = {recs.imagePath}';
rowStatus = {recs.status}'; lesionTypesCol = {recs.lesionTypes}';
predLbl = {recs.predictedGradeLabel}'; predIdx = [recs.predictedClassIndex]';
conf = [recs.confidence]';
proxyGt  = double([recs.proxyGtReferable])';
modelRef = double([recs.modelReferable])';
proxyOk  = double([recs.proxyPredictionCorrect])';
massAll = [recs.massInAll]'; ptAll = [recs.pointAll]'; iouAllv = [recs.iouAll]';
iouMassAllv = [recs.iouMassAll]'; diceAllv = [recs.diceMassAll]';
nLes = [recs.nMaskPxAll]'; nAtt = [recs.nAttnPx]';
maskAreaAll = [recs.maskAreaFracAll]';
massRet = [recs.massOnRetina]'; attRet = [recs.attnOnRetina]';
skipCol = {recs.errorMsg}';
tn = {'ma', 'he', 'ex', 'se'};
massT = zeros(nRecs, 4); ptT = zeros(nRecs, 4); iouT = zeros(nRecs, 4); nMaskT = zeros(nRecs, 4);
for t = 1:4
    massT(:, t) = arrayfun(@(r) r.massIn(t), recs)';
    ptT(:, t)   = arrayfun(@(r) r.point(t), recs)';
    iouT(:, t)  = arrayfun(@(r) r.iou(t), recs)';
    nMaskT(:, t) = arrayfun(@(r) r.nMaskPx(t), recs)';
end
T = table(ids, splits, paths, rowStatus, lesionTypesCol, predLbl, predIdx, ...
    conf, proxyGt, modelRef, proxyOk, massAll, ptAll, iouAllv, iouMassAllv, ...
    diceAllv, nLes, nAtt, maskAreaAll, massRet, attRet, ...
    massT(:,1), ptT(:,1), iouT(:,1), nMaskT(:,1), ...
    massT(:,2), ptT(:,2), iouT(:,2), nMaskT(:,2), ...
    massT(:,3), ptT(:,3), iouT(:,3), nMaskT(:,3), ...
    massT(:,4), ptT(:,4), iouT(:,4), nMaskT(:,4), ...
    skipCol, 'VariableNames', {'image_id', 'split', 'image_path', 'status', ...
    'lesion_types', 'predicted_grade', 'predicted_class_index', 'confidence', ...
    'proxy_gt_referable', 'model_referable', 'proxy_prediction_correct', ...
    'saliency_mass_in_lesion', 'pointing_game_hit', 'iou', 'iou_mass_top20', ...
    'dice_mass_top20', 'num_lesion_pixels', 'num_attention_pixels', ...
    'mask_area_frac', 'saliency_mass_on_retina', 'attention_on_retina_frac', ...
    'ma_saliency_mass', 'ma_pointing_hit', 'ma_iou', 'ma_num_mask_px', ...
    'he_saliency_mass', 'he_pointing_hit', 'he_iou', 'he_num_mask_px', ...
    'ex_saliency_mass', 'ex_pointing_hit', 'ex_iou', 'ex_num_mask_px', ...
    'se_saliency_mass', 'se_pointing_hit', 'se_iou', 'se_num_mask_px', ...
    'skip_or_error_reason'});
writetable(T, fullfile(outDir, 'per_image_results.csv'));
runtimeSec = toc(tStart);
save(fullfile(outDir, 'gradcam_lesion_alignment.mat'), 'recs', 'agg', 'proxy', ...
    'blockedExact', 'audit', 'examples', 'sanityPick', 'validPos', 'CONFIG', ...
    'classNamesRaw', 'classMapNote', 'expectedAttnPx', 'shaBefore', ...
    'runtimeSec', 'predDist', '-v7');
fprintf('[SAVE] per_image_results.csv + gradcam_lesion_alignment.mat\n');

%% ---- 9. Quality / sanity assertions (Phase 12) ----
assert(strcmpi(sha256Hex(CONFIG.modelPath), CONFIG.expectedSha256), ...
    'Locked model SHA-256 changed during the run!');
assert(strcmpi(sha256Hex(CONFIG.modelPath), shaBefore), ...
    'Model file was modified during the run!');
assert(numel(unique({recs.id})) == numel(recs), 'duplicate image ids in results');
assert(all([recs(scored).nAttnPx] == expectedAttnPx), ...
    'attention-region size drifted from the fixed rule');
assert(all(isfinite([recs(find(evalAny)).iouAll])), ...
    'every evaluable row must have a finite IoU');
nonEval = find(scored & ~evalAny);
if ~isempty(nonEval)
    assert(all(isnan([recs(nonEval).massInAll])), ...
        'non-evaluable rows must carry NaN lesion metrics (documented), not 0');
end
errRows = find(~scored);
if ~isempty(errRows)
    assert(all(~strcmp({recs(errRows).errorMsg}, '')), ...
        'every error row must carry a documented reason');
end
for e = 1:numel(examples)
    vi = examples(e).validPos;
    assert(any(strcmp({recs.id}, recs(vi).id)) && evalAny(vi), ...
        'visual example %s must correspond to an evaluated CSV row', recs(vi).id);
    assert(abs(examples(e).iou - recs(vi).iouAll) < 1e-12, ...
        'visual example metrics must match the reported numbers');
end
fprintf('[CHECK] all sanity assertions passed\n');

%% ---- 10. Human-readable report (README.md) ----
R = struct('config', CONFIG, 'audit', audit, 'agg', agg, 'proxy', proxy, ...
    'blockedExact', blockedExact, 'examples', examples, 'evalAny', evalAny, ...
    'predDist', predDist, 'classMapNote', classMapNote, ...
    'shaBefore', shaBefore, 'runtimeSec', runtimeSec, ...
    'nScored', nScored, 'nError', nError, 'nValid', nValid, ...
    'sanityIds', {pairs(validPos(sanityPick)).id}, ...
    'expectedAttnPx', expectedAttnPx);
writeReport(R, outDir);

%% ---- 11. Final console summary ----
c = agg.combined;
fprintf('\n');
fprintf('========================================\n');
fprintf('DRISHTICARE GRAD-CAM LESION ALIGNMENT\n');
fprintf('========================================\n');
fprintf('Model:\n  Day-7 pretrained ResNet-18 5-class (LOCKED, SHA-256 verified)\n');
fprintf('Evaluation images:\n  %d valid lesion-mask pairs (train %d / test %d), scored %d, errors %d\n', ...
    nValid, audit.perSplit.train, audit.perSplit.test, nScored, nError);
fprintf('Grad-CAM layer:\n  %s\n', CONFIG.featLayer);
fprintf('Attention threshold:\n  Top %d%% of pixels by activation (fixed a priori)\n', ...
    round(CONFIG.topFracPx * 100));
fprintf('Overall (any lesion, n=%d):\n', c.n);
fprintf('  Saliency mass in lesion: %.1f%%\n', 100 * c.massMean);
fprintf('  Pointing-game accuracy:  %.1f%%\n', 100 * c.pointAcc);
fprintf('  Mean IoU:                %.3f\n', c.iouMean);
fprintf('MA (n=%d):  mass %.1f%% / point %.1f%% / IoU %.3f\n', agg.ma.n, ...
    100 * agg.ma.massMean, 100 * agg.ma.pointAcc, agg.ma.iouMean);
fprintf('HE (n=%d):  mass %.1f%% / point %.1f%% / IoU %.3f\n', agg.he.n, ...
    100 * agg.he.massMean, 100 * agg.he.pointAcc, agg.he.iouMean);
fprintf('EX (n=%d):  mass %.1f%% / point %.1f%% / IoU %.3f\n', agg.ex.n, ...
    100 * agg.ex.massMean, 100 * agg.ex.pointAcc, agg.ex.iouMean);
fprintf('SE (n=%d):  mass %.1f%% / point %.1f%% / IoU %.3f\n', agg.se.n, ...
    100 * agg.se.massMean, 100 * agg.se.pointAcc, agg.se.iouMean);
fprintf('Proxy-correct predictions (n=%d):\n', agg.proxyCorrect.n);
fprintf('  Saliency mass = %.1f%%, Pointing = %.1f%%, IoU = %.3f\n', ...
    100 * agg.proxyCorrect.massMean, 100 * agg.proxyCorrect.pointAcc, ...
    agg.proxyCorrect.iouMean);
fprintf('Proxy-incorrect predictions (n=%d):\n', agg.proxyIncorrect.n);
fprintf('  Saliency mass = %.1f%%, Pointing = %.1f%%, IoU = %.3f\n', ...
    100 * agg.proxyIncorrect.massMean, 100 * agg.proxyIncorrect.pointAcc, ...
    agg.proxyIncorrect.iouMean);
fprintf('Exact 5-class correct/incorrect split: NOT COMPUTABLE (no IDRiD grades\n');
fprintf('for the segmentation set - see README for the proxy definition)\n');
fprintf('Outputs: %s\n', outDir);
fprintf('Runtime: %.1f s\n', runtimeSec);
fprintf('========================================\n');
try
    diary off;
catch
end

%% ===================== local functions =====================
function rec = newRec(p)
%NEWREC Field-complete per-image record (default = not scored / NaN).
    rec = struct('id', p.id, 'split', p.split, 'imagePath', p.imagePath, ...
        'status', 'error', 'errorMsg', 'not scored', ...
        'predClassName', '', 'predictedGrade', -1, 'predictedGradeLabel', '', ...
        'predictedClassIndex', -1, 'confidence', NaN, 'scores', NaN(1, 5), ...
        'proxyGtReferable', false, 'modelReferable', false, ...
        'proxyPredictionCorrect', false, ...
        'lesionTypes', p.lesionTypes, 'nLesionTypes', p.nLesionTypes, ...
        'massIn', NaN(1, 4), 'point', NaN(1, 4), 'iou', NaN(1, 4), ...
        'iouMass', NaN(1, 4), 'diceMass', NaN(1, 4), 'nMaskPx', zeros(1, 4), ...
        'maskAreaFrac', NaN(1, 4), ...
        'massInAll', NaN, 'pointAll', NaN, 'iouAll', NaN, 'iouMassAll', NaN, ...
        'diceMassAll', NaN, 'nMaskPxAll', 0, 'maskAreaFracAll', NaN, ...
        'nAttnPx', 0, 'massOnRetina', NaN, 'attnOnRetina', NaN, ...
        'retMaskValid', false, 'salMax', NaN, 'salMin', NaN, ...
        'cmapResized', false);
end

function [rec, cache] = scoreOneImage(p, net, CONFIG, outH, outW, gradeOf)
%SCOREONEIMAGE One image: preprocess -> predict -> Grad-CAM -> metrics.
%   Uses EXACTLY the inference preprocessing of predictSingleFundus.m and
%   the built-in gradCAM on the locked network (read-only, CPU).
    % --- EXACT inference preprocessing ---
    raw = imread(p.imagePath);
    if size(raw, 3) == 1
        raw = repmat(raw, 1, 1, 3);
    end
    modelInput = imresize(raw, [outH outW]);       % same call as inference
    % --- lesion masks -> model grid (same output-size resize, nearest) ---
    masks224 = false(outH, outW, 4);
    for t = 1:4
        if p.maskExists(t) && p.maskReadable(t)
            mfull = imread(p.maskPaths{t});
            masks224(:, :, t) = lesion_mask_to_model_grid(mfull, [outH outW]);
        end
    end
    % --- prediction (read-only model use) ---
    [predLbl, sc] = classify(net, modelInput);
    sc = sc(:)';
    [~, clsIdx] = max(sc);
    grade = gradeOf(char(predLbl));
    gradeLabel = CONFIG.gradeLabels{grade + 1};
    % --- Grad-CAM (built-in, CPU, verified feature layer) ---
    cmap = gradCAM(net, modelInput, clsIdx, 'FeatureLayer', CONFIG.featLayer, ...
                   'ExecutionEnvironment', 'cpu');
    cmap = double(cmap);
    cmapResized = false;
    if size(cmap, 1) ~= outH || size(cmap, 2) ~= outW
        cmap = imresize(cmap, [outH outW], 'bilinear');   % documented fallback
        cmapResized = true;
    end
    assert(all(isfinite(cmap(:))), 'Grad-CAM map contains NaN/Inf');
    sal = mat2gray(cmap);                          % as in gradcamExplain.m
    salSum = sum(sal(:));
    assert(salSum > 0, 'degenerate (zero) saliency map');   % -> logged error
    % --- metrics ---
    anyMask = any(masks224, 3);
    mAny = saliency_lesion_metrics(sal, anyMask, CONFIG.topFracPx, CONFIG.topFracMass);
    rec = newRec(p);
    rec.status = 'scored'; rec.errorMsg = '';
    rec.predClassName = char(predLbl); rec.predictedGrade = grade;
    rec.predictedGradeLabel = gradeLabel; rec.predictedClassIndex = clsIdx;
    rec.confidence = sc(clsIdx); rec.scores = sc;
    rec.proxyGtReferable = mAny.nMaskPx > 0;
    rec.modelReferable = grade >= 2;
    rec.proxyPredictionCorrect = (grade >= 2) == (mAny.nMaskPx > 0);
    for t = 1:4
        mm = saliency_lesion_metrics(sal, masks224(:, :, t), ...
            CONFIG.topFracPx, CONFIG.topFracMass);
        rec.massIn(t) = mm.massIn;     rec.point(t) = mm.point;
        rec.iou(t) = mm.iou;           rec.iouMass(t) = mm.iouMass;
        rec.diceMass(t) = mm.diceMass; rec.nMaskPx(t) = mm.nMaskPx;
        rec.maskAreaFrac(t) = mm.maskAreaFrac;
    end
    rec.massInAll = mAny.massIn;   rec.pointAll = mAny.point;
    rec.iouAll = mAny.iou;         rec.iouMassAll = mAny.iouMass;
    rec.diceMassAll = mAny.diceMass; rec.nMaskPxAll = mAny.nMaskPx;
    rec.maskAreaFracAll = mAny.maskAreaFrac; rec.nAttnPx = mAny.nAttnPx;
    % --- retina confound (same helper as the T6 study) ---
    [retMask, retValid] = createRetinalMask(modelInput);
    retMask = logical(retMask);
    rec.retMaskValid = retValid;
    rec.massOnRetina = sum(sal(retMask)) / salSum;
    if mAny.nAttnPx > 0
        rec.attnOnRetina = nnz(mAny.attn & retMask) / mAny.nAttnPx;
    end
    rec.salMax = max(sal(:)); rec.salMin = min(sal(:));
    rec.cmapResized = cmapResized;
    % --- figure cache (small; used only for post-loop visualization) ---
    [~, maxIdx] = max(sal(:));
    [pr, pc] = ind2sub([outH outW], maxIdx);
    cache = struct('modelInput', modelInput, 'sal', sal, 'masks224', masks224, ...
        'pointRC', [pr pc], 'attn', mAny.attn);
end

function [gradeOf, classNamesRaw, mapNote] = resolveClassMapping(net)
%RESOLVECLASSMAPPING Map network class names -> semantic DR grades 0..4.
%   Handles both folder-style names (class_0..class_4) and label-style
%   names; the actual mapping is recorded in the outputs.
    classNamesRaw = string(net.Layers(end).Classes);
    nC = numel(classNamesRaw);
    assert(nC == 5, 'Expected 5 classes, got %d', nC);
    grades = nan(nC, 1);
    for i = 1:nC
        nm = lower(char(classNamesRaw(i)));
        tok = regexp(nm, '(\d+)\s*$', 'tokens', 'once');
        if ~isempty(tok)
            grades(i) = str2double(tok{1});
        elseif contains(nm, 'mild')
            grades(i) = 1;
        elseif contains(nm, 'moderate')
            grades(i) = 2;
        elseif contains(nm, 'severe')
            grades(i) = 3;
        elseif contains(nm, 'prolif')
            grades(i) = 4;
        elseif contains(nm, 'no') && (contains(nm, 'dr') || ...
                contains(nm, 'diabet') || contains(nm, 'retinopath'))
            grades(i) = 0;
        end
    end
    assert(all(~isnan(grades)), ...
        'Cannot map class names {%s} to semantic grades', ...
        strjoin(classNamesRaw, ', '));
    assert(numel(unique(grades)) == 5, ...
        'Class-name grade mapping is not a bijection: %s', mat2str(grades));
    gradeOf = containers.Map(cellstr(classNamesRaw), num2cell(grades));
    mapNote = sprintf('%s -> grades %s', strjoin(classNamesRaw, ', '), ...
        mat2str(grades'));
end

function s = poolStats(mass, point, iou, iouMass, dice, area)
%POOLSTATS Aggregate a pooled image set (mean/median/std/chance ratios).
    s = struct('n', numel(mass), 'massMean', NaN, 'massMedian', NaN, ...
        'massStd', NaN, 'pointAcc', NaN, 'iouMean', NaN, 'iouMedian', NaN, ...
        'iouStd', NaN, 'iouMassMean', NaN, 'diceMean', NaN, ...
        'chanceMassMean', NaN, 'chancePointMean', NaN, ...
        'xChanceMass', NaN, 'xChancePoint', NaN);
    if s.n == 0
        return;
    end
    m   = mass(isfinite(mass));
    p   = point(isfinite(point));
    iv  = iou(isfinite(iou));
    imv = iouMass(isfinite(iouMass));
    dv  = dice(isfinite(dice));
    av  = area(isfinite(area));
    s.massMean = mean(m); s.massMedian = median(m); s.massStd = std(m);
    s.pointAcc = mean(p);
    s.iouMean = mean(iv); s.iouMedian = median(iv); s.iouStd = std(iv);
    s.iouMassMean = mean(imv); s.diceMean = mean(dv);
    s.chanceMassMean = mean(av);
    s.chancePointMean = s.chanceMassMean;
    s.xChanceMass = s.massMean / max(s.chanceMassMean, eps);
    s.xChancePoint = s.pointAcc / max(s.chancePointMean, eps);
end

function examples = pickExamples(recs, evalAny, seed)
%PICKEXAMPLES Deterministic, documented example selection (no cherry-picking).
%   best_alignment    : highest combined IoU
%   worst_alignment   : lowest combined IoU
%   median_alignment  : combined IoU closest to the median
%   proxy_correct_random / proxy_incorrect_random : seeded rng picks
    examples = struct('kind', {}, 'validPos', {}, 'id', {}, 'iou', {}, ...
        'mass', {}, 'point', {});
    idxEval = find(evalAny);
    ious = [recs(idxEval).iouAll];
    [~, orderDesc] = sort(ious, 'descend');
    addExample = @(kind, vp) struct('kind', kind, 'validPos', vp, ...
        'id', recs(vp).id, 'iou', recs(vp).iouAll, 'mass', recs(vp).massInAll, ...
        'point', recs(vp).pointAll);
    examples(end+1) = addExample('best_alignment', idxEval(orderDesc(1))); %#ok<AGROW>
    examples(end+1) = addExample('worst_alignment', idxEval(orderDesc(end))); %#ok<AGROW>
    medIou = median(ious);
    [~, midPos] = min(abs(ious - medIou));
    examples(end+1) = addExample('median_alignment', idxEval(midPos)); %#ok<AGROW>
    rng(seed + 1, 'twister');
    selC = find(evalAny & [recs.proxyPredictionCorrect]);
    if ~isempty(selC)
        examples(end+1) = addExample('proxy_correct_random', ...
            selC(randi(numel(selC)))); %#ok<AGROW>
    end
    selI = find(evalAny & ~[recs.proxyPredictionCorrect]);
    if ~isempty(selI)
        examples(end+1) = addExample('proxy_incorrect_random', ...
            selI(randi(numel(selI)))); %#ok<AGROW>
    end
end

function renderSanityFigure(p, cache, outPng)
%RENDERSANITYFIGURE Phase-5 check: does the transformed mask stay aligned?
%   Left column: original resolution (image, image+full-res GT).
%   Right column: model input grid (input, input+nearest-resized GT).
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1300 950]);
    orig = imread(p.imagePath);
    if size(orig, 3) == 1, orig = repmat(orig, 1, 1, 3); end
    subplot(2, 2, 1); imshow(orig, 'InitialMagnification', 'fit');
    title({'Original image', sprintf('%s (%s, %dx%d px)', p.id, p.split, ...
        size(orig, 1), size(orig, 2))}, 'Interpreter', 'none');
    gtFull = fullResCombinedMask(p);
    subplot(2, 2, 2);
    ov1 = tintOverlay(im2double(orig), gtFull, [0 0.85 0], 0.45);
    imshow(ov1, 'InitialMagnification', 'fit');
    title({'Original + doctor lesion GT (green)', ...
        sprintf('types: %s', strrep(p.lesionTypes, '+', ' + '))}, ...
        'Interpreter', 'none');
    subplot(2, 2, 3); imshow(cache.modelInput);
    title({'Model input 224x224', '(imresize, identical to inference)'});
    subplot(2, 2, 4);
    any224 = any(cache.masks224, 3);
    ov2 = tintOverlay(im2double(cache.modelInput), any224, [0 0.85 0], 0.45);
    imshow(ov2); hold on;
    plot(cache.pointRC(2), cache.pointRC(1), 'w*', 'MarkerSize', 13, 'LineWidth', 1.2);
    title({'Model input + transformed lesion GT (nearest)', ...
        sprintf('* = Grad-CAM argmax pixel (row %d, col %d)', ...
        cache.pointRC(1), cache.pointRC(2))});
    print(fig, outPng, '-dpng', '-r200');
    close(fig);
end

function renderExampleFigure(rec, p, cache, outPng, CONFIG)
%RENDEREXAMPLEFIGURE Four-panel presentation figure for one representative case.
    orig = imread(p.imagePath);
    if size(orig, 3) == 1, orig = repmat(orig, 1, 1, 3); end
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [30 30 1500 1050]);
    % Panel 1: original image
    subplot(2, 2, 1); imshow(orig, 'InitialMagnification', 'fit');
    title({'1) Original fundus image', ...
        sprintf('%s (%s split)', rec.id, rec.split)}, 'Interpreter', 'none');
    % Panel 2: doctor lesion GT at full resolution
    gtFull = fullResCombinedMask(p);
    subplot(2, 2, 2);
    ovG = tintOverlay(im2double(orig), gtFull, [0 0.85 0], 0.45);
    imshow(ovG, 'InitialMagnification', 'fit');
    title({'2) Doctor-annotated lesion mask (green)', ...
        sprintf('types: %s', strrep(rec.lesionTypes, '+', ' + '))}, ...
        'Interpreter', 'none');
    % Panel 3: Grad-CAM heatmap
    subplot(2, 2, 3);
    hrgb = ind2rgb(im2uint8(cache.sal), jet(256));
    imshow(hrgb); hold on;
    plot(cache.pointRC(2), cache.pointRC(1), 'w*', 'MarkerSize', 14, 'LineWidth', 1.3);
    title({'3) Grad-CAM heatmap (model input, 224x224)', ...
        sprintf('layer %s | predicted %s (p=%.2f) | * = argmax pixel', ...
        CONFIG.featLayer, rec.predictedGradeLabel, rec.confidence)}, ...
        'Interpreter', 'none');
    % Panel 4: agreement/disagreement overlay
    subplot(2, 2, 4);
    anyMask = any(cache.masks224, 3);
    ov4 = buildPanel4(cache.modelInput, anyMask, cache.attn);
    imshow(ov4); hold on;
    plot(cache.pointRC(2), cache.pointRC(1), 'w*', 'MarkerSize', 14, 'LineWidth', 1.3);
    if rec.proxyPredictionCorrect
        proxyStr = 'proxy-correct';
    else
        proxyStr = 'proxy-incorrect';
    end
    title({'4) Lesion GT vs AI attention (224x224 grid)', ...
        sprintf('IoU=%.3f | saliency mass in lesion=%.3f | pointing game=%d | %s', ...
        rec.iouAll, rec.massInAll, rec.pointAll, proxyStr)}, 'Interpreter', 'none');
    annotation(fig, 'textbox', [0 0.955 1 0.045], 'String', ...
        sprintf('GT lesion (green) | AI attention top-20%% (red) | overlap (yellow) | proxy: %s - engineering analysis, NOT clinical validation', ...
        proxyStr), 'EdgeColor', 'none', 'FontSize', 11, 'HorizontalAlignment', 'center');
    print(fig, outPng, '-dpng', '-r300');
    close(fig);
end

function mk = fullResCombinedMask(p)
%FULLRESCOMBINEDMASK Union of MA/HE/EX/SE masks at original resolution.
    mk = [];
    for t = 1:4
        if p.maskExists(t) && p.maskReadable(t)
            m = imread(p.maskPaths{t});
            if ndims(m) > 2, m = m(:, :, 1); end
            mb = double(m) > 0;
            if isempty(mk)
                mk = false(size(mb));
            end
            mk = mk | mb;
        end
    end
end

function ov = buildPanel4(modelInput, anyMask, attn)
%BUILDPANEL4 Overlay: GT (green), AI attention (red), agreement (yellow).
    base = im2double(modelInput);
    ov = base;
    ov = tintOverlay(ov, attn & ~anyMask, [1 0.15 0.15], 0.40);  % AI only
    ov = tintOverlay(ov, anyMask & ~attn, [0 0.8 0], 0.40);      % GT only
    ov = tintOverlay(ov, anyMask & attn,  [1 1 0], 0.55);        % agreement
    lesB = bwperim(anyMask);
    attB = bwperim(attn);
    colL = [0 0.9 0]; colA = [1 0 0];
    for c = 1:3
        ch = ov(:, :, c);
        ch(lesB & ~attB) = colL(c);
        ch(attB & ~lesB) = colA(c);
        ch(lesB & attB) = 1;                 % white where boundaries meet
        ov(:, :, c) = ch;
    end
end

function ov = tintOverlay(base, mask, color, alpha)
%TINTOVERLAY Alpha-blend a solid colour where mask is true.
    ov = base;
    for c = 1:3
        ch = ov(:, :, c);
        ch(mask) = (1 - alpha) * ch(mask) + alpha * color(c);
        ov(:, :, c) = ch;
    end
end

%% PLACEHOLDER_REST4










