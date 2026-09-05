function run_day4(mode)
% RUN_DAY4 Day 4: Image Enhancement
%   run_day4()       - Fast mode (100 images)
%   run_day4('fast') - Fast mode (100 images)
%   run_day4('full') - Full mode (all 3662 images)
%
%   Day 4 implements the image enhancement pipeline:
%   - CLAHE contrast enhancement
%   - Illumination normalization
%   - Denoising
%
%   Output:
%       - Enhanced images (stored in memory for pipeline)
%       - Before/after quality metrics comparison
%       - Enhancement statistics
%
%   This script does NOT train models. It enhances images for downstream
%   processing in Day 5-6.

    % Default mode
    if nargin < 1
        mode = 'fast';
    end

    %% Setup
    script_dir = fileparts(mfilename('fullpath'));
    project_root = fileparts(fileparts(script_dir));
    cd(project_root);

    addpath(fullfile(project_root, 'src', 'quality'));
    addpath(fullfile(project_root, 'src', 'enhancement'));

    fprintf('============================================\n');
    fprintf('       DrishtiCare - DAY 4 EXECUTION        \n');
    fprintf('         Image Enhancement                  \n');
    fprintf('============================================\n\n');

    fprintf('Project root: %s\n', project_root);
    fprintf('Mode: %s\n\n', upper(mode));

    %% Load dataset
    dataRoot = fullfile(project_root, 'data', 'aptos2019');
    trainCsv = fullfile(dataRoot, 'train.csv');
    trainDir = fullfile(dataRoot, 'train_images');

    try
        data = readtable(trainCsv);
        allFiles = dir(fullfile(trainDir, '*.png'));
        fprintf('Loaded dataset: %d images\n', length(allFiles));
    catch e
        fprintf('[ERROR] Failed to load dataset: %s\n', e.message);
        return;
    end

    %% Determine sample size
    rng(42);  % Reproducible

    if strcmpi(mode, 'full')
        numSamples = length(allFiles);
        fprintf('Mode: FULL (%d images)\n', numSamples);
    else
        numSamples = min(100, length(allFiles));
        fprintf('Mode: FAST (%d images)\n', numSamples);
    end

    % Stratified sampling
    fprintf('Performing stratified sampling...\n');
    classFiles = cell(5, 1);
    for i = 1:length(allFiles)
        [~, idx] = ismember(allFiles(i).name(1:end-4), data.id_code);
        if idx > 0
            classIdx = data.diagnosis(idx) + 1;
            classFiles{classIdx} = [classFiles{classIdx}; i];
        end
    end

    selectedIndices = [];
    classCounts = zeros(5, 1);
    classNames = {'0-NoDR', '1-Mild', '2-Moderate', '3-Severe', '4-Prolif'};

    for c = 1:5
        classCount = length(classFiles{c});
        if strcmpi(mode, 'full')
            sampleCount = classCount;
        else
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

    selectedIndices = selectedIndices(randperm(length(selectedIndices)));
    numSelected = length(selectedIndices);

    fprintf('Selected %d images for enhancement\n', numSelected);
    fprintf('Class distribution:\n');
    for c = 1:5
        fprintf('  %s: %d\n', classNames{c}, classCounts(c));
    end

    %% Process images
    fprintf('\n--- Enhancing Images ---\n');

    % Preallocate results
    id_codes = cell(numSelected, 1);
    diagnoses = zeros(numSelected, 1);
    brightness_before = zeros(numSelected, 1);
    brightness_after = zeros(numSelected, 1);
    contrast_before = zeros(numSelected, 1);
    contrast_after = zeros(numSelected, 1);
    focus_before = zeros(numSelected, 1);
    focus_after = zeros(numSelected, 1);

    startTime = tic;

    for i = 1:numSelected
        fileIdx = selectedIndices(i);
        imgName = allFiles(fileIdx).name;
        imgPath = fullfile(trainDir, imgName);

        % Get diagnosis
        [~, dataIdx] = ismember(imgName(1:end-4), data.id_code);
        if dataIdx > 0
            diagnoses(i) = data.diagnosis(dataIdx);
        end

        id_codes{i} = imgName(1:end-4);

        % Read and enhance
        try
            img = imread(imgPath);
            enhanced = enhanceImage(img);

            % Compute metrics before and after
            metrics_before = computeQualityMetrics(img);
            metrics_after = computeQualityMetrics(enhanced);

            brightness_before(i) = metrics_before.brightness;
            brightness_after(i) = metrics_after.brightness;
            contrast_before(i) = metrics_before.contrast;
            contrast_after(i) = metrics_after.contrast;
            focus_before(i) = metrics_before.focusScore;
            focus_after(i) = metrics_after.focusScore;

        catch e
            fprintf('[WARN] Failed to process %s: %s\n', imgName, e.message);
            brightness_before(i) = NaN;
            brightness_after(i) = NaN;
            contrast_before(i) = NaN;
            contrast_after(i) = NaN;
            focus_before(i) = NaN;
            focus_after(i) = NaN;
        end

        % Progress update
        if mod(i, 50) == 0 || i == numSelected
            elapsed = toc(startTime);
            eta = elapsed / i * (numSelected - i);
            fprintf('  Processed %d/%d (%.1f%%) [ETA: %.0fs]\n', ...
                i, numSelected, i/numSelected*100, eta);
        end
    end

    totalTime = toc(startTime);
    fprintf('\nProcessing complete: %.1f seconds\n', totalTime);
    fprintf('Rate: %.1f images/second\n', numSelected/totalTime);

    %% Compute improvement statistics
    fprintf('\n============================================\n');
    fprintf('         ENHANCEMENT RESULTS                \n');
    fprintf('============================================\n\n');

    % Compute improvements
    bright_improved = sum(brightness_after > brightness_before);
    contrast_improved = sum(contrast_after > contrast_before);
    focus_improved = sum(focus_after > focus_before);

    fprintf('Enhancement Statistics (%d images):\n', numSelected);
    fprintf('  Brightness improved: %d/%d (%.1f%%)\n', ...
        bright_improved, numSelected, bright_improved/numSelected*100);
    fprintf('  Contrast improved: %d/%d (%.1f%%)\n', ...
        contrast_improved, numSelected, contrast_improved/numSelected*100);
    fprintf('  Focus improved: %d/%d (%.1f%%)\n', ...
        focus_improved, numSelected, focus_improved/numSelected*100);

    % Compute mean improvements
    fprintf('\nMean Metric Changes:\n');
    fprintf('  Brightness: %.4f -> %.4f (Δ = %+.4f)\n', ...
        nanmean(brightness_before), nanmean(brightness_after), ...
        nanmean(brightness_after) - nanmean(brightness_before));
    fprintf('  Contrast:   %.4f -> %.4f (Δ = %+.4f)\n', ...
        nanmean(contrast_before), nanmean(contrast_after), ...
        nanmean(contrast_after) - nanmean(contrast_before));
    fprintf('  Focus:      %.6e -> %.6e (Δ = %+.6e)\n', ...
        nanmean(focus_before), nanmean(focus_after), ...
        nanmean(focus_after) - nanmean(focus_before));

    %% Per-diagnosis breakdown
    fprintf('\nResults by Diagnosis:\n');
    for d = 0:4
        diagMask = diagnoses == d;
        diagTotal = sum(diagMask);
        if diagTotal > 0
            diagBrightImproved = sum(brightness_after(diagMask) > brightness_before(diagMask));
            diagContrastImproved = sum(contrast_after(diagMask) > contrast_before(diagMask));
            fprintf('  %s: %d images, Bright=%d%%, Contrast=%d%%\n', ...
                classNames{d+1}, diagTotal, ...
                round(diagBrightImproved/diagTotal*100), ...
                round(diagContrastImproved/diagTotal*100));
        end
    end

    %% Save results
    outputDir = fullfile(project_root, 'data', 'analysis', 'day4');
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    % Build results table
    resultsTable = table(id_codes, diagnoses, ...
        brightness_before, brightness_after, ...
        contrast_before, contrast_after, ...
        focus_before, focus_after, ...
        'VariableNames', {'id_code', 'diagnosis', ...
            'brightness_before', 'brightness_after', ...
            'contrast_before', 'contrast_after', ...
            'focus_before', 'focus_after'});

    % Save CSV
    csvPath = fullfile(outputDir, 'enhancement_results.csv');
    writetable(resultsTable, csvPath);
    fprintf('\nSaved CSV: %s\n', csvPath);

    % Save MAT
    summary = struct();
    summary.mode = mode;
    summary.numAnalyzed = numSelected;
    summary.classCounts = classCounts;
    summary.classNames = classNames;
    summary.totalTime = totalTime;
    summary.resultsTable = resultsTable;

    matPath = fullfile(outputDir, 'enhancement_summary.mat');
    save(matPath, 'summary');
    fprintf('Saved MAT: %s\n', matPath);

    %% Important notes
    fprintf('\n--- IMPORTANT NOTES ---\n');
    fprintf('- Enhancements are ENGINEERING optimizations, NOT clinical processing\n');
    fprintf('- CLAHE, illumination normalization, and denoising are standard techniques\n');
    fprintf('- Enhancements may alter clinically relevant features\n');
    fprintf('- Clinical validation requires ophthalmologist review\n');

    fprintf('\n=== Day 4 Image Enhancement Complete ===\n');
end