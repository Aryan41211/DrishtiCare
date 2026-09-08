function run_task9b_variantA()
% RUN_TASK9B_VARIANTA Train variant A (raw) for Task 9B A/B experiment
%   run_task9b_variantA()
%
%   Trains a 5-class resnet18 on RAW input (no enhanceImage).
%   Identical protocol to variant B except preprocessing.

    fprintf('=== Task 9B Variant A: RAW Training ===\n');
    fprintf('Date: %s\n', datestr(now));

    projectRoot = pwd;
    addpath(genpath(fullfile(projectRoot, 'src')));

    config = defaultPretrainedConfig('day9_5class_raw');
    config.dataset.analysisDir = fullfile(projectRoot, 'data', 'analysis', 'day9');

    if ~exist(config.dataset.analysisDir, 'dir')
        mkdir(config.dataset.analysisDir);
    end

    rng(42);
    valDSraw = imageDatastore(fullfile(projectRoot, 'data', 'splits', 'val'), ...
        'IncludeSubfolders', true, 'LabelSource', 'foldernames');
    valDS = augmentedImageDatastore([224 224], valDSraw);

    trainDS = imageDatastore(fullfile(projectRoot, 'data', 'splits', 'train'), ...
        'IncludeSubfolders', true, 'LabelSource', 'foldernames');

    fprintf('Train: %d files, Val: %d files\n', ...
        length(trainDS.Files), length(valDSraw.Files));

    fprintf('\n--- Stage 1: Backbone frozen (15 epochs) ---\n');
    tic;
    try
        trainClassifier(trainDS, valDS, ...
            'Config', config, 'Stage', 1, ...
            'ExperimentId', 'day9_5class_raw', ...
            'NumClasses', 5);
        stage1Time = toc;
        fprintf('Stage 1 complete: %.1f seconds (%.1f min)\n', stage1Time, stage1Time/60);
    catch e
        stage1Time = toc;
        fprintf('Stage 1 FAILED after %.1f seconds: %s\n', stage1Time, e.message);
        rethrow(e);
    end

    fprintf('\n--- Stage 2: Backbone unfrozen (5 epochs) ---\n');
    config.finetune.stage2.maxEpochs = 5;
    config.training.maxEpochs = 5;

    rng(42);
    tic;
    try
        trainClassifier(trainDS, valDS, ...
            'Config', config, 'Stage', 2, ...
            'ExperimentId', 'day9_5class_raw', ...
            'NumClasses', 5);
        stage2Time = toc;
        fprintf('Stage 2 complete: %.1f seconds (%.1f min)\n', stage2Time, stage2Time/60);
    catch e
        stage2Time = toc;
        fprintf('Stage 2 FAILED after %.1f seconds: %s\n', stage2Time, e.message);
        rethrow(e);
    end

    fprintf('\n=== Variant A (raw) training complete ===\n');
    fprintf('Stage 1: %.1f s, Stage 2: %.1f s, Total: %.1f s\n', ...
        stage1Time, stage2Time, stage1Time + stage2Time);
end
