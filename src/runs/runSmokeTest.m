%% runSmokeTest.m
% DrishtiCare - 10 Image Smoke Test
% 2 random images from each DR category
% NO training / NO retraining

clear; clc; close all;

fprintf('\n============================================\n');
fprintf('   DRISHTICARE - SMOKE TEST (10 IMAGES)\n');
fprintf('============================================\n');

%% Setup
projectRoot = 'C:\projects\DrishtiCare';
cd(projectRoot);
addpath(genpath('src'));

rng(42);

%% Load locked Day-7 5-class model
modelPath = fullfile( ...
    projectRoot, ...
    'data','models', ...
    'day7_pretrained_resnet18_5class_stage2.mat');

S = load(modelPath);

% Find network automatically
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

%% Load validation images
valRoot = fullfile(projectRoot,'data','splits','val');

imds = imageDatastore( ...
    valRoot, ...
    'IncludeSubfolders',true, ...
    'LabelSource','foldernames');

fprintf('\nValidation images available: %d\n',numel(imds.Files));

%% Select 2 images from EACH category
selectedFiles = {};
selectedTrueClass = [];

for c = 0:4

    className = sprintf('class_%d',c);

    % Convert labels to strings for safe comparison
    labels = string(imds.Labels);

    idx = find(labels == className);

    if numel(idx) < 2
        error('Not enough images in %s.',className);
    end

    % Randomly select 2
    chosen = idx(randperm(numel(idx),2));

    selectedFiles = [selectedFiles; imds.Files(chosen)];
    selectedTrueClass = [selectedTrueClass; repmat(c,2,1)];

end

%% Shuffle the 10 images
order = randperm(10);

selectedFiles = selectedFiles(order);
selectedTrueClass = selectedTrueClass(order);

%% Class names
classNames = { ...
    'No DR', ...
    'Mild', ...
    'Moderate', ...
    'Severe', ...
    'Proliferative'};

%% Results
correct = 0;

fprintf('\nRunning predictions...\n\n');

figure( ...
    'Name','DrishtiCare - 10 Image Smoke Test', ...
    'NumberTitle','off', ...
    'Position',[50 50 1500 850]);

for i = 1:10

    %% Read image
    img = imread(selectedFiles{i});

    %% Same resizing pipeline used for evaluation
    augDS = augmentedImageDatastore( ...
        [224 224 3], ...
        imageDatastore({selectedFiles{i}}));

    %% Prediction
    [predLabel,scores] = classify(net,augDS);

    predString = string(predLabel);

    % Extract predicted class number
    predClass = str2double( ...
        extractAfter(predString,"class_"));

    trueClass = selectedTrueClass(i);

    confidence = max(scores) * 100;

    isCorrect = (predClass == trueClass);

    if isCorrect
        correct = correct + 1;
        status = 'CORRECT';
    else
        status = 'WRONG';
    end

    %% Display image
    subplot(2,5,i);
    imshow(img);

    if isCorrect
        titleColor = [0 0.6 0];
    else
        titleColor = [0.8 0 0];
    end

    title({ ...
        sprintf('%s',status), ...
        sprintf('True: %s',classNames{trueClass+1}), ...
        sprintf('Pred: %s',classNames{predClass+1}), ...
        sprintf('Confidence: %.1f%%',confidence)}, ...
        'Color',titleColor, ...
        'FontSize',10);

    %% Console output
    fprintf( ...
        '%2d. True: %-13s | Pred: %-13s | Confidence: %6.2f%% | %s\n', ...
        i, ...
        classNames{trueClass+1}, ...
        classNames{predClass+1}, ...
        confidence, ...
        status);

end

%% Final result
accuracy = correct / 10 * 100;

fprintf('\n============================================\n');
fprintf('             SMOKE TEST RESULT\n');
fprintf('============================================\n');
fprintf('Correct:  %d / 10\n',correct);
fprintf('Accuracy: %.2f%%\n',accuracy);
fprintf('============================================\n');

%% Save result image
outDir = fullfile( ...
    projectRoot, ...
    'data','analysis','smoke_test');

if ~exist(outDir,'dir')
    mkdir(outDir);
end

outFile = fullfile(outDir,'smoke_test_10_images.png');

saveas(gcf,outFile);

fprintf('\nVisualization saved to:\n%s\n',outFile);

fprintf('\nSmoke test finished.\n');
fprintf('NO training performed.\n');
fprintf('NO model weights modified.\n\n');