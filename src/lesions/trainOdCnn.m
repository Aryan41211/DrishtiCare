function trainOdCnn()
%TRAINODCNN Train small CNN OD-vs-background patch classifier (IDRiD)
%   192x192 green-channel patches, 4 conv blocks -> 2 classes (OD, BG).
%   Train on 44 IDRiD training images, hold out IDRiD_01..10.
%   Saves net + metrics to data/analysis/day8/od_cnn/.

projRoot = 'C:\projects\DrishtiCare';
dataFile = fullfile(projRoot,'data','analysis','day8','od_cnn','od_dataset.mat');
outDir   = fullfile(projRoot,'data','analysis','day8','od_cnn');
S = load(dataFile);
patches = S.patches; labels = S.labels; imgIdx = S.imgIdx; split = S.split;
n = numel(labels);
trIdx = find(split=='train'); vlIdx = find(split=='val');

inputSz = 192;    % patches are stored at 192, feed directly
aug = imageDataAugmenter(...
    'RandRotation',[-15 15],...
    'RandXReflection',true,...
    'RandYReflection',true,...
    'RandXTranslation',[-20 20],...
    'RandYTranslation',[-20 20],...
    'RandScale',[0.85 1.15]);
trds = augmentedImageDatastore([inputSz inputSz 3], patches(:,:,:,trIdx), labels(trIdx), 'DataAugmentation', aug, 'OutputSizeMode','resize');
vlds = augmentedImageDatastore([inputSz inputSz 3], patches(:,:,:,vlIdx), labels(vlIdx), 'OutputSizeMode','resize');

% ---- CNN: same skeleton as MA-CNN, slightly shallower ----
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
    'MaxEpochs',20,...
    'MiniBatchSize',32,...
    'InitialLearnRate',0.001,...
    'LearnRateSchedule','piecewise',...
    'LearnRateDropFactor',0.3,...
    'LearnRateDropPeriod',7,...
    'L2Regularization',1e-4,...
    'Shuffle','every-epoch',...
    'Verbose',true,...
    'Plots','none',...
    'ValidationData',vlds,...
    'ValidationFrequency',30);

net = trainNetwork(trds, layers, opts);

% ---- evaluate on held-out val patches ----
[Yval,scoreVal] = classify(net, vlds);
acc = mean(Yval == labels(vlIdx));
fprintf('Held-out patch accuracy: %.3f (%d/%d)\n', acc, sum(Yval==labels(vlIdx)), numel(vlIdx));
scoreOD = scoreVal(:,1);                  % P(class=OD)  Classes=['OD','BG']
[~,ord] = sort(scoreOD,'descend');
[X,Y,T,AUC] = perfcurve(double(labels(vlIdx)=='OD'), scoreOD, 1);
fprintf('Val AUC (OD vs BG): %.3f\n', AUC);
prec = cumsum(double(labels(vlIdx(ord))=='OD'))./(1:numel(vlIdx))';
rec  = cumsum(double(labels(vlIdx(ord))=='OD'))./sum(labels(vlIdx)=='OD');
fprintf('Val precision@recall>=0.9: %.3f\n', max(prec(rec>=0.9)));
fprintf('Val recall@precision>=0.9: %.3f\n', max(rec(prec>=0.9)));
save(fullfile(outDir,'od_cnn_net.mat'),'net');
save(fullfile(outDir,'od_cnn_metrics.mat'),'acc','AUC','X','Y','T','-v7.3');
fprintf('Saved net + metrics to %s\n', outDir);
end