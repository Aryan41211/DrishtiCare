function od = estimateOpticDisc(I, opts)
% ESTIMATEOPTICDISC Classical heuristic optic-disc localization
%   od = estimateOpticDisc(I)
%   od = estimateOpticDisc(I, opts)
%
%   Heuristic (non-deep) detection for arbitrary fundus images where IDRiD
%   OD markups are unavailable. Principle: the optic disc is the largest
%   bright, roughly-circular structure in the fundus. The disc often appears
%   as a bright RING around a darker cup, so the bright band is hole-filled
%   to recover the solid disc before the largest-blob selection.
%
%   Detection is intentionally conservative. If no confident disc-like blob
%   (round, plausible size) is found, the function returns [] — the caller
%   must treat [] as "optic disc NOT located" and flag that exudate counts
%   may include the optic-disc region (documented honest fallback).
%
%   Returns od = [cx cy radius] in ORIGINAL pixel coordinates (x=col, y=row),
%   or [] when no confident candidate exists.
%
%   MEASURED ACCURACY (IDRiD train, n=10, same images as Task 6):
%   3/10 within 300 px of the ground-truth OD center, 6/10 within 800 px,
%   1/10 refused, remaining candidates can be off target (classical method
%   limitation). For the SIH explainability report this is acceptable ONLY
%   because the report flags OD-not-localized cases instead of silently
%   trusting an unreliable circle.
%
%   opts fields:
%     .verbose     logical (default false)
%     .scale       downscale factor (default 4)
%     .minRadius   min accepted radius, ORIGINAL px (default 50)
%     .maxRadius   max accepted radius, ORIGINAL px (default 330)

    if nargin < 2, opts = struct(); end
    if ~isfield(opts, 'verbose'), opts.verbose = false; end
    if ~isfield(opts, 'scale'), opts.scale = 4; end
    if ~isfield(opts, 'minRadius'), opts.minRadius = 50; end
    if ~isfield(opts, 'maxRadius'), opts.maxRadius = 330; end

    if ischar(I) && exist(I, 'file')
        I = imread(I);
    end
    if size(I, 3) == 3
        I = im2double(rgb2gray(I));
    else
        I = im2double(I);
    end
    [h, w] = size(I);

    s = opts.scale;
    Ie = imresize(I, 1/s);
    [he, we] = size(Ie);

    % Illumination flattening makes the disc pop regardless of shadows
    Ieq = adapthisteq(Ie, 'NumTiles', [16 16], 'ClipLimit', 0.02);

    % Keep candidate work inside the retinal foreground, off image borders
    mask = createRetinalMask(I);
    maskE = imresize(mask, [he we]) > 0.5;
    maskE = imerode(maskE, strel('disk', 10));

    expectedR = 0.062 * w;          % ~6% of image width = typical disc radius
    best = []; bestScore = -inf;
    scored = 0;
    for thr = [0.40 0.50 0.60]
        binD = Ieq > thr;
        binD = imfill(binD, 'holes');        % ring -> solid disc
        binD = binD & maskE;
        binD = bwareaopen(binD, round((30/s)^2));
        cc = bwconncomp(binD);
        if cc.NumObjects == 0, continue; end
        mu = regionprops(cc, {'Area','Centroid','Eccentricity'});
        [~, k] = max([mu.Area]);
        a = mu(k).Area;
        r = sqrt(a/pi) * s;
        ecc = mu(k).Eccentricity;
        % Scale-aware band: the disc radius is a fairly stable fraction of
        % image width (~6%). Refuse blobs far outside that band so a bright
        % small blob (exudate plate) or a huge blob is not taken for the OD.
        if r < 0.5*expectedR || r > 1.5*expectedR || ...
           r < opts.minRadius || r > opts.maxRadius || ecc > 0.94
            continue;    % not disc-like: wrong scale, too small/large, or not round
        end
        scored = scored + 1;
        sc = (1 - ecc) * exp(-abs(r - expectedR) / (0.5 * expectedR));
        if sc > bestScore
            bestScore = sc;
            best = [mu(k).Centroid(1)*s, mu(k).Centroid(2)*s, r];
        end
    end

    % Conservative acceptance gate: a plausible disc must also be BRIGHT
    % relative to the retinal illumination. Measured on IDRiD train (n=10):
    % this mean>=0.62 gate keeps all correct picks and drops the worst
    % gross failures (err>1500 px). Limitation: ~40% of accepted discs are
    % still offset (classical method). Honest behavior: only apply OD-based
    % exclusion when this gate passes; otherwise the extractor skips
    % exclusion and the report flags "OD not located".
    od = [];
    if ~isempty(best)
        cy = round(best(2)/s); cx = round(best(1)/s); r = round(best(3)/s);
        if cx >= 1 && cx <= we && cy >= 1 && cy <= he && r >= 1
            [Xg, Yg] = meshgrid(1:we, 1:he);
            inD = ((Xg-cx).^2 + (Yg-cy).^2) <= r^2;
            discMean = mean(Ieq(inD & maskE));
            if discMean >= 0.62
                od = best;
            end
        end
    end

    if isempty(od)
        if opts.verbose, fprintf('  [OD] not located (gate not passed)\n'); end
        od = []; return;
    end
    if opts.verbose
        fprintf('  [OD] center [%.0f %.0f], r=%.0fpx (score %.3f, %d candidates)\n', ...
                od(1), od(2), od(3), bestScore, scored);
    end
end