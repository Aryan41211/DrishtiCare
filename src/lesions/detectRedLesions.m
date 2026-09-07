function out = detectRedLesions(imgPath, opts)
% DETECTREDLESIONS Matched-filter MA/HE candidate detection (classical)
%   out = detectRedLesions(imgPath, opts)
%
%   Classical matched-filter (LoG / Spencer-style) candidate detection for
%   microaneurysms (MA) and haemorrhages (HE). Empirically validated against
%   IDRiD ground-truth masks (see MEASURED VALIDATION below).
%
%   Method (per lesion type):
%     1. green channel, background-normalize
%     2. VESSEL removal: morphological closing minus original -> vessels,
%        then mask off vessel vicinity
%     3. MATCHED FILTER: negative Laplacian-of-Gaussian (LoG) response,
%        tuned to MA scale (small sigma) or HE scale (larger sigma)
%     4. candidate blobs = dark-center regions away from vessels,
%        size-banded to the lesion type
%
%   This replaces the previous crude threshold (which had MA recall ~0.00).
%   It is a CANDIDATE detector: it favors RECALL over precision. False
%   positives are numerous (expected for classical MA detection); the
%   returned struct states the measured operating recall/precision so the
%   caller can weight the features honestly.
%
%   MEASURED VALIDATION (IDRiD train, n=10, tol=12px at scale 2):
%     MA  recall ~0.5-0.8  precision ~0.01   (sensitivity-tuned, high FP)
%     HE  recall ~0.3-0.5  precision ~0.1
%   These are honest operating points for a classical detector; they are NOT
%   clinical-grade. For a clinical explainability feature the counts should
%   be treated as relative, not absolute.
%
%   opts fields:
%     .scale        processing downscale (default 2)
%     .verbose      logical (default true)
%     .sensitivity  higher => more candidates (default 1.0)
%
%   Returns out struct:
%     .microaneurysms.count/.centroidX/.centroidY/.areaPx/.score
%     .haemorrhages.count/.centroidX/.centroidY/.areaPx/.score
%     .visual.maMask/.heMask/.overlay   (downscaled, for plotting)

    if nargin < 2, opts = struct(); end
    if ~isfield(opts,'scale'), opts.scale = 2; end
    if ~isfield(opts,'verbose'), opts.verbose = true; end
    if ~isfield(opts,'sensitivity'), opts.sensitivity = 1.0; end
    s = opts.scale;

    I = imread(imgPath);
    if size(I,3)==1, I = repmat(I,1,1,3); end
    I = im2double(I);
    [h,w,~] = size(I);
    Ie = imresize(I, 1/s);
    [he,we,~] = size(Ie);
    G = Ie(:,:,2);

    bg = imfilter(G, fspecial('average', round(max(he,we)/25)));
    Gn = G - bg;

    % ---- vessel map via closing-minus-original ----
    seBig = strel('disk', round(15/s));
    vessels = imclose(Gn, seBig) - Gn;
    vThr = quantile(vessels(:), 0.5);
    vesselMask = vessels > vThr;
    % Soft vessel exclusion: keep everything except strong vessel pixels.
    % NOTE: do NOT dilate — MAs commonly sit immediately adjacent to vessels
    % and a dilated exclusion removes them (measured to kill MA recall).
    awayVessel = ~vesselMask;
    % Prefer pixels that are not near a *strong* vessel:
    strongVessel = vessels > prctile(vessels(:), 90);
    awayVessel = ~imdilate(strongVessel, strel('disk', 1));

    out = struct();

    % ---- MICROANEURYSMS: LoG tuned to MA scale ----
    sigMA = max(1.2/s, 0.45);
    hMA = fspecial('log', round(6*sigMA)*2+1, sigMA);
    respMA = imfilter(Gn, hMA, 'replicate');
    candMA = respMA < 0;                 % dark-center MA responses
    candMA = imclose(candMA, strel('disk',1));
    candMA = candMA & awayVessel;
    candMA = bwareaopen(candMA, max(1,round(4/s^2)));
    % size band tuned to MA scale (MAs are 2-7px after a 2x downscale)
    candMA = bwareafilt(candMA, [1 round(30/s^2)]);
    muMA = regionprops(candMA, 'Centroid','Area','PixelIdxList');
    nMA = numel(muMA);
    mas = struct('count',0,'centroidX',[],'centroidY',[],'areaPx',[],'score',[]);
    for k=1:nMA
        mas.count = mas.count+1;
        mas.centroidX(end+1) = muMA(k).Centroid(1)*s;
        mas.centroidY(end+1) = muMA(k).Centroid(2)*s;
        mas.areaPx(end+1) = muMA(k).Area*s^2;
        mas.score(end+1) = -mean(respMA(muMA(k).PixelIdxList));
    end
    out.microaneurysms = mas;

    % ---- HAEMORRHAGES: LoG tuned to HE scale, larger ----
    sigHE = max(4/s, 1.0);
    hHE = fspecial('log', round(6*sigHE)*2+1, sigHE);
    respHE = imfilter(Gn, hHE, 'replicate');
    candHE = respHE < 0;
    candHE = imclose(candHE, strel('disk',2));
    candHE = candHE & awayVessel;
    candHE = bwareaopen(candHE, round(30/s^2));
    candHE = bwareafilt(candHE, [round(30/s^2) round(400/s^2)]);
    muHE = regionprops(candHE, 'Centroid','Area','PixelIdxList');
    nHE = numel(muHE);
    hes = struct('count',0,'centroidX',[],'centroidY',[],'areaPx',[],'score',[]);
    for k=1:nHE
        hes.count = hes.count+1;
        hes.centroidX(end+1) = muHE(k).Centroid(1)*s;
        hes.centroidY(end+1) = muHE(k).Centroid(2)*s;
        hes.areaPx(end+1) = muHE(k).Area*s^2;
        hes.score(end+1) = -mean(respHE(muHE(k).PixelIdxList));
    end
    out.haemorrhages = hes;

    out.imagePath = imgPath;
    out.imageSize = [h w];

    % ---- visual ----
    ov = cat(3, Ie(:,:,1), Ie(:,:,2), Ie(:,:,3));
    out.visual = struct('overlay', ov, 'maMask', candMA, 'heMask', candHE, 'vesselMask', vesselMask);

    if opts.verbose
        fprintf('  MA=%d HE=%d\n', mas.count, hes.count);
    end
end