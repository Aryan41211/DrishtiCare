function feat = extractLesionCandidates(imgPath, opts)
% EXTRACTLESIONCANDIDATES Classical lesion candidate extraction (IDRiD)
%   feat = extractLesionCandidates(imgPath, opts)
%
%   Classical (non-deep-learning) candidate extraction for explainability +
%   fusion features:
%     - Microaneurysms:  multi-orientation top-hat morphology (green channel)
%     - Haemorrhages:    same normalized pipeline, discriminated by size/shape
%     - Exudates:        morphological reconstruction, optic-disc excluded
%
%   Returns counts, centroids (original-image coords) and masks scaled to
%   original image size.
%
%   opts fields:
%     .scale          downscale factor for processing (default 4)
%     .odCenter       [c r] optic disc center in ORIGINAL coords (default [])
%     .odRadius       optic disc radius in ORIGINAL pixels (default 0)
%     .fovea          [c r] fovea center in ORIGINAL coords (default [])
%     .verbose        logical (default true)
%     .returnVisual   logical: also return downscaled overlay images (default true)
%
%   Coordinates convention: [x, y] = [column, row] (MATLAB image coords).
%   This is an ENGINEERING explainability feature, not clinical diagnosis.

    if nargin < 2, opts = struct(); end
    if ~isfield(opts, 'scale'), opts.scale = 4; end
    if ~isfield(opts, 'odCenter'), opts.odCenter = []; end
    if ~isfield(opts, 'odRadius'), opts.odRadius = 0; end
    if ~isfield(opts, 'fovea'), opts.fovea = []; end
    if ~isfield(opts, 'verbose'), opts.verbose = true; end
    if ~isfield(opts, 'returnVisual'), opts.returnVisual = true; end

    s = opts.scale;

    %% Load and downscale
    I = imread(imgPath);
    if size(I, 3) == 3, I = im2double(I); elseif size(I, 3) == 1, I = repmat(im2double(I), [1 1 3]); end
    [h, w, ~] = size(I);
    Ie = imresize(I, 1/s);               % working image (downscaled)
    [he, we, ~] = size(Ie);

    %% Green channel (best for both red and bright lesions)
    G = Ie(:,:,2);

    %% Background normalization (remove slow illumination gradient)
    bg = imfilter(G, fspecial('average', round(max(we,he)/25)));
    Gnorm = G - bg;

    %% ============ MICROANEURYSMS + HAEMORRHAGES (red lesions) ============
    % Multi-orientation top-hat: dark dots/lines removed by bottom-hat on
    % the normalized green channel. Use disk SE for MAs, larger disk for HEs.
    se_disk_small = strel('disk', 1);          % ~MA scale (downscaled)
    se_disk_large = strel('disk', round(40/s)); % HE scale (~40px original radius; bridges vessels)

    % Bottom-hat (dark structures on bright bg) via closing minus original
    redResponseSmall = imbothat(Gnorm, se_disk_small);
    redResponseLarge = imbothat(Gnorm, se_disk_large);

    % Threshold: require strong local response (upper quantile of positive
    % response) to avoid textbook background texture over-detection.
    pS = redResponseSmall(:);  pSL = pS(pS > 0);
    pL = redResponseLarge(:);  pLL = pL(pL > 0);
    thrSmall = max(graythresh(redResponseSmall) * max(redResponseSmall(:)), ...
                   quantile(pSL, 0.85) * 1.2);
    thrLarge = max(graythresh(redResponseLarge) * max(redResponseLarge(:)), ...
                   quantile(pLL, 0.8));
    binSmall = redResponseSmall > thrSmall;
    binLarge = redResponseLarge > thrLarge;

    % Remove tiny noise (1-2 px downscaled)
    binSmall = bwareaopen(binSmall, 4);
    binLarge = bwareaopen(binLarge, 8);

    % Haemorrhages = large(binLarge) minus small(binSmall); MAs = small
    % candidates below HE size threshold.
    MAmaxArea = round((14/s)^2);   % max MA candidate area

    % Connected components
    ccSmall = bwconncomp(binSmall & ~binLarge);
    ccLarge = bwconncomp(binLarge);

    % ---- MAs: small, roundish ----
    mas = struct('count', 0, 'centroidX', [], 'centroidY', [], 'areaPx', []);
    maMu = regionprops(ccSmall, {'Area','Centroid','Eccentricity'});
    for k = 1:length(maMu)
        a = maMu(k).Area;
        ecc = maMu(k).Eccentricity;
        if a >= 4 && a <= MAmaxArea && ecc < 0.75
            mas.count = mas.count + 1;
            mas.centroidX(end+1) = maMu(k).Centroid(1) * s;
            mas.centroidY(end+1) = maMu(k).Centroid(2) * s;
            mas.areaPx(end+1) = a * s^2;
        end
    end

    % ---- HEs: larger, irregular but not vessel-like ----
    hes = struct('count', 0, 'centroidX', [], 'centroidY', [], 'areaPx', []);
    HEminArea = round((35/s)^2);
    heMu = regionprops(ccLarge, {'Area','Centroid','Eccentricity','MajorAxisLength','MinorAxisLength'});
    for k = 1:length(heMu)
        a = heMu(k).Area;
        ecc = heMu(k).Eccentricity;
        % Vessels are very elongated (ecc ~ 1); haemorrhages are
        % irregular blobs. Keep moderate eccentricity and reasonable size.
        if a >= HEminArea && ecc > 0.4 && ecc < 0.92 && a <= round((250/s)^2)
            hes.count = hes.count + 1;
            hes.centroidX(end+1) = heMu(k).Centroid(1) * s;
            hes.centroidY(end+1) = heMu(k).Centroid(2) * s;
            hes.areaPx(end+1) = a * s^2;
        end
    end

    %% ============ EXUDATES (bright lesions, optic-disc excluded) ============
    % Use maximum-projection of color channels (bright) on normalized image.
    % Background-normalize luminance, then opening-by-reconstruction to catch
    % bright irregular plates.
    L = Ie(:,:,1)*0.299 + Ie(:,:,2)*0.587 + Ie(:,:,3)*0.114;
    Lbg = imfilter(L, fspecial('average', round(max(we,he)/25)));
    Ln = L - Lbg;

    % White top-hat (bright structures)
    se_ex = strel('disk', round(max(2/s, 2)));
    exResp = imtophat(L, imclose(Ln > 0.05, se_ex)); % reconstruction-ish bright
    exP = exResp(:); exPos = exP(exP > 0);
    thrEx = max(graythresh(exResp) * max(exResp(:)), ...
                quantile(exPos, 0.7) * 1.2);
    binEx = exResp > thrEx;
    binEx = bwareaopen(binEx, round((10/s)^2));

    % Optic disc exclusion mask (circle around OD center/radius)
    discMask = false(he, we);
    if ~isempty(opts.odCenter) && opts.odRadius > 0
        oc = opts.odCenter(1)/s;
        or_ = opts.odRadius/s * 1.2;   % exclude disc + 20% margin
        [Xg, Yg] = meshgrid(1:we, 1:he);
        discMask = sqrt((Xg-oc).^2 + (Yg-(opts.odCenter(2)/s)).^2) <= or_;
    end
    binEx(discMask) = false;

    exmu = regionprops(bwconncomp(binEx), {'Area','Centroid'});
    exd = struct('count', 0, 'centroidX', [], 'centroidY', [], 'areaPx', [], 'distToFovea', []);
    exMin = round((10/s)^2);
    for k = 1:length(exmu)
        if exmu(k).Area >= exMin
            exd.count = exd.count + 1;
            cx = exmu(k).Centroid(1) * s;
            cy = exmu(k).Centroid(2) * s;
            exd.centroidX(end+1) = cx;
            exd.centroidY(end+1) = cy;
            exd.areaPx(end+1) = exmu(k).Area * s^2;
            if ~isempty(opts.fovea)
                exd.distToFovea(end+1) = sqrt((cx-opts.fovea(1))^2 + (cy-opts.fovea(2))^2);
            end
        end
    end

    %% Per-quadrant haemorrhage counts (about image center)
    cx0 = w/2; cy0 = h/2;
    q = [0 0 0 0];   % quadrants: [TR, TL, BL, BR] (row/col increasing down)
    for k = 1:length(hes.centroidX)
        xx = hes.centroidX(k); yy = hes.centroidY(k);
        if yy <= cy0
            if xx >= cx0, q(1) = q(1)+1; else, q(2) = q(2)+1; end
        else
            if xx >= cx0, q(4) = q(4)+1; else, q(3) = q(3)+1; end
        end
    end

    %% Assemble feature struct
    feat = struct();
    feat.imagePath = imgPath;
    feat.imageSize = [h w];
    feat.microaneurysms = mas;
    feat.haemorrhages = hes;
    feat.exudates = exd;
    feat.quadrantHemorrhage = q;     % [TR TL BL BR]
    feat.odCenter = opts.odCenter;
    feat.odRadius = opts.odRadius;
    feat.fovea = opts.fovea;
    if ~isempty(opts.fovea) && exd.count > 0
        feat.meanExudateDistToFovea = mean(exd.distToFovea);
        feat.minExudateDistToFovea = min(exd.distToFovea);
    else
        feat.meanExudateDistToFovea = NaN;
        feat.minExudateDistToFovea = NaN;
    end

    %% Visual (return downscaled overlays for inspection)
    if opts.returnVisual
        overlay = cat(3, Ie(:,:,1), Ie(:,:,2), Ie(:,:,3));
        maMask = false(he, we); if mas.count>0
            for k=1:mas.count, x=round(mas.centroidX(k)/s); y=round(mas.centroidY(k)/s);
                if x>=1&&x<=we&&y>=1&&y<=he, maMask(y,x)=true; end, end
        end
        heMask = false(he, we); if hes.count>0
            for k=1:hes.count, x=round(hes.centroidX(k)/s); y=round(hes.centroidY(k)/s);
                if x>=1&&x<=we&&y>=1&&y<=he, heMask(y,x)=true; end, end
        end
        exMask = binEx;
        feat.visual = struct();
        feat.visual.overlay = overlay;
        feat.visual.maMask = maMask;
        feat.visual.heMask = heMask;
        feat.visual.exMask = exMask;
        feat.visual.discMask = discMask;
    end

    if opts.verbose
        fprintf('  MA=%d HE=%d EX=%d  quadHE=[%d %d %d %d]\n', ...
            mas.count, hes.count, exd.count, q(1), q(2), q(3), q(4));
    end
end