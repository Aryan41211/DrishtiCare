% verify_branch_b.m
% Honest verification of Branch B on the firewalled eval slice (per-grade).
projectRoot = 'C:\projects\DrishtiCare';
cd(projectRoot);
addpath(genpath(fullfile(projectRoot, 'src')));
S = load(fullfile(projectRoot, 'data', 'analysis', 'day8', 'branch_b', 'feat_cache.mat'));
M = load(fullfile(projectRoot, 'data', 'analysis', 'day8', 'branch_b', 'branchB_model.mat'));
model = M.model;
X = double(S.X); g = S.grade; y = double(g>=2);
% Eval-slice confusion + per-grade predicted referable rate
ei = model.evalIdx;
pAll = zeros(numel(ei),1);
for i = 1:numel(ei), pAll(i) = branch_b_predict(X(ei(i),:), model); end
fprintf('Branch B eval n=%d  referable-rate=%.3f  AUC=%.3f\n', ...
    numel(ei), mean(pAll>=0.60), model.metrics.aucBestEval);
for gr = 0:4
    m = (g(ei)==gr);
    fprintf('  grade %d: n=%d  mean pRefB=%.3f  flagged=%.3f\n', ...
        gr, sum(m), mean(pAll(m)), mean(pAll(m)>=0.60));
end
fprintf('Match vs Branch A label @0.60 = %.3f (n=%d)\n', ...
    model.metrics.matchRateAll_eval, numel(ei));