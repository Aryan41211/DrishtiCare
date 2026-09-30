%% runSelectedImage.m
% DrishtiCare - Interactive Single Image Model Demo
% Select any retinal image and run the locked Day-7 model.
% NO TRAINING / NO RETRAINING

clear; clc; close all;

fprintf('\n============================================\n');
fprintf('     DRISHTICARE - IMAGE MODEL DEMO\n');
fprintf('============================================\n');

%% Project setup
projectRoot = 'C:\projects\DrishtiCare';
cd(projectRoot);
addpath(genpath(fullfile(projectRoot,'src')));

%% Load locked Day-7 model
modelPath = fullfile( ...
    projectRoot, ...
    'data','models', ...
    'day7_pretrained_resnet18_5class_stage2.mat');

if ~isfile(modelPath)
    error('Model not found:\n%s',modelPath);
end

S = load(modelPath);

vars = fieldnames(S);
net = [];

for k = 1:numel(vars)

    x = S.(vars{k});

    if isa(x,'DAGNetwork') || ...
       isa(x,'SeriesNetwork') || ...
       isa(x,'dlnetwork')

        net = x;
        break;
    end

end

if isempty(net)
    error('No neural network found in model file.');
end

fprintf('\nModel loaded successfully.\n');

%% Class names
classNames = { ...
    'No DR', ...
    'Mild', ...
    'Moderate', ...
    'Severe', ...
    'Proliferative'};

classLabels = { ...
    'class_0', ...
    'class_1', ...
    'class_2', ...
    'class_3', ...
    'class_4'};

%% Select image
fprintf('\nSelect a retinal image...\n');

[fileName,pathName] = uigetfile( ...
    {'*.jpg;*.jpeg;*.png;*.tif;*.tiff', ...
     'Retinal Images (*.jpg, *.jpeg, *.png, *.tif, *.tiff)'}, ...
    'Select Retinal Image');

%% Cancel handling
if isequal(fileName,0)

    fprintf('\nImage selection cancelled.\n');
    return;

end

filePath = fullfile(pathName,fileName);

fprintf('\nSelected image:\n%s\n',filePath);

%% Read image
img = imread(filePath);

%% Make RGB if grayscale
if size(img,3) == 1
    img = repmat(img,[1 1 3]);
end

%% Prepare image using same evaluation pipeline
singleDS = imageDatastore({filePath});

augDS = augmentedImageDatastore( ...
    [224 224 3], ...
    singleDS);

%% Run model
fprintf('\nRunning model inference...\n');

[predLabel,scores] = classify(net,augDS);

predLabel = string(predLabel);

%% Predicted class
predIndex = find(strcmp(classLabels,char(predLabel)));

if isempty(predIndex)

    % Fallback
    predIndex = find(strcmp(string(classLabels),predLabel));

end

predName = classNames{predIndex};

%% Confidence
confidence = max(scores) * 100;

%% Referral decision
%
% Moderate + Severe + Proliferative = Referable

isReferable = ismember( ...
    predLabel, ...
    ["class_2","class_3","class_4"]);

if isReferable
    referralDecision = 'REFER';
else
    referralDecision = 'NON-REFERABLE';
end

%% Try to identify true label
% If selected image is inside data/splits/val/class_X,
% determine its ground-truth label.

trueLabel = '';
trueName = '';
isCorrect = [];

parts = split(string(pathName),filesep);

for k = 1:numel(parts)

    if any(strcmp(parts(k),classLabels))

        trueLabel = parts(k);
        break;

    end

end

if trueLabel ~= ""

    trueIndex = find(strcmp(classLabels,char(trueLabel)));

    trueName = classNames{trueIndex};

    isCorrect = predLabel == trueLabel;

end

%% Print results
fprintf('\n============================================\n');
fprintf('           MODEL RESULT\n');
fprintf('============================================\n');

fprintf('Image:\n%s\n\n',filePath);

if trueName ~= ""
    fprintf('True Grade:      %s\n',trueName);
end

fprintf('Predicted Grade: %s\n',predName);
fprintf('Confidence:      %.2f%%\n',confidence);
fprintf('Referral:        %s\n',referralDecision);

if ~isempty(isCorrect)

    if isCorrect
        fprintf('Prediction:      CORRECT\n');
    else
        fprintf('Prediction:      WRONG\n');
    end

end

fprintf('\n--------------------------------------------\n');
fprintf('CLASS PROBABILITIES\n');
fprintf('--------------------------------------------\n');

for k = 1:numel(classNames)

    fprintf('%-15s : %7.2f%%\n', ...
        classNames{k}, ...
        scores(k)*100);

end

fprintf('============================================\n');

%% Display image
figure( ...
    'Name','DrishtiCare - Model Prediction', ...
    'NumberTitle','off', ...
    'Position',[250 100 1100 750]);

imshow(img);

%% Title
if ~isempty(isCorrect)

    if isCorrect
        status = '✓ CORRECT';
        titleColor = [0 0.6 0];
    else
        status = '✗ WRONG';
        titleColor = [0.8 0 0];
    end

    title({ ...
        'DrishtiCare', ...
        status, ...
        ['True: ' trueName], ...
        ['Predicted: ' predName], ...
        sprintf('Confidence: %.2f%%',confidence), ...
        ['Decision: ' referralDecision]}, ...
        'Color',titleColor, ...
        'FontSize',14);

else

    title({ ...
        'DrishtiCare', ...
        ['Predicted: ' predName], ...
        sprintf('Confidence: %.2f%%',confidence), ...
        ['Decision: ' referralDecision]}, ...
        'FontSize',14);

end

fprintf('\nNO TRAINING performed.\n');
fprintf('NO MODEL WEIGHTS modified.\n');
fprintf('============================================\n\n');