function [metricsTable, sampleInfo] = buildMetricsTable(dataRoot, mode, rngSeed)
% BUILDMETRICSTABLE Build a table of quality metrics for APTOS dataset
%   [metricsTable, sampleInfo] = buildMetricsTable(dataRoot, mode, rngSeed)
%
%   Inputs:
%       dataRoot - Path to aptos2019 folder
%       mode     - 'fast' (500 images) or 'full' (all 3662 images)
%       rngSeed  - Random seed for reproducibility (default: 42)
%
%   Outputs:
%       metricsTable - Table with one row per analyzed image
%       sampleInfo   - Struct with sampling information
%
%   The table contains columns:
%       id_code, diagnosis, image_path, width, height, aspect_ratio,
%       file_size_mb, brightness, contrast, focus_score,
%       foreground_fraction, background_fraction, illumination_metric,
%       mask_valid

    % Default arguments
    if nargin < 2
        mode = 'fast';
    end
    if nargin < 3
        rngSeed = 42;
    end

    % Setup paths
    if nargin < 1 || isempty(dataRoot)
        script_dir = fileparts(mfilename('fullpath'));
        project_root = fileparts(fileparts(script_dir));
        dataRoot = fullfile(project_root, 'data', 'aptos2019');
    end

    trainCsv = fullfile(dataRoot, 'train.csv');
    trainDir = fullfile(dataRoot, 'train_images');

    % Load CSV
    data = readtable(trainCsv);
    allFiles = dir(fullfile(trainDir, '*.png'));

    fprintf('Total images in dataset: %d\n', length(allFiles));

    % Set random seed for reproducibility
    rng(rngSeed);

    % Determine sample size
    if strcmpi(mode, 'full')
        numSamples = length(allFiles);
        fprintf('Mode: FULL (%d images)\n', numSamples);
    else
        numSamples = min(500, length(allFiles));
        fprintf('Mode: FAST (%d images)\n', numSamples);
    end

    % Stratified sampling: ensure representation from all classes
    fprintf('Performing stratified sampling...\n');

    % Group files by class
    classFiles = cell(5, 1);
    for i = 1:length(allFiles)
        [~, idx] = ismember(allFiles(i).name(1:end-4), data.id_code);
        if idx > 0
            classIdx = data.diagnosis(idx) + 1;  % 1-indexed
            classFiles{classIdx} = [classFiles{classIdx}; i];
        end
    end

    % Sample from each class proportionally
    selectedIndices = [];
    classCounts = zeros(5, 1);

    for c = 1:5
        classCount = length(classFiles{c});
        if strcmpi(mode, 'full')
            % Use all images
            sampleCount = classCount;
        else
            % Proportional sampling
            proportion = classCount / length(allFiles);
            sampleCount = max(1, round(numSamples * proportion));
            sampleCount = min(sampleCount, classCount);
        end

        if classCount > 0
            perm = randperm(classCount);
            selectedIndices = [selectedIndices; classFiles{c}(perm(1:sampleCount))];
            classCounts(c) = sampleCount;
        end
    end

    % Shuffle selected indices
    selectedIndices = selectedIndices(randperm(length(selectedIndices)));
    numSelected = length(selectedIndices);

    fprintf('Selected %d images for analysis\n', numSelected);
    fprintf('Class distribution in sample:\n');
    classNames = {'0-NoDR', '1-Mild', '2-Moderate', '3-Severe', '4-Prolif'};
    for c = 1:5
        fprintf('  %s: %d\n', classNames{c}, classCounts(c));
    end

    % Store sample information
    sampleInfo.mode = mode;
    sampleInfo.rngSeed = rngSeed;
    sampleInfo.numAnalyzed = numSelected;
    sampleInfo.classCounts = classCounts;
    sampleInfo.classNames = classNames;

    % Preallocate table arrays
    id_codes = cell(numSelected, 1);
    diagnoses = zeros(numSelected, 1);
    image_paths = cell(numSelected, 1);
    widths = zeros(numSelected, 1);
    heights = zeros(numSelected, 1);
    aspect_ratios = zeros(numSelected, 1);
    file_sizes = zeros(numSelected, 1);
    brightness_vals = zeros(numSelected, 1);
    contrast_vals = zeros(numSelected, 1);
    focus_vals = zeros(numSelected, 1);
    fg_frac = zeros(numSelected, 1);
    bg_frac = zeros(numSelected, 1);
    illum_vals = nan(numSelected, 1);
    mask_valid = false(numSelected, 1);

    % Process each image
    fprintf('\nProcessing images...\n');
    failedCount = 0;

    for i = 1:numSelected
        fileIdx = selectedIndices(i);
        imgName = allFiles(fileIdx).name;
        imgPath = fullfile(trainDir, imgName);

        % Get class label
        [~, dataIdx] = ismember(imgName(1:end-4), data.id_code);
        if dataIdx > 0
            diagnoses(i) = data.diagnosis(dataIdx);
        end

        % Store basic info
        id_codes{i} = imgName(1:end-4);
        image_paths{i} = imgPath;

        % Get file size
        fileInfo = dir(imgPath);
        file_sizes(i) = fileInfo.bytes / 1e6;  % MB

        % Read image and compute metrics
        try
            img = imread(imgPath);
            metrics = computeQualityMetrics(img);

            widths(i) = metrics.width;
            heights(i) = metrics.height;
            aspect_ratios(i) = metrics.aspectRatio;
            brightness_vals(i) = metrics.brightness;
            contrast_vals(i) = metrics.contrast;
            focus_vals(i) = metrics.focusScore;
            fg_frac(i) = metrics.foregroundFrac;
            bg_frac(i) = metrics.backgroundFrac;
            illum_vals(i) = metrics.illumination;
            mask_valid(i) = metrics.maskValid;

        catch
            failedCount = failedCount + 1;
            widths(i) = NaN;
            heights(i) = NaN;
            aspect_ratios(i) = NaN;
            brightness_vals(i) = NaN;
            contrast_vals(i) = NaN;
            focus_vals(i) = NaN;
            fg_frac(i) = NaN;
            bg_frac(i) = NaN;
            illum_vals(i) = NaN;
            mask_valid(i) = false;
        end

        % Progress update
        if mod(i, 100) == 0 || i == numSelected
            fprintf('  Processed %d/%d images\n', i, numSelected);
        end
    end

    fprintf('\nProcessing complete. Failed: %d images\n', failedCount);

    % Build table
    metricsTable = table(id_codes, diagnoses, image_paths, ...
        widths, heights, aspect_ratios, file_sizes, ...
        brightness_vals, contrast_vals, focus_vals, ...
        fg_frac, bg_frac, illum_vals, mask_valid, ...
        'VariableNames', {'id_code', 'diagnosis', 'image_path', ...
            'width', 'height', 'aspect_ratio', 'file_size_mb', ...
            'brightness', 'contrast', 'focus_score', ...
            'foreground_fraction', 'background_fraction', ...
            'illumination_metric', 'mask_valid'});

    fprintf('Metrics table built: %d rows, %d columns\n', ...
        height(metricsTable), width(metricsTable));
end
