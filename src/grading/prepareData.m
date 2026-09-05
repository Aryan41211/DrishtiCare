function [trainDS, valDS, splitInfo] = prepareData(varargin)
% PREPAREDATA Split APTOS dataset into train/validation datastores
%   [trainDS, valDS, splitInfo] = prepareData()
%   [trainDS, valDS, splitInfo] = prepareData('Config', config)
%
%   Outputs:
%       trainDS    - Training imageDatastore
%       valDS      - Validation imageDatastore
%       splitInfo  - Struct with split metadata
%
%   Optional Parameters:
%       'Config' - Training config struct (default: defaultTrainingConfig())
%
%   Method:
%       1. Load APTOS train.csv labels
%       2. Perform stratified split (configurable ratio)
%       3. Create folder-per-class structure
%       4. Create imageDatastore with labels
%       5. Compute class weights for imbalanced data
%       6. Protect test set from contamination
%
%   IMPORTANT: This is an ENGINEERING data preparation module, NOT a
%   clinical data processing system.

    %% Parse arguments
    p = inputParser;
    addParameter(p, 'Config', [], @(x) isstruct(x));
    parse(p, varargin{:});
    config = p.Results.Config;

    if isempty(config)
        config = defaultTrainingConfig();
    end

    %% Extract settings from config
    splitRatio = config.split.splitRatio;
    imageSize = config.input.imageSize;
    seed = config.split.randomSeed;
    dataRoot = config.dataset.dataRoot;
    trainCsv = config.dataset.trainCsv;
    trainDir = config.dataset.trainImages;
    splitDir = config.dataset.splitDir;

    %% Load labels
    fprintf('Loading APTOS labels...\n');
    data = readtable(trainCsv);
    numImages = height(data);
    fprintf('  Total images: %d\n', numImages);

    %% Test set protection
    if config.testProtection.enabled
        fprintf('Verifying test set protection...\n');
        testDir = config.dataset.testImages;
        if exist(testDir, 'dir')
            testFiles = dir(fullfile(testDir, '*.png'));
            testIds = {testFiles.name};
            testIds = cellfun(@(x) x(1:end-4), testIds, 'UniformOutput', false);

            % Check for overlap
            overlap = intersect(data.id_code, testIds);
            if ~isempty(overlap)
                warning('DrishtiCare:testOverlap', ...
                    'Found %d images in both train.csv and test directory. Removing from split.', ...
                    length(overlap));
                data = data(~ismember(data.id_code, overlap), :);
            end
            fprintf('  Test set: %d images (excluded from split)\n', length(testFiles));
        else
            fprintf('  Test directory not found (no protection needed)\n');
        end
    end

    %% Set random seed
    rng(seed);

    %% Perform stratified split
    fprintf('Performing stratified %d/%d split...\n', round(splitRatio*100), round((1-splitRatio)*100));

    trainIdx = [];
    valIdx = [];
    trainCounts = zeros(5, 1);
    valCounts = zeros(5, 1);

    for c = 0:4
        classIdx = find(data.diagnosis == c);
        numClass = length(classIdx);
        numTrain = round(numClass * splitRatio);

        % Shuffle
        perm = randperm(numClass);
        trainIdx = [trainIdx; classIdx(perm(1:numTrain))];
        valIdx = [valIdx; classIdx(perm(numTrain+1:end))];

        trainCounts(c+1) = numTrain;
        valCounts(c+1) = numClass - numTrain;

        fprintf('  Class %d: %d train, %d val\n', c, numTrain, numClass - numTrain);
    end

    % Shuffle final indices
    trainIdx = trainIdx(randperm(length(trainIdx)));
    valIdx = valIdx(randperm(length(valIdx)));

    fprintf('  Total train: %d, Total val: %d\n', length(trainIdx), length(valIdx));

    %% Verify no overlap
    assert(length(intersect(trainIdx, valIdx)) == 0, ...
        'Data leakage: images found in both train and val');
    fprintf('  No data leakage detected\n');

    %% Create folder-per-class structure
    fprintf('Creating folder-per-class structure...\n');

    if exist(splitDir, 'dir')
        rmdir(splitDir, 's');
    end

    % Create train folders
    for c = 0:4
        classDir = fullfile(splitDir, 'train', sprintf('class_%d', c));
        mkdir(classDir);
    end

    % Create val folders
    for c = 0:4
        classDir = fullfile(splitDir, 'val', sprintf('class_%d', c));
        mkdir(classDir);
    end

    %% Copy images to folders
    fprintf('Copying images to folders...\n');

    trainIds = cell(length(trainIdx), 1);
    valIds = cell(length(valIdx), 1);

    % Copy training images
    for i = 1:length(trainIdx)
        idx = trainIdx(i);
        imgName = data.id_code{idx};
        diag = data.diagnosis(idx);
        srcPath = fullfile(trainDir, [imgName '.png']);
        dstPath = fullfile(splitDir, 'train', sprintf('class_%d', diag), [imgName '.png']);
        copyfile(srcPath, dstPath);
        trainIds{i} = imgName;
    end

    % Copy validation images
    for i = 1:length(valIdx)
        idx = valIdx(i);
        imgName = data.id_code{idx};
        diag = data.diagnosis(idx);
        srcPath = fullfile(trainDir, [imgName '.png']);
        dstPath = fullfile(splitDir, 'val', sprintf('class_%d', diag), [imgName '.png']);
        copyfile(srcPath, dstPath);
        valIds{i} = imgName;
    end

    fprintf('  Folders created at: %s\n', splitDir);

    %% Create imageDatastores
    fprintf('Creating imageDatastores...\n');

    trainDirPath = fullfile(splitDir, 'train');
    valDirPath = fullfile(splitDir, 'val');

    % Training datastore
    trainDS = imageDatastore(trainDirPath, ...
        'IncludeSubfolders', true, ...
        'LabelSource', 'foldernames');

    % Validation datastore
    valDS = imageDatastore(valDirPath, ...
        'IncludeSubfolders', true, ...
        'LabelSource', 'foldernames');

    % Resize images
    trainDS = augmentedImageDatastore(imageSize, trainDS);
    valDS = augmentedImageDatastore(imageSize, valDS);

    fprintf('  Training samples: %d\n', length(trainDS.Files));
    fprintf('  Validation samples: %d\n', length(valDS.Files));

    %% Compute class weights for imbalanced data
    fprintf('Computing class weights...\n');

    classWeights = zeros(5, 1);
    totalSamples = sum(trainCounts);

    for c = 1:5
        classWeights(c) = totalSamples / (config.classes.numClasses * trainCounts(c));
    end

    % Normalize to sum to numClasses
    classWeights = classWeights / sum(classWeights) * config.classes.numClasses;

    fprintf('  Class distribution (train):\n');
    for c = 1:5
        fprintf('    %s: %d samples (weight: %.3f)\n', ...
            config.classes.names{c}, trainCounts(c), classWeights(c));
    end

    %% Save split information
    splitInfo = struct();
    splitInfo.date = datestr(now);
    splitInfo.splitRatio = splitRatio;
    splitInfo.randomSeed = seed;
    splitInfo.imageSize = imageSize;
    splitInfo.trainCount = length(trainIdx);
    splitInfo.valCount = length(valIdx);
    splitInfo.trainCounts = trainCounts;
    splitInfo.valCounts = valCounts;
    splitInfo.classWeights = classWeights;
    splitInfo.trainIds = trainIds;
    splitInfo.valIds = valIds;
    splitInfoclassNames = config.classes.names;

    %% Save split info
    splitInfoPath = fullfile(config.dataset.analysisDir, 'split_info.mat');
    if ~exist(config.dataset.analysisDir, 'dir')
        mkdir(config.dataset.analysisDir);
    end
    save(splitInfoPath, 'splitInfo');
    fprintf('  Split info saved to: %s\n', splitInfoPath);

    %% Summary
    fprintf('\n=== Data Preparation Summary ===\n');
    fprintf('Split ratio: %.0f/%.0f\n', splitRatio*100, (1-splitRatio)*100);
    fprintf('Image size: %dx%dx%d\n', imageSize(1), imageSize(2), imageSize(3));
    fprintf('Training samples: %d\n', length(trainDS.Files));
    fprintf('Validation samples: %d\n', length(valDS.Files));
    fprintf('Class weights: [%.3f, %.3f, %.3f, %.3f, %.3f]\n', classWeights);
    fprintf('Random seed: %d\n', seed);
    fprintf('================================\n\n');
end