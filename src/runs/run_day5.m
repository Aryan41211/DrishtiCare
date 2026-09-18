function run_day5(mode)
% RUN_DAY5 Master script for Day 5 - Classifier Setup
%   run_day5()          - Run in 'verify' mode (default)
%   run_day5('verify')  - Verify setup with forward-pass test
%   run_day5('setup')   - Prepare data and setup classifier
%   run_day5('train')   - Setup and start training
%
%   Mode:
%       'verify'  - Verify setup with forward-pass test (default)
%       'setup'   - Prepare data and setup classifier
%       'train'   - Prepare data, setup classifier, and start training
%
%   This script implements Day 5 of the DrishtiCare pipeline:
%   1. Load centralized config
%   2. Verify all components work (no training)
%   3. Prepare APTOS dataset (train/val split)
%   4. Setup ResNet-18 classifier with staged fine-tuning
%   5. Optionally start training
%
%   IMPORTANT: This is an ENGINEERING classifier setup, NOT a clinical
%   diagnostic system. The model must be validated before clinical use.

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
    fprintf('   DrishtiCare - Day 5 Classifier Setup     \n');
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

    %% Verify Days 1-4
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

    %% Verify config consistency
    fprintf('--- Verifying Configuration ---\n');

    % Check file paths
    assert(exist(config.dataset.trainCsv, 'file') == 2, ...
        'Train CSV not found');
    fprintf('[PASS] Train CSV: %s\n', config.dataset.trainCsv);

    assert(exist(config.dataset.trainImages, 'dir') == 7, ...
        'Train images directory not found');
    fprintf('[PASS] Train images: %s\n', config.dataset.trainImages);

    % Check class configuration
    assert(config.classes.numClasses == 5, ...
        'Expected 5 classes');
    fprintf('[PASS] Class count: %d\n', config.classes.numClasses);

    assert(length(config.classes.names) == 5, ...
        'Expected 5 class names');
    fprintf('[PASS] Class names: %s\n', strjoin(config.classes.names, ', '));

    assert(length(config.classes.referable) == 3, ...
        'Expected 3 referable classes');
    fprintf('[PASS] Referable classes: %s\n', mat2str(config.classes.referable));

    fprintf('\n');

    %% Mode: verify
    if strcmp(mode, 'verify')
        fprintf('--- Running Setup Tests ---\n');

        % Test 1: Data preparation
        fprintf('\nTest 1: Data preparation...\n');
        try
            [trainDS, valDS, splitInfo] = prepareData('Config', config);

            % Verify sample counts
            assert(length(trainDS.Files) == config.verify.expectedTrainCount, ...
                'Train count mismatch: expected %d, got %d', ...
                config.verify.expectedTrainCount, length(trainDS.Files));
            assert(length(valDS.Files) == config.verify.expectedValCount, ...
                'Val count mismatch: expected %d, got %d', ...
                config.verify.expectedValCount, length(valDS.Files));
            fprintf('[PASS] Data split: %d train, %d val\n', ...
                length(trainDS.Files), length(valDS.Files));

            % Verify no overlap
            trainFiles = cellfun(@fileparts, trainDS.Files, 'UniformOutput', false);
            valFiles = cellfun(@fileparts, valDS.Files, 'UniformOutput', false);
            overlap = intersect(trainFiles, valFiles);
            assert(isempty(overlap), 'Data leakage: %d overlapping files', length(overlap));
            fprintf('[PASS] No data leakage\n');

        catch e
            fprintf('[FAIL] Data preparation: %s\n', e.message);
            return;
        end

        % Test 2: Classifier setup
        fprintf('\nTest 2: Classifier setup...\n');
        try
            [lgraph, setupInfo] = setupClassifier('Config', config);
            fprintf('[PASS] Classifier created: %d layers\n', setupInfo.layerCount);
            fprintf('  Pretrained: %s\n', mat2str(setupInfo.pretrained));
            fprintf('  Input size: %s\n', mat2str(setupInfo.inputSize));
        catch e
            fprintf('[FAIL] Classifier setup: %s\n', e.message);
            return;
        end

        % Test 3: Forward pass
        fprintf('\nTest 3: Forward pass...\n');
        try
            % Read a raw training image and resize manually
            rawImg = imread(fullfile(trainDir, allFiles(1).name));
            testImg = imresize(rawImg, config.input.imageSize(1:2));
            inputSize = config.input.imageSize;

            % Verify dimensions
            assert(isequal(size(testImg), inputSize), ...
                'Image size mismatch: expected %s, got %s', ...
                mat2str(inputSize), mat2str(size(testImg)));
            fprintf('[PASS] Image dimensions correct: %s\n', mat2str(inputSize));

            % Forward pass: create a dlnetwork-compatible graph (remove classification layer)
            testImgSingle = single(testImg) / 255;
            lgraphTest = removeLayers(lgraph, 'output');
            dlnet = dlnetwork(lgraphTest);
            dlX = dlarray(testImgSingle, 'SSCB');
            dlY = predict(dlnet, dlX);
            predScores = extractdata(gather(dlY))';

            fprintf('[PASS] Forward pass successful\n');
            fprintf('  Raw output (pre-softmax): [%.3f, %.3f, %.3f, %.3f, %.3f]\n', predScores);

            % Verify output size
            assert(length(predScores) == config.classes.numClasses, ...
                'Output size mismatch: expected %d, got %d', ...
                config.classes.numClasses, length(predScores));
            fprintf('[PASS] Output size correct: %d classes\n', config.classes.numClasses);

            % Verify no NaN/Inf
            assert(~any(isnan(predScores)), 'Predictions contain NaN');
            assert(~any(isinf(predScores)), 'Predictions contain Inf');
            fprintf('[PASS] Predictions are valid (no NaN/Inf)\n');

        catch e
            fprintf('[FAIL] Forward pass: %s\n', e.message);
            return;
        end

        fprintf('\n');
    end

    %% Mode: setup
    if strcmp(mode, 'setup') || strcmp(mode, 'train')
        %% Prepare data
        fprintf('--- Preparing Data ---\n');
        try
            [trainDS, valDS, splitInfo] = prepareData('Config', config);
            fprintf('[PASS] Data prepared\n\n');
        catch e
            fprintf('[FAIL] Data preparation failed: %s\n', e.message);
            return;
        end

        %% Setup classifier
        fprintf('--- Setting Up Classifier ---\n');
        try
            [lgraph, setupInfo] = setupClassifier('Config', config);
            fprintf('[PASS] Classifier setup\n\n');
        catch e
            fprintf('[FAIL] Classifier setup failed: %s\n', e.message);
            return;
        end

        %% Save setup info
        setupPath = fullfile(config.dataset.modelDir, 'day5_setup.mat');
        if ~exist(config.dataset.modelDir, 'dir')
            mkdir(config.dataset.modelDir);
        end
        save(setupPath, 'setupInfo', 'config');
        fprintf('Setup info saved to: %s\n\n', setupPath);
    end

    %% Mode: train
    if strcmp(mode, 'train')
        fprintf('--- Starting Training ---\n');
        fprintf('WARNING: Training may take several hours on CPU.\n');
        fprintf('Consider using GPU or Google Colab for faster training.\n\n');

        try
            [trainedNet, info] = trainClassifier(trainDS, valDS, ...
                'Config', config, ...
                'Stage', 1);
            fprintf('[PASS] Stage 1 training completed\n\n');
        catch e
            fprintf('[FAIL] Training failed: %s\n', e.message);
            return;
        end
    end

    %% Print summary
    fprintf('============================================\n');
    fprintf('         DAY 5 COMPLETE                     \n');
    fprintf('============================================\n\n');

    fprintf('Deliverables:\n');
    fprintf('  1. Config: %s (v%s)\n', config.experimentId, config.version);
    fprintf('  2. Model: ResNet-18\n');
    fprintf('  3. Pretrained: %s\n', mat2str(config.model.usePretrained));
    fprintf('  4. Train/val split: %.0f/%.0f\n', config.split.splitRatio*100, (1-config.split.splitRatio)*100);
    fprintf('  5. Class weights: Computed\n');

    fprintf('\nNext steps:\n');
    fprintf('  - Day 6: Train classifier and evaluate results\n');
    fprintf('  - Consider GPU training for faster convergence\n');
    fprintf('  - Monitor training for overfitting\n');

    fprintf('\nReady for Day 6 (Training + Results)\n');
end