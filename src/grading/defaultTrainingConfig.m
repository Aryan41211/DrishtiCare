function config = defaultTrainingConfig()
% DEFAULTTRAININGCONFIG Centralized configuration for Day 5 classifier training
%   config = defaultTrainingConfig()
%
%   Returns a struct with all training settings.
%   This is the SINGLE SOURCE OF TRUTH for all Day 5 parameters.
%
%   IMPORTANT: This is an ENGINEERING training configuration, NOT a
%   clinical validation system.

    config = struct();

    %% Experiment identification
    config.experimentId = 'day6_resnet18_balanced';
    config.version = '1.1.0';
    config.date = datestr(now, 'yyyy-mm-dd');
    config.matlabVersion = version;

    %% Dataset settings
    config.dataset.projectRoot = pwd;
    config.dataset.dataRoot = fullfile(config.dataset.projectRoot, 'data', 'aptos2019');
    config.dataset.trainCsv = fullfile(config.dataset.dataRoot, 'train.csv');
    config.dataset.trainImages = fullfile(config.dataset.dataRoot, 'train_images');
    config.dataset.testImages = fullfile(config.dataset.dataRoot, 'test_images');
    config.dataset.splitDir = fullfile(config.dataset.projectRoot, 'data', 'splits');
    config.dataset.modelDir = fullfile(config.dataset.projectRoot, 'data', 'models');
    config.dataset.analysisDir = fullfile(config.dataset.projectRoot, 'data', 'analysis', 'day5');

    %% Class settings
    config.classes.numClasses = 5;
    config.classes.names = {'NoDR', 'Mild', 'Moderate', 'Severe', 'Proliferative'};
    config.classes.labels = 0:4;
    config.classes.referable = [2, 3, 4];  % Moderate, Severe, Proliferative
    config.classes.nonReferable = [0, 1];  % NoDR, Mild

    %% Split settings
    config.split.splitRatio = 0.8;
    config.split.randomSeed = 42;
    config.split.stratified = true;

    %% Input settings
    config.input.imageSize = [224, 224, 3];
    config.input.resizeMethod = 'bilinear';

    %% Model settings
    config.model.name = 'resnet18';
    config.model.usePretrained = false;  % Set true when support package installed
    config.model.numClasses = config.classes.numClasses;
    config.model.featureSize = 512;

    %% Fine-tuning stages
    config.finetune.stage1.freezeBackbone = true;
    config.finetune.stage1.freezeLayers = 60;  % Freeze all but last few layers
    config.finetune.stage1.maxEpochs = 15;
    config.finetune.stage1.learningRate = 1e-3;
    config.finetune.stage1.miniBatchSize = 32;

    config.finetune.stage2.freezeBackbone = false;
    config.finetune.stage2.maxEpochs = 15;
    config.finetune.stage2.learningRate = 1e-5;
    config.finetune.stage2.miniBatchSize = 16;

    %% Training settings (default: stage 1)
    config.training.optimizer = 'adam';
    config.training.maxEpochs = config.finetune.stage1.maxEpochs;
    config.training.miniBatchSize = config.finetune.stage1.miniBatchSize;
    config.training.initialLearnRate = config.finetune.stage1.learningRate;
    config.training.learnRateSchedule = 'piecewise';
    config.training.learnRateDropPeriod = 5;
    config.training.learnRateDropFactor = 0.5;
    config.training.validationPatience = 8;
    config.training.shuffle = 'every-epoch';
    config.training.executionEnvironment = 'auto';
    config.training.plots = 'training-progress';
    config.training.verbose = true;

    %% Class imbalance
    config.imbalance.useClassWeights = true;
    config.imbalance.classWeights = [];  % Computed during data preparation
    config.imbalance.maxPerClass = 800;  % Cap for in-memory oversampling

    %% Augmentation settings
    config.augmentation.useAugmentation = true;
    config.augmentation.rotation = [-15, 15];
    config.augmentation.xReflection = true;
    config.augmentation.xTranslation = [-10, 10];
    config.augmentation.yTranslation = [-10, 10];
    config.augmentation.xShear = [-5, 5];
    config.augmentation.yShear = [-5, 5];

    %% Preprocessing settings
    config.preprocessing.normalize = true;
    config.preprocessing.normalizeMethod = 'zerocenter';  % For ImageNet pretrained
    config.preprocessing.preserveAspectRatio = true;

    %% Referable DR settings
    config.referable.threshold = 0.5;  % Default placeholder
    config.referable.thresholdLabel = 'Configurable, not clinically validated';

    %% Output settings
    config.output.modelSavePath = fullfile(config.dataset.modelDir, ...
        [config.experimentId, '.mat']);
    config.output.checkpointPath = fullfile(config.dataset.modelDir, 'checkpoints');
    config.output.summaryPath = fullfile(config.dataset.analysisDir, ...
        [config.experimentId, '_summary.mat']);
    config.output.plotPath = fullfile(config.dataset.analysisDir, ...
        [config.experimentId, '_plots.png']);

    %% Test set protection
    config.testProtection.enabled = true;
    config.testProtection.testDir = config.dataset.testImages;
    config.testProtection.assertNoTestInTrain = true;
    config.testProtection.assertNoTestInVal = true;

    %% Verification
    config.verify.inputDimensions = [224, 224, 3];
    config.verify.outputClasses = 5;
    config.verify.classOrder = {'NoDR', 'Mild', 'Moderate', 'Severe', 'Proliferative'};
    config.verify.expectedTrainCount = 2929;
    config.verify.expectedValCount = 733;

    %% Print configuration summary
    fprintf('=== Training Configuration ===\n');
    fprintf('Experiment: %s\n', config.experimentId);
    fprintf('Model: %s\n', config.model.name);
    fprintf('Pretrained: %s\n', mat2str(config.model.usePretrained));
    fprintf('Input size: %s\n', mat2str(config.input.imageSize));
    fprintf('Output classes: %d\n', config.classes.numClasses);
    fprintf('Split ratio: %.0f/%.0f\n', config.split.splitRatio*100, (1-config.split.splitRatio)*100);
    fprintf('Random seed: %d\n', config.split.randomSeed);
    fprintf('Augmentation: %s\n', mat2str(config.augmentation.useAugmentation));
    fprintf('Class weights: %s\n', mat2str(config.imbalance.useClassWeights));
    fprintf('=============================\n\n');
end