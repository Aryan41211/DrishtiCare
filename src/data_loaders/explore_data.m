% explore_data.m - Day 2: APTOS Dataset Exploration
% Run this script to analyze the dataset
%
% Usage:
%   explore_data    % Runs with default path

fprintf('=== DrishtiCare Data Exploration ===\n');
fprintf('Date: %s\n\n', datestr(now));

%% Setup paths
script_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(fileparts(script_dir));
dataRoot = fullfile(project_root, 'data', 'aptos2019');

%% Load CSV
fprintf('--- Loading Dataset ---\n');
trainCsv = fullfile(dataRoot, 'train.csv');
data = readtable(trainCsv);
fprintf('Loaded %d images from train.csv\n\n', height(data));

%% 1. Class Distribution Analysis
fprintf('=== CLASS DISTRIBUTION ===\n');
classNames = {'0 - No DR', '1 - Mild', '2 - Moderate', '3 - Severe', '4 - Proliferative'};
classCounts = zeros(5, 1);
for i = 0:4
    classCounts(i+1) = sum(data.diagnosis == i);
end

fprintf('Class\t\tCount\tPercentage\n');
fprintf('-----\t\t-----\t----------\n');
for i = 1:5
    pct = classCounts(i) / height(data) * 100;
    fprintf('%s\t%d\t%.1f%%\n', classNames{i}, classCounts(i), pct);
end
fprintf('\n');

% Bar chart
figure('Name', 'Class Distribution', 'NumberTitle', 'off');
bar(0:4, classCounts, 'FaceColor', [0.2 0.6 0.8]);
xlabel('DR Severity Grade');
ylabel('Number of Images');
title('APTOS 2019 - Class Distribution');
xticks(0:4);
xticklabels(classNames);
xtickangle(45);
grid on;

% Add count labels on bars
for i = 1:5
    text(i-1, classCounts(i)+50, num2str(classCounts(i)), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold');
end

fprintf('[PASS] Class distribution plotted\n\n');

%% 2. Sample Images from Each Class
fprintf('=== SAMPLE IMAGES ===\n');
trainDir = fullfile(dataRoot, 'train_images');

figure('Name', 'Sample Images from Each Class', 'NumberTitle', 'off', ...
       'Position', [50, 50, 1400, 300]);

for class = 0:4
    classIdx = find(data.diagnosis == class);
    if ~isempty(classIdx)
        % Get first image from this class
        imgName = data.id_code{classIdx(1)};
        imgPath = fullfile(trainDir, [imgName '.png']);

        if exist(imgPath, 'file')
            img = imread(imgPath);
            subplot(1, 5, class+1);
            imshow(img);
            title(sprintf('Class %d\n%s', class, classNames{class+1}), ...
                'FontSize', 10, 'FontWeight', 'bold');

            [h, w, c] = size(img);
            fprintf('Class %d: %s (%dx%d)\n', class, imgName, h, w);
        end
    end
end
fprintf('\n');

%% 3. Multiple Samples Grid
fprintf('=== SAMPLE GRID (3 per class) ===\n');
figure('Name', 'Sample Grid - 3 per Class', 'NumberTitle', 'off', ...
       'Position', [50, 50, 1400, 800]);

for class = 0:4
    classIdx = find(data.diagnosis == class);
    numSamples = min(3, length(classIdx));

    for s = 1:numSamples
        imgName = data.id_code{classIdx(s)};
        imgPath = fullfile(trainDir, [imgName '.png']);

        if exist(imgPath, 'file')
            img = imread(imgPath);
            subplot(5, 3, class*3 + s);
            imshow(img);

            if s == 2
                title(sprintf('Class %d: %s', class, classNames{class+1}), ...
                    'FontSize', 10);
            end
        end
    end
end
fprintf('[PASS] Sample grid created\n\n');

%% 4. Image Size Analysis
fprintf('=== IMAGE SIZE ANALYSIS ===\n');
trainFiles = dir(fullfile(trainDir, '*.png'));
numAnalyze = min(100, length(trainFiles));

widths = zeros(numAnalyze, 1);
heights = zeros(numAnalyze, 1);

for i = 1:numAnalyze
    imgPath = fullfile(trainDir, trainFiles(i).name);
    info = imfinfo(imgPath);
    widths(i) = info.Width;
    heights(i) = info.Height;
end

fprintf('Width:  Min=%d, Max=%d, Mean=%.0f, Median=%d\n', ...
    min(widths), max(widths), mean(widths), median(widths));
fprintf('Height: Min=%d, Max=%d, Mean=%.0f, Median=%d\n', ...
    min(heights), max(heights), mean(heights), median(heights));

% Size distribution plot
figure('Name', 'Image Size Distribution', 'NumberTitle', 'off');
subplot(1,2,1);
histogram(widths, 20, 'FaceColor', [0.2 0.6 0.8]);
xlabel('Width (pixels)');
ylabel('Count');
title('Width Distribution');
grid on;

subplot(1,2,2);
histogram(heights, 20, 'FaceColor', [0.8 0.4 0.2]);
xlabel('Height (pixels)');
ylabel('Count');
title('Height Distribution');
grid on;

fprintf('[PASS] Size analysis complete\n\n');

%% 5. File Size Analysis
fprintf('=== FILE SIZE ANALYSIS ===\n');
fileSizes = zeros(numAnalyze, 1);
for i = 1:numAnalyze
    fileInfo = dir(fullfile(trainDir, trainFiles(i).name));
    fileSizes(i) = fileInfo.bytes / 1e6; % MB
end

fprintf('File Size: Min=%.2f MB, Max=%.2f MB, Mean=%.2f MB\n', ...
    min(fileSizes), max(fileSizes), mean(fileSizes));

figure('Name', 'File Size Distribution', 'NumberTitle', 'off');
histogram(fileSizes, 20, 'FaceColor', [0.4 0.7 0.4]);
xlabel('File Size (MB)');
ylabel('Count');
title('PNG File Size Distribution');
grid on;

fprintf('[PASS] File size analysis complete\n\n');

%% Summary
fprintf('=== EXPLORATION SUMMARY ===\n');
fprintf('[OK] Dataset has %d images across 5 classes\n', height(data));
fprintf('[OK] Class imbalance detected (Class 0: %d, Class 4: %d)\n', ...
    classCounts(1), classCounts(5));
fprintf('[OK] Images have varying sizes (need resizing for training)\n');
fprintf('[OK] Sample images displayed\n');
fprintf('\nNext: Run quality_analysis.m to check image quality\n');
fprintf('=== End Exploration ===\n');
