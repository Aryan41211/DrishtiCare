%% verify_ood.m — Sanity-check the Mahalanobis OOD detector
%  Shows in-distribution distance stats and tests synthetic OOD inputs.
%
%  Engineering demo — NOT a clinical device.

cd('C:\projects\DrishtiCare');
addpath(genpath('src'));

%% 1. Load precomputed stats
statsPath = fullfile('data', 'analysis', 'day8', 'ood', 'ood_stats.mat');
if ~exist(statsPath, 'file')
    error('Run buildOodStats first to generate ood_stats.mat');
end
S = load(statsPath, 'oodStats', 'mDistAll');
stats = S.oodStats;
dists = double(S.mDistAll);

fprintf('=== OOD Detector Verification ===\n');
fprintf('Feature layer: %s  (%d-d)\n', stats.featureLayer, stats.featDim);
fprintf('Images fit: %d\n', stats.nImagesFit);
fprintf('Threshold (p99): %.4f\n\n', stats.threshold);

fprintf('In-distribution Mahalanobis distance distribution:\n');
fprintf('  mean  = %.4f\n', mean(dists));
fprintf('  median= %.4f\n', median(dists));
fprintf('  p90   = %.4f\n', prctile(dists, 90));
fprintf('  p95   = %.4f\n', prctile(dists, 95));
fprintf('  p99   = %.4f\n', prctile(dists, 99));
fprintf('  max   = %.4f\n', max(dists));
fprintf('  false-OOD rate at threshold: %.2f%%\n\n', stats.distStats.falseOodRate);

%% 2. Sanity checks with synthetic/corrupted OOD inputs
fprintf('--- OOD Sanity Checks ---\n\n');

% (a) Solid-color image (pure red — not a fundus)
solidRed = uint8(repmat(reshape([255 0 0], 1, 1, 3), 224, 224));
[fA, dA, detA] = ood_detector(solidRed);
fprintf('(a) Solid red image:\n');
fprintf('    Mahalanobis dist = %.4f  (threshold=%.4f)  OOD=%d\n', ...
    dA, detA.threshold, fA);
fprintf('    Per-class dists: [%.4f %.4f %.4f %.4f %.4f]\n\n', detA.classDists);

% (b) Full Gaussian noise image
rng(7);
noiseImg = uint8(randn(224, 224, 3) * 60 + 128);
[fB, dB, detB] = ood_detector(noiseImg);
fprintf('(b) Gaussian noise image:\n');
fprintf('    Mahalanobis dist = %.4f  (threshold=%.4f)  OOD=%d\n', ...
    dB, detB.threshold, fB);
fprintf('    Per-class dists: [%.4f %.4f %.4f %.4f %.4f]\n\n', detB.classDists);

% (c) A real train image (first in the CSV) — should be IN-distribution
T = readtable(fullfile('data', 'aptos2019', 'train.csv'));
firstId = char(T.id_code(1));
realPath = fullfile('data', 'aptos2019', 'train_images', [firstId, '.png']);
[fC, dC, detC] = ood_detector(realPath);
fprintf('(c) Real train image (%s):\n', firstId);
fprintf('    Mahalanobis dist = %.4f  (threshold=%.4f)  OOD=%d\n', ...
    dC, detC.threshold, fC);
fprintf('    Per-class dists: [%.4f %.4f %.4f %.4f %.4f]\n\n', detC.classDists);

% (d) Heavily blurred version of the real image (Gaussian blur sigma=15)
rawReal = imread(realPath);
if size(rawReal, 3) == 1, rawReal = repmat(rawReal, 1, 1, 3); end
h = fspecial('gaussian', [25 25], 15);
blurred = imfilter(rawReal, h, 'replicate');
% Also crush brightness to 20%
blurredDark = uint8(double(blurred) * 0.2);
[fD, dD, detD] = ood_detector(blurredDark);
fprintf('(d) Blurred + darkened train image:\n');
fprintf('    Mahalanobis dist = %.4f  (threshold=%.4f)  OOD=%d\n', ...
    dD, detD.threshold, fD);
fprintf('    Per-class dists: [%.4f %.4f %.4f %.4f %.4f]\n\n', detD.classDists);

% (e) Solid black image
blackImg = uint8(zeros(224, 224, 3));
[fE, dE, detE] = ood_detector(blackImg);
fprintf('(e) Solid black image:\n');
fprintf('    Mahalanobis dist = %.4f  (threshold=%.4f)  OOD=%d\n', ...
    dE, detE.threshold, fE);
fprintf('    Per-class dists: [%.4f %.4f %.4f %.4f %.4f]\n\n', detE.classDists);

% (f) Salt-and-pepper noise on a real image
noisyReal = imnoise(rawReal, 'salt & pepper', 0.5);
[fF, dF, detF] = ood_detector(noisyReal);
fprintf('(f) Salt-and-pepper noise on real image (density=0.5):\n');
fprintf('    Mahalanobis dist = %.4f  (threshold=%.4f)  OOD=%d\n', ...
    dF, detF.threshold, fF);
fprintf('    Per-class dists: [%.4f %.4f %.4f %.4f %.4f]\n\n', detF.classDists);

%% 3. Summary table
fprintf('=== Summary ===\n');
fprintf('%-45s %10s %10s\n', 'Input', 'mDist', 'OOD?');
fprintf('%s\n', repmat('-', 1, 67));
fprintf('%-45s %10.4f %10d\n', '(a) Solid red', dA, fA);
fprintf('%-45s %10.4f %10d\n', '(b) Gaussian noise', dB, fB);
fprintf('%-45s %10.4f %10d\n', '(c) Real train image (ID)', dC, fC);
fprintf('%-45s %10.4f %10d\n', '(d) Blurred + darkened', dD, fD);
fprintf('%-45s %10.4f %10d\n', '(e) Solid black', dE, fE);
fprintf('%-45s %10.4f %10d\n', '(f) Salt-and-pepper noise', dF, fF);
fprintf('%-45s %10.4f\n', '(threshold)', stats.threshold);
fprintf('\nDone.\n');
