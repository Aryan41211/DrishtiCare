function config = defaultPretrainedConfig(experimentId)
% DEFAULTPRETRAINEDCONFIG Transfer-learning config (ImageNet ResNet-18)
%   config = defaultPretrainedConfig('day7_pretrained_resnet18_5class')
%
%   Same pipeline/split/augmentation as Day 6. Only initialization differs.
%   Stage 1: head-only (frozen backbone). Stage 2: full unfreeze, LR 1e-5.

    if nargin < 1 || isempty(experimentId)
        experimentId = 'day7_pretrained_resnet18_5class';
    end
    config = defaultTrainingConfig();
    config.experimentId = experimentId;
    config.version = '2.0.0-pretrained';
    config.model.usePretrained = true;
    config.model.initialization = 'ImageNet';
    config.output.modelSavePath = fullfile(config.dataset.modelDir, [experimentId, '.mat']);
    config.output.summaryPath = fullfile(config.dataset.analysisDir, [experimentId, '_summary.mat']);
    fprintf('Pretrained config: %s (init=%s)\n', experimentId, config.model.initialization);
end