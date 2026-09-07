function hardNegMineMaCnn()
%HARDNEGMINEMACNN Mine candidate-detector false positives as hard negatives
%   The candidate stage of detectMaCnn floods the CNN with dark-dot patches
%   that are NOT MAs but also NOT in the original clean-background negatives
%   (vessel segments, pigment, noise). This mines those patches from the 44
%   TRAINING images (held-out IDRiD_01..10 stay clean), collects the top-N by
%   P(MA), appends them to the training negatives, and retrains the CNN.
%
%   Outputs: ma_cnn_net.mat (retrained), ma_cnn_metrics.mat, and
%   ma_cnn_hardneg.mat (the mined patches + which images).

projRoot = 'C:\projects\DrishtiCare'; cd(projRoot);
addpath(fullfile(projRoot,'src','lesions'));
dataFile = fullfile(projRoot,'data','analysis','day8','ma_cnn','ma_dataset.mat');
outDir   = fullfile(projRoot,'data','analysis','day8','ma_cnn');
S = load(dataFile);
patches = S.patches; labels = S.labels; imgIdx = S.imgIdx; split = S.split;
origDir = fullfile(projRoot,'data','idrid','A. Segmentation','1. Original Images','a. Training Set');
gtRoot  = fullfile(projRoot,'data','idrid','A. Segmentation','2. All Segmentation Groundtruths','a. Training Set');
tol = 12; PH = 48; pad = PH/2;

% current net (or first trained version)
netData = load(fullfile(outDir,'ma_cnn_net.mat'));
net = netData.net;

% reuse previously mined hard negatives if present to avoid re-mining
hnFile = fullfile(outDir,'ma_cnn_hardneg.mat');
if exist(hnFile,'file')
    H = load(hnFile);
    hardP = H.hardP; nhard = size(hardP,4);
    nAll = numel(H.candScore);
    fprintf('Reusing %d hardest non-GT patches from %s (of %d mined)\n', nhard, hnFile, nAll);
else
% ---- mine candidates from TRAIN images only ----
imgFiles = dir(fullfile(origDir,'*.jpg'));
candPatches = []; candScore = [];
for i = 1:numel(imgFiles)
    numStr = regexp(imgFiles(i).name,'IDRiD_(\d+)\.jpg','tokens','once');
    num2 = str2double(numStr{1});
    if any(num2==S.HOLDOUT), continue; end     % keep held-out clean
    I = im2double(imread(fullfile(origDir,imgFiles(i).name)));
    [H,W,~] = size(I);
    G = I(:,:,2); s = 2; G2 = imresize(G,1/s);
    bh = imclose(G2, strel('disk',2)) - G2;
    thr = quantile(bh(:), 0.98);
    cand = bh > thr;
    cand = bwareaopen(cand,2);
    cand = bwareafilt(cand, [2 round(36/s^2)]);
    cc = bwconncomp(cand); mu = regionprops(cc,'Centroid');
    cent = round(cat(1,mu.Centroid)) .* s;
    % keep candidates not near any GT MA
    gm = imread(fullfile(gtRoot,'1. Microaneurysms',sprintf('IDRiD_%02d_MA.tif',num2)))>0;
    gg = bwconncomp(gm); gtC = zeros(gg.NumObjects,2);
    for b=1:gg.NumObjects
        [yy,xx]=ind2sub(size(gm),gg.PixelIdxList{b}); gtC(b,:)=[mean(xx) mean(yy)];
    end
    crops = zeros(PH,PH,3,size(cent,1),'uint8');
    keepm = false(size(cent,1),1);
    for k=1:size(cent,1)
        cx=cent(k,1); cy=cent(k,2);
        if cx<pad+1 || cx>W-pad || cy<pad+1 || cy>H-pad, continue; end
        if min(sqrt((gtC(:,1)-cx).^2+(gtC(:,2)-cy).^2)) <= tol, continue; end
        rr=cy-pad+1:cy+pad; rr2=cx-pad+1:cx+pad;
        crops(:,:,:,k) = uint8(255*I(rr,rr2,:)); keepm(k)=true;
    end
    crops(:,:,:,~keepm)=[]; 
    n = size(crops,4);
    if n==0, continue; end
    ds = augmentedImageDatastore([PH PH 3], crops, 'OutputSizeMode','resize');
    [~,sc] = classify(net, ds);
    candPatches = cat(4, candPatches, crops); candScore = [candScore; sc(:,1)]; %#ok<AGROW>
    fprintf('IDRiD_%02d: mined %d non-GT candidates\n', num2, n);
end

% ---- top-N hardest ----
nhard = 2409;   % balance with 2409 positives
[~,ord] = sort(candScore,'descend');
nhard = min(nhard, numel(ord));
ord = ord(1:nhard);
hardP = candPatches(:,:,:,ord);
fprintf('Selected %d hardest non-GT patches from %d mined\n', nhard, numel(candScore));
save(fullfile(outDir,'ma_cnn_hardneg.mat'),'hardP','candScore','-v7.3');
end

% ---- append to original dataset negatives, rebuild train/val ----
patchesAll = cat(4, patches, hardP);
labelsAll  = [labels; categorical(ones(size(hardP,4),1),[0 1],{'MA','BG'})];
imgIdxAll  = [imgIdx; (max(imgIdx(S.split=='train')))*ones(size(hardP,4),1)];
splitAll   = [split; categorical(repmat({'train'},size(hardP,4),1))];
fprintf('Appended %d hard negatives (balance kept)\n', size(hardP,4));

% ---- retrain ----
trIdx = find(splitAll=='train'); vlIdx = find(splitAll=='val');
aug = imageDataAugmenter(...
    'RandRotation',[-20 20],'RandXReflection',true,'RandYReflection',true,...
    'RandXTranslation',[-6 6],'RandYTranslation',[-6 6],'RandScale',[0.85 1.15]);
trds = augmentedImageDatastore([48 48 3], patchesAll(:,:,:,trIdx), labelsAll(trIdx), 'DataAugmentation',aug,'OutputSizeMode','resize');
vlds = augmentedImageDatastore([48 48 3], patchesAll(:,:,:,vlIdx), labelsAll(vlIdx), 'OutputSizeMode','resize');
layers = [
    imageInputLayer([48 48 3],'Normalization','none','Name','in')
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
opts = trainingOptions('adam','MaxEpochs',30,'MiniBatchSize',64,'InitialLearnRate',0.001,...
    'LearnRateSchedule','piecewise','LearnRateDropFactor',0.3,'LearnRateDropPeriod',10,...
    'L2Regularization',1e-4,'Shuffle','every-epoch','Verbose',false,'Plots','none',...
    'ValidationData',vlds,'ValidationFrequency',40);
net2 = trainNetwork(trds, layers, opts);

% ---- held-out patch metrics (unchanged set, now with negatives retrained) ----
[Yv,scv] = classify(net2, vlds);
acc = mean(Yv==labelsAll(vlIdx));
scMA = scv(:,1);
[~,ord] = sort(scMA,'descend');
[~,~,~,AUC] = perfcurve(double(labelsAll(vlIdx)=='MA'), scMA, 1);
fprintf('Retrained (hard-neg): patch acc=%.3f AUC=%.3f\n', acc, AUC);
save(fullfile(outDir,'ma_cnn_net.mat'),'net','net2');
fprintf('Saved ma_cnn_net.mat (net=original, net2=hard-neg-retrained)\n');
end