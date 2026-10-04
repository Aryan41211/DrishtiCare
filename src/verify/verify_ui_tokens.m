% verify_ui_tokens.m
% Contract gate for the DrishtiCare light clinical token layer.
%
% Asserts: every token field exists; every text pair clears WCAG AA 4.5:1;
% inkFaint, the non-text colour, clears 3:1; the spacing scale is a 4px
% progression; the theme Grad-CAM colormap actually exists on this MATLAB
% install. `hairline` is a documented decorative exception - it is MEASURED
% and printed (section 2c) but deliberately NOT asserted, because a panel
% boundary is already identified by the surface/canvas background difference
% and by spacing.
%
% SCOPE: read-only. Presentation only - touches no model, threshold or metric.
% Run from the repo root:
%   matlab -batch "run('src/verify/verify_ui_tokens.m')"
%
% Terminator on success: ALL UI TOKEN CHECKS PASS

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(projectRoot);
addpath(fullfile(projectRoot, 'src', 'ui'));

fprintf('== UI token contract audit ==\n');
nPass = 0;
t = drishtiTokens();

%% 1. Field presence
required = {'canvas','surface','sunken','hairline','ink','inkMuted','inkFaint', ...
    'danger','success','warningFill','warningInk','primary', ...
    'successBg','dangerBg','type','spacing'};
for k = 1:numel(required)
    assert(isfield(t, required{k}), sprintf('token field missing: %s', required{k}));
    v = t.(required{k});
    if ~isstruct(v)
        assert(isequal(size(v), [1 3]), sprintf('%s must be 1x3 RGB', required{k}));
        assert(all(v >= 0 & v <= 1), sprintf('%s must be within [0 1]', required{k}));
    end
end
typeNames = {'display','metric','body','label','caption'};
for k = 1:5
    assert(isfield(t.type, sprintf('t%d', k)) || ...
           isfield(t.type, typeNames{k}), ...
        'type scale incomplete');
end
fprintf('OK  1. all %d token fields present and in range\n', numel(required));
nPass = nPass + 1;

%% 2. Contrast floors - text >= 4.5:1, non-text >= 3:1
% One row per pair: {foreground name, foreground RGB, background name, background RGB}.
% The RGB columns are validated below before any ratio is taken, so a mistyped
% table cell fails loudly instead of silently comparing a colour against its
% own name (a char array, whose "luminance" is enormous and clears any floor).
textPairs = { ...
    'ink',        t.ink,        'surface',   t.surface; ...
    'ink',        t.ink,        'sunken',    t.sunken; ...
    'ink',        t.ink,        'canvas',    t.canvas; ...
    'inkMuted',   t.inkMuted,   'surface',   t.surface; ...
    'inkMuted',   t.inkMuted,   'sunken',    t.sunken; ...
    'inkMuted',   t.inkMuted,   'canvas',    t.canvas; ...
    'inkMuted',   t.inkMuted,   'successBg', t.successBg; ...
    'inkMuted',   t.inkMuted,   'dangerBg',  t.dangerBg; ...
    'danger',     t.danger,     'surface',   t.surface; ...
    'danger',     t.danger,     'sunken',    t.sunken; ...
    'danger',     t.danger,     'dangerBg',  t.dangerBg; ...
    'success',    t.success,    'surface',   t.surface; ...
    'success',    t.success,    'successBg', t.successBg; ...
    'warningInk', t.warningInk, 'warningFill', t.warningFill; ...
    'primary',    t.primary,    'surface',   t.surface; ...
    'primary',    t.primary,    'sunken',    t.sunken};
assertPairsAreColours(textPairs, 'textPairs');
worst = Inf;
for k = 1:size(textPairs, 1)
    fg = textPairs{k, 2}; bgv = textPairs{k, 4};
    r = ratio(fg, bgv);
    worst = min(worst, r);
    assert(r >= 4.5, sprintf('%s on %s = %.2f:1, below AA 4.5:1', ...
        textPairs{k,1}, textPairs{k,3}, r));
end
fprintf('OK  2a. %d text pairs clear AA 4.5:1 (worst %.2f:1)\n', size(textPairs,1), worst);
nPass = nPass + 1;

nonTextPairs = {'inkFaint', t.inkFaint, 'surface', t.surface; ...
                'inkFaint', t.inkFaint, 'sunken',  t.sunken; ...
                'inkFaint', t.inkFaint, 'canvas',  t.canvas};
assertPairsAreColours(nonTextPairs, 'nonTextPairs');
worstN = Inf;
for k = 1:size(nonTextPairs, 1)
    r = ratio(nonTextPairs{k,2}, nonTextPairs{k,4});
    worstN = min(worstN, r);
    assert(r >= 3.0, sprintf('inkFaint on %s = %.2f:1, below 3:1 non-text floor', ...
        nonTextPairs{k,3}, r));
end
fprintf('OK  2b. inkFaint clears 3:1 on every surface (worst %.2f:1)\n', worstN);
nPass = nPass + 1;

%% 2c. hairline is DECORATIVE - measured and reported, deliberately NOT asserted
% Panel boundaries are already identified by the surface/canvas background
% difference and by spacing, so the hairline is not the affordance WCAG 1.4.11
% asks about. It is printed here so anyone who later leans on it as a
% load-bearing boundary can see the number instead of assuming it was checked.
rHair = [ratio(t.hairline, t.surface), ratio(t.hairline, t.sunken), ...
         ratio(t.hairline, t.canvas)];
fprintf('INFO 2c. hairline is decorative: surface %.2f:1, sunken %.2f:1, canvas %.2f:1 - below the 3:1 non-text floor by design, not asserted\n', ...
    rHair(1), rHair(2), rHair(3));

%% 3. White on primary (button label)
r = ratio([1 1 1], t.primary);
assert(r >= 4.5, sprintf('white on primary = %.2f:1, below 4.5:1', r));
fprintf('OK  3. white on primary %.2f:1\n', r);
nPass = nPass + 1;

%% 4. The Grad-CAM colormap named by the theme must exist on THIS install
th = drishtiTheme();
cm = th.gradcam.colormap;
assert(exist(cm, 'file') == 2 || exist(cm, 'builtin') == 5, ...
    sprintf('theme colormap "%s" is not available in this MATLAB install', cm));
fprintf('OK  4. theme colormap "%s" resolves on this install\n', cm);
nPass = nPass + 1;

%% 5. Spacing scale is a 4px progression
sp = [t.spacing.s1 t.spacing.s2 t.spacing.s3 t.spacing.s4 t.spacing.s5];
assert(all(diff(sp) > 0), 'spacing scale must increase');
assert(all(mod(sp, 4) == 0), 'spacing scale must be a multiple of 4');
fprintf('OK  5. spacing scale [%s] is a 4px progression\n', num2str(sp));
nPass = nPass + 1;

fprintf('\nCHECKS: %d\n', nPass);
fprintf('ALL UI TOKEN CHECKS PASS\n');

% -------------------------------------------------------------------------
function assertPairsAreColours(pairs, name)
%ASSERTPAIRSARECOLOURS Every {fg name, fg RGB, bg name, bg RGB} row is well formed.
% Guards the contrast checks against a table whose RGB columns hold names
% instead of colours - such a row measures a char array and clears any floor.
assert(isequal(size(pairs, 2), 4), ...
    sprintf('%s must be an Nx4 table: {fg name, fg RGB, bg name, bg RGB}', name));
for k = 1:size(pairs, 1)
    for c = [2 4]
        v = pairs{k, c};
        assert(isnumeric(v) && isequal(size(v), [1 3]) && ...
               all(isfinite(v)) && all(v >= 0 & v <= 1), ...
            sprintf('%s row %d column %d must be a 1x3 RGB triple in [0 1]', name, k, c));
    end
end
end

function r = ratio(a, b)
L1 = relLum(a); L2 = relLum(b);
hi = max(L1, L2); lo = min(L1, L2);
r = (hi + 0.05) / (lo + 0.05);
end

function L = relLum(rgb)
v = double(rgb);
lo = v <= 0.03928;
v(lo) = v(lo) / 12.92;
hi = ~lo;
v(hi) = ((v(hi) + 0.055) / 1.055) .^ 2.4;
L = 0.2126 * v(1) + 0.7152 * v(2) + 0.0722 * v(3);
end
