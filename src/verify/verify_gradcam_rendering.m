% verify_gradcam_rendering.m
% Deterministic audit of the four Grad-CAM rendering properties that the
% EXECUTION_CHECKLIST previously left as "not verified as a discrete check":
%
%   1. normalization        - map is mapped to [0 1] before any colouring
%   2. resize/interpolation - heatmap is resampled to the base image size
%   3. colour-space         - every emitted colour is a colormap entry (this
%                             is what proves the colormap is applied AFTER
%                             the resize, not before)
%   4. alpha blending       - the implied per-pixel opacity is recovered from
%                             the output and compared to the theme bounds
%
% Two extra contract checks are included because the audit depends on them:
%   5. the input map is never mutated (rendering is presentation-only)
%   6. repeated calls are bit-identical (determinism)
%
% SCOPE: this audits src/ui/renderGradCAMViews.m only. It does NOT recompute
% Grad-CAM, does NOT touch any network, and does NOT alter a model, threshold
% or metric. It is a read-only check of the rendering layer.
%
% Run from the repo root:
%   matlab -batch "run('src/verify/verify_gradcam_rendering.m')"
%
% Terminator on success: ALL GRADCAM RENDERING AUDIT CHECKS PASS

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(projectRoot);
addpath(fullfile(projectRoot, 'src', 'ui'));

fprintf('== Grad-CAM rendering audit (renderGradCAMViews) ==\n');

th = drishtiTheme();
nPass = 0;

%% 0. Colormap contract
map = drishtiColormap(th.gradcam.colormap);
assert(isequal(size(map), [256 3]), 'colormap is 256 x 3');
assert(all(map(:) >= 0 & map(:) <= 1), 'colormap within [0 1]');
fprintf('OK  0. colormap %s is 256 x 3, low->high\n', th.gradcam.colormap);
nPass = nPass + 1;

%% Deterministic fixtures (no RNG anywhere in this script)
% Map deliberately spans negative and >1 values so that a correct
% normalization must clamp it into [0 1].
rawMap = linspace(-3, 5, 32);
rawMap = repmat(rawMap, 32, 1);
mapBefore = rawMap;                       % for the no-mutation check

% Mid-gray base so the alpha recovery is well conditioned.
baseImg = uint8(repmat(128, 48, 64, 3));

[overlay, heatRGB, heatmap] = renderGradCAMViews(rawMap, baseImg);
fprintf('OK  fixtures built (map 32x32 spanning -3..5, base 48x64x3)\n');

%% 1. Normalization
% Isolated first: render against a base image the SAME size as the map so no
% resize happens. Whatever this returns is the pure normalization result.
baseSame = uint8(repmat(128, size(rawMap, 1), size(rawMap, 2), 3));
[~, ~, hmNorm] = renderGradCAMViews(rawMap, baseSame);
assert(isnumeric(hmNorm) && isreal(hmNorm), 'normalized map is real numeric');
assert(min(hmNorm(:)) >= 0 && max(hmNorm(:)) <= 1, 'normalized map within [0 1]');
assert(abs(min(hmNorm(:)) - 0) < 1e-12, 'normalized map min is 0');
assert(abs(max(hmNorm(:)) - 1) < 1e-12, 'normalized map max is 1');
fprintf('OK  1a. normalization (no resize): raw -3..5 -> [%.6f .. %.6f] via mat2gray\n', ...
    min(hmNorm(:)), max(hmNorm(:)));

% The resized path is measured separately because the theme selects bicubic
% interpolation, and bicubic upscaling is allowed to ring slightly outside the
% source range. That overshoot is quantified below rather than asserted away.
overshoot = max([0, -min(heatmap(:)), max(heatmap(:)) - 1]);
fprintf('OK  1b. post-resize range [%.6f .. %.6f] (bicubic overshoot %.6f)\n', ...
    min(heatmap(:)), max(heatmap(:)), overshoot);
assert(overshoot < 0.05, 'post-resize overshoot is small (bicubic ringing)');
nPass = nPass + 1;

%% 2. Resize / interpolation
szMap = size(rawMap);
szBase = size(baseImg);
szHeat = size(heatmap);
assert(szHeat(1) == szBase(1) && szHeat(2) == szBase(2), ...
    'heatmap resampled to base image resolution');
assert(szMap(1) ~= szHeat(1) || szMap(2) ~= szHeat(2), ...
    'the fixture actually exercises a resize');
fprintf('OK  2. resize: %dx%d map -> %dx%d heatmap (base %dx%d, interp=%s)\n', ...
    szMap(1), szMap(2), szHeat(1), szHeat(2), szBase(1), szBase(2), th.gradcam.interp);
nPass = nPass + 1;

%% 3. Colour-space handling + colormap-applied-after-resize
assert(isa(overlay, 'uint8'), 'overlay is uint8');
assert(isa(heatRGB, 'uint8'), 'heatRGB is uint8');
assert(size(overlay, 3) == 3, 'overlay is 3-channel RGB (not grayscale)');
assert(size(heatRGB, 3) == 3, 'heatRGB is 3-channel RGB');
assert(isequal(size(overlay), szBase), 'overlay matches base size');
assert(isequal(size(heatRGB), szBase), 'heatRGB matches base size');

% Every distinct emitted colour must be an exact colormap entry. This only
% holds when the scalar map is resized FIRST and indexed into the colormap
% afterwards; colouring before the resize would interpolate between colours
% and produce entries that are not in the map.
map255 = uint8(round(map * 255));
cols = reshape(heatRGB, [], 3);
uniq  = unique(cols, 'rows');
maxDev = 0;
for i = 1:size(uniq, 1)
    d = abs(double(map255) - double(uniq(i, :)));
    maxDev = max(maxDev, min(max(d, [], 2)));
end
assert(maxDev <= 1, 'all emitted colours are colormap entries');
% Colormap indices 0 and 255 are turbo's legitimate endpoints, so a ramp that
% spans the full range will legitimately reach them. What must not happen is a
% non-finite value or a colour outside the map - maxDev above already rules the
% second out. Here we bound how much of the frame sits on those endpoints.
nPix = numel(heatmap);
nEndpoint = sum(reshape(heatRGB, [], 3) == 0, 'all') + ...
            sum(reshape(heatRGB, [], 3) == 255, 'all');
assert(all(isfinite(double(overlay(:)))) && all(isfinite(double(heatRGB(:)))), ...
    'no non-finite pixel in the emitted images');
assert(nEndpoint / nPix < 0.10, 'colormap endpoints confined to a small fraction of the frame');
fprintf('OK  3. colour-space: uint8 RGB, %d distinct colours, max colormap deviation %d/255, %.2f%% at map endpoints, no non-finite px\n', ...
    size(uniq, 1), maxDev, 100 * nEndpoint / nPix);
nPass = nPass + 1;

%% 4. Alpha blending - recover the implied opacity from the output
% overlay = alpha .* heatRGB + (1 - alpha) .* base
%   =>  alpha = (overlay - base) ./ (heatRGB - base)
% The fixture is a left-to-right ramp, so the first column is the minimum
% activation and the last column is the maximum.
hmRGB = ind2rgb(im2uint8(heatmap), map);
base  = im2double(baseImg);
num   = double(overlay) / 255 - base;      % both sides in double [0 1]
den   = hmRGB - base;

% Recover a per-channel opacity, keeping only channels where the colormap
% colour is far enough from the base grey to make the ratio meaningful.
% (turbo passes close to neutral grey in its mid-range, and its top colour is
% a dark red that sits near mid grey in the red channel, so some channels are
% deliberately excluded as ill-conditioned rather than silently averaged in.)
%
% Tolerance rationale: the overlay is stored as uint8, so each recovered
% opacity carries a quantisation error of about (1/255)/|den|. With the
% conditioning floor at COND_MIN that is at most 1/(255*COND_MIN); TOL is set
% just above it. A genuine alpha-policy error (for example applying one
% constant opacity everywhere) would move these estimates by ~0.18, far
% outside TOL, so the check still discriminates.
COND_MIN = 0.15;
valid = abs(den) > COND_MIN;
alphaCh = nan(size(den));
alphaCh(valid) = num(valid) ./ den(valid);
assert(nnz(valid) > 0.2 * numel(valid), 'alpha recovery is well conditioned');

% The fixture is a left-to-right ramp, so column 1 is the minimum activation
% and the last column is the maximum. Take every well-conditioned channel in
% those columns rather than relying on per-pixel NaN handling.
colLo = alphaCh(:, 1, :);  colLo = colLo(isfinite(colLo));
colHi = alphaCh(:, end, :); colHi = colHi(isfinite(colHi));
assert(~isempty(colLo) && ~isempty(colHi), 'both ramp ends yield an alpha estimate');
aLo = median(colLo);
aHi = median(colHi);

% Every recovered opacity must sit inside the theme's declared alpha window.
TOL = 1 / (255 * COND_MIN) + 0.005;
allA = alphaCh(isfinite(alphaCh));
assert(min(allA) >= th.gradcam.alphaLo - TOL, ...
    'no pixel is more transparent than the theme alphaLo');
assert(max(allA) <= th.gradcam.alphaHi + TOL, ...
    'no pixel is more opaque than the theme alphaHi');
assert(aHi > aLo, 'alpha increases with activation');

assert(abs(aLo - th.gradcam.alphaLo) <= TOL, ...
    sprintf('implied alpha at min activation matches alphaLo (got %.4f, want %.4f)', ...
        aLo, th.gradcam.alphaLo));
assert(abs(aHi - th.gradcam.alphaHi) <= TOL, ...
    sprintf('implied alpha at max activation matches alphaHi (got %.4f, want %.4f)', ...
        aHi, th.gradcam.alphaHi));
fprintf('OK  4. alpha blending: implied alpha %.4f (min act) -> %.4f (max act); theme [%.2f .. %.2f]\n', ...
    aLo, aHi, th.gradcam.alphaLo, th.gradcam.alphaHi);
fprintf('       recovered range [%.4f .. %.4f] over %d well-conditioned samples (uint8 tol %.4f)\n', ...
    min(allA), max(allA), numel(allA), TOL);
nPass = nPass + 1;

%% 5. The input map is never mutated (rendering is presentation-only)
assert(isequal(rawMap, mapBefore), 'input Grad-CAM map is not mutated');
fprintf('OK  5. input map unchanged (rendering does not alter Grad-CAM values)\n');
nPass = nPass + 1;

%% 6. Determinism
[ov2, hr2, hm2] = renderGradCAMViews(rawMap, baseImg);
assert(isequal(overlay, ov2) && isequal(heatRGB, hr2) && isequal(heatmap, hm2), ...
    'repeated render is bit-identical');
fprintf('OK  6. determinism: repeated render is bit-identical\n');
nPass = nPass + 1;

%% 7. Graceful degradation on missing evidence
[ovE, hrE, hmE] = renderGradCAMViews([], baseImg);
assert(isempty(ovE) && isempty(hrE) && isempty(hmE), 'empty map degrades to empty');
fprintf('OK  7. empty Grad-CAM map degrades gracefully (report omits the block)\n');
nPass = nPass + 1;

%% 8. The required scientific disclaimer is still carried by the theme
assert(contains(th.gradcam.disclaimer, 'not validated lesion localization'), ...
    'theme still carries the not-validated-lesion-localization disclaimer');
fprintf('OK  8. disclaimer present: "%s"\n', th.gradcam.disclaimer);
nPass = nPass + 1;

fprintf('\nCHECKS: %d\n', nPass);
fprintf('ALL GRADCAM RENDERING AUDIT CHECKS PASS\n');
