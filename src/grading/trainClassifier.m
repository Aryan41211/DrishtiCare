function [net, info] = trainClassifier(dataRoot, options)
% TRAINCLASSIFIER Train DR classifier using transfer learning
%   [net, info] = trainClassifier(dataRoot, options)
%
%   Inputs:
%       dataRoot - Path to aptos2019 folder
%       options  - Training options struct (optional)
%
%   Outputs:
%       net  - Trained network
%       info - Training info struct

    %% Default options
    if nargin < 2
        options = struct();
    end

    if ~isfield(options, 'Network')
        options.Network = 'resnet18';  % 'resnet18', 'resnet50', 'efficientnetb0'
    end
    if ~isfield(options, 'MaxEpochs')
        options.MaxEpochs = 10;
    end
    if ~isfield(options, 'MiniBatchSize')
        options.MiniBatchSize = 32;
    end
    if ~isfield(options, 'InitialLearnRate')
        options.InitialLearnRate = 0.001;
    end
    if ~isfield(options, 'ValidationFrequency')
        options.ValidationFrequency = 50;
    end
    if ~isfield(options, 'InputSize')
        options.InputSize = [224 224 3];
    end
    if ~isfield(options, 'Verbose')
        options.Verbose = true;
    end
    if ~isfield(options, 'Plots')
        options.Plots = 'training-progress';
    end

    fprintf('=== DrishtiCare Classifier Training ===\n');
    fprintf('Network: %s\n', options.Network);
    fprintf('Max Epochs: %d\n', options.MaxEpochs);
    fprintf('Batch Size: %d\n\n', options.MiniBatchSize);

    %% Setup paths
    if nargin < 1 || isempty(dataRoot)
        script_dir = fileparts(mfilename('fullpath'));
        project_root = fileparts(fileparts(script_dir));
        dataRoot = fullfile(project_root, 'data', 'aptos2019');
    end

    %% Create datastores
    fprintf('--- Loading Data ---\n');
    trainCsv = fullfile(dataRoot, 'train.csv');
    trainDir = fullfile(dataRoot, 'train_images');

    data = readtable(trainCsv);

    % Create image paths and labels
    imgPaths = fullfile(trainDir, strcat(data.id_code, '.png'));
    labels = categorical(data.diagnosis);

    % Create imageDatastore
    imds = imageDatastore(imgPaths, 'Labels', labels);

    % Split into train and validation (80/20)
    [trainDS, valDS] = splitEachLabel(imds, 0.8, 'randomized');

    fprintf('Training images:   %d\n', numel(trainDS.Files));
    fprintf('Validation images: %d\n\n', numel(valDS.Files));

    %% Augmentation
    fprintf('--- Setting Up Augmentation ---\n');
    augmenter = imageDataAugmenter( ...
        'RandRotation', [-10, 10], ...
        'RandXTranslation', [-10, 10], ...
        'RandYTranslation', [-10, 10], ...
        'RandXReflection', true, ...
        'RandXScale', [0.9, 1.1], ...
        'RandYScale', [0.9, 1.1]);

    augmentedTrainDS = augmentedImageDatastore(options.InputSize, trainDS, ...
        'DataAugmentation', augmenter);
    augmentedValDS = augmentedImageDatastore(options.InputSize, valDS);

    fprintf('[OK] Augmentation configured\n\n');

    %% Create network
    fprintf('--- Creating Network: %s ---\n', options.Network);

    switch lower(options.Network)
        case 'resnet18'
            baseNet = resnet18;
            lgraph = layerGraph(baseNet);
            % Replace final layers
            lgraph = replaceLayer(lgraph, 'fc1000', ...
                fullyConnectedLayer(5, 'Name', 'fc_dr', ...
                'WeightLearnRateFactor', 10, 'BiasLearnRateFactor', 10));
            lgraph = replaceLayer(lgraph, 'ClassificationLayer_predictions', ...
                classificationLayer('Name', 'classification'));

        case 'resnet50'
            baseNet = resnet50;
            lgraph = layerGraph(baseNet);
            lgraph = replaceLayer(lgraph, 'fc1000', ...
                fullyConnectedLayer(5, 'Name', 'fc_dr', ...
                'WeightLearnRateFactor', 10, 'BiasLearnRateFactor', 10));
            lgraph = replaceLayer(lgraph, 'ClassificationLayer_predictions', ...
                classificationLayer('Name', 'classification'));

        case 'efficientnetb0'
            baseNet = efficientnetb0;
            lgraph = layerGraph(baseNet);
            lgraph = replaceLayer(lgraph, 'ClassificationLayer-Loss', ...
                classificationLayer('Name', 'classification'));
            % Modify final fc layer
            for i = 1:length(lgraph.Layers)
                if isa(lgraph.Layers(i), 'nnet.cnn.layer.FullyConnectedLayer')
                    if lgraph.Layers(i).OutputSize == 1000
                        lgraph.Layers(i) = fullyConnectedLayer(5, ...
                            'Name', 'fc_dr', ...
                            'WeightLearnRateFactor', 10, ...
                            'BiasLearnRateFactor', 10);
                    end
                end
            end

        otherwise
            error('Unknown network: %s', options.Network);
    end

    fprintf('[OK] Network created: %s\n\n', options.Network);

    %% Training options
    fprintf('--- Configuring Training ---\n');
    opts = trainingOptions('sgdm', ...
        'MaxEpochs', options.MaxEpochs, ...
        'MiniBatchSize', options.MiniBatchSize, ...
        'InitialLearnRate', options.InitialLearnRate, ...
        'LearnRateSchedule', 'piecewise', ...
        'LearnRateDropFactor', 0.5, ...
        'LearnRateDropPeriod', 5, ...
        'ValidationData', augmentedValDS, ...
        'ValidationFrequency', options.ValidationFrequency, ...
        'Verbose', options.Verbose, ...
        'Plots', options.Plots, ...
        'ExecutionEnvironment', 'auto');

    fprintf('[OK] Training options configured\n\n');

    %% Train network
    fprintf('--- Training Started ---\n');
    tic;
    [net, info] = trainNetwork(augmentedTrainDS, lgraph, opts);
    trainingTime = toc;

    fprintf('\n--- Training Complete ---\n');
    fprintf('Training time: %.1f minutes\n', trainingTime/60);

    %% Save model
    saveDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'models');
    if ~exist(saveDir, 'dir')
        mkdir(saveDir);
    end

    modelPath = fullfile(saveDir, sprintf('dr_classifier_%s.mat', options.Network));
    save(modelPath, 'net', 'info', 'options');
    fprintf('Model saved to: %s\n', modelPath);

    %% Evaluate on validation set
    fprintf('\n--- Quick Evaluation ---\n');
    [predLabels, scores] = classify(net, augmentedValDS);
    trueLabels = valDS.Labels;

    accuracy = sum(predLabels == trueLabels) / numel(trueLabels);
    fprintf('Validation Accuracy: %.2f%%\n', accuracy * 100);

    % Confusion matrix
    figure('Name', 'Training Results', 'NumberTitle', 'off');
    subplot(1,2,1);
    plotconfusion(trueLabels, predLabels);
    title('Confusion Matrix');

    subplot(1,2,2);
    plot(info.TrainingLoss);
    hold on;
    plot(info.ValidationLoss);
    xlabel('Iteration');
    ylabel('Loss');
    title('Training Loss');
    legend('Training', 'Validation');
    grid on;

    fprintf('\n=== Training Complete ===\n');
    fprintf('Net: %s, Accuracy: %.2f%%\n', options.Network, accuracy*100);
end
