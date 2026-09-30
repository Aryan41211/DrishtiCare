%% runRandomImage.m
% DrishtiCare - Random Single Image Test
% NO TRAINING / NO RETRAINING

clear; clc; close all;

fprintf('\n============================================\n');
fprintf('   DRISHTICARE - RANDOM IMAGE TEST\n');
fprintf('============================================\n');

%% Setup
projectRoot = 'C:\projects\DrishtiCare';
cd(projectRoot);
addpath(genpath(fullfile(projectRoot,'src')));

rng('shuffle');

%% Load locked Day-7 model
modelPath = fullfile( ...
    projectRoot, ...
    'data','models', ...
    'day7_pretrained_resnet18_5class_stage2.mat');

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
    error('No neural network found.');
end

%% Load validation dataset
valRoot = fullfile( ...
    projectRoot, ...
    'data','splits','val');

imds = imageDatastore( ...
    valRoot, ...
    'IncludeSubfolders',true, ...
    'LabelSource','foldernames');

%% Pick one random image
idx = randi(numel(imds.Files));

file = imds.Files{idx};
img = imread(file);

trueLabel = string(imds.Labels(idx));

%% Prepare image
singleDS = imageDatastore({file});

augDS = augmentedImageDatastore( ...
    [224 224 3], ...
    singleDS);

%% Prediction
[predLabel,scores] = classify(net,augDS);

predLabel = string(predLabel);

confidence = max(scores) * 100;

%% Convert class names
classMap = containers.Map( ...
    {'class_0','class_1','class_2','class_3','class_4'}, ...
    {'No DR','Mild','Moderate','Severe','Proliferative'});

trueName = classMap(char(trueLabel));
predName = classMap(char(predLabel));

%% Referral decision
% Moderate, Severe and Proliferative = referable

isReferable = ismember( ...
    predLabel, ...
    ["class_2","class_3","class_4"]);

if isReferable
    referral = 'REFER';
else
    referral = 'NON-REFERABLE';
end

%% Correct?
isCorrect = trueLabel == predLabel;

%% Print
fprintf('\n--------------------------------------------\n');
fprintf('RANDOM IMAGE RESULT\n');
fprintf('--------------------------------------------\n');

fprintf('Image:       %s\n',file);
fprintf('True Grade:  %s\n',trueName);
fprintf('Prediction:  %s\n',predName);
fprintf('Confidence:  %.2f%%\n',confidence);
fprintf('Referral:    %s\n',referral);

if isCorrect
    fprintf('Result:      CORRECT\n');
else
    fprintf('Result:      WRONG\n');
end

fprintf('--------------------------------------------\n');

%% Display
figure( ...
    'Name','DrishtiCare - Random Image Test', ...
    'NumberTitle','off', ...
    'Position',[300 150 1000 700]);

imshow(img);

if isCorrect
    titleColor = [0 0.6 0];
    status = 'CORRECT';
else
    titleColor = [0.8 0 0];
    status = 'WRONG';
end

title({ ...
    ['DrishtiCare - ' status], ...
    ['True: ' trueName], ...
    ['Predicted: ' predName], ...
    sprintf('Confidence: %.2f%%',confidence), ...
    ['Decision: ' referral]}, ...
    'Color',titleColor, ...
    'FontSize',13);

fprintf('\nNO TRAINING performed.\n');
fprintf('NO MODEL WEIGHTS modified.\n\n');