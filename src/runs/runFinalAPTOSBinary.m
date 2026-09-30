%% runFinalAPTOSBinary.m
% Final Day-7 Binary Referral Evaluation
% No training. No retraining. Uses locked Day-7 binary model.

clc;
clear;

fprintf('\n============================================\n');
fprintf('   DRISHTICARE - FINAL APTOS BINARY TEST\n');
fprintf('============================================\n');

%% Project setup
projectRoot = 'C:\projects\DrishtiCare';
cd(projectRoot);
addpath(genpath(fullfile(projectRoot,'src')));

%% Paths
modelPath = fullfile( ...
    projectRoot, ...
    'data','models', ...
    'day7_pretrained_resnet18_binary_stage2.mat');

valPath = fullfile( ...
    projectRoot, ...
    'data','splits','val');

%% Check files
if ~isfile(modelPath)
    error('Binary model not found:\n%s', modelPath);
end

if ~isfolder(valPath)
    error('Validation folder not found:\n%s', valPath);
end

%% Load locked binary model
S = load(modelPath);

vars = fieldnames(S);

% Find network
net = [];
for i = 1:numel(vars)
    candidate = S.(vars{i});

    if isa(candidate,'DAGNetwork') || ...
       isa(candidate,'SeriesNetwork') || ...
       isa(candidate,'dlnetwork')

        net = candidate;
        break;
    end
end

if isempty(net)
    error('No neural network found in model file.');
end

%% Load validation data
valRaw = imageDatastore( ...
    valPath, ...
    'IncludeSubfolders', true, ...
    'LabelSource', 'foldernames');

% IMPORTANT:
% Match the preprocessing used during Day-7 evaluation/training.
valDS = augmentedImageDatastore( ...
    [224 224 3], ...
    valRaw);

fprintf('\nValidation images: %d\n', numel(valRaw.Files));

%% Run inference
fprintf('Running binary inference...\n');

[YPred, scores] = classify(net, valDS);

%% Convert 5-class ground truth to binary
%
% class_0 = No DR          -> nonreferable
% class_1 = Mild DR        -> nonreferable
% class_2 = Moderate DR    -> referable
% class_3 = Severe DR      -> referable
% class_4 = Proliferative  -> referable

YTrue5 = valRaw.Labels;

YTrue = categorical( ...
    ismember(string(YTrue5), ...
    ["class_2","class_3","class_4"]), ...
    [false true], ...
    {'nonreferable','referable'});

%% Accuracy
acc = mean(YPred == YTrue);

%% Confusion matrix
C = confusionmat( ...
    YTrue, ...
    YPred, ...
    'Order', categorical({'nonreferable','referable'}));

TN = C(1,1);
FP = C(1,2);
FN = C(2,1);
TP = C(2,2);

%% Metrics
sensitivity = TP / (TP + FN);
specificity = TN / (TN + FP);
precision   = TP / (TP + FP);
f1          = 2 * precision * sensitivity / ...
              (precision + sensitivity);

%% Display
fprintf('\n============================================\n');
fprintf('   DAY-7 BINARY REFERRAL RESULTS\n');
fprintf('============================================\n');

fprintf('Accuracy:    %.2f%%\n', acc * 100);
fprintf('Sensitivity: %.2f%%\n', sensitivity * 100);
fprintf('Specificity: %.2f%%\n', specificity * 100);
fprintf('Precision:   %.2f%%\n', precision * 100);
fprintf('F1:          %.4f\n', f1);

fprintf('\nConfusion Matrix:\n');
fprintf('                 Pred Non-Ref   Pred Ref\n');
fprintf('Actual Non-Ref       %4d          %4d\n', TN, FP);
fprintf('Actual Ref           %4d          %4d\n', FN, TP);

fprintf('\nTP=%d  FP=%d  FN=%d  TN=%d\n', ...
    TP, FP, FN, TN);

fprintf('============================================\n');
fprintf('Evaluation complete. NO training performed.\n');
fprintf('============================================\n\n');