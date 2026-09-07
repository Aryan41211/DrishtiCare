function trainMaCnn()
%TRAINMACNN Train small CNN MA-vs-background patch classifier (IDRiD)
%   Small (2 conv-block) CNN on 48x48 RGB patches. Train on 44 IDRiD
%   images, hold out IDRiD_01..10 for image-level patch evaluation.
%   Uses resizing->40x40 input + augmentation (rotation/reflection/scale/
%   translation) to generalise. Saves net + metrics + val ROC/PR data.
%   Script/CmdLine path: also used by the detector (detectMaCnn).

projRoot = 'C:\projects\DrishtiCare';
dataFile = fullfile(projRoot,'data','analysis','day8','ma_cnn','ma_dataset.mat');
outDir   = fullfile(projRoot,'data','analysis','day8','ma_cnn');
S = load(dataFile);
patches = S.patches; labels = S.labels; imgIdx = S.imgIdx; split = S.split;
n = numel(labels);
trIdx = find(split=='train'); vlIdx = find(split=='val');

% ---- input pipeline: resize patches to 40x40? resize to 48 first then
% augmentedImageDatastore handles augmentation only; we use 48 direct.
inputSz = 48;
aug = imageDataAugmenter(...
    'RandRotation',[-20 20],...
    'RandXReflection',true,...
    'RandYReflection',true,...
    'RandXTranslation',[-6 6],...
    'RandYTranslation',[-6 6],...
    'RandScale',[0.85 1.15]);
trds = augmentedImageDatastore([inputSz inputSz 3], patches(:,:,:,trIdx), labels(trIdx), 'DataAugmentation', aug, 'OutputSizeMode','resize');
vlds = augmentedImageDatastore([inputSz inputSz 3], patches(:,:,:,vlIdx), labels(vlIdx), 'OutputSizeMode','resize');

% ---- CNN (small, 2 conv blocks) ----
layers = [
    imageInputLayer([inputSz inputSz 3],'Normalization','none','Name','in')
    convolution2dLayer(3,16,'Padding','same','Name','c1')
    batchNormalizationLayer('Name','bn1')
    reluLayer('Name','r1')
    maxPooling2dLayer(2,'Stride',2,'Name','p1')
    convolution2dLayer(3,32,'Padding','same','Name','c2')
    batchNormalizationLayer('Name','bn2')
    reluLayer('Name','r2')
    maxPooling2dLayer(2,'Stride',2,'Name','p2')
    convolution2dLayer(3,64,'Padding','same','Name','c3')
    batchNormalizationLayer('Name','bn3')
    reluLayer('Name','r3')
    maxPooling2dLayer(2,'Stride',2,'Name','p3')
    convolution2dLayer(3,128,'Padding','same','Name','c4')
    batchNormalizationLayer('Name','bn4')
    reluLayer('Name','r4')
    dropoutLayer(0.3,'Name','dp')
    globalAveragePooling2dLayer('Name','gap')
    fullyConnectedLayer(2,'Name','fc')
    softmaxLayer('Name','sm')
    classificationLayer('Name','out')];
analyzeNetwork(layers);

opts = trainingOptions('adam',...
    'MaxEpochs',30,...
    'MiniBatchSize',64,...
    'InitialLearnRate',0.001,...
    'LearnRateSchedule','piecewise',...
    'LearnRateDropFactor',0.3,...
    'LearnRateDropPeriod',10,...
    'L2Regularization',1e-4,...
    'Shuffle','every-epoch',...
    'Verbose',false,...
    'Plots','none',...
    'ValidationData',vlds,...
    'ValidationFrequency',40);

net = trainNetwork(trds, layers, opts);

% ---- evaluate ----
[Yval,scoreVal] = classify(net, vlds);
acc = mean(Yval == labels(vlIdx));
fprintf('Held-out image patch accuracy: %.3f  (%d/%d)\n', acc, sum(Yval==labels(vlIdx)), numel(vlIdx));
scoreMA = scoreVal(:,1);                  % P(class=MA)  (Classes=['MA','BG'])
[~,ord] = sort(scoreMA,'descend');
[X,Y,T,AUC] = perfcurve(double(labels(vlIdx)=='MA'), scoreMA, 1);
fprintf('Val AUC (MA vs BG): %.3f\n', AUC);
prec = cumsum(double(labels(vlIdx(ord))=='MA'))./ (1:numel(vlIdx))';
rec  = cumsum(double(labels(vlIdx(ord))=='MA'))./sum(labels(vlIdx)=='MA');
fprintf('Val precision@recall>=0.5: %.3f\n', max(prec(rec>=0.5)));
fprintf('Val recall@precision>=0.5: %.3f\n', max(rec(prec>=0.5)));
save(fullfile(outDir,'ma_cnn_net.mat'),'net');
save(fullfile(outDir,'ma_cnn_metrics.mat'),'acc','AUC','X','Y','T','-v7.3');
fprintf('Saved net + metrics to %s\n', outDir);
end