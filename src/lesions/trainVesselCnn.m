function trainVesselCnn()
%TRAINVESSELCNN Train small CNN VESSEL-vs-background patch classifier (DRIVE).
%   Small (4 conv-block 16/32/64/128) CNN on 64x64 green-channel patches.
%   Trained on 16 DRIVE training images (21..36), images 37..40 held OUT.
%   Uses augmentation (rotation/reflection/scale/translation) and reports the
%   held-out patch accuracy + ROC-AUC. Saves data/analysis/day8/vessel/
%   vessel_cnn_net.mat (field 'net') + vessel_cnn_metrics.mat.
%   This is the house 4-block design from trainMaCnn/trainFoveaCnn, applied to
%   a 64x64 input so the receptive field covers ~2 vessel diameters.

projRoot = 'C:\projects\DrishtiCare';
dataFile = fullfile(projRoot,'data','analysis','day8','vessel','vessel_dataset.mat');
outDir   = fullfile(projRoot,'data','analysis','day8','vessel');
S = load(dataFile);
patches = S.patches; labels = S.labels; imgIdx = S.imgIdx; split = S.split;
n = numel(labels);
trIdx = find(split=='train'); vlIdx = find(split=='val');

inputSz = 64;
aug = imageDataAugmenter(...
    'RandRotation',[-15 15],...
    'RandXReflection',true,...
    'RandYReflection',true,...
    'RandXTranslation',[-4 4],...
    'RandYTranslation',[-4 4]);
trds = augmentedImageDatastore([inputSz inputSz 3], patches(:,:,:,trIdx), labels(trIdx), ...
    'DataAugmentation', aug, 'OutputSizeMode','resize');
vlds = augmentedImageDatastore([inputSz inputSz 3], patches(:,:,:,vlIdx), labels(vlIdx), ...
    'OutputSizeMode','resize');

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

opts = trainingOptions('adam',...
    'MaxEpochs',15,...
    'MiniBatchSize',128,...
    'InitialLearnRate',0.001,...
    'LearnRateSchedule','piecewise',...
    'LearnRateDropFactor',0.3,...
    'LearnRateDropPeriod',5,...
    'L2Regularization',1e-4,...
    'Shuffle','every-epoch',...
    'Verbose',false,...
    'Plots','none',...
    'ValidationData',vlds,...
    'ValidationFrequency',30,...
    'OutputFcn',@(info) saveVesselNet(info, outDir));

net = trainNetwork(trds, layers, opts);

[Yval,scoreVal] = classify(net, vlds);
acc = mean(Yval == labels(vlIdx));
fprintf('Held-out patch accuracy: %.3f  (%d/%d)\n', acc, sum(Yval==labels(vlIdx)), numel(vlIdx));
scoreV = scoreVal(:,1);                  % P(class=VESSEL)  (Classes=['VESSEL','BG'])
[~,ord] = sort(scoreV,'descend');
[X,Y,T,AUC] = perfcurve(double(labels(vlIdx)=='VESSEL'), scoreV, 1);
fprintf('Val AUC (VESSEL vs BG): %.3f\n', AUC);
prec = cumsum(double(labels(vlIdx(ord))=='VESSEL'))./(1:numel(vlIdx))';
rec  = cumsum(double(labels(vlIdx(ord))=='VESSEL'))./sum(labels(vlIdx)=='VESSEL');
fprintf('Val precision@recall>=0.5: %.3f\n', max(prec(rec>=0.5)));
fprintf('Val recall@precision>=0.5: %.3f\n', max(rec(prec>=0.5)));
save(fullfile(outDir,'vessel_cnn_net.mat'),'net');
save(fullfile(outDir,'vessel_cnn_metrics.mat'),'acc','AUC','X','Y','T','-v7.3');
fprintf('Saved net + metrics to %s\n', outDir);
end

function stop = saveVesselNet(info, outDir)
stop = false;
if strcmp(info.State, 'done')
    try
        net = info.Network;
        save(fullfile(outDir,'vessel_cnn_net.mat'), 'net', '-v7.3');
    catch
    end
end
end