function buildDriveVesselDataset()
%BUILDDRIVEVESSELDATASET Build vessel-vs-background patch dataset from DRIVE.
%   Positive patches = 64x64 green-channel crops centred on manually-marked
%   vessel pixels (DRIVE training 1st_manual); negative patches = FOV crops
%   centred on non-vessel pixels at least 3 px away from any marked vessel.
%
%   Image-held-out split mirrors buildMaDataset: images 21..36 are the
%   training pool, images 37..40 are held OUT for held-out patch evaluation
%   (the same 4-image scheme the MA/OD CNNs use). If the DRIVE test manual
%   ground truths are present they are NOT used here at any point.
%
%   Patches are the green channel replicated to 3 channels (uint8), PH=64.
%   Saves data/analysis/day8/vessel/vessel_dataset.mat
%
%   Outputs: patches (uint8 64x64x3xN), labels (categorical {'VESSEL','BG'}),
%   imgIdx (N int = DRIVE image number 21..40), split ('train'|'val'), PH.

projRoot = 'C:\projects\DrishtiCare';
driveRoot = fullfile(projRoot,'data','drive','DRIVE','training');
outDir  = fullfile(projRoot,'data','analysis','day8','vessel');
if ~exist(outDir,'dir'), mkdir(outDir); end

PH = 64;                  % patch size (px, full-res)
pad = PH/2;
N_POS_TRAIN = 600;        % positives (and matched negatives) per training image
N_POS_VAL   = 600;        % per held-out (val) image
NEG_MARGIN = 3;           % negative centre must be >= this many px from any vessel
HOLDOUT = [37 38 39 40];  % DRIVE images held OUT for patch-level evaluation

f = dir(fullfile(driveRoot,'images','*.tif'));
f = sort({f.name});
nIm = numel(f);
assert(nIm == 20, 'DRIVE training expected 20 images, found %d', nIm);

patches = []; labels = []; imgIdx = [];
nPos = 0; nNeg = 0;
for i = 1:nIm
    numStr = regexp(f{i},'^(\d+)_training\.tif$','tokens','once');
    numImg = str2double(numStr{1});
    I = imread(fullfile(driveRoot,'images',f{i}));
    G = im2uint8(I(:,:,2));                       % green channel
    Mm = imread(fullfile(driveRoot,'1st_manual',sprintf('%02d_manual1.gif',numImg))) > 0;
    mf = imread(fullfile(driveRoot,'mask',sprintf('%02d_training_mask.gif',numImg))) > 0;
    Mm = Mm & mf;                                 % restrict GT to FOV
    [H,W] = size(G);
    inPool = ~any(numImg == HOLDOUT);
    nTarget = N_POS_TRAIN; if ~inPool, nTarget = N_POS_VAL; end

    % ---- positive centres: random vessel pixels (kept inside crop margin) ----
    [yy,xx] = find(Mm);
    ok = xx > pad & xx <= W-pad & yy > pad & yy <= H-pad;
    yy = yy(ok); xx = xx(ok);
    if numel(xx) < nTarget, nTarget = numel(xx); end
    sel = randsample(numel(xx), nTarget);
    cPos = [xx(sel) yy(sel)];
    Ppos = extractCrops(G, cPos, PH);
    nPos = nPos + size(Ppos,4);

    % ---- negative centres: FOV pixels far from vessels (center-based label) ----
    nv = imdilate(Mm, strel('disk', NEG_MARGIN));
    candPool = find(mf & ~nv);
    [cPy,cPx] = ind2sub([H W], candPool);
    ok = cPx > pad & cPx <= W-pad & cPy > pad & cPy <= H-pad;
    cPy = cPy(ok); cPx = cPx(ok);
    nNegT = min(nTarget, numel(cPx));
    sel = randsample(numel(cPx), nNegT);
    cNeg = [cPx(sel) cPy(sel)];
    Pneg = extractCrops(G, cNeg, PH);
    nNeg = nNeg + size(Pneg,4);

    patches = cat(4, patches, Ppos, Pneg);
    labels  = [labels; zeros(size(Ppos,4),1); ones(size(Pneg,4),1)];
    imgIdx  = [imgIdx; repmat(numImg, size(Ppos,4)+size(Pneg,4), 1)];

    sp = 'train'; if ~inPool, sp = 'val'; end
    fprintf('%02d split=%s pos=%d neg=%d\n', numImg, sp, ...
        size(Ppos,4), size(Pneg,4));
end

labels = categorical(labels, [0 1], {'VESSEL','BG'});
split = repmat({'train'}, size(imgIdx));
for k = 1:numel(imgIdx)
    if any(imgIdx(k) == HOLDOUT), split{k} = 'val'; end
end
split = categorical(split);

rng(42);
order = randperm(size(patches,4));
patches = patches(:,:,:,order);
labels  = labels(order);
imgIdx  = imgIdx(order);
split   = split(order);

fprintf('\nTOTAL: %d positives, %d negatives (%.3f balance), %d patches, %d images\n', ...
    nPos, nNeg, nPos/max(nPos+nNeg,1), size(patches,4), nIm);
fprintf('val (held-out) patches: %d\n', sum(split=='val'));

save(fullfile(outDir,'vessel_dataset.mat'), 'patches','labels','imgIdx','split', ...
     'HOLDOUT','PH','N_POS_TRAIN','N_POS_VAL','-v7.3');
fprintf('Saved %s\n', fullfile(outDir,'vessel_dataset.mat'));
end

function P = extractCrops(G, cxy, PH)
    H = size(G,1); W = size(G,2); n = size(cxy,1);
    pad = PH/2;
    P = zeros(PH,PH,3,n,'uint8');
    g3 = repmat(G, [1 1 3]);
    for k = 1:n
        cx = round(cxy(k,1)); cy = round(cxy(k,2));
        rr = cy-pad+1:cy+pad; rr2 = cx-pad+1:cx+pad;
        P(:,:,:,k) = g3(rr,rr2,:);
    end
end