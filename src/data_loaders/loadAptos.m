function [trainImgs, trainLabels, testImgs, testIds] = loadAptos(dataRoot)
% LOADAPTOS Load APTOS 2019 dataset
%   [trainImgs, trainLabels, testImgs, testIds] = loadAptos(dataRoot)
%
%   Inputs:
%       dataRoot - Path to aptos2019 folder (default: '../../data/aptos2019')
%
%   Outputs:
%       trainImgs   - Cell array of training images
%       trainLabels - Numeric array of diagnosis labels (0-4)
%       testImgs    - Cell array of test images
%       testIds     - Cell array of test image IDs

    if nargin < 1
        dataRoot = fullfile('..', '..', 'data', 'aptos2019');
    end

    fprintf('Loading APTOS 2019 dataset...\n');

    %% Load training data
    trainCsv = fullfile(dataRoot, 'train.csv');
    trainDir = fullfile(dataRoot, 'train_images');

    if ~exist(trainCsv, 'file')
        error('train.csv not found at: %s', trainCsv);
    end

    trainData = readtable(trainCsv);
    fprintf('Found %d training images\n', height(trainData));

    trainImgs = cell(height(trainData), 1);
    trainLabels = zeros(height(trainData), 1);

    for i = 1:height(trainData)
        imgName = [trainData.id_code{i}, '.png'];
        imgPath = fullfile(trainDir, imgName);

        if exist(imgPath, 'file')
            trainImgs{i} = imread(imgPath);
            trainLabels(i) = trainData.diagnosis(i);
        else
            warning('Image not found: %s', imgPath);
            trainImgs{i} = [];
        end
    end

    % Remove empty entries
    emptyIdx = cellfun(@isempty, trainImgs);
    trainImgs(emptyIdx) = [];
    trainLabels(emptyIdx) = [];

    fprintf('Loaded %d training images\n', length(trainImgs));

    %% Load test data
    testCsv = fullfile(dataRoot, 'test.csv');
    testDir = fullfile(dataRoot, 'test_images');

    if exist(testCsv, 'file')
        testData = readtable(testCsv);
        fprintf('Found %d test images\n', height(testData));

        testImgs = cell(height(testData), 1);
        testIds = cell(height(testData), 1);

        for i = 1:height(testData)
            imgName = [testData.id_code{i}, '.png'];
            imgPath = fullfile(testDir, imgName);

            if exist(imgPath, 'file')
                testImgs{i} = imread(imgPath);
                testIds{i} = testData.id_code{i};
            else
                testImgs{i} = [];
                testIds{i} = testData.id_code{i};
            end
        end

        emptyIdx = cellfun(@isempty, testImgs);
        testImgs(emptyIdx) = [];
        testIds(emptyIdx) = [];

        fprintf('Loaded %d test images\n', length(testImgs));
    else
        testImgs = {};
        testIds = {};
        fprintf('No test.csv found, skipping test set\n');
    end

    fprintf('Dataset loading complete!\n');
end
