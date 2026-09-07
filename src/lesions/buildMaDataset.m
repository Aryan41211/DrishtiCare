function buildMaDataset()
%BUILDMADATASET Build MA positive + background-negative patches from IDRiD
%   2412 MA blobs across the 54 IDRiD train images (measured). Patches are
%   48x48 full-resolution RGB crops centred on each MA blob; negatives are
%   sampled from regions free of ANY lesion annotation (MA/HE/EX dilated)
%   and away from the optic disc.
%
%   Image-holdout split: images IDRiD_01..10 are held OUT for detector
%   evaluation (same set used for the classical validation), remaining 44
%   images are the training pool. Saves data/analysis/day8/ma_cnn/ma_dataset.mat
%
%   Outputs: patches (uint8 48x48x3xN), labels (categorical), imageIdx (N), split ('train'|'val')

projRoot = 'C:\projects\DrishtiCare';
origDir = fullfile(projRoot,'data','idrid','A. Segmentation','1. Original Images','a. Training Set');
gtRoot  = fullfile(projRoot,'data','idrid','A. Segmentation','2. All Segmentation Groundtruths','a. Training Set');
outDir  = fullfile(projRoot,'data','analysis','day8','ma_cnn');
if ~exist(outDir,'dir'), mkdir(outDir); end

PH = 48;                 % patch size (px, full-res)
HOLDOUT = 1:10;          % images IDRiD_01..10 held out for detector eval
pad = PH/2;

maFold  = fullfile(gtRoot,'1. Microaneurysms');
heFold  = fullfile(gtRoot,'2. Haemorrhages');
exFold  = fullfile(gtRoot,'3. Hard Exudates');
odFold  = fullfile(gtRoot,'5. Optic Disc');

f = dir(fullfile(origDir,'*.jpg'));
nIm = numel(f);
posPatches = []; posLabels = []; negPatches = []; negLabels = [];
posImg = []; negImg = [];
for i = 1:nIm
    numStr = regexp(f(i).name,'IDRiD_(\d+)\.jpg','tokens','once');
    num2 = str2double(numStr{1});
    I = im2uint8(imread(fullfile(origDir,f(i).name)));
    [H,W,~] = size(I);
    maM  = readMask(fullfile(maFold,sprintf('IDRiD_%02d_MA.tif',num2)));
    heM  = readMask(fullfile(heFold,sprintf('IDRiD_%02d_HE.tif',num2)));
    exM  = readMask(fullfile(exFold,sprintf('IDRiD_%02d_EX.tif',num2)));
    odM  = readMask(fullfile(odFold,sprintf('IDRiD_%02d_OD.tif',num2)));
    cc = bwconncomp(maM);
    np = cc.NumObjects;
    seK = strel('disk',8);
    nonLesion = ~imdilate(maM|heM|exM|odM, seK);
    if i<=length(HOLDOUT)
        split = 'val';
    else
        split = 'train';
    end
    % positives: centre patch on each MA blob centroid (skip border-touching)
    kp = 0; sel = zeros(np,1);
    cxy = zeros(np,2);
    for b = 1:np
        [yy,xx] = ind2sub(size(maM), cc.PixelIdxList{b});
        cx = mean(xx); cy = mean(yy);
        if cx<pad+1 || cx>W-pad || cy<pad+1 || cy>H-pad, continue; end
        kp = kp+1; sel(kp)=b; cxy(kp,:)=[cx cy];
    end
    posPatches = cat(4, posPatches, extractPatches(I, cxy(1:kp,:), PH)); %#ok<AGROW>
    posLabels  = [posLabels; zeros(kp,1)]; %#ok<AGROW>
    posImg     = [posImg; repmat(num2,kp,1)]; %#ok<AGROW>
    % negatives: balanced count = kp positive patches, random lesion-free
    if kp>0
        ncand = kp; negC = zeros(ncand,2); found = 0; tries = 0;
        while found<ncand && tries<50*ncand
            tries = tries+1;
            cx = randi([pad+1 W-pad]); cy = randi([pad+1 H-pad]);
            % require the whole patch interior lesion-free
            rr = max(cy-pad,1):min(cy+pad,H); rr2 = max(cx-pad,1):min(cx+pad,W);
            if all(nonLesion(rr,rr2),'all')
                found = found+1; negC(found,:) = [cx cy];
            end
        end
        negC = negC(1:found,:);
        negPatches = cat(4, negPatches, extractPatches(I, negC, PH)); %#ok<AGROW>
        negLabels  = [negLabels; ones(found,1)]; %#ok<AGROW>
        negImg     = [negImg; repmat(num2,found,1)]; %#ok<AGROW>
    end
    fprintf('%s (%d):  pos=%d  neg=%d  split=%s\n', f(i).name, np, kp, size(negPatches,4), split);
end

patches = cat(4, posPatches, negPatches);
labels  = categorical([posLabels; negLabels], [0 1], {'MA','BG'});
imgIdx  = [posImg; negImg];
split   = repmat({'train'}, size(imgIdx));
for k = 1:numel(imgIdx)
    if any(imgIdx(k)==HOLDOUT), split{k} = 'val'; end
end
split = categorical(split);

fprintf('\nTOTAL: %d positives, %d negatives, %d images\n', numel(posLabels), numel(negLabels), nIm);
% reorder per-class -> shuffle once (CNN sees augmentation)
rng(42);
order = randperm(size(patches,4));
save(fullfile(outDir,'ma_dataset.mat'),'patches','labels','imgIdx','split',...
     'HOLDOUT','PH','-v7.3');
fprintf('Saved %s\n', fullfile(outDir,'ma_dataset.mat'));
end

function P = extractPatches(I, cxy, PH)
    H = size(I,1); W = size(I,2); n = size(cxy,1);
    pad = PH/2;
    P = zeros(PH,PH,3,n,'uint8');
    for k = 1:n
        cx = round(cxy(k,1)); cy = round(cxy(k,2));
        rr = cy-pad+1:cy+pad; rr2 = cx-pad+1:cx+pad;
        P(:,:,:,k) = I(rr,rr2,:);
    end
end

function M = readMask(p)
    if exist(p,'file')
        M = imread(p)>0;
    else
        M = zeros(2848,4288)>0;   % treat missing lesion mask as absent (e.g. IDRiD_43 HE)
    end
end