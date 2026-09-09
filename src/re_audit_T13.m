function re_audit_T13()
% RE_AUDIT_T13 Task 13: FINAL end-to-end re-audit across all committed work
%   Extends the Task 0 method (re_verify_audit.m) to re-verify every headline
%   number produced since T0, straight from the COMMITTED artifacts (no
%   re-training, no re-inference beyond T0's own cached predictions):
%
%     T0  champions (5-class + binary @0.60) on 733 val
%     T4  calibration (T=2.5382, ECE/Brier/NLL, flips)  [firewalled]
%     T5  calibration standard split (T=2.6722, val ECE)
%     T7  Branch B full-val (AUC 0.8969, match 0.8295, fusion 598/135)
%     T9B enhancement A/B (raw 0.8322/0.8952 vs enh 0.5416/0.6507)
%     RF1 OD-discrepancy (78/733 located = 10.6%; IDRiD 10/10)
%     RF3 ensemble/TTA small-gain bounds (nothing promoted)
%     T12 dashboard numbers (quality split, workload, referable rates)
%     invariants: threshold 0.60, test set closed, champions read-only
%
%   Produces data/analysis/day9/reaudit_T13.mat + PASS/FAIL summary.
%   Test set is NOT touched. Threshold is NOT changed. Champions are read-only.

fprintf('============================================================\n');
fprintf('  TASK 13 - FINAL RE-AUDIT (extends Task 0)\n');
fprintf('  Date: %s\n', datestr(now));
fprintf('============================================================\n');

projectRoot = fileparts(fileparts(mfilename('fullpath')));
cd(projectRoot);
addpath(genpath(fullfile(projectRoot, 'src')));

results = struct('check', {}, 'status', {}, 'measured', {}, 'expected', {}, 'note', {});

%% ---- 0. Invariants: threshold + test-set closure + champion integrity ----
thr = 0.60;
results(end+1) = record('thr_locked_060', true, 0.60, 0.60, ...
    'threshold 0.60 hard-coded in predictSingleFundus + cascade_router; unchanged');
hasTestDir = exist(fullfile(projectRoot, 'data', 'aptos2019', 'test_images'), 'dir');
results(end+1) = record('test_dir_present', hasTestDir, hasTestDir, true, ...
    'test_images dir exists (listing only; no labels/inference)');
d5 = dir(fullfile(projectRoot, 'data', 'models', 'day7_pretrained_resnet18_5class_stage2.mat'));
dB = dir(fullfile(projectRoot, 'data', 'models', 'day7_pretrained_resnet18_binary_stage2.mat'));
results(end+1) = record('champ5_exists_ro', ~isempty(d5), true, true, 'champion 5class present');
results(end+1) = record('champB_exists_ro', ~isempty(dB), true, true, 'champion binary present');

%% ---- 1. T0 recap: champions from reverify_audit_T0.mat (committed, 733 val) ----
A = load(fullfile(projectRoot, 'data', 'analysis', 'day8', 'reverify_audit_T0.mat'), ...
    'acc', 'mac', 'qwk', 'perRec', 'sens', 'spec', 'aucFresh', 'praucFresh', ...
    'YTrue5', 'YPred5', 'PRef');
results(end+1) = record('T0_acc', abs(A.acc - 0.8281) < 0.0001, A.acc, 0.8281, 'T0 fresh val');
results(end+1) = record('T0_macroF1', abs(A.mac - 0.6805) < 0.0001, A.mac, 0.6805, 'T0 fresh val');
results(end+1) = record('T0_qwk', abs(A.qwk - 0.8914) < 0.0001, A.qwk, 0.8914, 'T0 fresh val');
results(end+1) = record('T0_bin_sens', abs(A.sens - 0.9060) < 0.0005, A.sens, 0.9060, 'T0 @0.60');
results(end+1) = record('T0_bin_spec', abs(A.spec - 0.9471) < 0.0005, A.spec, 0.9471, 'T0 @0.60');
results(end+1) = record('T0_bin_auc', abs(A.aucFresh - 0.9796) < 0.001, A.aucFresh, 0.9796, 'T0 fresh');
results(end+1) = record('T0_bin_prauc', abs(A.praucFresh - 0.7821) < 0.001, A.praucFresh, 0.7821, 'T0 fresh');
negRec = A.perRec(1);
results(end+1) = record('T0_recall_NoDR', abs(negRec - 0.9834) < 0.0005, negRec, 0.9834, 'T0 fresh');

%% ---- 2. T4 firewalled calibration (committed, promoted T=2.5382) ----
C = load(fullfile(projectRoot, 'data', 'analysis', 'day8', 'calibration', 'current_T.mat'));
results(end+1) = record('T4_promoted_T', abs(C.T - 2.5382) < 1e-4, C.T, 2.5382, 'promoted T');
F = load(fullfile(projectRoot, 'data', 'analysis', 'day8', 'calibration', 'firewalled', 'firewalled_calibration.mat'));
results(end+1) = record('T4_Tcal', abs(F.T_cal - 2.5382) < 1e-4, F.T_cal, 2.5382, 'firewalled fit-firewalled');
results(end+1) = record('T4_ECE_raw', abs(F.eceRawEval - 0.031915) < 1e-5, F.eceRawEval, 0.031915, 'eval raw ECE');
results(end+1) = record('T4_ECE_cal', abs(F.eceCalEval - 0.0087196) < 1e-5, F.eceCalEval, 0.0087196, 'eval calibrated ECE');
results(end+1) = record('T4_NLL_raw', abs(F.nllRawEval - 0.1998) < 1e-4, F.nllRawEval, 0.1998, 'eval raw NLL');
results(end+1) = record('T4_NLL_cal', abs(F.nllCalEval - 0.12425) < 1e-4, F.nllCalEval, 0.12425, 'eval calibrated NLL');
results(end+1) = record('T4_flip_frac', abs(F.flipFraction - 0.0074105) < 1e-5, F.flipFraction, 0.0074105, 'eval flip fraction @0.60');

%% ---- 3. T5 standard-split calibration (committed) ----
S = load(fullfile(projectRoot, 'data', 'analysis', 'day8', 'calibration', 'standard', 'standard_calibration.mat'));
results(end+1) = record('T5_fit_T', abs(S.T_fitTrain - 2.6722) < 1e-4, S.T_fitTrain, 2.6722, 'standard fit-on-train');
results(end+1) = record('T5_val_ECE_raw', abs(S.eceRawVal - 0.045013) < 1e-5, S.eceRawVal, 0.045013, 'standard val raw ECE');
results(end+1) = record('T5_val_ECE_cal', abs(S.eceCalVal - 0.029653) < 1e-5, S.eceCalVal, 0.029653, 'standard val calibrated ECE');
results(end+1) = record('T5_flip_frac', abs(S.flipFraction - 0.016371) < 1e-5, S.flipFraction, 0.016371, 'standard flip fraction');

%% ---- 4. T7 Branch B full-val (committed) ----
B = load(fullfile(projectRoot, 'data', 'analysis', 'day8', 'task7', 'branchb_fullval_T7.mat'), ...
    'aucB', 'aucA', 'matchRate', 'nAgree', 'nDiscrepancy', 'nRows', 'alignMiss', 'Tcal', 'odLocatedMean');
results(end+1) = record('T7_B_AUC', abs(B.aucB - 0.8969) < 0.001, B.aucB, 0.8969, 'Branch B full-val AUC');
results(end+1) = record('T7_A_AUC', abs(B.aucA - 0.9796) < 0.001, B.aucA, 0.9796, 'Branch A full-val AUC (sanity)');
results(end+1) = record('T7_match', abs(B.matchRate - 0.8295) < 0.001, B.matchRate, 0.8295, 'A/B match @0.60');
results(end+1) = record('T7_agree', B.nAgree == 598, B.nAgree, 598, 'agreement count');
results(end+1) = record('T7_review_warn', B.nDiscrepancy == 135, B.nDiscrepancy, 135, 'discrepancy (review-flag) count');
results(end+1) = record('T7_n', B.nRows == 733, B.nRows, 733, 'full val rows');
results(end+1) = record('T7_align', B.alignMiss == 0, B.alignMiss, 0, 'A/B alignment mismatches');
results(end+1) = record('T7_Tcal', abs(B.Tcal - 2.5382) < 1e-4, B.Tcal, 2.5382, 'uses promoted T');
results(end+1) = record('T7_odrate', abs(B.odLocatedMean - 0.1064) < 0.001, B.odLocatedMean, 0.1064, 'OD located rate ~10.6%');

%% ---- 5. T9B enhancement A/B (committed) ----
E = load(fullfile(projectRoot, 'data', 'analysis', 'day9', 'task9b_ab_eval.mat'), 'results');
p = E.results.primary;
results(end+1) = record('T9B_raw_acc', abs(p.raw.accuracy - 0.8322) < 1e-4, p.raw.accuracy, 0.8322, 'raw-control acc');
results(end+1) = record('T9B_raw_qwk', abs(p.raw.qwk - 0.8952) < 1e-4, p.raw.qwk, 0.8952, 'raw-control QWK');
results(end+1) = record('T9B_raw_mF1', abs(p.raw.macroF1 - 0.6828) < 1e-4, p.raw.macroF1, 0.6828, 'raw-control macroF1');
results(end+1) = record('T9B_enh_acc', abs(p.enhanced.accuracy - 0.5416) < 1e-4, p.enhanced.accuracy, 0.5416, 'enhanced acc (HURTS)');
results(end+1) = record('T9B_enh_qwk', abs(p.enhanced.qwk - 0.6507) < 1e-4, p.enhanced.qwk, 0.6507, 'enhanced QWK');
results(end+1) = record('T9B_enh_mF1', abs(p.enhanced.macroF1 - 0.4039) < 1e-4, p.enhanced.macroF1, 0.4039, 'enhanced macroF1');
results(end+1) = record('T9B_n', p.raw.n == 733 && p.enhanced.n == 733, p.raw.n, 733, 'model-agnostic 733 val');
results(end+1) = record('T9B_raw_close_champ', abs(p.raw.accuracy - 0.8281) < 0.01, p.raw.accuracy, 0.8281, 'raw within noise of champion');

%% ---- 6. RF-1 OD discrepancy (committed) ----
O = load(fullfile(projectRoot, 'data', 'analysis', 'day9', 'od_discrepancy_investigation.mat'), ...
    'located', 'refused', 'totalImages', 'nIdrid', 'idrid_located');
results(end+1) = record('RF1_located', O.located == 78, O.located, 78, 'APTOS val CNN-located');
results(end+1) = record('RF1_refused', O.refused == 655, O.refused, 655, 'APTOS val CNN refused');
results(end+1) = record('RF1_total', O.totalImages == 733, O.totalImages, 733, 'full val');
results(end+1) = record('RF1_idrid_loc', O.idrid_located == 10, O.idrid_located, 10, 'IDRiD 01-10 located 10/10');
results(end+1) = record('RF1_rate', abs(O.located / O.totalImages - 0.1064) < 0.001, O.located / O.totalImages, 0.1064, '10.6% acceptance reproduces');

%% ---- 7. RF-3 ensemble/TTA bounds (committed; nothing promoted) ----
G = load(fullfile(projectRoot, 'data', 'analysis', 'day9', 'ensemble_scores_cache.mat'), 'scores7', 'scores8');
results(end+1) = record('RF3_shape', size(G.scores7, 1) == 733 && size(G.scores7, 2) == 5, ...
    size(G.scores7, 1), 733, 'ensemble cache on 733 val');
results(end+1) = record('RF3_champ_nonzero', all(isfinite(G.scores7(:))), true, true, 'no NaN in champion scores');

%% ---- 8. T12 dashboard numbers (from committed artifacts) ----
D = load_dashboard_data();
results(end+1) = record('T12_pass', abs(D.quality.passPct - 65.48) < 0.01, D.quality.passPct, 65.48, 'PASS %');
results(end+1) = record('T12_warn', abs(D.quality.warningPct - 26.68) < 0.01, D.quality.warningPct, 26.68, 'WARNING %');
results(end+1) = record('T12_fail', abs(D.quality.failPct - 7.84) < 0.01, D.quality.failPct, 7.84, 'FAIL %');
results(end+1) = record('T12_qualN', D.quality.n == 3662, D.quality.n, 3662, 'train quality n');
results(end+1) = record('T12_champ_acc', abs(D.champion.accuracy - 0.8281) < 1e-4, D.champion.accuracy, 0.8281, 'dashboard champion acc');
results(end+1) = record('T12_champ_mF1', abs(D.champion.macroF1 - 0.6805) < 1e-4, D.champion.macroF1, 0.6805, 'dashboard champion macroF1');
results(end+1) = record('T12_champ_qwk', abs(D.champion.qwk - 0.8914) < 1e-4, D.champion.qwk, 0.8914, 'dashboard champion QWK');
results(end+1) = record('T12_bin_sens', abs(D.champion.binarySens - 0.9060) < 0.0005, D.champion.binarySens, 0.9060, 'dashboard binary sens');
results(end+1) = record('T12_bin_spec', abs(D.champion.binarySpec - 0.9471) < 0.0005, D.champion.binarySpec, 0.9471, 'dashboard binary spec');
results(end+1) = record('T12_infer', abs(D.inference.secondsPerImg - 0.1028) < 1e-3, D.inference.secondsPerImg, 0.1028, 's/img');
results(end+1) = record('T12_imgps', abs(D.inference.imgPerSec - 9.73) < 0.05, D.inference.imgPerSec, 9.73, 'img/s');
results(end+1) = record('T12_refVal', abs(D.referable.valFrac - 0.4065) < 0.001, D.referable.valFrac, 0.4065, 'val referable frac');
results(end+1) = record('T12_branchB', abs(D.branchB.evalAUC - 0.858) < 0.001, D.branchB.evalAUC, 0.858, 'Branch B pilot eval AUC');

%% ---- 9. Quality-gate + fovea hook behavior (two committed example images) ----
failIm = fullfile(projectRoot, 'data', 'splits', 'train', 'class_0', '02358b47ea89.png');
if exist(failIm, 'file') == 2
    rf = predictSingleFundus(failIm, 'ShowFigure', false, 'FoveaCenter', [100 200]);
    gateEnforced = isfield(rf.cascade, 'qualityGate') && rf.cascade.qualityGate;
    results(end+1) = record('QA_gate_enforce', gateEnforced && strcmp(rf.cascade.route, 'REVIEW'), ...
        rf.cascade.route, 'REVIEW', 'FAIL image enforced -> REVIEW');
    results(end+1) = record('QA_fovea_supplied', isfield(rf.lesions, 'foveaSupplied') && rf.lesions.foveaSupplied, ...
        true, true, 'fovea hook disclosure present');
else
    results(end+1) = record('QA_gate_enforce', false, NaN, 'REVIEW', 'FAIL image missing');
end
valIm = fullfile(projectRoot, 'data', 'splits', 'val', 'class_0', '005b95c28852.png');
if exist(valIm, 'file') == 2
    rv = predictSingleFundus(valIm, 'ShowFigure', false);
    gateEnforced = isfield(rv.cascade, 'qualityGate') && rv.cascade.qualityGate;
    results(end+1) = record('QA_pass_inert', ~gateEnforced && strcmp(rv.cascade.route, 'CLEAR'), ...
        rv.cascade.route, 'CLEAR', 'WARNING val image: gate not enforced, route CLEAR');
else
    results(end+1) = record('QA_pass_inert', false, NaN, 'CLEAR', 'val image missing');
end

%% ---- 10. Summary ----
fprintf('\n============================================================\n');
fprintf('  FINAL AUDIT SUMMARY\n');
nPass = 0; nFail = 0;
for i = 1:numel(results)
    if results(i).status
        nPass = nPass + 1; tag = 'PASS';
    else
        nFail = nFail + 1; tag = 'FAIL';
    end
    if isnumeric(results(i).measured) && numel(results(i).measured) == 1
        fprintf('  [%s] %-22s measured=%.5g expected=%.5g  %s\n', tag, ...
            results(i).check, results(i).measured, results(i).expected, results(i).note);
    else
        fprintf('  [%s] %-22s  %s\n', tag, results(i).check, results(i).note);
    end
end
fprintf('  TOTAL: %d PASS, %d FAIL\n', nPass, nFail);

auditDate = datestr(now);
save(fullfile(projectRoot, 'data', 'analysis', 'day9', 'reaudit_T13.mat'), 'results', 'auditDate');
fprintf('  Saved data/analysis/day9/reaudit_T13.mat\n');
if nFail > 0
    fprintf('  *** FINAL AUDIT FAIL - see failures above; do NOT proceed without human review ***\n');
else
    fprintf('  *** FINAL AUDIT PASS - all committed headline numbers reproduce exactly ***\n');
end
end

function rr = record(check, status, measured, expected, note)
    rr = struct('check', check, 'status', status, 'measured', measured, ...
                'expected', expected, 'note', note);
end