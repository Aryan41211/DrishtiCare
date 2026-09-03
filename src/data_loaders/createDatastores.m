function [trainDS, valDS, testDS] = createDatastores(dataRoot, splitRatio)
% CREATEDATASTORES Create MATLAB datastores for training
%   [trainDS, valDS, testDS] = createDatastores(dataRoot, splitRatio)
%
%   Inputs:
%       dataRoot   - Path to aptos2019 folder
%       splitRatio - Train/val split ratio (default: 0.8)
%
%   Outputs:
%       trainDS - Training imageDatastore
%       valDS   - Validation imageDatastore
%       testDS  - Test imageDatastore

    if nargin < 1
        dataRoot = fullfile('..', '..', 'data', 'aptos2019');
    end
    if nargin < 2
        splitRatio = 0.8;
    end

    fprintf('Creating datastores...\n');

    %% Create training datastore from CSV
    trainCsv = fullfile(dataRoot, 'train.csv');
    trainDir = fullfile(dataRoot, 'train_images');

    trainData = readtable(trainCsv);

    % Create image paths and labels
    imgPaths = fullfile(trainDir, strcat(trainData.id_code, '.png'));
    labels = categorical(trainData.diagnosis);

    % Create imageDatastore
    imds = imageDatastore(imgPaths, 'Labels', labels);

    %% Split into train and validation
    [trainDS, valDS] = splitEachLabel(imds, splitRatio, 'randomized');

    fprintf('Train: %d images\n', numel(trainDS.Files));
    fprintf('Val:   %d images\n', numel(valDS.Files));

    %% Create test datastore
    testCsv = fullfile(dataRoot, 'test.csv');
    testDir = fullfile(dataRoot, 'test_images');

    if exist(testCsv, 'file')
        testData = readtable(testCsv);
        testPaths = fullfile(testDir, strcat(testData.id_code, '.png'));

        % Only include files that exist
        existIdx = exist(testPaths, 'file') == 2;
        testPaths = testPaths(existIdx);

        testDS = imageDatastore(testPaths);
        fprintf('Test:  %d images\n', numel(testDS.Files));
    else
        testDS = imageDatastore({});
        fprintf('No test set found\n');
    end

    fprintf('Datastores created!\n');
end
