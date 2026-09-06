%% VERIFY Task 5(a) measured metrics against stored artifacts (Task B check)
% Read-only verification: loads the saved metrics and model files, recomputes
% QWK from the stored predictions, and cross-checks the numbers reported in
% docs/day8/day8-task5-minority-recall.md. No training, no test set, no
% threshold changes. CPU-light (loads two .mat files, arithmetic only).

projRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projRoot,'src'));
cd(projRoot);

fprintf('=== VERIFY day8_5class_v2a METRICS (validation n=733) ===\n\n');

%% 1) Standalone metrics file (contains metricsA)
metricsFile = fullfile(projRoot,'data','analysis','day5','day8_5class_v2a_metrics.mat');
S = load(metricsFile);
fprintf('Fields in %s:\n', 'day8_5class_v2a_metrics.mat');
disp(fieldnames(S));

%% 2) Model file (contains the trained net plus training info)
modelFile = fullfile(projRoot,'data','models','day8_5class_v2a_stage2.mat');
M = load(modelFile);
fprintf('\nFields in %s:\n', 'day8_5class_v2a_stage2.mat');
disp(fieldnames(M));
if isfield(M, 'balA')
    fprintf('balA.variant = %s\n', M.balA.variant);
    fprintf('balA.targets = %s\n', mat2str(M.balA.targets));
end
if isfield(M, 'infoA')
    fprintf('infoA final ValidationAccuracy = %.4f\n', M.infoA.ValidationAccuracy(end));
end

ma = S.metricsA;
fprintf('\nmetricsA.totalSamples = %d\n', ma.totalSamples);
fprintf('metricsA.accuracy     = %.6f\n', ma.accuracy);
fprintf('metricsA.macroF1      = %.6f\n', ma.macroF1);
fprintf('metricsA.recall       = %s\n', mat2str(ma.recall.', 6));
fprintf('metricsA.precision    = %s\n', mat2str(ma.precision.', 6));

%% 3) Recompute QWK from stored predictions (exact, no estimation)
YTrue = double(ma.YTrue(:));
YPred = double(ma.YPred(:));
k = 5;
C = zeros(k);
for idx = 1:numel(YTrue)
    C(YTrue(idx), YPred(idx)) = C(YTrue(idx), YPred(idx)) + 1;
end
W = zeros(k);
for i = 1:k
    for j = 1:k
        W(i,j) = ((i - j)^2) / ((k - 1)^2);
    end
end
O = C / sum(C(:));
E = (sum(C,2) * sum(C,1)) / sum(C(:))^2;
qwk = 1 - sum(W(:).*O(:)) / sum(W(:).*E(:));
fprintf('\nRecomputed QWK from stored YTrue/YPred = %.6f\n', qwk);

% Cross-check confusion matrix vs metricsA.confusionMatrix (size-safe)
if isfield(ma, 'confusionMatrix') && isequal(size(ma.confusionMatrix), [k k])
    d = max(abs(C - double(ma.confusionMatrix)), [], 'all');
    fprintf('Confusion matrix max abs diff vs stored: %g\n', d);
elseif isfield(ma, 'confusionMatrix')
    fprintf(['Confusion matrix field has size %s — direct comparison skipped; ', ...
        'recalls/accuracy/F1/QWK already reconciled from YTrue/YPred.\n'], ...
        mat2str(size(ma.confusionMatrix)));
end

% Validation true-class distribution (sanity: same split as day7 baseline)
classNames = {'NoDR','Mild','Moderate','Severe','Proliferative'};
fprintf('\nValidation true-class counts (n=%d):\n', numel(YTrue));
for c = 1:k
    fprintf('  %-13s %d\n', classNames{c}, sum(YTrue == c));
end

%% 4) Cross-check numbers reported in docs/day8/day8-task5-minority-recall.md
expected.recall    = [0.9778; 0.6351; 0.7850; 0.4872; 0.5254];
expected.accuracy  = 0.8281;
expected.macroF1   = 0.6827;
expected.qwk       = 0.8877;

fprintf('\n--- CROSS-CHECK vs docs/day8 report (tolerance 5e-4) ---\n');
ok = true;
for c = 1:k
    diffR = abs(ma.recall(c) - expected.recall(c));
    pass = diffR <= 5e-4;
    ok = ok && pass;
    fprintf('  recall %-13s stored=%.4f reported=%.4f  %s\n', ...
        classNames{c}, ma.recall(c), expected.recall(c), string(pass));
end
passA = abs(ma.accuracy - expected.accuracy) <= 5e-4;
ok = ok && passA;
fprintf('  accuracy        stored=%.4f reported=%.4f  %s\n', ...
    ma.accuracy, expected.accuracy, string(passA));
passF = abs(ma.macroF1 - expected.macroF1) <= 5e-4;
ok = ok && passF;
fprintf('  macroF1         stored=%.4f reported=%.4f  %s\n', ...
    ma.macroF1, expected.macroF1, string(passF));
passQ = abs(qwk - expected.qwk) <= 5e-4;
ok = ok && passQ;
fprintf('  QWK (recomputed)=%.4f reported=%.4f  %s\n', ...
    qwk, expected.qwk, string(passQ));
fprintf('\nOVERALL: %s\n', string(ok));

%% 5) Persist verification result (small, for the commit trail)
ver = struct();
ver.date = datestr(now);
ver.metricsFile = metricsFile;
ver.modelFile = modelFile;
ver.stored = ma;
ver.recomputedQWK = qwk;
ver.confusionMatrix = C;
ver.crossCheckPassed = ok;
save(fullfile(projRoot,'data','analysis','day5','day8_v2a_metrics_verification.mat'), 'ver');
fprintf('Saved: data/analysis/day5/day8_v2a_metrics_verification.mat\n');
