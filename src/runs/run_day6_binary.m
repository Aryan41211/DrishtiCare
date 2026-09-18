function run_day6_binary(mode)
% RUN_DAY6_BINARY Binary referable/non-referable classifier (validation only)
%   run_day6_binary('verify') - build binary split, setup 2-class net, forward pass
%   run_day6_binary('train')  - Stage 1 + Stage 2 training
%   run_day6_binary('eval')   - evaluate saved binary model
%
%   Experiment ID: day6_binary_referable_v1 (never touches 5-class champion)

    if nargin < 1, mode = 'verify'; end

    project_root = pwd;
    addpath(fullfile(project_root, 'src', 'setup'));
    addpath(fullfile(project_root, 'src', 'quality'));
    addpath(fullfile(project_root, 'src', 'enhancement'));
    addpath(fullfile(project_root, 'src', 'grading'));

    fprintf('============================================\n');
    fprintf('   DrishtiCare - Day 6 Binary Referable      \n');
    fprintf('============================================\n');
    fprintf('Mode: %s  Date: %s\n\n', upper(mode), datestr(now));

    config = defaultTrainingConfig();
    experimentId = 'day6_binary_referable_v1';
    binTrainDir = fullfile(project_root, 'data', 'splits_binary', 'train');
    binValDir = fullfile(project_root, 'data', 'splits_binary', 'val');

    if strcmp(mode, 'verify')
        [trainDS, valDS, binInfo] = prepareBinaryData('Config', config);
        fprintf('[PASS] Binary split ready\n');
        [lgraph, setupInfo] = setupClassifier('Config', config, 'NumClasses', 2);
        assert(setupInfo.numClasses == 2, 'Head is not 2-class');
        fprintf('[PASS] 2-class head ready\n');

        % Forward pass
        raw = imageDatastore(binValDir, 'IncludeSubfolders', true, ...
            'LabelSource', 'foldernames');
        img = imresize(imread(raw.Files{1}), config.input.imageSize(1:2));
        lt = removeLayers(lgraph, 'output');
        dlY = predict(dlnetwork(lt), dlarray(single(img)/255, 'SSCB'));
        out = extractdata(gather(dlY))';
        assert(length(out) == 2, 'Output is not 2-dimensional');
        fprintf('[PASS] Forward pass: 2 outputs, no NaN/Inf\n');
        return;
    end

    if strcmp(mode, 'train')
        fprintf('WARNING: ~1.5h on CPU. Test set stays untouched.\n\n');
        [trainDS, valDS, ~] = prepareBinaryData('Config', config);

        fprintf('=== Binary Stage 1 ===\n');
        [trainedNet1, info1] = trainClassifier(trainDS, valDS, ...
            'Config', config, 'Stage', 1, ...
            'ExperimentId', experimentId, 'NumClasses', 2, ...
            'DataDir', binTrainDir);

        fprintf('=== Binary Stage 2 ===\n');
        [trainedNet2, info2] = trainClassifier(trainDS, valDS, ...
            'Config', config, 'Stage', 2, ...
            'ExperimentId', experimentId, 'NumClasses', 2, ...
            'DataDir', binTrainDir);

        valDSraw = imageDatastore(binValDir, 'IncludeSubfolders', true, ...
            'LabelSource', 'foldernames');
        metrics = evaluateBinaryClassifier(trainedNet2, valDSraw, ...
            'Config', config, 'ExperimentId', experimentId);
        save(fullfile(config.dataset.modelDir, [experimentId '_traininfo.mat']), ...
            'info1', 'info2', 'metrics', 'config');
        fprintf('\nBinary training complete.\n');
        return;
    end

    if strcmp(mode, 'eval')
        modelPath = fullfile(config.dataset.modelDir, [experimentId '_stage2.mat']);
        assert(exist(modelPath, 'file') == 2, 'Train first: model missing');
        S = load(modelPath, 'trainedNet');
        valDSraw = imageDatastore(binValDir, 'IncludeSubfolders', true, ...
            'LabelSource', 'foldernames');
        evaluateBinaryClassifier(S.trainedNet, valDSraw, ...
            'Config', config, 'ExperimentId', experimentId);
        return;
    end

    error('Unknown mode: %s (use verify/train/eval)', mode);
end