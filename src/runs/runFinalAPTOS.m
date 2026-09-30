cd('C:\projects\DrishtiCare');
addpath(genpath('src'));

fprintf('\n============================================\n');
fprintf('   FINAL DAY-7 APTOS EVALUATION\n');
fprintf('============================================\n');

%% Load locked 5-class model
S = load('data\models\day7_pretrained_resnet18_5class_stage2.mat');
net = S.trainedNet;
config = S.config;

%% Load validation datastore EXACTLY like training
valFolder = fullfile('data','splits','val');

valRaw = imageDatastore(valFolder, ...
    'IncludeSubfolders', true, ...
    'LabelSource', 'foldernames');

valDS = augmentedImageDatastore( ...
    config.input.imageSize, valRaw);

fprintf('\nValidation images: %d\n', numel(valRaw.Files));

%% Evaluate using the same datastore preprocessing
YPred = classify(net, valDS);

%% True labels
YTrue = valRaw.Labels;

%% Accuracy
acc = mean(YPred == YTrue);

fprintf('\n============================================\n');
fprintf('5-CLASS RESULTS\n');
fprintf('============================================\n');
fprintf('Accuracy: %.2f%%\n', acc*100);

%% Confusion matrix
figure;
confusionchart(YTrue, YPred);
title('Day-7 ResNet-18 — APTOS Validation');

%% Per-class recall
classes = categories(YTrue);

fprintf('\nPer-class Recall:\n');

for i = 1:numel(classes)

    trueClass = YTrue == classes{i};

    recall = sum(YPred(trueClass) == classes{i}) ...
        / sum(trueClass);

    fprintf('%-15s %.2f%%\n', ...
        classes{i}, recall*100);

end

fprintf('\n============================================\n');
fprintf('DONE — NO RETRAINING PERFORMED\n');
fprintf('============================================\n');