function [vessels, response, fov] = extractVessels(img, varargin)
%EXTRACTVESSELS Classical retinal blood vessel segmentation (prototype).
%   [vessels, response, fov] = extractVessels(img)
%   [vessels, response, fov] = extractVessels(img, Params)
%   [vessels, response, fov] = extractVessels(img, 'fov', FovMask)
%
%   img      : RGB (or grayscale) retinal image.
%   Params   : optional struct overriding fields of the configuration
%              section below (see CONFIG). Unknown fields are ignored.
%   FovMask  : optional logical retinal field-of-view mask. When omitted
%              an automatic FOV is estimated from the green channel.
%
%   Returns:
%     vessels  - logical binary vessel map restricted to the FOV.
%     response - continuous vessel response in (0..1), before thresholding.
%     fov      - the field-of-view mask actually used.
%
%   Method (classical, Image Processing Toolbox only, CPU - MATLAB R2026a):
%     1. Green channel  (retinal vessels are most visible there)
%     2. CLAHE contrast enhancement   (adapthisteq)
%     3. Background / illumination correction AND multi-scale vessel
%        enhancement via closing-based (bottom-hat) contrast at increasing
%        vessel scales: max_k imbothat(green, disk(k)).  The closing-based
%        top-hat removes the local background (illumination) trend at the
%        vessel scale, and it responds ONLY to DARK objects, so bright
%        lesions (exudates), the optic disc and the background are not
%        enhanced. The scale-wise max preserves thin AND thick vessels.
%     4. Tubularity gating with fibermetric (Frangi vesselness filter):
%            gate = fibermetric(vesselMap, gateThickness, 'bright')
%            resp = vesselMap .* (1 - gateWeight + gateWeight*gate)
%        The Frangi filter scores elongated tubular structures, so the
%        gate DAMPENS blob-like dark regions (e.g. hemorrhages, shadowy
%        artifacts) while keeping vessel ~zero effect on elongated vessels.
%        (Pure multi-scale bottom-hat was tested first; it produced more
%         false positives. The gate recovered specificity with higher Dice.)
%     5. Threshold on the normalized response. 'otsu' (with optional scale),
%        'percentile' (keeps the brightest fraction of FOV pixels), or
%        'adaptive'.
%     6. Morphological cleanup: isolated-pixel removal, orientation-
%        preserving line openings (keeps vessels, removes salt-and-pepper),
%        a small closing, and removal of components smaller than minArea.
%     7. Restriction to the retinal field of view (supplied or automatic).
%
%   NOTES
%   - This is a research prototype, NOT a clinically validated system.
%   - All tuning values live in the CONFIG section below for reproducibility.

%% ============================== CONFIG ===================================
% Every magic number used by the pipeline is defined here. Override any
% field by passing a struct as the second input argument.
D = struct();

% -- CLAHE contrast enhancement --------------------------------------------
D.claheNumTiles    = [8 8];  % CLAHE tile grid (rows x cols)
D.claheClipLimit   = 0.02;   % CLAHE contrast clip limit (0=off, 1=max)

% -- Multi-scale vessel enhancement (bottom-hat across scales) -------------
D.morphThickness   = [2 4 6 8]; % radii (px) of the bottom-hat disks.
                                % Largest radius must exceed max vessel
                                % half-width. The scale-wise max keeps thin
                                % and thick vessels.

% -- Tubularity gate (fibermetric / Frangi) --------------------------------
D.gateThickness    = [3 4 5]; % vessel thickness scales (px) used by the
                              % Frangi gate. Kept small to gate blobs but
                              % not to widen vessels.
D.gatePolarity     = 'bright';% polarity of tubular structures in the
                              % vessel map (vessels are bright there).
D.gateWeight       = 0.4;     % 0 = pure morphology (no gating),
                              % 1 = full Frangi gating.

% -- Thresholding ----------------------------------------------------------
D.thresholdMethod  = 'otsu';    % 'otsu' | 'adaptive' | 'percentile'
D.thresholdScale   = 1.00;      % multiplier on the Otsu level (>1 = fewer
                                % vessels, <1 = more).
D.adaptSensitivity = 0.50;      % sensitivity used only by 'adaptive' method.
D.thresholdFrac    = 0.15;      % in-FOV vessel-area fraction used only by
                                % 'percentile' (keeps the brightest frac of
                                % FOV pixels).

% -- Morphological cleanup -------------------------------------------------
D.lineLength       = 9;      % length (px, odd) of the line SEs used for the
                             % orientation-preserving opening (noise removal).
D.lineAngles       = 0:30:150; % line orientations tested.
D.closeDisk        = 2;      % radius (px) of closing used to reconnect
                             % broken vessel segments.
D.minArea          = 40;     % connected components smaller than this (px)
                             % are removed (kills salt-and-pepper specks).

% -- Field of view ----------------------------------------------------------
D.fovErodeRadius   = 15;     % px erosion applied by the AUTOMATIC FOV (only
                             % used when no FovMask is supplied). Removes
                             % bright rim artifacts / vignetting border.

%% ============================= PIPELINE ==================================

% ---- Input handling --------------------------------------------------------
[P, fovUser]  = parseInputs(varargin, D);

if size(img, 3) == 3
    g0 = img(:,:,2);                 % green channel: vessels most visible
else
    g0 = img;
end
g0 = im2double(g0);

% ---- 1. CLAHE contrast enhancement -----------------------------------------
g   = adapthisteq(im2uint8(g0), 'NumTiles', P.claheNumTiles, ...
    'ClipLimit', P.claheClipLimit);
g   = im2double(g);

% ---- 2. Background/illumination correction + multi-scale vessel contrast --
% Closing-based top-hat: imbothat(g,disk) = imclose(g,disk) - g. It removes
% the local background level (illumination trend) and responds only to dark
% structures narrower than the disk. The max over increasing scales keeps
% both thin and thick vessels and ignores bright lesions / optic disc.
vess = zeros(size(g));
for k = 1:numel(P.morphThickness)
    vess = max(vess, imbothat(g, strel('disk', P.morphThickness(k))));
end
vess = mat2gray(vess);

% ---- 3. Tubularity gating with fibermetric (Frangi) ------------------------
gate = fibermetric(vess, P.gateThickness, 'ObjectPolarity', P.gatePolarity);
gate = mat2gray(im2double(gate));
response = vess .* (1 - P.gateWeight + P.gateWeight * gate);
response = mat2gray(response);

% ---- 4. Thresholding -------------------------------------------------------
% (FOV mask is needed by the 'percentile' method, so resolve it first.)
if ~isempty(fovUser)
    fov = logical(fovUser);
else
    fov = autoFOV(g0, P.fovErodeRadius);
end
switch lower(P.thresholdMethod)
    case 'otsu'
        level    = P.thresholdScale * graythresh(response);
        vessels  = response > level;
    case 'adaptive'
        tMap     = adaptthresh(response, P.adaptSensitivity);
        vessels  = response > tMap;
    case 'percentile'
        % Keep the brightest `thresholdFrac` fraction of FOV pixels as vessels
        % (density-based thresholding; robust to acquisition gain/contrast).
        level    = prctile(response(fov), 100*(1 - P.thresholdFrac));
        vessels  = response > level;
    otherwise
        error('extractVessels:badMethod', ...
            'thresholdMethod must be ''otsu'', ''adaptive'' or ''percentile'', got %s.', ...
            P.thresholdMethod);
end

% ---- 5. Morphological cleanup ---------------------------------------------
vessels = bwmorph(vessels, 'clean');               % isolated pixels

% Orientation-preserving opening: a pixel survives only if it is part of a
% line-like structure aligned with one of the tested angles. This kills
% salt-and-pepper / blobby noise while keeping vessels of any orientation.
lineOpening = false(size(vessels));
for k = 1:numel(P.lineAngles)
    seLine = strel('line', P.lineLength, P.lineAngles(k));
    lineOpening = lineOpening | imopen(vessels, seLine);
end
vessels = vessels & lineOpening;

vessels = imclose(vessels, strel('disk', P.closeDisk)); % reconnect breaks
vessels = bwareaopen(vessels, P.minArea);               % drop small specks

% ---- 6. Field-of-view restriction (mask already computed for %ile) ---------
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
                    error('extractVessels:badArg', ...
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
        error('extractVessels:badParams', 'Params override must be a struct.');
    end
    fnames = fieldnames(override);
    for i = 1:numel(fnames)
        if isfield(P, fnames{i})
            P.(fnames{i}) = override.(fnames{i});
        else
            warning('extractVessels:unknownParam', ...
                'Ignoring unknown parameter ''%s''.', fnames{i});
        end
    end
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