%% Firewalled-subset temperature-scaling calibration (binary referable)
%  LEAST-LEAKY estimate achievable given the net saw ALL images in-distribution.
%
%  Honesty caveat (documented):
%  -----------------------------
%  The binary referable classifier was trained on every image in this cache, so
%  NO true firewalled calibration set exists in-distribution. This script
%  therefore builds the least-leaky estimate achievable:
%    - CALIBRATION set: first 500 of the 2929 train indices, shuffled with
%      rng(42) and taken deterministically. Temperature T is fitted here.
%    - EVAL set: the remaining 2429 train images, disjoint from the 500.
%  Fit and eval are disjoint and deterministic, but BOTH sets are
%  in-distribution images the net has seen. Fitting on the 500 and reporting on
%  the 2429 is an estimate of how well temperature scaling generalizes WITHIN
%  the training population. It REDUCES but does NOT eliminate optimism. This is
%  NOT a true generalization figure; that would require a held-out set the net
%  never saw, which we do not have (official APTOS test set is closed).
%
%  Constraint: T in [0.1, 8.0] via fminbnd. Locked binary threshold = 0.60.
%
%  No function definitions (per -batch rule); helpers inlined.
%
%  Requires: data/analysis/day8/calibration/aptos_train_cache.mat
%  Writes:   data/analysis/day8/calibration/firewalled/firewalled_calibration.mat

%% Robust repo-root resolution (run() temporarily changes cwd to the script folder)
repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repoRoot, 'src')));

%% Load cache (absolute path; the cache is READ-ONLY)
dataCache = fullfile(repoRoot, 'data', 'analysis', 'day8', 'calibration', 'aptos_train_cache.mat');
load(dataCache);
% Variables: pRef (3662x1), s5 (3662x5), grade (3662x1), isVal (3662x1), ids (3662x1 string)
% Train = ~isVal (2929), val = isVal (733). Test set CLOSED.

%% Deterministic firewalled split (seed 42)
rng(42);
allTrain = find(~isVal);
allTrain = allTrain(randperm(numel(allTrain)));
calIdx  = allTrain(1:500);      % CALIBRATION: fit T here
evalIdx = allTrain(501:end);    % EVAL: evaluate here (2429)

y  = (grade >= 2);
z  = log(pRef ./ (1 - pRef));
z  = max(min(z, 40), -40);

zCal  = z(calIdx);   yCal  = y(calIdx);
zEval = z(evalIdx);  yEval = y(evalIdx);

%% NLL objective (closed-form sigmoid)
logsig = @(a) 1 ./ (1 + exp(-a));
nllfn  = @(T, zv, yv) -mean( yv .* log(logsig(zv./T)) + (1-yv).*log(1 - logsig(zv./T)) );

%% Fit T on CALIBRATION 500 (constrained [0.1, 8.0])
[T_cal, fvalCal] = fminbnd(@(T) nllfn(T, zCal, yCal), 0.1, 8.0);

%% Fit T on EVAL 2429 (OPTIMISTIC upper-bound sanity check ONLY)
[T_eval, fvalEval] = fminbnd(@(T) nllfn(T, zEval, yEval), 0.1, 8.0);

%% Calibrated probabilities on EVAL (using T_cal as primary)
pRawEval = pRef(evalIdx);
pCalEval = logsig(zEval / T_cal);

%% --- ECE (10 equal-width bins), computed inline for raw and calibrated ---
nBins = 10;
edges = linspace(0, 1, nBins+1);

% Raw ECE on EVAL
counts = zeros(1,nBins); avgP = zeros(1,nBins); avgY = zeros(1,nBins);
for b = 1:nBins
    mask = pRawEval > edges(b) & pRawEval <= edges(b+1);
    if b == 1, mask = mask | pRawEval <= edges(1); end
    counts(b) = sum(mask);
    if counts(b) > 0
        avgP(b) = mean(pRawEval(mask));
        avgY(b) = mean(yEval(mask));
    end
end
eceRawEval = sum(counts .* abs(avgP - avgY)) / sum(counts);

% Calibrated ECE on EVAL
counts = zeros(1,nBins); avgP = zeros(1,nBins); avgY = zeros(1,nBins);
for b = 1:nBins
    mask = pCalEval > edges(b) & pCalEval <= edges(b+1);
    if b == 1, mask = mask | pCalEval <= edges(1); end
    counts(b) = sum(mask);
    if counts(b) > 0
        avgP(b) = mean(pCalEval(mask));
        avgY(b) = mean(yEval(mask));
    end
end
eceCalEval = sum(counts .* abs(avgP - avgY)) / sum(counts);

%% --- Brier and NLL ---
brierRawEval = mean((pRawEval - yEval).^2);
brierCalEval = mean((pCalEval - yEval).^2);

pKeep = @(p) max(min(p, 1-1e-15), 1e-15);
nllRawEval = mean(-yEval.*log(pKeep(pRawEval)) - (1-yEval).*log(1 - pKeep(pRawEval)));
nllCalEval = mean(-yEval.*log(pKeep(pCalEval)) - (1-yEval).*log(1 - pKeep(pCalEval)));

%% --- Binned reliability tables (array of structs) ---
relRaw = struct('binMid', cell(1,1), 'pred', cell(1,1), 'obs', cell(1,1), 'count', cell(1,1));
relCal = struct('binMid', cell(1,1), 'pred', cell(1,1), 'obs', cell(1,1), 'count', cell(1,1));

relRaw.binMid = (edges(1:end-1) + edges(2:end)) / 2;
relCal.binMid = (edges(1:end-1) + edges(2:end)) / 2;
relRaw.count = zeros(1,nBins); relRaw.pred = zeros(1,nBins); relRaw.obs = zeros(1,nBins);
relCal.count = zeros(1,nBins); relCal.pred = zeros(1,nBins); relCal.obs = zeros(1,nBins);

for b = 1:nBins
    mRaw = pRawEval > edges(b) & pRawEval <= edges(b+1);
    mCal = pCalEval > edges(b) & pCalEval <= edges(b+1);
    if b == 1
        mRaw = mRaw | pRawEval <= edges(1);
        mCal = mCal | pCalEval <= edges(1);
    end
    relRaw.count(b) = sum(mRaw);
    relCal.count(b) = sum(mCal);
    if relRaw.count(b) > 0
        relRaw.pred(b) = mean(pRawEval(mRaw));
        relRaw.obs(b)  = mean(yEval(mRaw));
    end
    if relCal.count(b) > 0
        relCal.pred(b) = mean(pCalEval(mCal));
        relCal.obs(b)  = mean(yEval(mCal));
    end
end

%% --- Flip fraction across locked 0.60 threshold ---
decRaw = (pRawEval >= 0.60);
decCal = (pCalEval >= 0.60);
flipFraction = mean(decRaw ~= decCal);
nFlip = sum(decRaw ~= decCal);

%% --- Print reliability tables ---
fprintf('\n  RAW (on EVAL %d): reliability table\n', numel(evalIdx));
fprintf('    %8s  %8s  %8s  %6s\n', 'BinMid', 'Pred', 'Obs', 'Count');
for b = 1:nBins
    if relRaw.count(b) > 0
        fprintf('    %8.3f  %8.3f  %8.3f  %6d\n', relRaw.binMid(b), relRaw.pred(b), relRaw.obs(b), relRaw.count(b));
    else
        fprintf('    %8.3f  %8s  %8s  %6d\n', relRaw.binMid(b), '-', '-', 0);
    end
end

fprintf('\n  CALIBRATED T_cal=%.4f (on EVAL %d): reliability table\n', T_cal, numel(evalIdx));
fprintf('    %8s  %8s  %8s  %6s\n', 'BinMid', 'Pred', 'Obs', 'Count');
for b = 1:nBins
    if relCal.count(b) > 0
        fprintf('    %8.3f  %8.3f  %8.3f  %6d\n', relCal.binMid(b), relCal.pred(b), relCal.obs(b), relCal.count(b));
    else
        fprintf('    %8.3f  %8s  %8s  %6d\n', relCal.binMid(b), '-', '-', 0);
    end
end

%% --- Summary ---
fprintf('\n');
fprintf('=============================================================\n');
fprintf('  FIREWALLED TEMPERATURE SCALING (binary referable, thr=0.60)\n');
fprintf('=============================================================\n');
fprintf('  Split (rng 42): CALIBRATION=%d, EVAL=%d, total train=%d\n', numel(calIdx), numel(evalIdx), numel(allTrain));
fprintf('  T_cal  (fit on 500):  %.4f   (NLL obj %.6f)\n', T_cal, fvalCal);
fprintf('  T_eval (fit on 2429): %.4f   (NLL obj %.6f)  [OPTIMISTIC upper bound]\n', T_eval, fvalEval);
fprintf('\n  %-16s  %10s  %10s\n', 'Metric (EVAL)', 'Raw', 'Cal(T_cal)');
fprintf('  %-16s  %10.4f  %10.4f\n', 'ECE',  eceRawEval,  eceCalEval);
fprintf('  %-16s  %10.4f  %10.4f\n', 'Brier', brierRawEval, brierCalEval);
fprintf('  %-16s  %10.4f  %10.4f\n', 'NLL',   nllRawEval,   nllCalEval);
fprintf('\n');
fprintf('  Flip fraction across 0.60 (EVAL): %.4f%%  (%d / %d images)\n', flipFraction*100, nFlip, numel(evalIdx));
fprintf('  Raw referable decisions: %d / %d (%.1f%%)\n', sum(decRaw), numel(evalIdx), 100*mean(decRaw));
fprintf('  Cal referable decisions: %d / %d (%.1f%%)\n', sum(decCal), numel(evalIdx), 100*mean(decCal));
fprintf('=============================================================\n');

%% --- Save ---
outDir = fullfile(repoRoot, 'data', 'analysis', 'day8', 'calibration', 'firewalled');
if ~exist(outDir, 'dir'), mkdir(outDir); end
save(fullfile(outDir, 'firewalled_calibration.mat'), ...
    'T_cal', 'T_eval', 'fvalCal', 'fvalEval', ...
    'eceRawEval', 'eceCalEval', ...
    'brierRawEval', 'brierCalEval', ...
    'nllRawEval', 'nllCalEval', ...
    'flipFraction', 'nFlip', ...
    'relRaw', 'relCal', ...
    'calIdx', 'evalIdx');
fprintf('\nSaved to %s/firewalled_calibration.mat\n', outDir);