%% runFinalModelEvaluation.m
% DrishtiCare - Final 5-Class Model Evaluation
% Safe one-image-at-a-time evaluation
% NO TRAINING / NO RETRAINING

clear; clc;

fprintf('\n============================================\n');
fprintf(' DRISHTICARE - FINAL MODEL EVALUATION\n');
fprintf('============================================\n');

%% Setup
projectRoot = 'C:\projects\DrishtiCare';
cd(projectRoot);
addpath(genpath(fullfile(projectRoot,'src')));

%% Load model
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

fprintf('\nModel loaded successfully.\n');

%% Validation dataset
valRoot = fullfile( ...
    projectRoot, ...
    'data','splits','val');

imds = imageDatastore( ...
    valRoot, ...
    'IncludeSubfolders',true, ...
    'LabelSource','foldernames');

N = numel(imds.Files);

fprintf('Validation images: %d\n',N);
fprintf('\nRunning safe image-by-image inference...\n');

%% Storage
YPred = categorical(strings(N,1));
scoresAll = zeros(N,5);

valid = false(N,1);

%% Evaluate one image at a time
for i = 1:N

    try

        % Read image directly
        img = readimage(imds,i);

        % Create temporary one-image datastore
        tempDS = imageDatastore({imds.Files{i}});

        % Same resizing pipeline used by Day-7 evaluation
        tempAug = augmentedImageDatastore( ...
            [224 224 3], ...
            tempDS);

        % Prediction
        [pred,scores] = classify(net,tempAug);

        YPred(i) = pred;
        scoresAll(i,:) = scores;
        valid(i) = true;

    catch ME

        fprintf('\nWARNING: Image %d failed\n',i);
        fprintf('File: %s\n',imds.Files{i});
        fprintf('Error: %s\n',ME.message);

        continue;

    end

    if mod(i,25) == 0
        fprintf('Processed %d / %d\n',i,N);
    end

end

%% Remove failed images
validIdx = find(valid);

YTrue = imds.Labels(validIdx);
YPredValid = YPred(validIdx);
scoresValid = scoresAll(validIdx,:);

fprintf('\n============================================\n');
fprintf('Inference finished.\n');
fprintf('Successful: %d / %d\n',numel(validIdx),N);
fprintf('Failed:     %d\n',sum(~valid));
fprintf('============================================\n');

%% Class names
classNames = categories(YTrue);
numClasses = numel(classNames);

%% Accuracy
accuracy = mean(YPredValid == YTrue);

%% Confusion matrix
C = confusionmat( ...
    YTrue, ...
    YPredValid, ...
    'Order',categorical(classNames));

%% Per-class metrics
recall = zeros(numClasses,1);
precision = zeros(numClasses,1);
f1 = zeros(numClasses,1);

for c = 1:numClasses

    TP = C(c,c);
    FN = sum(C(c,:)) - TP;
    FP = sum(C(:,c)) - TP;

    if TP + FN > 0
        recall(c) = TP/(TP+FN);
    end

    if TP + FP > 0
        precision(c) = TP/(TP+FP);
    end

    if precision(c)+recall(c) > 0
        f1(c) = ...
            2*precision(c)*recall(c) / ...
            (precision(c)+recall(c));
    end
end

macroF1 = mean(f1);

%% QWK
trueNum = double(YTrue);
predNum = double(YPredValid);

try

    qwk = quadraticWeightedKappa( ...
        trueNum,predNum);

catch

    % Manual QWK
    O = C;
    total = sum(O(:));

    rowSum = sum(O,2);
    colSum = sum(O,1);

    E = rowSum * colSum / total;

    W = zeros(numClasses);

    for i = 1:numClasses
        for j = 1:numClasses
            W(i,j) = ((i-j)^2) / ...
                ((numClasses-1)^2);
        end
    end

    qwk = 1 - ...
        sum(sum(W.*O)) / ...
        sum(sum(W.*E));

end

%% Binary referral evaluation
%
% class_0 + class_1 = NON-REFERABLE
% class_2 + class_3 + class_4 = REFERABLE

trueBinary = ismember( ...
    string(YTrue), ...
    ["class_2","class_3","class_4"]);

predBinary = ismember( ...
    string(YPredValid), ...
    ["class_2","class_3","class_4"]);

TP = sum(trueBinary & predBinary);
TN = sum(~trueBinary & ~predBinary);
FP = sum(~trueBinary & predBinary);
FN = sum(trueBinary & ~predBinary);

binaryAccuracy = ...
    (TP+TN)/(TP+TN+FP+FN);

sensitivity = TP/(TP+FN);
specificity = TN/(TN+FP);
precisionBinary = TP/(TP+FP);

f1Binary = ...
    2*precisionBinary*sensitivity / ...
    (precisionBinary+sensitivity);

%% Print final results
fprintf('\n============================================\n');
fprintf('       DRISHTICARE FINAL RESULTS\n');
fprintf('============================================\n');

fprintf('\n5-CLASS DR GRADING\n');
fprintf('--------------------------------------------\n');
fprintf('Accuracy : %.2f%%\n',accuracy*100);
fprintf('Macro F1 : %.4f\n',macroF1);
fprintf('QWK      : %.4f\n',qwk);

fprintf('\n--------------------------------------------\n');
fprintf('PER-CLASS METRICS\n');
fprintf('--------------------------------------------\n');

fprintf('%-15s %10s %10s %10s\n', ...
    'Class','Recall','Precision','F1');

for c = 1:numClasses

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

fprintf('\n============================================\n');
fprintf('       BINARY REFERRAL RESULTS\n');
fprintf('============================================\n');

fprintf('Accuracy    : %.2f%%\n',binaryAccuracy*100);
fprintf('Sensitivity : %.2f%%\n',sensitivity*100);
fprintf('Specificity : %.2f%%\n',specificity*100);
fprintf('Precision   : %.2f%%\n',precisionBinary*100);
fprintf('F1          : %.4f\n',f1Binary);

fprintf('\nTP=%d  FP=%d  FN=%d  TN=%d\n', ...
    TP,FP,FN,TN);

fprintf('\n============================================\n');
fprintf('Evaluation complete.\n');
fprintf('NO TRAINING performed.\n');
fprintf('NO MODEL WEIGHTS modified.\n');
fprintf('============================================\n');