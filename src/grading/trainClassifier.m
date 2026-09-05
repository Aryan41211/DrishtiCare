function [trainedNet, info] = trainClassifier(trainDS, valDS, varargin)
% TRAINCLASSIFIER Train DR classifier with staged fine-tuning
%   [trainedNet, info] = trainClassifier(trainDS, valDS)
%   [trainedNet, info] = trainClassifier(trainDS, valDS, 'Config', config)
%
%   Inputs:
%       trainDS - Training imageDatastore (augmented)
%       valDS   - Validation imageDatastore (augmented)
%
%   Optional Parameters:
%       'Config' - Training config struct (default: defaultTrainingConfig())
%       'Stage'  - Training stage: 1 or 2 (default: 1)
%
%   Outputs:
%       trainedNet - Trained network
%       info       - Training information

    %% Parse arguments
    p = inputParser;
    addParameter(p, 'Config', [], @(x) isstruct(x));
    addParameter(p, 'Stage', 1, @(x) ismember(x, [1, 2]));
    addParameter(p, 'ExperimentId', '', @ischar);
    addParameter(p, 'NumClasses', [], @(x) isempty(x) || (isnumeric(x) && x > 0));
    addParameter(p, 'DataDir', '', @ischar);  % override train folder for balancing
    parse(p, varargin{:});
    config = p.Results.Config;
    stage = p.Results.Stage;

    if isempty(config)
        config = defaultTrainingConfig();
    end

    %% Extract settings from config
    experimentId = p.Results.ExperimentId;
    if isempty(experimentId)
        experimentId = config.experimentId;
    end
    numClasses = p.Results.NumClasses;
    if isempty(numClasses)
        numClasses = config.classes.numClasses;
    end
    checkpointDir = config.output.checkpointPath;

    %% Setup checkpoint directory
    if ~exist(checkpointDir, 'dir')
        mkdir(checkpointDir);
    end

    %% Configure data augmentation
    fprintf('Configuring data augmentation...\n');

    augmenter = imageDataAugmenter(...
        'RandRotation', config.augmentation.rotation, ...
        'RandXReflection', config.augmentation.xReflection, ...
        'RandXTranslation', config.augmentation.xTranslation, ...
        'RandYTranslation', config.augmentation.yTranslation, ...
        'RandXShear', config.augmentation.xShear, ...
        'RandYShear', config.augmentation.yShear);

    fprintf('  Rotation: [%d, %d] degrees\n', config.augmentation.rotation);
    fprintf('  Reflection: horizontal\n');

    %% Configure training options based on stage
    fprintf('\nConfiguring training options (Stage %d)...\n', stage);

    if stage == 1
        stageConfig = config.finetune.stage1;
        stageName = 'Stage 1: Backbone frozen';
    else
        stageConfig = config.finetune.stage2;
        stageName = 'Stage 2: Backbone unfrozen';
    end

    maxEpochs = stageConfig.maxEpochs;
    miniBatchSize = stageConfig.miniBatchSize;
    learningRate = stageConfig.learningRate;

    % Checkpoint path
    checkpointPath = fullfile(checkpointDir, ...
        sprintf('%s_stage%d', experimentId, stage));

    % Ensure checkpoint directory exists
    if ~exist(checkpointPath, 'dir')
        mkdir(checkpointPath);
    end

    %% Create balanced training set via in-memory oversampling (no file copy)
    % Repeats minority-class file paths in the datastore. Mathematically
    % equivalent to class weighting, zero extra disk usage.
    fprintf('Creating balanced training set (in-memory oversampling)...\n');
    splitTrainDir = p.Results.DataDir;
    if isempty(splitTrainDir)
        splitTrainDir = fullfile(config.dataset.splitDir, 'train');
    end
    trainDSraw = imageDatastore(splitTrainDir, ...
        'IncludeSubfolders', true, ...
        'LabelSource', 'foldernames');
    balancedTrainDS = createBalancedDatastore(trainDSraw, config);

    % Validation frequency based on balanced training size
    try
        numTrainSamples = length(balancedTrainDS.Files);
    catch
        numTrainSamples = length(trainDSraw.Files);
    end
    validationFrequency = floor(numTrainSamples / miniBatchSize);

    % Training options
    options = trainingOptions('adam', ...
        'MaxEpochs', maxEpochs, ...
        'MiniBatchSize', miniBatchSize, ...
        'InitialLearnRate', learningRate, ...
        'LearnRateSchedule', 'piecewise', ...
        'LearnRateDropPeriod', config.training.learnRateDropPeriod, ...
        'LearnRateDropFactor', config.training.learnRateDropFactor, ...
        'ValidationData', valDS, ...
        'ValidationFrequency', validationFrequency, ...
        'ValidationPatience', config.training.validationPatience, ...
        'Shuffle', config.training.shuffle, ...
        'CheckpointPath', checkpointPath, ...
        'Verbose', config.training.verbose, ...
        'Plots', 'none', ...
        'ExecutionEnvironment', config.training.executionEnvironment);

    fprintf('  Optimizer: Adam\n');
    fprintf('  Max epochs: %d\n', maxEpochs);
    fprintf('  Mini-batch size: %d\n', miniBatchSize);
    fprintf('  Learning rate: %.2e\n', learningRate);
    fprintf('  Validation frequency: %d iterations\n', validationFrequency);

    %% Setup classifier
    fprintf('Setting up classifier...\n');

    % For Stage 2, load Stage 1 model and unfreeze
    if stage == 2
        stage1Path = fullfile(config.dataset.modelDir, ...
            sprintf('%s_stage1.mat', experimentId));
        if exist(stage1Path, 'file')
            fprintf('Loading Stage 1 model...\n');
            load(stage1Path, 'trainedNet');
            lgraph = layerGraph(trainedNet);

            % Unfreeze all layers by restoring learn rate factors
            fprintf('Unfreezing all layers...\n');
            for i = 1:length(lgraph.Layers)
                layer = lgraph.Layers(i);
                if isprop(layer, 'WeightLearnRateFactor')
                    layer.WeightLearnRateFactor = 1;
                end
                if isprop(layer, 'BiasLearnRateFactor')
                    layer.BiasLearnRateFactor = 1;
                end
                lgraph = replaceLayer(lgraph, layer.Name, layer);
            end
        else
            fprintf('Stage 1 model not found, creating fresh classifier...\n');
            [lgraph, ~] = setupClassifier('Config', config, 'NumClasses', numClasses);
        end
    else
        [lgraph, ~] = setupClassifier('Config', config, 'NumClasses', numClasses);
    end

    %% Start training
    fprintf('\n=== Starting Training ===\n');
    fprintf('Stage: %s\n', stageName);
    fprintf('Start time: %s\n', datestr(now));
    tic;

    [trainedNet, info] = trainNetwork(balancedTrainDS, lgraph, options);

    trainingTime = toc;
    fprintf('\nTraining completed in %.1f seconds (%.1f minutes)\n', ...
        trainingTime, trainingTime/60);

    %% Save trained model
    modelPath = fullfile(config.dataset.modelDir, ...
        sprintf('%s_stage%d.mat', experimentId, stage));
    fprintf('Saving trained model to: %s\n', modelPath);

    % Save model + metadata
    save(modelPath, 'trainedNet', 'info', 'config', 'stage', 'trainingTime');

    %% Save training summary
    summary = struct();
    summary.experimentId = experimentId;
    summary.stage = stage;
    summary.date = datestr(now);
    summary.trainingTime = trainingTime;
    summary.finalTrainAccuracy = info.TrainingAccuracy(end);
    summary.finalValAccuracy = info.ValidationAccuracy(end);
    summary.finalTrainLoss = info.TrainingLoss(end);
    summary.finalValLoss = info.ValidationLoss(end);
    summary.epochsCompleted = length(info.TrainingLoss);

    summaryPath = fullfile(config.dataset.analysisDir, ...
        sprintf('%s_stage%d_summary.mat', experimentId, stage));
    save(summaryPath, 'summary');

    %% Print training summary
    fprintf('\n=== Training Summary ===\n');
    fprintf('Stage: %s\n', stageName);
    fprintf('Final training accuracy: %.2f%%\n', info.TrainingAccuracy(end));
    fprintf('Final validation accuracy: %.2f%%\n', info.ValidationAccuracy(end));
    fprintf('Final training loss: %.4f\n', info.TrainingLoss(end));
    fprintf('Final validation loss: %.4f\n', info.ValidationLoss(end));
    fprintf('Epochs completed: %d\n', length(info.TrainingLoss));
    fprintf('Training time: %.1f seconds\n', trainingTime);
    fprintf('========================\n\n');
end

function balancedDS = createBalancedDatastore(trainDSraw, config)
    %% In-memory balanced datastore (repeats file paths, no disk copy)
    files = trainDSraw.Files;
    labels = trainDSraw.Labels;
    netClasses = categories(labels);
    fprintf('  Network classes: %s\n', strjoin(netClasses, ', '));

    numClasses = length(netClasses);
    classCounts = zeros(numClasses, 1);
    for c = 1:numClasses
        classCounts(c) = sum(labels == netClasses{c});
    end
    maxCount = min(max(classCounts), config.imbalance.maxPerClass);
    fprintf('  Class counts before balancing:\n');
    for c = 1:numClasses
        fprintf('    %s: %d -> %d\n', netClasses{c}, classCounts(c), maxCount);
    end

    % Repeat minority-class paths in memory
    rng(config.split.randomSeed);
    balancedFiles = cell(maxCount * numClasses, 1);
    balancedLabelCell = cell(maxCount * numClasses, 1);
    pos = 1;
    for c = 1:numClasses
        classFiles = files(labels == netClasses{c});
        n = length(classFiles);
        repIdx = randi(n, maxCount, 1);  % sample with replacement
        for k = 1:maxCount
            balancedFiles{pos} = classFiles{repIdx(k)};
            balancedLabelCell{pos} = netClasses{c};
            pos = pos + 1;
        end
    end
    order = randperm(length(balancedFiles));
    balancedFiles = balancedFiles(order);
    balancedLabelCell = balancedLabelCell(order);

    rawBalanced = imageDatastore(balancedFiles, ...
        'Labels', categorical(balancedLabelCell, netClasses));

    balancedDS = augmentedImageDatastore(config.input.imageSize, rawBalanced, ...
        'DataAugmentation', imageDataAugmenter(...
            'RandRotation', config.augmentation.rotation, ...
            'RandXReflection', config.augmentation.xReflection, ...
            'RandXTranslation', config.augmentation.xTranslation, ...
            'RandYTranslation', config.augmentation.yTranslation, ...
            'RandXShear', config.augmentation.xShear, ...
            'RandYShear', config.augmentation.yShear));

    fprintf('  Balanced training set: %d samples (no disk copy)\n', length(balancedFiles));
end