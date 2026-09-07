function buildFoveaDataset()
%BUILDFOVEADATASET Build fovea patch dataset from IDRiD fovea GT CSV
%   54 IDRiD *training-set* images (test set UNTOUCHED). For each image:
%     POSITIVES: P patches centred at the fovea GT centre (small jitter, so
%                the CNN learns the foveal pit, not an exact pixel).
%     NEGATIVES: P patches centred well away from BOTH the fovea AND the
%                optic disc, inside the retina, so the CNN learns what is
%                NOT the fovea.
%   Working scale s=4 (IDRiD 4288x2848 -> 1072x712). Patch = 192px @s4.
%   Image-holdout split: IDRiD_01..10 are VAL (detector eval), rest TRAIN,
%   matching the MA-CNN / OD-CNN convention.
%   Fovea radius guess: R = round(0.030*min(H,W)) full-res (~128px), a
%   modest size (~0.25x the disc) so positives are tightly anchored.
%
%   Saves data/analysis/day8/fovea_cnn/fovea_dataset.mat
%   patches (uint8 192x192x3xN, green-channel replicated), labels
%   categorical {'FOV','BG'}, imgIdx (N), split ('train'|'val'), PH,
%   gtCenters (54x2 full-res x/y fovea GT).

projRoot  = 'C:\projects\DrishtiCare';
origDir   = fullfile(projRoot,'data','idrid','A. Segmentation','1. Original Images','a. Training Set');
odMaskDir = fullfile(projRoot,'data','idrid','A. Segmentation','2. All Segmentation Groundtruths','a. Training Set','5. Optic Disc');
foveaCsv  = fullfile(projRoot,'data','idrid','C. Localization','2. Groundtruths','2. Fovea Center Location','IDRiD_Fovea_Center_Training Set_Markups.csv');
outDir    = fullfile(projRoot,'data','analysis','day8','fovea_cnn');
if ~exist(outDir,'dir'), mkdir(outDir); end

S = 4;                    % working scale (same as classical detector)
PH = 192;                 % patch size @s4
HOLDOUT = 1:10;           % IDRiD_01..10 held out as VAL
P = 24;                   % positives AND negatives per image
SEED = 7;

f = dir(fullfile(origDir,'*.jpg'));
nIm = numel(f);
assert(nIm == 54, 'Expected 54 IDRiD training images, found %d', nIm);

% ---- parse fovea GT CSV: header, then IDRiD_###, x, y ----
fid = fopen(foveaCsv,'r');
hdr = fgetl(fid);                    % skip header
gtCenters = nan(nIm,2);
gtIdx     = zeros(nIm,1);
ln = 0;
while ~feof(fid)
    t = fgetl(fid);
    if isempty(t), continue; end
    parts = strsplit(strtrim(t), ',');
    if isempty(parts{1}), continue; end
    tok = regexp(parts{1}, 'IDRiD_(\d+)', 'tokens', 'once');
    if isempty(tok), continue; end
    num2 = str2double(tok{1});
    x = str2double(parts{2}); y = str2double(parts{3});
    if num2 >= 1 && num2 <= 54
        gtCenters(num2,:) = [x y];
        gtIdx(num2) = num2;
    end
    ln = ln + 1;
end
fclose(fid);
assert(all(isfinite(gtCenters(:))), 'Fovea GT parse incomplete (n=%d)', ln);
fprintf('Loaded fovea GT for IDRiD_001: x=%d y=%d (expect ~[1494 1970])\n', ...
    gtCenters(1,1), gtCenters(1,2));
assert(abs(gtCenters(1,1)-1494)<=2 && abs(gtCenters(1,2)-1970)<=2, ...
    'Unexpected fovea GT for IDRiD_001: [%g %g]', gtCenters(1,1), gtCenters(1,2));

outPatches = zeros(PH,PH,3,0,'uint8');
outLabels  = categorical(zeros(0,1), [0 1], {'FOV','BG'});
outImg     = ones(0,1);
outSplit   = cell(0,1);

rng(SEED);
for i = 1:nIm
    tok = regexp(f(i).name, 'IDRiD_(\d+)\.jpg', 'tokens', 'once');
    num2 = str2double(tok{1});
    I = imread(fullfile(origDir, f(i).name));
    green = im2uint8(I(:,:,2));
    G = imresize(green, 1/S);
    [H,W] = size(G);

    % fovea GT centre @s4
    cFo = [gtCenters(num2,1)/S, gtCenters(num2,2)/S];
    % fovea radius @s4 (full-res R -> /S)
    Rf_full = round(0.030 * min(size(I,1), size(I,2)));
    Rf = max(8, round(Rf_full / S));

    % optic disc centre/radius @s4 (for negative exclusion, as in buildOdDataset)
    odm = imread(fullfile(odMaskDir, sprintf('IDRiD_%02d_OD.tif', num2))) > 0;
    odmE = imresize(odm, [H W]) > 0.5;
    st = regionprops(odmE, 'Centroid', 'Area');
    [~,big] = max([st.Area]);
    cOd = st(big).Centroid;
    Rd  = round(sqrt(st(big).Area/pi));

    % retina foreground @s4 (for inside-retina negative placement)
    [rm, rmValid] = createRetinalMask(imresize(I, 1/S));
    if rmValid
        fg = rm;
    else
        fg = true(H,W);              % fallback: whole frame
    end

    if any(num2 == HOLDOUT)
        split = 'val';
    else
        split = 'train';
    end

    % ---- positives: jittered around fovea GT -----------------------------
    posC = zeros(P,2);
    for p = 1:P
        jx = round((rand-0.5) * 0.5 * Rf);   % jitter within +-0.25 Rf
        jy = round((rand-0.5) * 0.5 * Rf);
        posC(p,:) = [cFo(1)+jx, cFo(2)+jy];
    end
    posPat = extractCrops(G, posC, PH);

    % ---- negatives: away from fovea AND disc, inside retina --------------
    % exclusion: too close to fovea or disc (>=2.5R) -> not allowed
    [XX,YY] = meshgrid(1:W, 1:H);
    nearFo = sqrt((XX-cFo(1)).^2 + (YY-cFo(2)).^2) < 2.5*Rf;
    nearOd = sqrt((XX-cOd(1)).^2 + (YY-cOd(2)).^2) < 2.5*Rd;
    allowed = fg & ~nearFo & ~nearOd;

    negC = zeros(P,2); found = 0; tries = 0;
    while found < P && tries < 400*P
        tries = tries + 1;
        cx = randi([PH/2+1, W-PH/2]); cy = randi([PH/2+1, H-PH/2]);
        if allowed(cy,cx)
            found = found + 1; negC(found,:) = [cx cy];
        end
    end
    negC = negC(1:found,:);
    negPat = extractCrops(G, negC, PH);

    outPatches = cat(4, outPatches, posPat, negPat);
    outLabels  = [outLabels; categorical(zeros(P,1),[0 1],{'FOV','BG'}); ...
                             categorical(ones(found,1),[0 1],{'FOV','BG'})];
    outImg = [outImg; repmat(num2, P+found, 1)];
    for q = 1:(P+found), outSplit{end+1,1} = split; end
    fprintf('%s (%d): pos=%d neg=%d split=%s Rf@4=%d\n', ...
        f(i).name, num2, P, found, split, Rf);
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
    sum(labels=='FOV'), sum(labels=='BG'), numel(labels), nIm);
save(fullfile(outDir,'fovea_dataset.mat'),'patches','labels','imgIdx','split',...
     'HOLDOUT','PH','S','gtCenters','-v7.3');
fprintf('Saved %s\n', fullfile(outDir,'fovea_dataset.mat'));
end

function C = extractCrops(G, cxy, PH)
    H = size(G,1); W = size(G,2); n = size(cxy,1);
    half = PH/2;
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
