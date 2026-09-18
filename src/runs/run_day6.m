function run_day6(mode)
% RUN_DAY6 Master script for Day 6 - Training + Results
%   run_day6()          - Run in 'verify' mode (default)
%   run_day6('verify')  - Verify setup without training
%   run_day6('train')   - Train classifier (Stage 1 + Stage 2)
%   run_day6('eval')    - Evaluate trained model
%   run_day6('compare') - Compare original vs enhanced input
%
%   IMPORTANT: This is an ENGINEERING training pipeline, NOT a clinical
%   validation system.

    %% Default mode
    if nargin < 1
        mode = 'verify';
    end

    %% Setup paths
    project_root = pwd;
    addpath(fullfile(project_root, 'src', 'setup'));
    addpath(fullfile(project_root, 'src', 'quality'));
    addpath(fullfile(project_root, 'src', 'enhancement'));
    addpath(fullfile(project_root, 'src', 'grading'));

    %% Print header
    fprintf('============================================\n');
    fprintf('   DrishtiCare - Day 6 Training + Results    \n');
    fprintf('============================================\n\n');
    fprintf('Mode: %s\n', upper(mode));
    fprintf('Date: %s\n\n', datestr(now));

    %% Load config
    fprintf('--- Loading Configuration ---\n');
    try
        config = defaultTrainingConfig();
        fprintf('[PASS] Config loaded (v%s)\n\n', config.version);
    catch e
        fprintf('[FAIL] Config load failed: %s\n', e.message);
        return;
    end

    %% Verify environment
    fprintf('--- Verifying Environment ---\n');
    try
        verify_environment();
        fprintf('[PASS] Environment ready\n\n');
    catch e
        fprintf('[FAIL] Environment check failed: %s\n', e.message);
        return;
    end

    %% Verify Days 1-5
    fprintf('--- Verifying Previous Days ---\n');

    % Day 2
    try
        trainDir = fullfile(config.dataset.dataRoot, 'train_images');
        allFiles = dir(fullfile(trainDir, '*.png'));
        fprintf('[PASS] Day 2: %d images available\n', length(allFiles));
    catch e
        fprintf('[FAIL] Day 2 verification failed: %s\n', e.message);
        return;
    end

    % Day 3
    try
        qconfig = defaultQualityConfig();
        fprintf('[PASS] Day 3: Quality config loaded (v%s)\n', qconfig.version);
    catch e
        fprintf('[FAIL] Day 3 verification failed: %s\n', e.message);
        return;
    end

    % Day 4
    try
        testImg = imread(fullfile(trainDir, allFiles(1).name));
        [enhanced, qi] = enhanceImage(testImg);
        fprintf('[PASS] Day 4: Enhancement working (score=%.4f)\n', qi.overallScore);
    catch e
        fprintf('[FAIL] Day 4 verification failed: %s\n', e.message);
        return;
    end

    fprintf('\n');

    %% Mode: verify
    if strcmp(mode, 'verify')
        fprintf('--- Running Setup Tests ---\n');

        % Test 1: Data preparation
        fprintf('\nTest 1: Data preparation...\n');
        try
            [trainDS, valDS, splitInfo] = prepareData('Config', config);
            assert(length(trainDS.Files) == config.verify.expectedTrainCount, ...
                'Train count mismatch');
            assert(length(valDS.Files) == config.verify.expectedValCount, ...
                'Val count mismatch');
            fprintf('[PASS] Data split: %d train, %d val\n', ...
                length(trainDS.Files), length(valDS.Files));
        catch e
            fprintf('[FAIL] Data preparation: %s\n', e.message);
            return;
        end

        % Test 2: Classifier setup
        fprintf('\nTest 2: Classifier setup...\n');
        try
            [lgraph, setupInfo] = setupClassifier('Config', config);
            fprintf('[PASS] Classifier created: %d layers\n', setupInfo.layerCount);
        catch e
            fprintf('[FAIL] Classifier setup: %s\n', e.message);
            return;
        end

        % Test 3: Forward pass
        fprintf('\nTest 3: Forward pass...\n');
        try
            rawImg = imread(fullfile(trainDir, allFiles(1).name));
            testImg = imresize(rawImg, config.input.imageSize(1:2));
            lgraphTest = removeLayers(lgraph, 'output');
            dlnet = dlnetwork(lgraphTest);
            dlX = dlarray(single(testImg) / 255, 'SSCB');
            dlY = predict(dlnet, dlX);
            predScores = extractdata(gather(dlY))';
            assert(length(predScores) == config.classes.numClasses, ...
                'Output size mismatch');
            fprintf('[PASS] Forward pass successful\n');
        catch e
            fprintf('[FAIL] Forward pass: %s\n', e.message);
            return;
        end

        fprintf('\n');
    end

    %% Mode: train
    if strcmp(mode, 'train')
        fprintf('--- Starting Training (Stage 1 + Stage 2) ---\n');
        fprintf('WARNING: Training on CPU may take 1-2 hours.\n\n');

        % Prepare data
        fprintf('Preparing data...\n');
        try
            [trainDS, valDS, splitInfo] = prepareData('Config', config);
            fprintf('[PASS] Data prepared\n\n');
        catch e
            fprintf('[FAIL] Data preparation: %s\n', e.message);
            return;
        end

        % Stage 1: Backbone frozen
        fprintf('=== Stage 1: Backbone Frozen ===\n');
        tic;
        try
            [trainedNet1, info1] = trainClassifier(trainDS, valDS, ...
                'Config', config, ...
                'Stage', 1);
            trainTime1 = toc;
            fprintf('[PASS] Stage 1 completed (%.1f minutes)\n\n', trainTime1/60);
        catch e
            fprintf('[FAIL] Stage 1 training: %s\n', e.message);
            return;
        end

        % Evaluate Stage 1
        fprintf('--- Evaluating Stage 1 Model ---\n');
        try
            valDSraw = imageDatastore(fullfile(config.dataset.splitDir, 'val'), ...
                'IncludeSubfolders', true, ...
                'LabelSource', 'foldernames');
            metrics1 = evaluateClassifier(trainedNet1, valDSraw, 'Config', config);
            fprintf('[PASS] Stage 1 evaluation complete\n\n');
        catch e
            fprintf('[FAIL] Stage 1 evaluation: %s\n', e.message);
            return;
        end

        % Stage 2: Backbone unfrozen
        fprintf('=== Stage 2: Backbone Unfrozen ===\n');
        tic;
        try
            [trainedNet2, info2] = trainClassifier(trainDS, valDS, ...
                'Config', config, ...
                'Stage', 2);
            trainTime2 = toc;
            fprintf('[PASS] Stage 2 completed (%.1f minutes)\n\n', trainTime2/60);
        catch e
            fprintf('[FAIL] Stage 2 training: %s\n', e.message);
            return;
        end

        % Evaluate Stage 2
        fprintf('--- Evaluating Stage 2 Model ---\n');
        try
            valDSraw = imageDatastore(fullfile(config.dataset.splitDir, 'val'), ...
                'IncludeSubfolders', true, ...
                'LabelSource', 'foldernames');
            metrics2 = evaluateClassifier(trainedNet2, valDSraw, 'Config', config);
            fprintf('[PASS] Stage 2 evaluation complete\n\n');
        catch e
            fprintf('[FAIL] Stage 2 evaluation: %s\n', e.message);
            return;
        end

        % Generate visualizations
        fprintf('--- Generating Visualizations ---\n');
        try
            plotTrainingResults(info1, metrics1, 'Config', config, 'Stage', 1);
            plotTrainingResults(info2, metrics2, 'Config', config, 'Stage', 2);
            fprintf('[PASS] Visualizations generated\n\n');
        catch e
            fprintf('[FAIL] Visualizations: %s\n', e.message);
            return;
        end

        % Save combined results
        resultsPath = fullfile(config.dataset.analysisDir, ...
            [config.experimentId '_results.mat']);
        save(resultsPath, 'trainedNet1', 'info1', 'metrics1', ...
             'trainedNet2', 'info2', 'metrics2', 'config');
        fprintf('Results saved to: %s\n\n', resultsPath);

        % Compare stages
        fprintf('=== Stage Comparison ===\n');
        fprintf('%-20s %10s %10s\n', 'Metric', 'Stage 1', 'Stage 2');
        fprintf('%-20s %10s %10s\n', '------', '-------', '-------');
        fprintf('%-20s %9.2f%% %9.2f%%\n', 'Accuracy', metrics1.accuracy*100, metrics2.accuracy*100);
        fprintf('%-20s %10.4f %10.4f\n', 'Macro F1', metrics1.macroF1, metrics2.macroF1);
        fprintf('%-20s %10.4f %10.4f\n', 'QWK', metrics1.qwk, metrics2.qwk);
        fprintf('%-20s %10.4f %10.4f\n', 'Ref Sensitivity', metrics1.referable.sensitivity, metrics2.referable.sensitivity);
        fprintf('%-20s %10.4f %10.4f\n', 'Ref Specificity', metrics1.referable.specificity, metrics2.referable.specificity);
        fprintf('========================\n\n');
    end

    %% Mode: eval
    if strcmp(mode, 'eval')
        fprintf('--- Evaluating Existing Model ---\n');

        % Check if model exists
        modelPath = fullfile(config.dataset.modelDir, ...
            [config.experimentId '_stage2.mat']);
        if ~exist(modelPath, 'file')
            modelPath = fullfile(config.dataset.modelDir, ...
                [config.experimentId '_stage1.mat']);
            if ~exist(modelPath, 'file')
                fprintf('[FAIL] No trained model found.\n');
                fprintf('  Run with mode="train" first.\n');
                return;
            end
        end

        % Load model
        fprintf('Loading model from: %s\n', modelPath);
        load(modelPath, 'trainedNet');
        fprintf('[PASS] Model loaded\n');

        % Prepare validation data (raw, not augmented)
        fprintf('Preparing validation data...\n');
        valDSraw = imageDatastore(fullfile(config.dataset.splitDir, 'val'), ...
            'IncludeSubfolders', true, ...
            'LabelSource', 'foldernames');
        fprintf('[PASS] Validation data ready: %d files\n', length(valDSraw.Files));

        % Evaluate
        fprintf('Evaluating...\n');
        try
            metrics = evaluateClassifier(trainedNet, valDSraw, 'Config', config);
            fprintf('[PASS] Evaluation complete\n\n');
        catch e
            fprintf('[FAIL] Evaluation: %s\n', e.message);
            return;
        end

        % Save results
        resultsPath = fullfile(config.dataset.analysisDir, ...
            [config.experimentId '_results.mat']);
        save(resultsPath, 'metrics', 'config');
        fprintf('Results saved to: %s\n\n', resultsPath);
    end

    %% Mode: compare (original vs enhanced)
    if strcmp(mode, 'compare')
        fprintf('--- Comparing Original vs Enhanced Input ---\n');

        % This experiment compares:
        % A: Original images -> resize -> normalize -> ResNet-18
        % B: Original images -> enhance -> resize -> normalize -> ResNet-18

        fprintf('NOTE: This experiment requires separate training runs.\n');
        fprintf('Use run_day6_compare.m for full comparison.\n\n');
    end

    %% Print summary
    fprintf('============================================\n');
    fprintf('         DAY 6 COMPLETE                     \n');
    fprintf('============================================\n\n');

    if strcmp(mode, 'train')
        fprintf('Results:\n');
        fprintf('  Stage 1 Accuracy: %.2f%%\n', metrics1.accuracy * 100);
        fprintf('  Stage 1 Macro F1: %.4f\n', metrics1.macroF1);
        fprintf('  Stage 2 Accuracy: %.2f%%\n', metrics2.accuracy * 100);
        fprintf('  Stage 2 Macro F1: %.4f\n', metrics2.macroF1);
    elseif strcmp(mode, 'eval')
        fprintf('Results:\n');
        fprintf('  Overall Accuracy: %.2f%%\n', metrics.accuracy * 100);
        fprintf('  Macro F1: %.4f\n', metrics.macroF1);
        fprintf('  QWK: %.4f\n', metrics.qwk);
        fprintf('  Referable Sensitivity: %.4f\n', metrics.referable.sensitivity);
        fprintf('  Referable Specificity: %.4f\n', metrics.referable.specificity);
    end

    fprintf('\nNext steps:\n');
    fprintf('  - Day 7: Grad-CAM explainability\n');
    fprintf('  - Consider GPU training for better results\n');

    fprintf('\nReady for Day 7 (Explainability)\n');
end