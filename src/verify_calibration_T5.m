% verify_calibration_T5.m
% Task 5 of the staged verification plan — confidence calibration.
%
% PART 1 — BINARY re-verification (artifact-only, NO new inference):
%   Loads fresh predictions on the 733-image val set from
%   data/analysis/day8/reverify_audit_T0.mat (PRef, YTrue5) and re-computes
%   the reliability diagram, ECE, Brier and NLL for RAW vs TEMPERATURE-
%   CALIBRATED P(referable), using the PROMOTED temperature read from
%   data/analysis/day8/calibration/current_T.mat via loadTemperatureParams
%   and the exact promoted transform temperatureScale (the same code path
%   predictSingleFundus uses). This is a holdout-style check on the 733 val
%   set, reported SEPARATELY from the documented firewalled 2429-image eval
%   numbers (they are NOT forced to match).
%
% PART 2 — 5-CLASS reliability assessment (NO calibration fit):
%   Uses s5All (733x5 per-image class probabilities, rows sum to 1) +
%   YTrue5. Computes per-class ECE and an overall top-1 ECE (bin the max
%   predicted probability vs whether the argmax class matched truth).
%   This is an ASSESSMENT ONLY — the plan asks for a 5-class reliability
%   check; no 5-class temperature has ever been fitted in this repo.
%
% Reads:
%   data/analysis/day8/reverify_audit_T0.mat
%   data/analysis/day8/calibration/current_T.mat  (binary T, read-only)
% Writes:
%   data/analysis/day8/calibration/calibration_verify_T5.mat
%   data/analysis/day8/calibration/reliability_curve.png
%
% No inference, no retraining, no writes to src/calibration or current_T.mat.

% ---------------------------------------------------------------------------
repoRoot = 'C:\projects\DrishtiCare';
cd(repoRoot);
addpath(genpath(fullfile(repoRoot, 'src')));

%% ---- 0. Load artifacts (artifact-only; test set untouched) ----------------
R = load(fullfile(repoRoot, 'data', 'analysis', 'day8', 'reverify_audit_T0.mat'));
PRef   = double(R.PRef(:));
YTrue5 = double(R.YTrue5(:));
s5All  = double(R.s5All);
n      = numel(YTrue5);
assert(n == 733, 'Expected 733 val images, got %d', n);

T = loadTemperatureParams();  % promoted binary temperature (current_T.mat)
fprintf('Promoted binary temperature T = %.4f\n', T);

%% ---- 1. Binary referable: raw vs calibrated on the 733 val set ------------
yRef    = YTrue5 >= 3;                 % Moderate/Severe/Proliferative
pRaw    = PRef;
pCal    = temperatureScale(PRef, T);   % exact promoted transform

nBins = 10;
edges = linspace(0, 1, nBins + 1);

[muPRaw, muYRaw, cntRaw, eceRaw] = relCurve(pRaw, yRef, edges);
[muPCal, muYCal, cntCal, eceCal] = relCurve(pCal, yRef, edges);

brierRaw = mean((pRaw - yRef).^2);
brierCal = mean((pCal - yRef).^2);

pclamp   = @(pv) max(min(pv, 1-1e-15), 1e-15);
nllRaw   = mean(-yRef .* log(pclamp(pRaw)) - (1-yRef) .* log(1 - pclamp(pRaw)));
nllCal   = mean(-yRef .* log(pclamp(pCal))  - (1-yRef) .* log(1 - pclamp(pCal)));

decRaw = pRaw >= 0.60;
decCal = pCal >= 0.60;
flipRate = mean(decRaw ~= decCal);
nFlip    = sum(decRaw ~= decCal);

fprintf('\n=== BINARY referable, val n=%d (artifact re-verification) ===\n', n);
fprintf('%s\n', repmat('-', 1, 60));
fprintf('  Raw     : ECE %.4f | Brier %.4f | NLL %.4f\n', eceRaw, brierRaw, nllRaw);
fprintf('  Cal T=%.4f: ECE %.4f | Brier %.4f | NLL %.4f\n', T, eceCal, brierCal, nllCal);
fprintf('  Flip @0.60: %.4f%% (%d / %d)\n', flipRate*100, nFlip, n);
fprintf('%s\n', repmat('-', 1, 60));
fprintf('  Bin      Raw(pred/obs/cnt)     Cal(pred/obs/cnt)\n');
for b = 1:nBins
    fprintf('  (%.2f,%.2f]  %.3f/%.3f/%4d      %.3f/%.3f/%4d\n', ...
        edges(b), edges(b+1), muPRaw(b), muYRaw(b), cntRaw(b), ...
        muPCal(b), muYCal(b), cntCal(b));
end
fprintf('  Note: bin 1 also includes p <= %.3f\n', edges(1));

% Documented firewalled-eval numbers (2429 images) for reference only.
docFirewall = struct(...
    'eceRaw', 0.0319, 'eceCal', 0.0087, ...
    'brierRaw', 0.0371, 'brierCal', 0.0336, ...
    'nllRaw', 0.1998, 'nllCal', 0.1243, ...
    'flipPct', 0.741, 'nEval', 2429);

%% ---- 2. 5-class reliability assessment (no calibration fit) ---------------
classNames = {'NoDR', 'Mild', 'Moderate', 'Severe', 'Proliferative'};

perClassECE = zeros(5, 1);
perClassCnt = zeros(5, 1);   % population of each class in val
for c = 1:5
    yc = (YTrue5 == c);
    perClassCnt(c) = sum(yc);
    [~, ~, ~, perClassECE(c)] = relCurve(s5All(:, c), yc, edges);
end

[pMax, yPred] = max(s5All, [], 2);
top1Ok = (yPred == YTrue5);
[~, ~, ~, top1ECE] = relCurve(pMax, top1Ok, edges);
top1Acc = mean(top1Ok);

fprintf('\n=== 5-CLASS reliability (ASSESSMENT ONLY, no calibration fit) ===\n');
fprintf('%s\n', repmat('-', 1, 60));
fprintf('%-15s %5s  %7s   %s\n', 'Class', 'n', 'prev%', 'ECE');
for c = 1:5
    fprintf('%-15s %5d  %7.1f%%   %.4f\n', ...
        classNames{c}, perClassCnt(c), 100*perClassCnt(c)/n, perClassECE(c));
end
fprintf('  ----\n');
fprintf('  Top-1 (max prob vs argmax-match): acc=%.4f  ECE=%.4f\n', top1Acc, top1ECE);
fprintf('  5-class temperature: NOT FITTED in this repo (binary T=%0.4f only).\n', T);

%% ---- 3. Reliability diagram (PNG) ----------------------------------------
f = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 900 420]);
subplot(1, 2, 1); hold on;
plot(muPRaw, muYRaw, 'o-', 'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], 'LineWidth', 1.5);
plot(muPCal, muYCal, 's-', 'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], 'LineWidth', 1.5);
plot([0 1], [0 1], 'k--', 'LineWidth', 1);
xlabel('Predicted P(referable)'); ylabel('Observed fraction referable');
title(sprintf('Binary reliability (val n=%d): ECE %.4f -> %.4f', n, eceRaw, eceCal));
legend({'Raw', sprintf('Cal T=%.4f', T), 'Ideal'}, 'Location', 'southeast');
axis([0 1 0 1]); grid on;

subplot(1, 2, 2);
bar(1:5, perClassECE, 0.55, 'FaceColor', [0.30 0.45 0.70]);
set(gca, 'XTick', 1:5, 'XTickLabel', classNames, 'XTickLabelRotation', 20);
ylabel('Per-class ECE'); ylim([0 max(0.05, 1.05*max(perClassECE))]);
title(sprintf('5-class per-class ECE (assessment only); top-1 ECE=%.4f', top1ECE));
grid on;

outPng = fullfile(repoRoot, 'data', 'analysis', 'day8', 'calibration', 'reliability_curve.png');
print(f, outPng, '-dpng', '-r110');
fprintf('\nPNG saved: %s\n', outPng);

%% ---- 4. Save --------------------------------------------------------------
binEdges = edges(:)';
binRaw   = [ (edges(1:end-1)+edges(2:end))/2; muPRaw; muYRaw; cntRaw ]';
binCal   = [ (edges(1:end-1)+edges(2:end))/2; muPCal; muYCal; cntCal ]';
% binRaw/binCal columns: [binMid, pred, obs, count]

out          = struct();
out.brierRaw  = brierRaw;
out.nllCal    = nllCal;
out.nFlip     = nFlip;
out.top1Acc   = top1Acc;
out.perClassCnt = perClassCnt;
out.classNames  = classNames;
out.docFirewalled = docFirewall;

save(fullfile(repoRoot, 'data', 'analysis', 'day8', 'calibration', 'calibration_verify_T5.mat'), ...
    'eceRaw', 'eceCal', 'brierRaw', 'brierCal', 'nllRaw', 'nllCal', ...
    'flipRate', 'nFlip', 'binEdges', 'binRaw', 'binCal', ...
    'perClassECE', 'top1ECE', 'n', 'T', 'top1Acc', 'perClassCnt', 'classNames', 'out');
fprintf('\nSaved: data/analysis/day8/calibration/calibration_verify_T5.mat\n');

% =============================================================================
% Local function
% =============================================================================
function [muP, muY, cnt, ece] = relCurve(p, y, edges)
% RELCURVE Reliability curve on equal-width bins.
%   Binning convention matches analyse_calibration_firewalled.m exactly:
%   bin b = (edges(b), edges(b+1)], with bin 1 also absorbing p <= edges(1).
%   ECE = weighted mean |meanPred - meanObs| across populated bins.
    nBins  = numel(edges) - 1;
    cnt = zeros(1, nBins);
    muP = zeros(1, nBins);
    muY = zeros(1, nBins);
    for b = 1:nBins
        m = p > edges(b) & p <= edges(b+1);
        if b == 1, m = m | p <= edges(1); end
        cnt(b) = sum(m);
        if cnt(b) > 0
            muP(b) = mean(p(m));
            muY(b) = mean(y(m));
        end
    end
    ece = sum(cnt .* abs(muP - muY)) / sum(cnt);
end