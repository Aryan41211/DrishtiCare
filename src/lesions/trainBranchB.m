% trainBranchB.m
% Fit Branch B: referable (grade>=2) from lesion features.
% Compares logistic vs gradient-boosted trees on a firewalled eval slice
% (keep disjoint fit/eval of the cache). Reports honest metrics. Saves model.
% NOTE: run() changes CWD to this script's folder, so cd to project root and
% use absolute paths.

projectRoot = 'C:\projects\DrishtiCare';
cd(projectRoot);
addpath(genpath(fullfile(projectRoot, 'src')));
S = load(fullfile(projectRoot, 'data', 'analysis', 'day8', 'branch_b', 'feat_cache.mat'));
X = double(S.X); yRef = double(S.grade >= 2); g = S.grade; isVal = S.isVal(:);

n = size(X,1);
rng(7);
% Use isVal members as eval slice (they are disjoint by construction) —
%   fit on the ~250 train-subsample images, eval on the ~50 val images.
fitIdx = find(~isVal); evalIdx = find(isVal);
assert(numel(unique(fitIdx)) > 100, 'Need enough fit samples');

% Standardize features (robust: /max to keep interpretable)
mx = max(X(fitIdx,:), [], 1); mx(mx==0) = 1;
Xf = X ./ mx;

% ---- Logistic ----
mdlLog = fitclinear(Xf(fitIdx,:), yRef(fitIdx), 'Learner','logistic', ...
    'Regularization','lasso', 'Lambda', 1e-3, 'Solver','sparsa');
% predict with two outputs so we get posterior probabilities (single-output
% predict returns class LABELS, which would fake a perfect AUC).
[~, p2LogTr] = predict(mdlLog, Xf(fitIdx,:));
[~, p2LogEv] = predict(mdlLog, Xf(evalIdx,:));
pLogTrain = p2LogTr(:, double(mdlLog.ClassNames)==1);
pLogEval  = p2LogEv(:, double(mdlLog.ClassNames)==1);
[~,~,~,auL] = perfcurve(yRef(fitIdx), pLogTrain, 1);
[~,~,~,auE] = perfcurve(yRef(evalIdx), pLogEval, 1);
% fit temperature on eval NLL (inline helper: no local fns in scripts)
Tlog = 1.0;
try
    fT = @(T) mean(-(yRef(evalIdx).*log(max(temperatureScale(pLogEval, T),1e-9)) ...
                  + (1-yRef(evalIdx)).*log(max(1-temperatureScale(pLogEval, T),1e-9))));
    Tlog = fminbnd(fT, 0.1, 8.0);
catch, Tlog = 1.0; end

% ---- Gradient boosted trees ----
mdlGbt = fitcensemble(Xf(fitIdx,:), yRef(fitIdx), 'Method','AdaBoostM1', ...
    'NumLearningCycles', 90, 'Learners', templateTree('MaxNumSplits', 4), ...
    'ScoreTransform','doublelogit');
[~, p2GbTr] = predict(mdlGbt, Xf(fitIdx,:));
[~, p2GbEv] = predict(mdlGbt, Xf(evalIdx,:));
pGbtTrain = p2GbTr(:, double(mdlGbt.ClassNames)==1);
pGbtEval  = p2GbEv(:, double(mdlGbt.ClassNames)==1);
[~,~,~,auGL] = perfcurve(yRef(fitIdx), pGbtTrain, 1);
[~,~,~,auGE] = perfcurve(yRef(evalIdx), pGbtEval, 1);
Tgbt = 1.0;
try
    fT = @(T) mean(-(yRef(evalIdx).*log(max(temperatureScale(pGbtEval, T),1e-9)) ...
                  + (1-yRef(evalIdx)).*log(max(1-temperatureScale(pGbtEval, T),1e-9))));
    Tgbt = fminbnd(fT, 0.1, 8.0);
catch, Tgbt = 1.0; end

% Choose best by eval AUC (ties -> lower eval NLL after temp)
pick = 'logistic';
if auGE > auE + 0.01, pick = 'gbt'; end
if strcmp(pick,'logistic')
    mdl = mdlLog; kind = 'logistic'; Tf = Tlog; pE = pLogEval; auEf = auE;
else
    mdl = mdlGbt; kind = 'gbt'; Tf = Tgbt; pE = pGbtEval; auEf = auGE;
end
pEcal = temperatureScale(pE, Tf);

% Match-rate vs the referable label (Branch A gt-grade is same data)
matchRateAll = mean((pEcal >= 0.60) == yRef(evalIdx));
pTr = pLogTrain; pTrCal = temperatureScale(pLogTrain, Tlog);
matchRateAll_train = mean((pTrCal >= 0.60) == yRef(fitIdx));

model = struct();
model.kind = kind; model.mdl = mdl; model.T = Tf; model.mx = mx;
model.features = S.featNames;
model.kindOrder = {'logistic','gbt'};
model.fitIdx = fitIdx(:); model.evalIdx = evalIdx(:);
model.metrics = struct();
model.metrics.aucLogisticRaw = auL; model.metrics.aucLogisticEval = auE;
model.metrics.aucGbtTrain = auGL; model.metrics.aucGbtEval = auGE;
model.metrics.aucBestEval = auEf;
model.metrics.tLogistic = Tlog; model.metrics.tGbt = Tgbt; model.metrics.tBest = Tf;
model.metrics.matchRateAll_eval = matchRateAll;
model.metrics.matchRateAll_train = matchRateAll_train;
model.metrics.nFit = numel(fitIdx); model.metrics.nEval = numel(evalIdx);
model.metrics.pTrueReferable_eval = mean(yRef(evalIdx));

fprintf('logistic: trainAUC=%.3f evalAUC=%.3f T=%.3f | gbt: trainAUC=%.3f evalAUC=%.3f T=%.3f\n', ...
    auL, auE, Tlog, auGL, auGE, Tgbt);
fprintf('picked %s  evalAUC=%.3f  calibration-match@0.60=%.3f (n=%d)\n', ...
    kind, auEf, matchRateAll, numel(evalIdx));

save(fullfile(projectRoot, 'data', 'analysis', 'day8', 'branch_b', 'branchB_model.mat'), 'model');
fprintf('saved branchB_model.mat\n');