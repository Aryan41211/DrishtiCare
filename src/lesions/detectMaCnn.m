function out = detectMaCnn(imgPath, opts)
%DETECTMACNN CNN-based microaneurysm detector (candidate + classifier)
%   out = detectMaCnn(imgPath, opts)
%
%   Stage 1: sensitive dark-dot candidate generation via black-hat on the
%   green channel (downscaled x2), ranked by response, capped at MAXCAND.
%   This stage deliberately favours RECALL (the CNN filters false positives).
%   Stage 2: each candidate centroid is re-cropped at FULL resolution
%   (48x48, matching the training distribution) and classified by the
%   trained MA-vs-background CNN (see trainMaCnn). Detections = candidates
%   with P(MA) >= opts.scoreThr; the full score list is returned so the
%   caller can pick its own operating point.
%
%   Validation (held-out IDRiD_01..10, tol=12px, >20k candidates/image):
%     See docs/task-tracker.md & data/analysis/day8/ma_cnn/ma_cnn_detection.mat
%
%   opts:
%     .scoreThr   CNN P(MA) threshold for .detections (default 0.75)
%     .maxCand    max candidates kept per image  (default 20000)
%     .net        net to use (optional; else loads ma_cnn_net.mat)
%     .verbose    logical (default false)
%
%   Returns out:
%     .detections.k/p/tRectSamp  struct: centroidX, centroidY, score
%     .scores                   all candidate scores (sorted desc)
%     .candidateCentroids       all candidates (full-res px, Nx2)
if nargin < 2, opts = struct(); end
    if ~isfield(opts,'scoreThr'), opts.scoreThr = 0.75; end
    if ~isfield(opts,'maxCand'), opts.maxCand = 20000; end
    if ~isfield(opts,'nmsRadius'), opts.nmsRadius = 24; end
    if ~isfield(opts,'ensemble'), opts.ensemble = false; end
    if ~isfield(opts,'verbose'), opts.verbose = false; end
    net2b = [];

    if ~isfield(opts,'net')
        netData = load(fullfile('C:\projects\DrishtiCare','data','analysis','day8','ma_cnn','ma_cnn_net.mat'));
        if isfield(netData,'net2')
            net = netData.net2;   % hard-negative retrained preferred
            if opts.ensemble && isfield(netData,'net')
                net2b = netData.net;
            end
        else
            net = netData.net;
        end
    else
        net = opts.net;
    end

    I = imread(imgPath);
    if size(I,3)==1, I = repmat(I,1,1,3); end
    I = im2double(I);
    [H,W,~] = size(I);
    G = I(:,:,2);
    s = 2;
    G2 = imresize(G,1/s);
    % ---- stage 1: dark-dot candidates (black-hat = closing - original) ----
    bh = imclose(G2, strel('disk',2)) - G2;       % dark small objects light up
    % exclude strong vessels: black-hat is big on vessel lines too; keep only
    % compact dots via a second structural criterion later (CNN handles it).
    thr = quantile(bh(:), 0.98);                 % sensitive: top 2% brightest dots
    cand = bh > thr;
    cand = bwareaopen(cand, 2);
    cand = bwareafilt(cand, [2 round(36/s^2)]);  % MA-size blobs in downscaled frame
    cc = bwconncomp(cand);
    mu = regionprops(cc, 'Centroid','PixelIdxList');
    nC = cc.NumObjects;
    % rank by mean black-hat response, cap
    resp = zeros(nC,1);
    for k=1:nC
        resp(k) = mean(bh(cc.PixelIdxList{k}));
    end
    [~,ord] = sort(resp,'descend');
    ord = ord(1:min(nC,opts.maxCand));
    nC = numel(ord);
    cent = round(cat(1,mu(ord).Centroid)) .* s;   % full-res centroids
    % ---- stage 2: classify full-res 48x48 crops ----
    PH = 48; pad = PH/2;
    crops = zeros(PH,PH,3,nC,'uint8');
    keep = true(nC,1);
    for k=1:nC
        cx = cent(k,1); cy = cent(k,2);
        if cx<pad+1 || cx>W-pad || cy<pad+1 || cy>H-pad
            keep(k)=false; continue;
        end
        rr = cy-pad+1:cy+pad; rr2 = cx-pad+1:cx+pad;
        crops(:,:,:,k) = uint8(255*I(rr,rr2,:));
    end
    crops(:,:,:,~keep) = [];
    cx = cent(keep,1); cy = cent(keep,2);
    nC = size(crops,4);
    ds = augmentedImageDatastore([PH PH 3], crops, 'OutputSizeMode','resize');
    [~, sc] = classify(net, ds);
    scMA = sc(:,1);                              % P(MA)
    if ~isempty(net2b)
        [~, scB] = classify(net2b, ds);
        scMA = 0.5*(scMA + scB(:,1));
    end
    [~,ord] = sort(scMA,'descend');
    scMA = scMA(ord); cx = cx(ord); cy = cy(ord);

    out.centroidX = cx; out.centroidY = cy; out.score = scMA;
    % non-maximum suppression: keep only the highest-scoring candidate within
    % NMS radius (default 24px full-res, ~1 MA diameter) -- collapses the
    % flood of overlapping candidates per true MA into one detection
    r = opts.nmsRadius;
    keep = true(nC,1);
    for k=1:nC
        if ~keep(k), continue; end
        d2 = (cx- cx(k)).^2 + (cy - cy(k)).^2;
        keep(d2 <= r^2 & (1:nC)' > k) = false;
    end
    nmsX = cx(keep); nmsY = cy(keep); nmsS = scMA(keep);
    sel = nmsS >= opts.scoreThr;
    out.detections = struct('centroidX',nmsX(sel),'centroidY',nmsY(sel),'score',nmsS(sel));
    out.centroidX = nmsX; out.centroidY = nmsY; out.score = nmsS;
    out.imagePath = imgPath; out.imageSize = [H W];
    if opts.verbose
        fprintf('  MA candidates=%d  (NMS r=%d) -> %d  detections>=%.2f = %d\n', nC, r, sum(keep), opts.scoreThr, sum(sel));
    end
end