% bootstrap_cis_T4.m
% Task 4 of the staged verification plan: compute bootstrap confidence
% intervals (percentile method, B=1000) for the project's headline metrics.
%
% Manual resampling (Statistics Toolbox NOT available): outage randi(N,N,1)
% sampling with replacement over the 733 validation rows, same index used for
% all metrics. Percentile CIs are the 2.5% and 97.5% percentiles of the
% bootstrap distribution; SE is the std of that distribution.
%
% Loads FRESH predictions from reverify_audit_T0.mat (no re-inference).

tic;

% ---- Load fresh predictions -------------------------------------------------
d = load(fullfile('data', 'analysis', 'day8', 'reverify_audit_T0.mat'));
YTrue5 = d.YTrue5(:);
YPred5 = d.YPred5(:);
PRef   = d.PRef(:);
N = numel(YTrue5);

thr = 0.60;
YTrueRef = YTrue5 >= 3;
nCls = 5;
B = 1000;
rng(2026);
fprintf('Loaded %d fresh val rows. Running B=%d bootstrap iterations...\n', N, B);

% ---- Point estimates on the full 733 ---------------------------------------
[ptSens, ptSpec, ptAcc, ptMac, ptQWK, ptRec4, ptRec5] = ...
    evalMetrics(YTrue5, YPred5, PRef, YTrueRef, thr, nCls);

% ---- Bootstrap loop ---------------------------------------------------------
bootSens  = zeros(B,1);
bootSpec  = zeros(B,1);
bootAcc   = zeros(B,1);
bootMac   = zeros(B,1);
bootQWK   = zeros(B,1);
bootRec4  = zeros(B,1);
bootRec5  = zeros(B,1);

for b = 1:B
    idx = randi(N, N, 1);
    [s, sp, a, m, q, r4, r5] = evalMetrics(...
        YTrue5(idx), YPred5(idx), PRef(idx), YTrueRef(idx), thr, nCls);
    bootSens(b)  = s;
    bootSpec(b)  = sp;
    bootAcc(b)   = a;
    bootMac(b)   = m;
    bootQWK(b)   = q;
    bootRec4(b)  = r4;
    bootRec5(b)  = r5;
    if mod(b, 200) == 0
        fprintf('  %d/%d\n', b, B);
    end
end

% ---- Summarize each metric --------------------------------------------------
names = {'Binary Sens @0.60', 'Binary Spec @0.60', '5-class Accuracy', ...
         '5-class MacroF1',    '5-class QWK',       'Recall Severe (cl4)', ...
         'Recall Proliferative (cl5)'};
pts   = [ptSens, ptSpec, ptAcc, ptMac, ptQWK, ptRec4, ptRec5];
boots = {bootSens, bootSpec, bootAcc, bootMac, bootQWK, bootRec4, bootRec5};

fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('Metric                              Point     95%% CI            SE\n');
fprintf('%s\n', repmat('-', 1, 72));

out.metricNames = names(:);
out.point = pts(:);
out.ciLow  = zeros(7,1);
out.ciHigh = zeros(7,1);
out.se     = zeros(7,1);
out.dist   = cell(7,1);

for k = 1:7
    bt  = boots{k};
    ci  = prctile(bt, [2.5 97.5]);
    se  = std(bt);
    out.ciLow(k)  = ci(1);
    out.ciHigh(k) = ci(2);
    out.se(k)     = se;
    out.dist{k}   = bt(:);
    fprintf('%-38s %.4f   [%.4f, %.4f]   %.4f\n', names{k}, pts(k), ci(1), ci(2), se);
end

% ---- Sanity check vs documented point estimates -----------------------------
expSens = 0.9060; expSpec = 0.9471; expAcc = 0.8281; expMac = 0.6805; expQWK = 0.8914;
expected = [expSens, expSpec, expAcc, expMac, expQWK, 0.4872, 0.5254];
tol = 0.0005;

fprintf('\n%s\n', '--- Point-estimate sanity check (full 733) ---');
fprintf('%-38s %-10s %-10s  %s\n', 'Metric', 'Point', 'Expected', 'Status');
allPass = true;
for k = 1:7
    ok = abs(pts(k) - expected(k)) <= tol;
    if ~ok, allPass = false; end
    tag = 'PASS'; if ~ok, tag = 'FAIL'; end
    fprintf('%-38s %-10.4f %-10.4f  %s\n', names{k}, pts(k), expected(k), tag);
end
fprintf('%s\n', repmat('-', 1, 72));
if allPass
    fprintf('OVERALL SANITY: PASS\n');
else
    fprintf('OVERALL SANITY: FAIL (numbers reported unmodified above)\n');
    error('Sanity check FAILED: point estimates differ from documented metrics.');
end

% ---- Save results -----------------------------------------------------------
out.B = B;
out.seed = 2026;
out.N = N;
out.bootstrapVars = { ...
    'bootSens', 'bootSpec', 'bootAcc', 'bootMac', 'bootQWK', 'bootRec4', 'bootRec5'};
save(fullfile('data', 'analysis', 'day8', 'bootstrap_T4.mat'), 'out', ...
    'bootSens', 'bootSpec', 'bootAcc', 'bootMac', 'bootQWK', 'bootRec4', 'bootRec5');
fprintf('\nSaved: data/analysis/day8/bootstrap_T4.mat\n');

elapsed = toc;
fprintf('Runtime: %.1f s\n', elapsed);

% =============================================================================
% Local function
% =============================================================================
function [sens, spec, acc, mac, qwk, recCl4, recCl5] = evalMetrics(...
    YTrue5, YPred5, PRef, YTrueRef, thr, nCls)
    % Binary @ threshold
    YPredRef = PRef >= thr;
    tp = sum(YTrueRef &  YPredRef);
    fp = sum(~YTrueRef & YPredRef);
    fn = sum(YTrueRef  & ~YPredRef);
    tn = sum(~YTrueRef & ~YPredRef);
    sens = tp / (tp + fn + eps);
    spec = tn / (tn + fp + eps);

    % 5-class accuracy
    acc = mean(YPred5 == YTrue5);

    % per-class recall, F1 -> macroF1
    conf = zeros(nCls);
    for c = 1:nCls
        for r = 1:nCls
            conf(r, c) = sum(YTrue5 == r & YPred5 == c);
        end
    end
    perF1 = zeros(nCls, 1);
    for c = 1:nCls
        tp_c = conf(c, c);
        fp_c = sum(conf(:, c)) - tp_c;
        fn_c = sum(conf(c, :)) - tp_c;
        perF1(c) = 2 * tp_c / (2 * tp_c + fp_c + fn_c + eps);
    end
    mac = mean(perF1);

    % class-4 (Severe) and class-5 (Proliferative) recall
    recCl4 = conf(4, 4) / (sum(conf(4, :)) + eps);
    recCl5 = conf(5, 5) / (sum(conf(5, :)) + eps);

    % quadratic weighted kappa
    qwk = computeQWK(YTrue5, YPred5, nCls);
end

function qwk = computeQWK(yTrue, yPred, numClasses)
    n = length(yTrue);
    W = zeros(numClasses);
    for i = 1:numClasses
        for j = 1:numClasses
            W(i, j) = (i - j)^2 / (numClasses - 1)^2;
        end
    end
    O = zeros(numClasses);
    for i = 1:n
        O(yTrue(i), yPred(i)) = O(yTrue(i), yPred(i)) + 1;
    end
    E = zeros(numClasses);
    rowSums = sum(O, 2); colSums = sum(O, 1);
    for i = 1:numClasses
        for j = 1:numClasses
            E(i, j) = rowSums(i) * colSums(j) / n;
        end
    end
    numer = sum(W(:) .* O(:)); denom = sum(W(:) .* E(:));
    qwk = 1 - numer / (denom + eps);
end
