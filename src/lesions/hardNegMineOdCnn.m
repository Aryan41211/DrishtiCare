function hardNegMineOdCnn()
%HARDNEGMINEODCNN Mine hard negatives for the OD CNN and retrain
%   The first OD CNN saturated on bright non-disc structures (exudate
%   plates, bright washes) because training negatives were only "not the
%   disc" and never contained bright false-positive regions or partially
%   offset discs. Following the MA-CNN hard-negative recipe:
%     1. For each of the 44 TRAIN images, run the coarse sliding grid with
%        the existing net and collect false positives: grid cells with
%        P(OD) near the peak but whose centre is >= 1.0*R from GT, plus
%        offset cells at 1.0-2.5R (disc partially in window).
%     2. Cap ~P per image, add to the TRAIN pool (never to val), retrain a
%        second net (net2) on originals+hard negatives.
%   Saves od_cnn_hardneg.mat (mined crop indices) and od_cnn_net.mat with
%   field net2 appended (net = original, net2 = hard-neg retrained).

projRoot  = 'C:\projects\DrishtiCare';
outDir    = fullfile(projRoot,'data','analysis','day8','od_cnn');
dataFile  = fullfile(outDir,'od_dataset.mat');
netFileSt = fullfile(outDir,'od_cnn_net.mat');

S = load(dataFile);
patches = S.patches; labels = S.labels; imgIdx = S.imgIdx; split = S.split;
HOLDOUT = S.HOLDOUT; PH = S.PH;

origDir   = fullfile(projRoot,'data','idrid','A. Segmentation','1. Original Images','a. Training Set');
odMaskDir = fullfile(projRoot,'data','idrid','A. Segmentation','2. All Segmentation Groundtruths','a. Training Set','5. Optic Disc');

T = load(netFileSt); net = T.net;

STRIDE = 48; Sscale = 4; half = PH/2;
P_PER_IMG = 12;

newCrops = zeros(PH,PH,3,0,'uint8');
newImg   = ones(0,1);
for i = 1:54
    num2 = i;
    if any(num2 == HOLDOUT), continue; end       % val images: report-only
    I = imread(fullfile(origDir, sprintf('IDRiD_%02d.jpg', num2)));
    G = im2uint8(imresize(I(:,:,2), 1/Sscale));
    [H,W] = size(G);
    odm = imread(fullfile(odMaskDir, sprintf('IDRiD_%02d_OD.tif', num2))) > 0;
    odmE = imresize(odm, [H W]) > 0.5;
    st = regionprops(odmE,'Centroid','Area');
    [~,k] = max([st.Area]);
    cGT = st(k).Centroid; R = round(sqrt(st(k).Area/pi));

    % coarse grid
    xs = half+1:STRIDE:W-half+1; ys = half+1:STRIDE:H-half+1;
    nx = numel(xs); ny = numel(ys);
    crops = zeros(PH,PH,3,nx*ny,'uint8');
    cidx = 0;
    for j = 1:ny
        y0 = ys(j)-half; y1 = ys(j)+half-1;
        for ii = 1:nx
            x0 = xs(ii)-half; x1 = xs(ii)+half-1;
            cidx = cidx+1;
            crops(:,:,:,cidx) = repmat(G(y0:y1,x0:x1),[1 1 3]);
        end
    end
    ds = augmentedImageDatastore([PH PH 3], crops,'OutputSizeMode','resize');
    [~,sc] = classify(net, ds);
    Pmap = reshape(sc(:,1), [ny nx]);

    % false positives: P high & >1.0*R from GT centre, or offset band
    sel = [];
    for j = 1:ny
        for ii = 1:nx
            c = [xs(ii), ys(j)];
            d = norm(c - cGT);
            if d >= 1.0*R && d <= 2.5*R && Pmap(j,ii) >= 0.5
                sel(end+1) = (j-1)*nx + ii; %#ok<SAGROW>
            end
        end
    end
    % also any very-bright false positive farther out
    for j = 1:ny
        for ii = 1:nx
            c = [xs(ii), ys(j)];
            d = norm(c - cGT);
            if d > 2.5*R && Pmap(j,ii) >= 0.7
                sel(end+1) = (j-1)*nx + ii; %#ok<SAGROW>
            end
        end
    end
    sel = unique(sel);
    [~,ord] = sort(Pmap(sel), 'descend');
    sel = sel(ord(1:min(P_PER_IMG, numel(sel))));
    addCrops = crops(:,:,:,sel(:));
    newCrops = cat(4, newCrops, addCrops);
    newImg   = [newImg; repmat(num2, size(sel(:)))];
    fprintf('%s: %d hard negatives\n', sprintf('IDRiD_%02d', num2), numel(sel));
end

fprintf('TOTAL mined: %d hard negatives\n', size(newCrops,4));
% persist mined crops immediately so a later training timeout does not
% discard the (expensive) sliding-window inference pass
save(fullfile(outDir,'od_cnn_hardneg.mat'), 'newCrops', 'newImg', '-v7.3');
fprintf('Saved mined hard negatives to od_cnn_hardneg.mat\n');

% Append to TRAIN pool only
nOrig = numel(labels);
minedAmt = size(newCrops,4);
cropPool = cat(4, patches, newCrops);
labPool  = [labels; categorical(zeros(minedAmt,1),[0 1],{'OD','BG'})];
imgPool  = [imgIdx; newImg];
splitPool = repmat(categorical({'train'}), nOrig + minedAmt, 1);
for q = 1:minedAmt
    if any(imgPool(nOrig+q) == HOLDOUT), splitPool(nOrig+q) = 'val'; end
end
for q = 1:nOrig
    splitPool(q) = split(q);
end

disp(table(sum(labPool=='OD'), sum(labPool=='BG'), 'VariableNames', {'OD','BG'}));

% ---- retrain net2 (same arch, fresh weights, sequencing optional) ----
trIdx = find(splitPool=='train'); vlIdx = find(splitPool=='val');
aug = imageDataAugmenter(...
    'RandRotation',[-15 15],...
    'RandXReflection',true,...
    'RandYReflection',true,...
    'RandXTranslation',[-20 20],...
    'RandYTranslation',[-20 20],...
    'RandScale',[0.85 1.15]);
trds = augmentedImageDatastore([PH PH 3], cropPool(:,:,:,trIdx), labPool(trIdx), 'DataAugmentation', aug, 'OutputSizeMode','resize');
vlds = augmentedImageDatastore([PH PH 3], cropPool(:,:,:,vlIdx), labPool(vlIdx), 'OutputSizeMode','resize');
layers = [
    imageInputLayer([PH PH 3],'Normalization','none','Name','in')
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
    'MiniBatchSize',32,...
    'InitialLearnRate',0.001,...
    'LearnRateSchedule','piecewise',...
    'LearnRateDropFactor',0.3,...
    'LearnRateDropPeriod',5,...
    'L2Regularization',1e-4,...
    'Shuffle','every-epoch',...
    'Verbose',true,...
    'Plots','none',...
    'ValidationData',vlds,...
    'ValidationFrequency',30);
net2 = trainNetwork(trds, layers, opts);

% ---- evaluate net2 on ORIGINAL clean val patches ----
[Yval,scoreVal] = classify(net2, vlds);
acc = mean(Yval == labPool(vlIdx));
fprintf('net2 held-out clean-val accuracy: %.3f\n', acc);
scoreOD = scoreVal(:,1);
[~,ord]=sort(scoreOD,'descend');
[X,Y,T,AUC] = perfcurve(double(labPool(vlIdx)=='OD'), scoreOD, 1);
fprintf('net2 clean-val AUC: %.3f\n', AUC);

netFile = fullfile(outDir,'od_cnn_net.mat');
save(netFile, 'net', 'net2', '-v7.3');   % net=original, net2=hard-neg retrained
fprintf('Done.\n');
end