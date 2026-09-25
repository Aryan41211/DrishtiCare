function confirm_provenance_resolutions(projectRoot)
%CONFIRM_PROVENANCE_RESOLUTIONS  Decisive checks on the 3 resolved discrepancies.
%
%   Confirms, from the authoritative artifacts only:
%     1. DRIVE task8 mean Dice is the MEAN of the 20-image vector, not a single element.
%     2. Human inter-observer Dice is stored as an explicit mean (meanHumanDice).
%     3. The Day-7 scratch-baseline conflict is a CATEGORY ERROR plus a wrong
%        referable definition (label>=2 vs the frozen label>=3), not two
%        competing accuracy/QWK values.
%
%   READ-ONLY. Trains nothing, tunes nothing.

if nargin < 1 || isempty(projectRoot)
    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
P = @(varargin) fullfile(projectRoot, varargin{:});

fprintf('\n########## 1. DRIVE task8 per-image Dice vectors ##########\n');
d = load(P('data','analysis','day8','task8','drive_test_dice.mat'));
fn = fieldnames(d);
for i = 1:numel(fn)
    v = d.(fn{i});
    if isnumeric(v) && numel(v) == 20
        fprintf('  %-12s n=%d  mean=%.6f  median=%.6f  min=%.6f  max=%.6f\n', ...
            fn{i}, numel(v), mean(v), median(v), min(v), max(v));
    end
end
fprintf('  --> doc value 0.2576 matches the MEAN of dice1 (%.6f)\n', mean(d.dice1));
fprintf('  --> 0.2541 is dice1 element #19 = %.6f (a SINGLE image, not a mean)\n', d.dice1(19));

fprintf('\n########## 2. Human inter-observer Dice ##########\n');
vm = load(P('data','analysis','vessel','drive_vessel_metrics.mat'));
r = vm.results;
fprintf('  results.meanHumanDice      = %.6f\n', r.meanHumanDice);
if isfield(r, 'humanDice') && numel(r.humanDice) == 20
    fprintf('  mean(results.humanDice)    = %.6f   (n=%d)\n', mean(r.humanDice), numel(r.humanDice));
end
if isfield(r, 'm2')
    fprintf('  r.m2 element #18           = %.6f   <-- the 0.7881 in the doc is THIS element\n', r.m2(18));
end
fprintf('  --> authoritative human inter-observer Dice = %.4f (meanHumanDice)\n', r.meanHumanDice);

fprintf('\n########## 3. Day-7 scratch baseline: what were 0.8307/0.8667 and 0.8322/0.9080? ##########\n');
a = load(P('data','analysis','day5','day5_resnet18_baseline_results.mat'));
b = load(P('data','analysis','day7','eval_fixed_day5_resnet18_baseline_stage2.mat'));

fprintf('  day5_resnet18_baseline_results.mat / metrics2:\n');
fprintf('     accuracy=%.6f  macroF1=%.6f  qwk=%.6f\n', a.metrics2.accuracy, a.metrics2.macroF1, a.metrics2.qwk);
fprintf('     referable.sensitivity=%.6f  referable.specificity=%.6f\n', ...
    a.metrics2.referable.sensitivity, a.metrics2.referable.specificity);
fprintf('     referable tp=%d fp=%d fn=%d tn=%d  -> implied POSITIVES=%d\n', ...
    a.metrics2.referable.tp, a.metrics2.referable.fp, a.metrics2.referable.fn, a.metrics2.referable.tn, ...
    a.metrics2.referable.tp + a.metrics2.referable.fn);

fprintf('  day7/eval_fixed_day5_resnet18_baseline_stage2.mat / m:\n');
fprintf('     accuracy=%.6f  macroF1=%.6f  qwk=%.6f\n', b.m.accuracy, b.m.macroF1, b.m.qwk);
fprintf('     referable.sensitivity=%.6f  referable.specificity=%.6f\n', ...
    b.m.referable.sensitivity, b.m.referable.specificity);
fprintf('     referable tp=%d fp=%d fn=%d tn=%d  -> implied POSITIVES=%d\n', ...
    b.m.referable.tp, b.m.referable.fp, b.m.referable.fn, b.m.referable.tn, ...
    b.m.referable.tp + b.m.referable.fn);

fprintf('\n  Are the 5-class predictions identical (i.e. only the binary op-point differs)?\n');
fprintf('     YTrue identical : %d\n', isequal(a.metrics2.YTrue, b.m.YTrue));
fprintf('     YPred identical : %d\n', isequal(a.metrics2.YPred, b.m.YPred));

yt = a.metrics2.YTrue;
fprintf('\n  Positives in the SAME YTrue under each referable definition:\n');
fprintf('     sum(YTrue>=2) = %d   <- matches day5 implied positives (%d)\n', sum(yt >= 2), a.metrics2.referable.tp + a.metrics2.referable.fn);
fprintf('     sum(YTrue>=3) = %d   <- FROZEN definition (Phase 7); eval_fixed positives = %d\n', sum(yt >= 3), b.m.referable.tp + b.m.referable.fn);

fprintf('\n  Recompute sens/spec at the FROZEN definition (label>=3) from the day5 confusion matrix:\n');
cm = a.metrics2.confusionMatrix;   % rows = true, cols = predicted (verified below)
tp = sum(cm(4:5, 4:5), 'all'); fn = sum(cm(4:5, 1:3), 'all');
tn = sum(cm(1:3, 1:3), 'all'); fp = sum(cm(1:3, 4:5), 'all');
fprintf('     label>=3 : tp=%d fn=%d tn=%d fp=%d  sens=%.6f spec=%.6f\n', tp, fn, tn, fp, tp/(tp+fn), tn/(tn+fp));
fprintf('     eval_fixed reported : tp=%d fn=%d tn=%d fp=%d  sens=%.6f spec=%.6f\n', ...
    b.m.referable.tp, b.m.referable.fn, b.m.referable.tn, b.m.referable.fp, b.m.referable.sensitivity, b.m.referable.specificity);
fprintf('     MATCHES eval_fixed : %d\n', ...
    isequal([tp fn tn fp], [b.m.referable.tp b.m.referable.fn b.m.referable.tn b.m.referable.fp]));

outDir = P('data','analysis','day11','provenance');
if ~isfolder(outDir), mkdir(outDir); end
save(fullfile(outDir, 'provenance_resolutions.mat'), 'd', 'vm', 'a', 'b');
fprintf('\nSaved: data/analysis/day11/provenance/provenance_resolutions.mat\n');
end
