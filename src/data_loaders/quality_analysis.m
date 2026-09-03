% quality_analysis.m - Day 2: Image Quality Analysis
% Analyze blur, brightness, contrast, and FOV coverage
%
% Usage:
%   quality_analysis

fprintf('=== DrishtiCare Quality Analysis ===\n');
fprintf('Date: %s\n\n', datestr(now));

%% Setup paths
script_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(fileparts(script_dir));
dataRoot = fullfile(project_root, 'data', 'aptos2019');
trainDir = fullfile(dataRoot, 'train_images');
trainCsv = fullfile(dataRoot, 'train.csv');

%% Load CSV
data = readtable(trainCsv);
trainFiles = dir(fullfile(trainDir, '*.png'));

% Sample size for analysis (use all if < 500)
numSamples = min(500, length(trainFiles));
fprintf('Analyzing %d images for quality...\n\n', numSamples);

%% Preallocate arrays
blurScores = zeros(numSamples, 1);
brightness = zeros(numSamples, 1);
contrast = zeros(numSamples, 1);
fovCoverage = zeros(numSamples, 1);
fileSizes = zeros(numSamples, 1);
classLabels = zeros(numSamples, 1);
imgWidths = zeros(numSamples, 1);
imgHeights = zeros(numSamples, 1);

%% Analyze each image
fprintf('Processing images...\n');
for i = 1:numSamples
    imgName = trainFiles(i).name;
    imgPath = fullfile(trainDir, imgName);

    % Read image
    img = imread(imgPath);
    if size(img, 3) == 3
        gray = rgb2gray(img);
    else
        gray = img;
    end

    % Get class label
    [~, idx] = ismember(imgName(1:end-4), data.id_code);
    if idx > 0
        classLabels(i) = data.diagnosis(idx);
    end

    % Get image size
    [h, w, ~] = size(img);
    imgWidths(i) = w;
    imgHeights(i) = h;

    % 1. Blur detection (Variance of Laplacian)
    laplacian = fspecial('laplacian');
    filtered = imfilter(double(gray), laplacian);
    blurScores(i) = var(filtered(:));

    % 2. Brightness
    brightness(i) = mean(gray(:));

    % 3. Contrast (standard deviation)
    contrast(i) = std(double(gray(:)));

    % 4. FOV Coverage (simple threshold)
    mask = gray > 20;
    fovCoverage(i) = sum(mask(:)) / numel(mask);

    % 5. File size
    fileInfo = dir(imgPath);
    fileSizes(i) = fileInfo.bytes / 1e6;

    if mod(i, 100) == 0
        fprintf('  Processed %d/%d images\n', i, numSamples);
    end
end
fprintf('Done!\n\n');

%% Analysis Results
fprintf('=== QUALITY METRICS SUMMARY ===\n');

% Blur
fprintf('\n--- Blur Score (Variance of Laplacian) ---\n');
fprintf('Min: %.1f, Max: %.1f, Mean: %.1f, Median: %.1f\n', ...
    min(blurScores), max(blurScores), mean(blurScores), median(blurScores));
blurThreshold = 100;
blurry = sum(blurScores < blurThreshold);
fprintf('Potentially blurry (<%d): %d images (%.1f%%)\n', ...
    blurThreshold, blurry, blurry/numSamples*100);

% Brightness
fprintf('\n--- Brightness ---\n');
fprintf('Min: %.1f, Max: %.1f, Mean: %.1f, Median: %.1f\n', ...
    min(brightness), max(brightness), mean(brightness), median(brightness));
tooDark = sum(brightness < 40);
tooBright = sum(brightness > 220);
fprintf('Too dark (<40): %d images (%.1f%%)\n', tooDark, tooDark/numSamples*100);
fprintf('Too bright (>220): %d images (%.1f%%)\n', tooBright, tooBright/numSamples*100);

% Contrast
fprintf('\n--- Contrast ---\n');
fprintf('Min: %.1f, Max: %.1f, Mean: %.1f, Median: %.1f\n', ...
    min(contrast), max(contrast), mean(contrast), median(contrast));

% FOV Coverage
fprintf('\n--- FOV Coverage ---\n');
fprintf('Min: %.2f, Max: %.2f, Mean: %.2f, Median: %.2f\n', ...
    min(fovCoverage), max(fovCoverage), mean(fovCoverage), median(fovCoverage));
lowFov = sum(fovCoverage < 0.3);
fprintf('Low FOV (<30%%): %d images (%.1f%%)\n', lowFov, lowFov/numSamples*100);

%% Visualizations
fprintf('\n--- Creating Visualizations ---\n');

% Figure 1: Blur Distribution
figure('Name', 'Quality Analysis - Blur', 'NumberTitle', 'off');
subplot(2,2,1);
histogram(blurScores, 30, 'FaceColor', [0.2 0.6 0.8]);
hold on;
xline(blurThreshold, 'r--', 'LineWidth', 2);
xlabel('Blur Score');
ylabel('Count');
title('Blur Score Distribution');
legend('Scores', sprintf('Threshold (%d)', blurThreshold));
grid on;

% Figure 2: Brightness Distribution
subplot(2,2,2);
histogram(brightness, 30, 'FaceColor', [0.8 0.6 0.2]);
hold on;
xline(40, 'r--', 'LineWidth', 2);
xline(220, 'r--', 'LineWidth', 2);
xlabel('Brightness');
ylabel('Count');
title('Brightness Distribution');
legend('Brightness', 'Thresholds');
grid on;

% Figure 3: Contrast Distribution
subplot(2,2,3);
histogram(contrast, 30, 'FaceColor', [0.4 0.7 0.4]);
xlabel('Contrast (Std Dev)');
ylabel('Count');
title('Contrast Distribution');
grid on;

% Figure 4: FOV Coverage Distribution
subplot(2,2,4);
histogram(fovCoverage, 30, 'FaceColor', [0.7 0.3 0.7]);
hold on;
xline(0.3, 'r--', 'LineWidth', 2);
xlabel('FOV Coverage');
ylabel('Count');
title('Field of View Coverage');
legend('Coverage', 'Threshold (30%)');
grid on;

sgtitle('Image Quality Analysis', 'FontSize', 14, 'FontWeight', 'bold');

% Figure 2: Blur vs Brightness scatter
figure('Name', 'Quality Analysis - Scatter', 'NumberTitle', 'off');
scatter(blurScores, brightness, 20, classLabels, 'filled');
colormap(gca, jet(5));
cb = colorbar;
cb.Ticks = 0:4;
cb.TickLabels = classNames;
xlabel('Blur Score');
ylabel('Brightness');
title('Blur vs Brightness by Class');
grid on;

% Figure 3: Worst quality images
fprintf('\n--- Worst Quality Images ---\n');
[~, blurIdx] = sort(blurScores);
fprintf('\nBlurriest 5 images:\n');
for i = 1:min(5, length(blurIdx))
    idx = blurIdx(i);
    fprintf('  %s: blur=%.1f, brightness=%.1f, class=%d\n', ...
        trainFiles(idx).name, blurScores(idx), brightness(idx), classLabels(idx));
end

[~, brightIdx] = sort(brightness);
fprintf('\nDarkest 5 images:\n');
for i = 1:min(5, length(brightIdx))
    idx = brightIdx(i);
    fprintf('  %s: brightness=%.1f, blur=%.1f, class=%d\n', ...
        trainFiles(idx).name, brightness(idx), blurScores(idx), classLabels(idx));
end

%% Quality Report
fprintf('\n=== QUALITY REPORT ===\n');
fprintf('Total images analyzed: %d\n', numSamples);
fprintf('\nPotential Issues:\n');
fprintf('  Blurry images: %d (%.1f%%)\n', blurry, blurry/numSamples*100);
fprintf('  Too dark: %d (%.1f%%)\n', tooDark, tooDark/numSamples*100);
fprintf('  Too bright: %d (%.1f%%)\n', tooBright, tooBright/numSamples*100);
fprintf('  Low FOV: %d (%.1f%%)\n', lowFov, lowFov/numSamples*100);

fprintf('\nRecommendations:\n');
fprintf('  1. Blur threshold: Use %d for quality gate\n', blurThreshold);
fprintf('  2. Brightness range: Keep images between 40-220\n');
fprintf('  3. FOV threshold: Reject images with <30%% coverage\n');
fprintf('  4. Class imbalance: Use oversampling or class weights\n');

fprintf('\n[OK] Quality analysis complete\n');
fprintf('=== End Quality Analysis ===\n');
