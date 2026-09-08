function [vessels, response, fov, dbg] = extractVessels3(img, varargin)
%EXTRACTVESSELS3 Phase-3 classical vessel segmenter candidate (prototype).
%   [vessels, response, fov, dbg] = extractVessels3(img)
%   [vessels, response, fov, dbg] = extractVessels3(img, Params)
%   [vessels, response, fov, dbg] = extractVessels3(img, 'fov', FovMask)
%
%   img      : RGB (or grayscale) retinal image.
%   Params   : optional struct overriding the CONFIG section below
%              (use vesselParams3 for a populated preset).
%   FovMask  : optional logical retinal field-of-view mask.
%
%   Returns:
%     vessels  - logical binary vessel map restricted to the FOV.
%     response - continuous vessel response in (0..1), before thresholding.
%     fov      - the field-of-view mask actually used.
%     dbg      - diagnostics: background, corrected, OD mask/ring, bright
%                lesion mask, Frangi gate (empty when the stage is off).
%
%   PURPOSE: the session champion (extractVessels.m) scores ~0.75 Dice on
%   DRIVE test yet VISUALLY over-segments: false positives cluster on the
%   optic-disc rim, wide illumination-shading confluences, bright lesion
%   borders and the FOV edge. These concentrated FP blobs barely move the
%   area-weighted Dice, so the candidate attacks exactly those sources
%   while preserving thin vessels by REUSING the champion's proven
%   enhancement (CLAHE -> multi-scale bottom-hat -> mild Frangi gate) and
%   adding ONLY surgical post-hoc suppression:
%
%     FP source                attack (all inside FOV, champion enh kept)
%     --------------------------------------------------------------
%     optic-disc rim           OD = largest bright central blob; STRONG
%                              attenuation on its dilated rim ring, mild
%                              attenuation in the disc interior so retinal
%                              vessels crossing the disc survive.
%     bright lesions +         bright connected blobs above a high in-FOV
%       specular highlights    percentile (excluding the OD) are dilated
%                              and the response beneath them attenuated
%                              (bottom-hat fires on their dark borders).
%     FOV edge / texture       everything inside FOV; line-opening + area
%                              cleanup after thresholding.
%
%   The flat-field (illumination) stage is present but OFF by default:
%   experiments showed that a strong global flat-field subtraction destroys
%   low-contrast vessel signal (a Gaussian background over-subtracts the
%   vessel band), lowering Dice far below the champion. Enable it via
%   `flatFieldEnable` only with a GENTLE sigma when the goal is to flatten
%   extreme vignetting on non-DRIVE stills.
%
%   Method (Image Processing Toolbox only, CPU - MATLAB R2026a):
%     1. Green channel.
%     2. FOV first (everything below restricted to the FOV).
%     3. [optional] leak-free flat-field correction (Gaussian background +
%        regionfill), gentler than the champion's implicit bottom-hat.
%     4. CLAHE.
%     5. Multi-scale bottom-hat vessel enhancement [2 3 4 6 8].
%     6. Mild Frangi (fibermetric) tubularity gate; moderate weight so thin
%        vessels are gated in, not out.
%     7. OD-rim + bright-lesion suppression.
%     8. Adaptive or in-FOV percentile threshold (never one global level).
%     9. Orientation-preserving cleanup + closing + area (+ thin-vessel
%        short line-opening + bridge reconnect).
%
%   NOTES
%   - Research prototype, NOT a clinically validated system.
%   - extractVessels.m (the session champion) is intentionally untouched.

%% ============================== CONFIG ===================================
D = struct();

% -- Color / FOV -----------------------------------------------------------
D.greenChannel        = true;   % use green channel; set false for grayscale.
D.fovErodeRadius      = 15;     % px erosion for the AUTOMATIC FOV only.

% -- Optional flat-field correction (OFF by default - see purpose note) ---
D.flatFieldEnable     = false;
D.bgSigma             = 30;     % sigma (px) of Gaussian illumination estimate.
D.bgErodeFrac         = 6;      % ~3*sigma factor to seed the in-FOV interior.
D.bgClampLo           = 0;      % clamp g - B to [lo hi] (pre-CLAHE).
D.bgClampHi           = 1;

% -- CLAHE ------------------------------------------------------------------
D.claheNumTiles       = [8 8];
D.claheClipLimit      = 0.02;

% -- Multi-scale vessel enhancement -----------------------------------------
D.morphThickness      = [2 3 4 6 8]; % bottom-hat disk radii (px).

% -- Tubularity gate (Frangi / fibermetric) ---------------------------------
D.gateThickness       = [2 3 4 5 6];
D.gatePolarity        = 'bright';
D.gateWeight          = 0.5;

% -- Optic-disc suppression -------------------------------------------------
D.odEnable            = true;
D.odBrightPerc        = 96;
D.odMinSize           = 2000;
D.odMaxFrac           = 0.10;
D.odNearCenter        = 0.55;   % centroid within this frac of FOV central radius
D.odDilateFrac        = 1.5;    % disc radius multiplier for suppressed region
D.odRingFrac          = 0.55;   % ring width as a frac of disc radius
D.odRingAtten         = 0.05;   % response multiplier on the rim ring (strong)
D.odInteriorAtten     = 0.85;   % response multiplier in the disc interior -
                                % MILD: the disc itself is bright (bottom-hat
                                % ignores it); central vessels must survive.

% -- Bright-lesion / highlight suppression ----------------------------------
D.brightEnable        = true;
D.brightPerc          = 99;
D.brightMinSize       = 30;
D.brightDilate        = 3;      % px dilation around each blob.
D.brightAtten         = 0.05;
D.brightMaxFrac       = 0.05;   % exclude blobs this big (they are the OD).

% -- Thresholding -----------------------------------------------------------
D.thresholdMethod     = 'percentile'; % 'adaptive' | 'percentile' | 'otsu'
D.thresholdFrac       = 0.12;   % keep this frac of FOV pixels as vessels
D.adaptSensitivity    = 0.50;   % only used by 'adaptive'.
D.thresholdScale      = 1.00;   % only used by 'otsu'.

% -- Morphological cleanup --------------------------------------------------
D.lineLength          = 9;      % line-opening length (odd).
D.lineAngles          = 0:15:165;
D.thinPreserve        = false;  % short line-opening (L=5) OR-combined keeps
                                % thin vessels but can retain noise; off by
                                % default (champion cleanliness) - tune.
D.closeDisk           = 2;
D.minArea             = 40;
D.doBridge            = true;   % reconnect single-pixel thin breaks.

%% ============================= PIPELINE ==================================

[P, fovUser] = parseInputs(varargin, D);

if size(img, 3) == 3 && P.greenChannel
    g0 = img(:,:,2);
else
    g0 = img;
end
g0 = im2double(g0);

% ---- 1. FOV first ---------------------------------------------------------
if ~isempty(fovUser)
    fov = logical(fovUser);
else
    fov = autoFOV(g0, P.fovErodeRadius);
end

dbg = struct();

% ---- 2. Optional leak-free flat-field correction --------------------------
g = g0;
if P.flatFieldEnable
    dbg.background = estimateIllumination(g0, fov, P.bgSigma, P.bgErodeFrac);
    dbg.corrected  = mat2gray(clampf(g0 - dbg.background, ...
        P.bgClampLo, P.bgClampHi));
    g = dbg.corrected;
else
    dbg.background = []; dbg.corrected = [];
end

% ---- 3. CLAHE --------------------------------------------------------------
g = im2double(adapthisteq(im2uint8(g), 'NumTiles', P.claheNumTiles, ...
    'ClipLimit', P.claheClipLimit));

% ---- 4. Multi-scale bottom-hat vessel enhancement --------------------------
vess = zeros(size(g));
for k = 1:numel(P.morphThickness)
    vess = max(vess, imbothat(g, strel('disk', P.morphThickness(k))));
end
vess = mat2gray(vess);

% ---- 5. Tubularity gate ----------------------------------------------------
gate = fibermetric(vess, P.gateThickness, 'ObjectPolarity', P.gatePolarity);
gate = mat2gray(im2double(gate));
dbg.gate = gate;
resp = vess .* (1 - P.gateWeight + P.gateWeight * gate);

% ---- 6. OD-rim + bright-lesion suppression ---------------------------------
dbg.odMask = false(size(g)); dbg.odRing = false(size(g));
dbg.brightMask = false(size(g));
if P.odEnable
    [dbg.odMask, dbg.odRing] = detectOpticDisc(g0, fov, P);
    resp = attenuateIn(resp, dbg.odMask, dbg.odRing, ...
        P.odInteriorAtten, P.odRingAtten);
end
if P.brightEnable
    dbg.brightMask = brightLesionMask(g0, dbg.odMask, fov, P);
    resp = attenuateIn(resp, dbg.brightMask, [], P.brightAtten, P.brightAtten);
end

response = mat2gray(resp);

% ---- 7. Thresholding --------------------------------------------------------
switch lower(P.thresholdMethod)
    case 'otsu'
        level   = P.thresholdScale * graythresh(response);
        vessels = response > level;
    case 'adaptive'
        tMap    = adaptthresh(response, P.adaptSensitivity);
        vessels = response > tMap;
    case 'percentile'
        if nnz(fov) == 0
            vessels = false(size(response));
        else
            level   = prctile(response(fov), 100*(1 - P.thresholdFrac));
            vessels = response > level;
        end
    otherwise
        error('extractVessels3:badMethod', ...
            'thresholdMethod must be ''otsu'', ''adaptive'' or ''percentile''.');
end

% ---- 8. Morphological cleanup -----------------------------------------------
vessels = bwmorph(vessels, 'clean');

lens = P.lineLength;
if P.thinPreserve
    lens = [lens 5];
end
lineOpening = false(size(vessels));
for L = lens
    for a = P.lineAngles
        lineOpening = lineOpening | imopen(vessels, strel('line', L, a));
    end
end
vessels = vessels & lineOpening;

vessels = imclose(vessels, strel('disk', P.closeDisk));
vessels = bwareaopen(vessels, P.minArea);
if P.doBridge
    vessels = bwmorph(vessels, 'bridge');
end
vessels = vessels & fov;

end

%% ============================ LOCAL FUNCTIONS ===============================

function [P, fovUser] = parseInputs(argsIn, D)
%Parse optional arguments: a struct (param overrides) and/or 'fov', mask.
    P = D;
    fovUser = [];
    k = 1;
    while k <= numel(argsIn)
        a = argsIn{k};
        if ischar(a) || isstring(a)
            key = lower(char(a));
            switch key
                case 'fov'
                    k = k + 1;
                    fovUser = argsIn{k};
                case {'params', 'p'}
                    k = k + 1;
                    P = mergeParams(P, argsIn{k});
                otherwise
                    error('extractVessels3:badArg', ...
                        'Unknown name-value argument ''%s''.', key);
            end
        elseif isstruct(a)
            P = mergeParams(P, a);
        end
        k = k + 1;
    end
end

function P = mergeParams(P, override)
%Overwrite CONFIG fields present in the override struct; ignore unknowns.
    if ~isstruct(override)
        error('extractVessels3:badParams', 'Params override must be a struct.');
    end
    fnames = fieldnames(override);
    for i = 1:numel(fnames)
        if isfield(P, fnames{i})
            P.(fnames{i}) = override.(fnames{i});
        else
            warning('extractVessels3:unknownParam', ...
                'Ignoring unknown parameter ''%s''.', fnames{i});
        end
    end
end

function bg = estimateIllumination(g0, fov, sigma, erodeFrac)
%Estimate a leak-free illumination field: Gaussian of the green channel
%computed ONLY on fully-interior FOV pixels, extrapolated with regionfill
%(smooth Poisson fill). Avoids the large-morphological-disk border leak.
    sigma  = max(sigma, 5);
    erodeR = max(1, round(erodeFrac * sigma));
    erodeR = min(erodeR, floor(min(size(fov)) / 5));
    seed   = imerode(fov, strel('disk', erodeR));
    if nnz(seed) < 50
        seed   = imerode(fov, strel('disk', max(1, floor(0.5*erodeR))));
    end
    fs     = 2*round(2*sigma) + 1;
    b0 = imgaussfilt(g0 .* double(fov), sigma, 'FilterSize', fs);
    if nnz(seed) > 0
        bg = regionfill(b0, ~seed);
    else
        bg = b0;
    end
    bg = bg .* double(fov);
end

function [odMask, odRing] = detectOpticDisc(g, fov, P)
%OD detection: largest brightish, reasonably central in-FOV blob.
    odMask = false(size(g));
    odRing = false(size(g));
    m = (g > prctile(g(fov), P.odBrightPerc)) & fov;
    cc = bwconncomp(m, 4);
    if isempty(cc.PixelIdxList), return; end
    sizes = cellfun(@numel, cc.PixelIdxList);
    nFov  = nnz(fov);
    ok    = sizes >= P.odMinSize & sizes <= P.odMaxFrac * nFov;
    if ~any(ok), return; end
    ids = find(ok);
    [yy, xx] = ndgrid(1:size(g,1), 1:size(g,2));
    fCy = mean(yy(fov)); fCx = mean(xx(fov));
    radFov = sqrt(nFov / pi);
    bestScore = -inf; best = 0;
    for i = ids(:)'
        ca = cc.PixelIdxList{i};
        cy = mean(yy(ca)); cx = mean(xx(ca));
        d  = sqrt((cy - fCy).^2 + (cx - fCx).^2) / radFov;
        if d > P.odNearCenter, continue; end
        score = sizes(i) / (1 + 2*d);
        if score > bestScore
            bestScore = score; best = i;
        end
    end
    if best == 0
        [~, mi] = max(sizes(ids));
        best = ids(mi);
    end
    od = false(size(g)); od(cc.PixelIdxList{best}) = true;
    rad   = sqrt(sum(od(:)) / pi);
    dilR  = max(1, round(P.odDilateFrac * rad));
    odMask = imdilate(od, strel('disk', dilR)) & fov;
    ringR  = max(1, round(P.odRingFrac * rad));
    odRing = odMask & ~imerode(odMask, strel('disk', ringR));
end

function m = brightLesionMask(g, odMask, fov, P)
%Bright blobs (top in-FOV percentile) that are NOT the optic disc, slightly
%dilated; suppress the response beneath their dark borders.
    m = false(size(g));
    b = (g > prctile(g(fov), P.brightPerc)) & fov & ~odMask;
    cc = bwconncomp(b, 4);
    if isempty(cc.PixelIdxList), return; end
    nFov = nnz(fov);
    ids  = [];
    for i = 1:numel(cc.PixelIdxList)
        sz = numel(cc.PixelIdxList{i});
        if sz >= P.brightMinSize && sz <= P.brightMaxFrac * nFov
            ids(end+1) = i; %#ok<AGROW>
        end
    end
    for i = ids
        m(cc.PixelIdxList{i}) = true;
    end
    if ~isempty(ids)
        m = imdilate(m, strel('disk', P.brightDilate)) & fov;
    end
end

function r = attenuateIn(r, mask, ring, interiorAtten, ringAtten)
%Multiply response by interiorAtten inside `mask` and by ringAtten on the
%`ring` (if provided). Ring pixels win over the interior.
    if isempty(mask) || ~any(mask(:)), return; end
    if isempty(ring)
        r(mask) = r(mask) * interiorAtten;
    else
        interior = mask & ~ring;
        r(interior) = r(interior) * interiorAtten;
        r(ring) = r(ring) * ringAtten;
    end
end

function x = clampf(x, lo, hi)
    x = max(x, lo); x = min(x, hi);
end

function fov = autoFOV(g0, erodeRadius)
%AUTOFOV Automatically segment the retinal field of view from the green
%channel: Otsu threshold, keep the largest connected component, fill holes,
%smooth, then erode to remove bright/rim artifacts at the FOV boundary.
    m = imbinarize(im2uint8(g0));
    cc = bwconncomp(m, 4);
    if isempty(cc.PixelIdxList)
        fov = false(size(m));
        return;
    end
    numPix = cellfun(@numel, cc.PixelIdxList);
    [~, mi] = max(numPix);
    fov = false(size(m));
    fov(cc.PixelIdxList{mi}) = true;
    fov = imclose(fov, strel('disk', 5));
    fov = imfill(fov, 'holes');
    if erodeRadius > 0
        fov = imerode(fov, strel('disk', erodeRadius));
    end
end