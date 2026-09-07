function [flag, mDist, detail] = ood_detector(imgOrPath, varargin)
% OOD_DETECTOR Mahalanobis-distance out-of-distribution detector
%   [flag, mDist, detail] = ood_detector(imgOrPath)
%   [flag, mDist, detail] = ood_detector(imgOrPath, 'Threshold', t)
%
%   Inputs:
%       imgOrPath — file path (char/string) OR HxWx3 uint8 RGB image array
%
%   Optional Parameters:
%       'Threshold'  — override threshold (default: from ood_stats.mat)
%
%   Outputs:
%       flag   — logical scalar; true = flagged as OOD (send to human review)
%       mDist  — scalar Mahalanobis distance
%       detail — struct with fields:
%                  .classDists   — 1x5 per-class Mahalanobis distances
%                  .nearestClass — nearest class index (1-5, maps to 0-4)
%                  .threshold    — threshold used for flagging
%                  .isOod        — logical (same as flag)
%
%   Uses persistent variables to load OOD stats and model only once per
%   MATLAB session.
%
%   Engineering demo — NOT a clinical device.

    persistent oodStats cachedNet;
    if isempty(oodStats)
        projectRoot = pwd;
        statsPath = fullfile(projectRoot, 'data', 'analysis', 'day8', 'ood', 'ood_stats.mat');
        if ~exist(statsPath, 'file')
            error('ood_detector:noStats', ...
                'OOD stats not found at %s. Run buildOodStats first.', statsPath);
        end
        S = load(statsPath, 'oodStats');
        oodStats = S.oodStats;

        % Load the classification network for feature extraction
        S2 = load(oodStats.modelPath, 'trainedNet');
        cachedNet = S2.trainedNet;
    end

    p = inputParser;
    addParameter(p, 'Threshold', oodStats.threshold, @isnumeric);
    parse(p, varargin{:});
    thr = p.Results.Threshold;

    %% Get image
    if ischar(imgOrPath) || isstring(imgOrPath)
        raw = imread(char(imgOrPath));
    else
        raw = imgOrPath;
    end

    %% Preprocess: replicate gray to 3ch, resize to 224x224
    if size(raw, 3) == 1
        raw = repmat(raw, 1, 1, 3);
    end
    modelIn = imresize(raw, oodStats.imgSize);

    %% Extract features from pool5
    feat = activations(cachedNet, modelIn, oodStats.featureLayer, ...
        'Output', 'channels');
    featVec = reshape(feat, 1, []);

    %% Compute per-class Mahalanobis distances
    mu = oodStats.mu;           % 5 x 512
    SigmaInv = oodStats.SigmaInv;  % 512 x 512
    nClasses = size(mu, 1);
    classDists = zeros(1, nClasses, 'single');
    for c = 1:nClasses
        diff_c = featVec - mu(c, :);
        classDists(c) = sqrt(diff_c * SigmaInv * diff_c');
    end

    [mDist, nearestIdx] = min(classDists);
    mDist = double(mDist);

    %% Flag as OOD
    flag = mDist > thr;

    %% Build detail
    detail = struct();
    detail.classDists = double(classDists);
    detail.nearestClass = nearestIdx - 1;  % 0-indexed label
    detail.threshold = thr;
    detail.isOod = flag;
end
