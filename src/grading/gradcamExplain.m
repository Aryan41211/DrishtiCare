function [overlay, heatmap, scores] = gradcamExplain(trainedNet, img, varargin)
% GRADCAMEXPLAIN Grad-CAM heatmap for a DR classifier prediction
%   [overlay, heatmap, scores] = gradcamExplain(trainedNet, img)
%   [...] = gradcamExplain(trainedNet, img, 'TargetClass', idx, 'FeatureLayer', name)
%
%   Inputs:
%       trainedNet - DAGNetwork with classification output
%       img        - HxWx3 image (will be resized to network input)
%
%   Optional:
%       'TargetClass'  - 1-indexed class to explain (default: predicted class)
%       'FeatureLayer' - conv feature layer (default: 'res5b_relu')
%
%   Outputs:
%       overlay - heatmap blended on original image
%       heatmap - normalized [0,1] Grad-CAM map
%       scores  - 5- or 2-class probability vector
%
%   ENGINEERING explainability aid, NOT a clinical justification.

    p = inputParser;
    addParameter(p, 'TargetClass', [], @(x) isempty(x) || isnumeric(x));
    addParameter(p, 'FeatureLayer', 'res5b_relu', @ischar);
    parse(p, varargin{:});

    inputSize = trainedNet.Layers(1).InputSize;
    imgResized = imresize(img, inputSize(1:2));

    [pred, scores] = classify(trainedNet, imgResized);
    scores = scores(:)';
    if iscell(pred), pred = pred{1}; end

    targetClass = p.Results.TargetClass;
    if isempty(targetClass)
        [~, targetClass] = max(scores);
    end

    cmap = gradCAM(trainedNet, imgResized, targetClass, ...
        'FeatureLayer', p.Results.FeatureLayer);
    heatmap = mat2gray(cmap);

    % Overlay jet heatmap at 40% opacity
    hm = imresize(heatmap, [size(imgResized,1), size(imgResized,2)]);
    overlay = imfuse(repmat(hm, 1, 1, 3), ...
        im2double(imgResized), 'blend', 'Scaling', 'joint');
end