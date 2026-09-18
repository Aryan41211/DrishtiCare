function eval_branchb_fullval_T7()
%EVAL_BRANCHB_FULLVAL_T7 Task 7 (Stage 4): Branch B on the FULL 733-image val set.
%   Evaluates the EXISTING Branch B lesion-feature classifier (trained on the
%   250-image train subsample) on the full 733 validation images with FULL
%   lesion-feature extraction cost. NO retraining. Thresholds unchanged.
%   Reuses Branch A predictions from reverify_audit_T0.mat (no re-inference).
%
%   Outputs:
%     data/analysis/day8/task7/branchb_cache_partial.mat  (resumable cache)
%     data/analysis/day8/task7/branchb_fullval_T7.mat     (final results)
%
%   Feature extraction is SLOW (~8 s/img avg => 1.5-2.5 h). The partial cache
%   allows resume: rows with done=true are skipped on re-run.

projectRoot = 'C:\projects\DrishtiCare';
cd(projectRoot);
addpath(genpath(fullfile(projectRoot, 'src')));

root = fullfile('data', 'analysis', 'day8', 'task7');
if ~exist(root, 'dir'), mkdir(root); end
cacheFile = fullfile(root, 'branchb_cache_partial.mat');
outFile   = fullfile(root, 'branchb_fullval_T7.mat');
thr       = 0.60;  % locked decision threshold (unchanged)

%% ---- 1. Enumerate the 733 val images (same sorted order as re_verify_audit) ----
valDS = imageDatastore(fullfile('data', 'splits', 'val'), ...
    'IncludeSubfolders', true);
valDS.Files = sort(valDS.Files);
n = numel(valDS.Files);
fprintf('Task 7: %d validation images to process (sorted listing)\n', n);
if n ~= 733
    error('eval_branchb_fullval_T7: expected 733 val images, found %d', n);
end

% Grade from the class_<g> folder name WITHOUT fileparts (broken in this build)
grade = zeros(n, 1);
for i = 1:n
    parts = strsplit(valDS.Files{i}, filesep);
    gi = find(~cellfun(@isempty, regexp(parts, '^class_[0-4]$')), 1);
    if isempty(gi)
        error('eval_branchb_fullval_T7: no class_<g> folder in %s', valDS.Files{i});
    end
    grade(i) = str2double(strrep(parts{gi}, 'class_', ''));
end

%% ---- 2. Extract lesion features (full cost), resumable ----
X = zeros(n, 10);
done = false(n, 1); failed = false(n, 1);
extractionTimeSec = 0;
if exist(cacheFile, 'file')
    C = load(cacheFile, 'X', 'done', 'grade', 'failed', 'extractionTimeSec');
    if numel(C.done) == n
        X = C.X; done = C.done; grade = C.grade; failed = C.failed;
        if isfield(C, 'extractionTimeSec'), extractionTimeSec = C.extractionTimeSec; end
        fprintf('Resuming: %d/%d rows already extracted\n', sum(done), n);
    end
end

tStart = tic;
for i = 1:n
    if done(i), continue; end
    imgPath = valDS.Files{i};
    tImg = tic;
    odOk = false; odc = []; odr = 0;
    try
        [cx, cy, r, ~] = locateOpticDiscCnn(imread(imgPath));
        odOk = ~isempty(cx) && numel(cx) == 1 && cx > 0;
        if odOk, odc = [cx cy]; odr = r; end
    catch
        odOk = false;
    end
    try
        f = extractLesionCandidates(imgPath, struct('returnVisual', false, 'verbose', false, ...
                                                    'odCenter', odc, 'odRadius', odr));
        q = f.quadrantHemorrhage; if isempty(q), q = zeros(1, 4); end
        row = zeros(1, 10);
        row(1)  = f.microaneurysms.count;
        row(2)  = f.haemorrhages.count;
        row(3)  = f.exudates.count;
        row(4:7) = q;
        row(8)  = double(odOk);
        ed = f.exudates.centroidX; ey = f.exudates.centroidY;
        if odOk && ~isempty(ed)
            if isempty(odr) || odr <= 0, odr = 0; end
            dthr = 1.5 * max(odr, 50);
            d = sqrt(sum(([ed; ey] - [odc(1); odc(2)]).^2, 1));
            row(9)  = double(sum(d <= dthr));
            row(10) = mean(d);
        end
        X(i, :) = row;
        failed(i) = false;
    catch me
        X(i, :) = zeros(1, 10);
        failed(i) = true;
        fprintf('  WARN row %d (%s) extraction failed: %s\n', i, imgPath, me.message);
    end
    done(i) = true;
    extractionTimeSec = extractionTimeSec + toc(tImg);
    if mod(sum(done), 25) == 0 || i == n
        ids = valDS.Files;
        save(cacheFile, 'X', 'ids', 'done', 'grade', 'failed', 'extractionTimeSec', '-v7');
        nDone = sum(done);
        el = toc(tStart);
        avg = el / max(nDone, 1);
        eta = avg * (n - nDone);
        fprintf('  %d/%d done (%.0f s elapsed, avg %.1f s/img, ETA ~%.0f min)\n', ...
            nDone, n, el, avg, eta / 60);
    end
end
if sum(done) == n && ~failed(1) % final save of the complete cache
    ids = valDS.Files;
    save(cacheFile, 'X', 'ids', 'done', 'grade', 'failed', 'extractionTimeSec', '-v7');
end
fprintf('Extraction complete: %d rows (%.1f s total, failed=%d)\n', ...
    n, extractionTimeSec, sum(failed));

%% ---- 3. Branch B predictions (reuse existing model, NO retraining) ----
SBB = load(fullfile('data', 'analysis', 'day8', 'branch_b', 'branchB_model.mat'));
mdl = SBB.model;
pRefB = zeros(n, 1);
for i = 1:n
    pRefB(i) = branch_b_predict(X(i, :), mdl);
end

%% ---- 4. Branch A predictions (reuse audit T0; no re-inference) ----
A = load(fullfile('data', 'analysis', 'day8', 'reverify_audit_T0.mat'), ...
         'PRef', 'YTrue5', 'YPred5', 's5All');
PRef = A.PRef; YTrue5 = A.YTrue5; YPred5 = A.YPred5; s5All = A.s5All;
if numel(PRef) ~= n
    error('eval_branchb_fullval_T7: audit PRef length %d, expected %d', numel(PRef), n);
end

% Alignment cross-check: folder grade must equal audit gold grade (YTrue5-1)
alignMiss = sum(grade ~= YTrue5 - 1);
fprintf('Alignment check (grade vs YTrue5-1): %d mismatches / %d rows\n', alignMiss, n);
if alignMiss > 0
    fprintf('  WARNING: order mismatch; results may be misaligned. Inspect before trusting.\n');
end

yRef   = YTrue5 >= 3;   % referable = Moderate/Severe/Proliferative (grade>=2)
goldGrade = YTrue5 - 1;

%% ---- 5. Metrics ----
[~, ~, ~, aucB] = perfcurve(yRef, pRefB, true);
[~, ~, ~, aucA] = perfcurve(yRef, PRef, true);
matchRate = mean((PRef >= thr) == (pRefB >= thr));

perGrade = zeros(5, 1); perGradeN = zeros(5, 1);
for g = 0:4
    idx = goldGrade == g;
    perGradeN(g + 1) = sum(idx);
    perGrade(g + 1)  = mean(pRefB(idx));
end

nARef    = sum(PRef >= thr);
nARefBAg = sum(PRef >= thr & pRefB >= thr);
nANonRef    = sum(PRef < thr);
nANonRefBAg = sum(PRef < thr & pRefB < thr);

odLocatedMean = mean(X(:, 8));

%% ---- 6. Fusion per image (call fuseEvidence exactly as predictSingleFundus) ----
Tcal = loadTemperatureParams();
nAgree = 0; nDiscrepancy = 0; nRows = n;
for i = 1:n
    aInfo.grade     = YPred5(i) - 1;              % predicted grade 0-4
    aInfo.pRefCal   = temperatureScale(PRef(i), Tcal);  % calibrated P referable
    aInfo.confident = max(s5All(i, :)) >= 0.80;   % conf = max 5-class softmax
    bInfo.pRefB     = pRefB(i);
    bInfo.available = true;
    [ag, dis, ~] = fuseEvidence(aInfo, bInfo);
    nAgree = nAgree + double(ag);
    nDiscrepancy = nDiscrepancy + double(dis);
end

%% ---- 7. Report + save ----
fprintf('\n');
fprintf('==============================================================\n');
fprintf('  TASK 7 - BRANCH B FULL-VAL (733) RESULTS\n');
fprintf('==============================================================\n');
fprintf('  Branch B AUC (full 733)  : %.4f\n', aucB);
fprintf('  Branch A AUC (recheck)   : %.4f  (audit day7 = 0.9796)\n', aucA);
fprintf('  Match rate @0.60         : %.4f\n', matchRate);
fprintf('  A referable n=%d,   B agrees %d (%.1f%%)\n', nARef, nARefBAg, 100 * nARefBAg / max(nARef, 1));
fprintf('  A non-referable n=%d, B agrees %d (%.1f%%)\n', nANonRef, nANonRefBAg, 100 * nANonRefBAg / max(nANonRef, 1));
fprintf('  Fusion: agree %d, discrepancy/REVIEW %d (of %d)\n', nAgree, nDiscrepancy, nRows);
fprintf('  Per-grade mean pRefB [g0..g4] = %s\n', sprintf('%.4f ', perGrade(:)'));
    fprintf('  Per-grade n        [g0..g4] = %s\n', sprintf('%.0f ', perGradeN(:)'));
fprintf('  odLocated mean = %.4f\n', odLocatedMean);
fprintf('  Extraction time = %.0f s (~%.2f h) for %d images (failed=%d)\n', ...
    extractionTimeSec, extractionTimeSec / 3600, n, sum(failed));
fprintf('  Tree: aucB.%.4f aucA.%.4f match.%.4f agree.%d dis.%d od%.2f\n', ...
    aucB, aucA, matchRate, nAgree, nDiscrepancy, odLocatedMean);
fprintf('==============================================================\n');

save(outFile, 'X', 'pRefB', 'PRef', 'YTrue5', 'grade', 'goldGrade', ...
     'aucB', 'aucA', 'matchRate', 'perGrade', 'perGradeN', ...
     'nAgree', 'nDiscrepancy', 'nRows', 'nARef', 'nARefBAg', ...
     'nANonRef', 'nANonRefBAg', 'odLocatedMean', 'extractionTimeSec', ...
     'failed', 'alignMiss', 'Tcal');
fprintf('Saved %s\n', outFile);
end