function buildOdDataset()
%BUILDODDATASET Build optic-disc patch dataset from IDRiD OD masks
%   54 IDRiD *training-set* images (test set UNTOUCHED). For each image:
%     POSITIVES: P patches centred near the GT OD centre (jittered so the
%                CNN learns the disc appearance, not the exact pixel).
%     NEGATIVES: P patches centred well away from the OD (>=2.5*R), inside
%                the retina, so the CNN learns what is NOT the disc.
%   Working scale s=4 (IDRiD 4288x2848 -> 1072x712). Patch = 192px @s4
%   (~770px full-res, 1.5x the ~520px disc diameter for context).
%   Image-holdout split: IDRiD_01..10 are VAL (detector eval), rest TRAIN,
%   matching the MA-CNN convention.
%
%   Saves data/analysis/day8/od_cnn/od_dataset.mat
%   patches (uint8 192x192x3xN, green-channel replicated), labels
%   categorical {'OD','BG'}, imgIdx (N), split ('train'|'val'), PH.

projRoot  = 'C:\projects\DrishtiCare';
origDir   = fullfile(projRoot,'data','idrid','A. Segmentation','1. Original Images','a. Training Set');
odMaskDir = fullfile(projRoot,'data','idrid','A. Segmentation','2. All Segmentation Groundtruths','a. Training Set','5. Optic Disc');
outDir    = fullfile(projRoot,'data','analysis','day8','od_cnn');
if ~exist(outDir,'dir'), mkdir(outDir); end

S = 4;                    % working scale (same as classical detector)
PH = 192;                 % patch size @s4
HOLDOUT = 1:10;           % IDRiD_01..10 held out as VAL
P = 24;                   % positives AND negatives per image
SEED = 7;

f = dir(fullfile(origDir,'*.jpg'));
nIm = numel(f);
assert(nIm == 54, 'Expected 54 IDRiD training images, found %d', nIm);

outPatches = zeros(PH,PH,3,0,'uint8');
outLabels  = categorical(zeros(0,1), [0 1], {'OD','BG'});
outImg     = ones(0,1);
outSplit   = cell(0,1);

rng(SEED);
for i = 1:nIm
    tok = regexp(f(i).name, 'IDRiD_(\d+)\.jpg', 'tokens', 'once');
    num2 = str2double(tok{1});
    I = imread(fullfile(origDir, f(i).name));
    % green channel: bright disc vs background; vessels dark. Replicate to 3ch.
    green = im2uint8(I(:,:,2));
    G = imresize(green, 1/S);
    [H,W] = size(G);

    odm = imread(fullfile(odMaskDir, sprintf('IDRiD_%02d_OD.tif', num2))) > 0;
    odmE = imresize(odm, [H W]) > 0.5;
    st = regionprops(odmE, 'Centroid', 'Area');
    [~,big] = max([st.Area]);
    cGT = st(big).Centroid;                 % [x y] @s4
    R = round(sqrt(st(big).Area/pi));       % radius @s4

    if any(num2 == HOLDOUT)
        split = 'val';
    else
        split = 'train';
    end

    % ---- positives: jittered around GT centre ----------------------------
    posC = zeros(P,2);
    for p = 1:P
        jx = round((rand-0.5) * 0.5 * R);   % jitter within +-0.25 R
        jy = round((rand-0.5) * 0.5 * R);
        posC(p,:) = [cGT(1)+jx, cGT(2)+jy];
    end
    posPat = extractCrops(G, posC, PH);

    % ---- negatives: >=2.5*R away from OD, inside retina, no disc overlap -
    nonDisc = ~imdilate(odmE, strel('disk', round(2.5*R)));
    negC = zeros(P,2); found = 0; tries = 0;
    while found < P && tries < 200*P
        tries = tries + 1;
        cx = randi([PH/2+1, W-PH/2]); cy = randi([PH/2+1, H-PH/2]);
        if nonDisc(cy,cx)
            found = found + 1; negC(found,:) = [cx cy];
        end
    end
    negC = negC(1:found,:);
    negPat = extractCrops(G, negC, PH);

    outPatches = cat(4, outPatches, posPat, negPat);
    outLabels  = [outLabels; categorical(zeros(P,1),[0 1],{'OD','BG'}); ...
                             categorical(ones(found,1),[0 1],{'OD','BG'})];
    outImg = [outImg; repmat(num2, P+found, 1)];
    for q = 1:(P+found), outSplit{end+1,1} = split; end
    fprintf('%s (%d): pos=%d neg=%d split=%s R@4=%d\n', ...
        f(i).name, num2, P, found, split, R);
end

split = categorical(outSplit);
% shuffle
rng(SEED);
order = randperm(numel(outLabels));
patches = outPatches(:,:,:,order);
labels  = outLabels(order);
imgIdx  = outImg(order);
split   = split(order);

fprintf('\nTOTAL: %d pos, %d neg => %d patches, %d images\n', ...
    sum(labels=='OD'), sum(labels=='BG'), numel(labels), nIm);
save(fullfile(outDir,'od_dataset.mat'),'patches','labels','imgIdx','split',...
     'HOLDOUT','PH','S','-v7.3');
fprintf('Saved %s\n', fullfile(outDir,'od_dataset.mat'));
end

function C = extractCrops(G, cxy, PH)
    H = size(G,1); W = size(G,2); n = size(cxy,1);
    half = PH/2;                 % half window, so half*2+? use exact PH span
    C = zeros(PH,PH,3,n,'uint8');
    for k = 1:n
        cx = round(cxy(k,1)); cy = round(cxy(k,2));
        x0 = max(1,cx-half); x1 = min(W,cx+half-1);
        y0 = max(1,cy-half); y1 = min(H,cy+half-1);
        crop = G(y0:y1, x0:x1);
        padL = x1-x0+1; padT = y1-y0+1;
        if padL < PH || padT < PH
            tmp = zeros(PH,PH,'uint8');
            tmp(1:padT, 1:padL) = crop;
            crop = tmp;
        end
        C(:,:,:,k) = repmat(crop, [1 1 3]);
    end
end