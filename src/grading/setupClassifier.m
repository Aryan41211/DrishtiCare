function [lgraph, setupInfo] = setupClassifier(varargin)
% SETUPCLASSIFIER Load ResNet-18 and prepare for DR classification
%   [lgraph, setupInfo] = setupClassifier()
%   [lgraph, setupInfo] = setupClassifier('Config', config)
%
%   Outputs:
%       lgraph    - Layer graph with modified final layers
%       setupInfo - Struct with setup metadata
%
%   Optional Parameters:
%       'Config' - Training config struct (default: defaultTrainingConfig())
%
%   Method:
%       1. Try pretrained ResNet-18; fallback to untrained architecture
%       2. Extract layer graph
%       3. Replace final fully connected layer for 5 DR classes
%       4. Replace classification layer
%       5. Freeze backbone for staged fine-tuning
%
%   IMPORTANT: This is an ENGINEERING classifier setup, NOT a clinical
%   diagnostic system. The model must be validated before clinical use.

    %% Parse arguments
    p = inputParser;
    addParameter(p, 'Config', [], @(x) isstruct(x));
    addParameter(p, 'NumClasses', [], @(x) isempty(x) || (isnumeric(x) && x > 0));
    parse(p, varargin{:});
    config = p.Results.Config;

    if isempty(config)
        config = defaultTrainingConfig();
    end

    %% Extract settings from config
    numClasses = p.Results.NumClasses;
    if isempty(numClasses)
        numClasses = config.classes.numClasses;
    end
    usePretrained = config.model.usePretrained;
    stage1Config = config.finetune.stage1;

    %% Load pretrained model or use untrained architecture
    fprintf('Loading ResNet-18 architecture...\n');

    pretrainedAvailable = false;
    lgraph = [];

    % Try pretrained first
    if usePretrained
        try
            net = resnet18;
            if isa(net, 'nnet.cnn.LayerGraph')
                lgraph = net;
            else
                lgraph = layerGraph(net);
            end
            pretrainedAvailable = true;
            fprintf('  Pretrained ResNet-18: AVAILABLE\n');
        catch e
            fprintf('  Pretrained ResNet-18: NOT AVAILABLE (%s)\n', e.message);
        end
    end

    % Fallback to untrained
    if isempty(lgraph)
        lgraph = resnet18('Weights', 'none');
        fprintf('  Using untrained ResNet-18 (random weights)\n');
    end

    %% Identify layer names
    fcLayerName = 'fc1000';
    outputLayerName = 'ClassificationLayer_predictions';
    featureSize = 512;

    %% Replace final layers
    fprintf('Replacing final layers for %d classes...\n', numClasses);

    % New fully connected layer
    newFC = fullyConnectedLayer(numClasses, ...
        'Name', 'fc_dr', ...
        'WeightLearnRateFactor', 10, ...
        'BiasLearnRateFactor', 10);

    % New softmax layer
    newSoftmax = softmaxLayer('Name', 'softmax_dr');

    % New classification layer
    newClassLayer = classificationLayer('Name', 'output');

    % Replace layers
    lgraph = replaceLayer(lgraph, fcLayerName, newFC);
    lgraph = replaceLayer(lgraph, outputLayerName, newClassLayer);

    %% Freeze backbone for staged fine-tuning
    if stage1Config.freezeBackbone
        fprintf('Freezing backbone for staged fine-tuning...\n');

        freezeCount = stage1Config.freezeLayers;
        layerNames = {lgraph.Layers.Name};

        for i = 1:min(freezeCount, length(lgraph.Layers))
            layer = lgraph.Layers(i);

            % Skip input layer (no learnable parameters)
            if isa(layer, 'nnet.cnn.layer.ImageInputLayer')
                continue;
            end

            % Freeze weights by setting learn rate factors to 0
            if isprop(layer, 'WeightLearnRateFactor')
                layer.WeightLearnRateFactor = 0;
            end
            if isprop(layer, 'BiasLearnRateFactor')
                layer.BiasLearnRateFactor = 0;
            end

            lgraph = replaceLayer(lgraph, layer.Name, layer);
        end

        fprintf('  Frozen %d layers\n', freezeCount);
    end

    %% Verify architecture
    fprintf('\n=== Classifier Architecture ===\n');
    fprintf('Model: ResNet-18\n');
    fprintf('Pretrained: %s\n', mat2str(pretrainedAvailable));
    fprintf('Input size: %s\n', mat2str(lgraph.Layers(1).InputSize));
    fprintf('Output classes: %d\n', numClasses);
    fprintf('Total layers: %d\n', length(lgraph.Layers));
    fprintf('Connections: %d\n', size(lgraph.Connections, 1));

    % Show final layers
    fprintf('\nFinal layers:\n');
    for i = max(1, length(lgraph.Layers)-4):length(lgraph.Layers)
        layer = lgraph.Layers(i);
        fprintf('  %s (%s)\n', layer.Name, class(layer));
    end
    fprintf('================================\n\n');

    %% Save setup info
    setupInfo = struct();
    setupInfo.date = datestr(now);
    setupInfo.model = 'resnet18';
    setupInfo.pretrained = pretrainedAvailable;
    setupInfo.inputSize = lgraph.Layers(1).InputSize;
    setupInfo.numClasses = numClasses;
    setupInfo.featureSize = featureSize;
    setupInfo.frozenLayers = stage1Config.freezeLayers;
    setupInfo.layerCount = length(lgraph.Layers);
end