%% runSmokeTest100.m
% DrishtiCare - 100 Image Balanced Smoke Test
% 20 random images from each DR category
% NO TRAINING / NO RETRAINING

clear; clc; close all;

fprintf('\n============================================\n');
fprintf(' DRISHTICARE - 100 IMAGE BALANCED SMOKE TEST\n');
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
    error('No neural network found in model file.');
end

%% Load validation data
valRoot = fullfile( ...
    projectRoot, ...
    'data','splits','val');

imds = imageDatastore( ...
    valRoot, ...
    'IncludeSubfolders',true, ...
    'LabelSource','foldernames');

fprintf('\nValidation images available: %d\n',numel(imds.Files));

%% Classes
classNames = { ...
    'No DR', ...
    'Mild', ...
    'Moderate', ...
    'Severe', ...
    'Proliferative'};

labels = string(imds.Labels);

%% Select 20 random images per class
selectedFiles = cell(100,1);
trueClasses = zeros(100,1);

n = 1;

for c = 0:4

    className = sprintf('class_%d',c);

    idx = find(labels == className);

    if numel(idx) < 20
        error('Not enough images in %s.',className);
    end

    chosen = idx(randperm(numel(idx),20));

    for j = 1:20
        selectedFiles{n} = imds.Files{chosen(j)};
        trueClasses(n) = c;
        n = n + 1;
    end
end

%% Shuffle
order = randperm(100);

selectedFiles = selectedFiles(order);
trueClasses = trueClasses(order);

%% Run predictions
predClasses = zeros(100,1);
confidences = zeros(100,1);

correct = 0;

fprintf('\nRunning predictions on 100 images...\n\n');

for i = 1:100

    singleDS = imageDatastore({selectedFiles{i}});

    augDS = augmentedImageDatastore( ...
        [224 224 3], ...
        singleDS);

    [predLabel,scores] = classify(net,augDS);

    predString = string(predLabel);

    predClass = str2double( ...
        extractAfter(predString,"class_"));

    trueClass = trueClasses(i);

    confidence = max(scores) * 100;

    predClasses(i) = predClass;
    confidences(i) = confidence;

    if predClass == trueClass
        correct = correct + 1;
        status = 'CORRECT';
    else
        status = 'WRONG';
    end

    fprintf( ...
        '%3d/100 | True: %-13s | Pred: %-13s | %6.2f%% | %s\n', ...
        i, ...
        classNames{trueClass+1}, ...
        classNames{predClass+1}, ...
        confidence, ...
        status);
end

%% Overall accuracy
accuracy = correct / 100;

%% Confusion matrix
trueCat = categorical( ...
    trueClasses, ...
    0:4, ...
    classNames);

predCat = categorical( ...
    predClasses, ...
    0:4, ...
    classNames);

C = confusionmat( ...
    trueCat, ...
    predCat, ...
    'Order',categorical(classNames));

%% Per-class metrics
recall = zeros(5,1);
precision = zeros(5,1);
f1 = zeros(5,1);

for c = 1:5

    TP = C(c,c);
    FN = sum(C(c,:)) - TP;
    FP = sum(C(:,c)) - TP;

    recall(c) = TP / (TP + FN);

    if TP + FP > 0
        precision(c) = TP / (TP + FP);
    end

    if precision(c) + recall(c) > 0
        f1(c) = 2 * precision(c) * recall(c) / ...
            (precision(c) + recall(c));
    end
end

%% Confidence analysis
meanConfidence = mean(confidences);

wrongIdx = predClasses ~= trueClasses;

if any(wrongIdx)
    wrongConfidence = mean(confidences(wrongIdx));
else
    wrongConfidence = NaN;
end

%% Final report
fprintf('\n============================================\n');
fprintf('           100 IMAGE SMOKE TEST\n');
fprintf('============================================\n');

fprintf('Correct:          %d / 100\n',correct);
fprintf('Accuracy:         %.2f%%\n',accuracy*100);
fprintf('Mean Confidence:  %.2f%%\n',meanConfidence);

if ~isnan(wrongConfidence)
    fprintf('Wrong Prediction Confidence: %.2f%%\n', ...
        wrongConfidence);
end

fprintf('\n--------------------------------------------\n');
fprintf('PER-CLASS RESULTS\n');
fprintf('--------------------------------------------\n');

fprintf('%-15s %10s %10s %10s\n', ...
    'Class','Recall','Precision','F1');

for c = 1:5

    fprintf('%-15s %9.2f%% %9.2f%% %9.4f\n', ...
        classNames{c}, ...
        recall(c)*100, ...
        precision(c)*100, ...
        f1(c));
end

fprintf('\n--------------------------------------------\n');
fprintf('CONFUSION MATRIX\n');
fprintf('--------------------------------------------\n');

disp(C);

fprintf('Rows    = Actual\n');
fprintf('Columns = Predicted\n');

fprintf('============================================\n');
fprintf('Smoke test complete.\n');
fprintf('NO training performed.\n');
fprintf('NO model weights modified.\n');
fprintf('============================================\n');

%% Save results
outDir = fullfile( ...
    projectRoot, ...
    'data','analysis','smoke_test');

if ~exist(outDir,'dir')
    mkdir(outDir);
end

%% Save confusion matrix figure
fig = figure( ...
    'Name','DrishtiCare - 100 Image Smoke Test', ...
    'NumberTitle','off');

confusionchart( ...
    trueCat, ...
    predCat, ...
    'RowSummary','row-normalized', ...
    'ColumnSummary','column-normalized');

title('DrishtiCare - 100 Image Balanced Smoke Test');

saveas(fig, ...
    fullfile(outDir,'smoke_test_100_confusion_matrix.png'));

%% Save numerical results
results.accuracy = accuracy;
results.correct = correct;
results.total = 100;
results.confusionMatrix = C;
results.recall = recall;
results.precision = precision;
results.f1 = f1;
results.meanConfidence = meanConfidence;
results.wrongPredictionConfidence = wrongConfidence;
results.selectedFiles = selectedFiles;
results.trueClasses = trueClasses;
results.predClasses = predClasses;
results.confidences = confidences;

save( ...
    fullfile(outDir,'smoke_test_100_results.mat'), ...
    'results');

fprintf('\nResults saved in:\n%s\n\n',outDir);