%% Constrained temperature-scaling calibration (standard train/val split)
%  Fits T on val, fits T on train, evaluates both on val.
%  Requires: data/analysis/day8/calibration/aptos_train_cache.mat

% Resolve repo root independent of current folder (run cd's into script dir)
scriptDir = fileparts(mfilename('fullpath'));  % repo\src\calibration
srcDir = fileparts(scriptDir);                 % repo\src
rootDir = fileparts(srcDir);                   % repo root

addpath(genpath(srcDir));
cd(rootDir);

load(fullfile(rootDir, 'data', 'analysis', 'day8', 'calibration', 'aptos_train_cache.mat'));
% Variables: pRef (3662x1), grade (3662x1), isVal (3662x1 logical)

y = (grade >= 2);
z = log(pRef ./ (1 - pRef));
z = max(min(z, 40), -40);

trainIdx = ~isVal;
valIdx   = isVal;

zTrain = z(trainIdx);  yTrain = y(trainIdx);
zVal   = z(valIdx);    yVal   = y(valIdx);

%% NLL objective (closed-form sigmoid)
nllfn = @(T, zv, yv) -mean( yv .* log(1./(1+exp(-zv./T))) + (1-yv).*log(1-1./(1+exp(-zv./T))) );

%% Fit T on VAL split
[T_fitVal, fvalVal] = fminbnd(@(T) nllfn(T, zVal, yVal), 0.1, 8.0);

%% Fit T on TRAIN split
[T_fitTrain, fvalTrain] = fminbnd(@(T) nllfn(T, zTrain, yTrain), 0.1, 8.0);

%% Evaluate on VAL split: raw vs calibrated
pRaw = pRef(valIdx);
pCalVal   = 1./(1+exp(-zVal/T_fitVal));
pCalTrain = 1./(1+exp(-zVal/T_fitTrain));

nBins = 10;
edges = linspace(0, 1, nBins+1);

%% ECE / reliability table for raw
counts = zeros(1,nBins); avgP = zeros(1,nBins); avgY = zeros(1,nBins);
for b = 1:nBins
    mask = pRaw > edges(b) & pRaw <= edges(b+1);
    if b == 1, mask = mask | pRaw <= edges(1); end
    counts(b) = sum(mask);
    if counts(b) > 0, avgP(b) = mean(pRaw(mask)); avgY(b) = mean(yVal(mask)); end
end
eceRawVal = sum(counts .* abs(avgP - avgY)) / sum(counts);
tabRaw.counts = counts; tabRaw.avgP = avgP; tabRaw.avgY = avgY; tabRaw.mid = (edges(1:end-1)+edges(2:end))/2;

%% ECE / reliability table for calibrated (train fit)
counts = zeros(1,nBins); avgP = zeros(1,nBins); avgY = zeros(1,nBins);
for b = 1:nBins
    mask = pCalTrain > edges(b) & pCalTrain <= edges(b+1);
    if b == 1, mask = mask | pCalTrain <= edges(1); end
    counts(b) = sum(mask);
    if counts(b) > 0, avgP(b) = mean(pCalTrain(mask)); avgY(b) = mean(yVal(mask)); end
end
eceCalT = sum(counts .* abs(avgP - avgY)) / sum(counts);
tabCal.counts = counts; tabCal.avgP = avgP; tabCal.avgY = avgY; tabCal.mid = (edges(1:end-1)+edges(2:end))/2;

%% ECE for calibrated (val fit)
counts = zeros(1,nBins); avgP = zeros(1,nBins); avgY = zeros(1,nBins);
for b = 1:nBins
    mask = pCalVal > edges(b) & pCalVal <= edges(b+1);
    if b == 1, mask = mask | pCalVal <= edges(1); end
    counts(b) = sum(mask);
    if counts(b) > 0, avgP(b) = mean(pCalVal(mask)); avgY(b) = mean(yVal(mask)); end
end
eceCalVal = sum(counts .* abs(avgP - avgY)) / sum(counts);
tabCalVal.counts = counts; tabCalVal.avgP = avgP; tabCalVal.avgY = avgY; tabCalVal.mid = (edges(1:end-1)+edges(2:end))/2;

%% Brier
brierRawVal  = mean((pRaw - yVal).^2);
brierCalT    = mean((pCalTrain - yVal).^2);
brierCalVal  = mean((pCalVal - yVal).^2);

%% NLL
pcls = @(pv) max(min(pv, 1-1e-15), 1e-15);
nllRawVal  = mean(-yVal.*log(pcls(pRaw)) - (1-yVal).*log(1-pcls(pRaw)));
nllCalT    = mean(-yVal.*log(pcls(pCalTrain)) - (1-yVal).*log(1-pcls(pCalTrain)));
nllCalVal  = mean(-yVal.*log(pcls(pCalVal)) - (1-yVal).*log(1-pcls(pCalVal)));

%% Flip fraction across 0.60 threshold (train-fitted T as primary)
decRaw = (pRaw >= 0.60);
decCal = (pCalTrain >= 0.60);
flipFraction = mean(decRaw ~= decCal);

%% Print reliability tables
fprintf('\n=== Reliability: Raw (on val) ===');
fprintf('\n  %8s  %8s  %8s  %6s\n', 'BinMid', 'Pred', 'Obs', 'Count');
for b = 1:nBins
    if tabRaw.counts(b) > 0
        fprintf('  %8.3f  %8.3f  %8.3f  %6d\n', tabRaw.mid(b), tabRaw.avgP(b), tabRaw.avgY(b), tabRaw.counts(b));
    else
        fprintf('  %8.3f  %8s  %8s  %6d\n', tabRaw.mid(b), '-', '-', 0);
    end
end

fprintf('\n=== Reliability: Calibrated with T_fitTrain=%.4f (on val) ===', T_fitTrain);
fprintf('\n  %8s  %8s  %8s  %6s\n', 'BinMid', 'Pred', 'Obs', 'Count');
for b = 1:nBins
    if tabCal.counts(b) > 0
        fprintf('  %8.3f  %8.3f  %8.3f  %6d\n', tabCal.mid(b), tabCal.avgP(b), tabCal.avgY(b), tabCal.counts(b));
    else
        fprintf('  %8.3f  %8s  %8s  %6d\n', tabCal.mid(b), '-', '-', 0);
    end
end

%% --- Summary ---
fprintf('\n');
fprintf('============================================\n');
fprintf('  TEMPERATURE SCALING RESULTS (val split)\n');
fprintf('============================================\n');
fprintf('  T fitted on val:   %.4f\n', T_fitVal);
fprintf('  T fitted on train: %.4f\n', T_fitTrain);
fprintf('  NLL obj (val):     %.6f\n', fvalVal);
fprintf('  NLL obj (train):   %.6f\n', fvalTrain);
fprintf('\n');
fprintf('  %-22s  %10s  %10s\n', 'Metric', 'Raw', 'Cal(T_train)');
fprintf('  %-22s  %10.4f  %10.4f\n', 'ECE', eceRawVal, eceCalT);
fprintf('  %-22s  %10.4f  %10.4f\n', 'Brier', brierRawVal, brierCalT);
fprintf('  %-22s  %10.4f  %10.4f\n', 'NLL', nllRawVal, nllCalT);
fprintf('\n');
fprintf('  Flip fraction across 0.60: %.4f%% (%d / %d images)\n', flipFraction*100, sum(decRaw ~= decCal), sum(valIdx));
fprintf('  Raw referable decisions on val: %d / %d (%.1f%%)\n', sum(decRaw), sum(valIdx), 100*mean(decRaw));
fprintf('  Cal referable decisions on val: %d / %d (%.1f%%)\n', sum(decCal), sum(valIdx), 100*mean(decCal));
fprintf('============================================\n');

%% --- Save ---
outDir = fullfile(rootDir, 'data', 'analysis', 'day8', 'calibration', 'standard');
if ~exist(outDir, 'dir'), mkdir(outDir); end
save(fullfile(outDir, 'standard_calibration.mat'), ...
    'T_fitVal', 'T_fitTrain', ...
    'eceRawVal', 'eceCalVal', 'eceCalT', ...
    'brierRawVal', 'brierCalVal', 'brierCalT', ...
    'nllRawVal', 'nllCalVal', 'nllCalT', ...
    'flipFraction', 'tabRaw', 'tabCal', 'tabCalVal');
fprintf('\nSaved to %s/standard_calibration.mat\n', outDir);