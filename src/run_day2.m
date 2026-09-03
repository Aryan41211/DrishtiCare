function run_day2(mode)
% RUN_DAY2 Day 2: Dataset and Quality Exploration
%   run_day2()       - Fast mode (500 images)
%   run_day2('fast') - Fast mode (500 images)
%   run_day2('full') - Full mode (all 3662 images)
%
%   Day 2 explores the APTOS dataset and characterizes image quality
%   variation. It does NOT train any models or set final thresholds.
%
%   Output:
%       - Visualizations (figures)
%       - Metrics table (data/analysis/day2/)
%       - Summary statistics
%
%   This script discovers project-relative paths automatically.

    % Default mode
    if nargin < 1
        mode = 'fast';
    end

    % Track success/failure of each stage
    stages = struct('name', {}, 'passed', {}, 'error', {});

    fprintf('============================================\n');
    fprintf('       DrishtiCare - DAY 2 EXECUTION       \n');
    fprintf('============================================\n\n');

    %% Setup paths
    script_dir = fileparts(mfilename('fullpath'));
    project_root = fileparts(script_dir);
    cd(project_root);

    % Add source folders to path
    addpath(fullfile(project_root, 'src', 'quality'));
    addpath(fullfile(project_root, 'src', 'data_loaders'));

    fprintf('Project root: %s\n', project_root);
    fprintf('Mode: %s\n\n', upper(mode));

    %% STEP 1: Dataset Exploration
    fprintf('============================================\n');
    fprintf('         STEP 1: DATASET EXPLORATION         \n');
    fprintf('============================================\n\n');

    try
        % Load CSV metadata
        dataRoot = fullfile(project_root, 'data', 'aptos2019');
        trainCsv = fullfile(dataRoot, 'train.csv');
        data = readtable(trainCsv);
        fprintf('Loaded train.csv: %d images\n', height(data));

        % Class distribution
        classNames = {'0-No DR', '1-Mild', '2-Moderate', '3-Severe', '4-Proliferative'};
        classCounts = zeros(5, 1);
        for i = 0:4
            classCounts(i+1) = sum(data.diagnosis == i);
        end

        fprintf('\nClass Distribution:\n');
        for i = 1:5
            pct = classCounts(i) / height(data) * 100;
            fprintf('  %s: %d (%.1f%%)\n', classNames{i}, classCounts(i), pct);
        end

        % Store for later
        datasetInfo.numImages = height(data);
        datasetInfo.classCounts = classCounts;
        datasetInfo.classNames = classNames;

        fprintf('\n[PASS] APTOS metadata loaded\n');
        stages(1).name = 'Dataset metadata';
        stages(1).passed = true;

    catch e
        fprintf('[FAIL] Dataset loading failed: %s\n', e.message);
        stages(1).name = 'Dataset metadata';
        stages(1).passed = false;
        stages(1).error = e.message;
        fprintf('\nCannot continue without dataset. Aborting.\n');
        printDay2Summary(stages, mode);
        return;
    end

    %% STEP 2: Quality Metric Analysis
    fprintf('\n============================================\n');
    fprintf('      STEP 2: QUALITY METRIC ANALYSIS       \n');
    fprintf('============================================\n\n');

    try
        fprintf('Building metrics table (%s mode)...\n', mode);
        [metricsTable, sampleInfo] = buildMetricsTable(dataRoot, mode, 42);

        fprintf('\n[PASS] Quality metrics computed for %d images\n', ...
            sampleInfo.numAnalyzed);
        stages(2).name = 'Quality metrics';
        stages(2).passed = true;

    catch e
        fprintf('[FAIL] Quality metrics failed: %s\n', e.message);
        stages(2).name = 'Quality metrics';
        stages(2).passed = false;
        stages(2).error = e.message;
        fprintf('\nCannot continue without metrics. Aborting.\n');
        printDay2Summary(stages, mode);
        return;
    end

    %% STEP 3: Extreme / Potentially Problematic Image Review
    fprintf('\n============================================\n');
    fprintf('   STEP 3: EXTREME IMAGE REVIEW             \n');
    fprintf('============================================\n\n');

    try
        reviewExtremeExamples(metricsTable, sampleInfo);
        fprintf('\n[PASS] Extreme examples reviewed\n');
        stages(3).name = 'Extreme review';
        stages(3).passed = true;

    catch e
        fprintf('[WARN] Extreme review failed: %s\n', e.message);
        stages(3).name = 'Extreme review';
        stages(3).passed = false;
        stages(3).error = e.message;
    end

    %% STEP 4: Create Visualizations
    fprintf('\n============================================\n');
    fprintf('      STEP 4: VISUALIZATIONS                \n');
    fprintf('============================================\n\n');

    try
        createVisualizations(metricsTable, sampleInfo, dataRoot);
        fprintf('\n[PASS] Visualizations created\n');
        stages(4).name = 'Visualizations';
        stages(4).passed = true;

    catch e
        fprintf('[WARN] Visualizations failed: %s\n', e.message);
        stages(4).name = 'Visualizations';
        stages(4).passed = false;
        stages(4).error = e.message;
    end

    %% STEP 5: Save Analysis Results
    fprintf('\n============================================\n');
    fprintf('      STEP 5: SAVE RESULTS                  \n');
    fprintf('============================================\n\n');

    try
        saveDay2Results(metricsTable, sampleInfo, project_root);
        fprintf('\n[PASS] Results saved\n');
        stages(5).name = 'Save results';
        stages(5).passed = true;

    catch e
        fprintf('[WARN] Saving failed: %s\n', e.message);
        stages(5).name = 'Save results';
        stages(5).passed = false;
        stages(5).error = e.message;
    end

    %% Print Summary
    printDay2Summary(stages, mode);
end

function printDay2Summary(stages, mode)
    fprintf('\n============================================\n');
    fprintf('         DAY 2 SUMMARY                      \n');
    fprintf('============================================\n\n');

    allPassed = true;
    for i = 1:length(stages)
        if stages(i).passed
            fprintf('[PASS] %s\n', stages(i).name);
        else
            fprintf('[FAIL] %s: %s\n', stages(i).name, stages(i).error);
            allPassed = false;
        end
    end

    fprintf('\n--- Important Notes ---\n');
    fprintf('- Quality thresholds are exploratory and NOT clinically validated\n');
    fprintf('- Metrics use engineering proxies, not clinical standards\n');
    fprintf('- No ophthalmologist validation has been performed\n');

    fprintf('\n--- Deferred ---\n');
    fprintf('- Final quality-gate thresholds -> Day 3\n');
    fprintf('- Model training -> Days 5-6\n');
    fprintf('- Model evaluation -> Day 6+\n');

    fprintf('\n--- Next ---\n');
    fprintf('Day 3: Quality Assessment Module\n');

    if allPassed
        fprintf('\n=== Day 2 Complete (All Stages Passed) ===\n');
    else
        fprintf('\n=== Day 2 Complete (Some Stages Failed) ===\n');
    end
end
