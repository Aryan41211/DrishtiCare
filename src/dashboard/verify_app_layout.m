% verify_app_layout.m
% Layout audit for the DRISHTI screening app (RetinaAIApp).
%
% PURPOSE
%   EXECUTION_CHECKLIST.md Phase B carried an unticked "verify responsive
%   layout" box, annotated "not verified ... it does not assert layout at more
%   than one window size". This script establishes the facts about the layout
%   instead of leaving the box ambiguous:
%
%     1. every visible component sits inside the figure bounds at the design
%        size (no clipping, no zero-extent, no off-canvas control)
%     2. no component overlaps the header or footer bands
%     3. the figure's resize policy and design canvas size
%     4. whether the default window fits on the current primary screen
%
%   The app positions everything absolutely against a fixed canvas rather than
%   using a uigridlayout, so "responsive layout at multiple window sizes" is
%   not a property this app has. That is reported as a fact, not asserted as a
%   pass.
%
% SCOPE: read-only. Instantiates the app headlessly, measures geometry, closes
% it. Loads no model, touches no threshold, metric or calibration value, and
% runs no inference.
%
% Run from the repo root:
%   matlab -batch "run('src/dashboard/verify_app_layout.m')"
%
% Terminator on success: ALL DRISHTI APP LAYOUT CHECKS PASS

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(projectRoot);
addpath(genpath(fullfile(projectRoot, 'src')));

fprintf('== DRISHTI app layout audit ==\n');
nPass = 0;

app = RetinaAIApp();
drawnow;
fig = app.UIFigure;
assert(isvalid(fig), 'UIFigure is valid');

%% 1. Design canvas and resize policy
pos = fig.Position;
fprintf('INFO figure Position      = [%g %g %g %g]\n', pos(1), pos(2), pos(3), pos(4));
fprintf('INFO figure Resize        = %s\n', char(fig.Resize));
ss = get(groot, 'ScreenSize');
fprintf('INFO primary screen       = [%g %g]\n', ss(3), ss(4));
isFixed = strcmpi(char(fig.Resize), 'off');
fprintf('INFO fixed-canvas design  = %s\n', ternary(isFixed, 'yes (Resize off)', 'no'));

%% 2. Walk every descendant and compute its absolute position
% Positions in MATLAB UI components are relative to the parent, so the absolute
% rectangle is the sum of the chain up to the figure.
items = collect(fig, 0, 0);
fprintf('INFO descendants measured = %d\n', numel(items));

figL = 0; figB = 0;
figR = pos(3); figT = pos(4);

nClipped = 0; nZero = 0; nBad = 0;
for k = 1:numel(items)
    it = items(k);
    p = it.pos;
    if p(3) <= 0 || p(4) <= 0
        nZero = nZero + 1;
        fprintf('WARN zero/negative extent: %s [%g %g %g %g]\n', it.name, p(1), p(2), p(3), p(4));
        continue;
    end
    if p(1) < figL - 0.5 || p(2) < figB - 0.5 || ...
       p(1) + p(3) > figR + 0.5 || p(2) + p(4) > figT + 0.5
        nClipped = nClipped + 1;
        if nClipped <= 10
            fprintf('WARN outside figure: %-28s [%g %g %g %g]\n', it.name, p(1), p(2), p(3), p(4));
        end
    end
end
fprintf('INFO clipped by figure    = %d\n', nClipped);
fprintf('INFO zero-extent          = %d\n', nZero);
assert(nClipped == 0, 'no component is clipped by the figure at the design size');
assert(nZero == 0, 'no component has a zero or negative extent');
fprintf('OK  1. all %d components lie inside the %gx%g canvas\n', numel(items), figR, figT);
nPass = nPass + 1;

%% 3. The layout bands must tile without overlap
% Bands are the app's top-level bands, not every nested panel: they are found by
% walking down at most two grid levels from the figure. `fig.Children` is not
% usable - it returns only the root container once the bands are nested inside
% uigridlayout, and a uigridlayout is deliberately not a
% matlab.ui.container.Panel, so the Panel filter over fig.Children matched
% nothing at all. The panel interiors in turn contain nested panels (the quality
% well, the pipeline track) which are deliberately EXCLUDED here: they are not
% bands, and counting them would break the shared-band assertion below.
rects = bandRects(fig);
assert(~isempty(rects), 'the figure exposes at least one layout band');
fprintf('INFO bands discovered      = %d\n', size(rects, 1));

topY   = rects(:, 2) + rects(:, 4);
isHead = abs(topY - figT) < 0.5;    % flush with the top of the canvas
nHead  = sum(isHead);
assert(nHead == 1, 'exactly one header band sits flush with the top');

rest   = rects(~isHead, :);
minY   = min(rest(:, 2));
isFoot = ~isHead & abs(rects(:, 2) - minY) < 0.5;
nFoot  = sum(isFoot);
assert(nFoot == 1, 'exactly one bottom bar is the lowest band');

isBody = ~isHead & ~isFoot;
nBody  = sum(isBody);
fprintf('INFO layout bands         = %d header, %d content, %d bottom\n', ...
    nHead, nBody, nFoot);
assert(nBody >= 3, 'at least three content panels tile the middle of the canvas');

head = rects(isHead, :);
foot = rects(isFoot, :);
body = sortrows(rects(isBody, :), 1);
for i = 1:nBody
    fprintf('INFO content panel %d     [%g %g %g %g]\n', i, body(i,1), body(i,2), body(i,3), body(i,4));
end
for i = 1:nBody-1
    a = body(i, :); b = body(i+1, :);
    assert(a(2) == b(2) && a(4) == b(4), ...
        'content panels %d and %d share the same vertical band', i, i+1);
    assert(a(1) + a(3) <= b(1) + 0.5, ...
        'content panel %d ends before panel %d begins (no overlap)', i, i+1);
end
fprintf('OK  2. %d content panels share one band and are ordered left to right\n', nBody);
nPass = nPass + 1;

footTop = foot(2) + foot(4);
headBot = head(2);
for i = 1:nBody
    q = body(i, :);
    assert(q(2) >= footTop - 0.5, 'content panel %d clears the bottom bar', i);
    assert(q(2) + q(4) <= headBot + 0.5, 'content panel %d clears the header band', i);
end
fprintf('OK  3. content panels clear the header band (y<=%g) and bottom bar (y>=%g)\n', ...
    headBot, footTop);
nPass = nPass + 1;

%% 4. The app must be grid-driven and resizable
grids = findall(fig, 'Type', 'uigridlayout');
assert(~isempty(grids), 'the app must be built on a uigridlayout root');
isFixed = strcmpi(char(fig.Resize), 'off');
assert(~isFixed, 'the figure must be resizable (Resize on), not a fixed canvas');
fprintf('OK  4. grid-driven root (%d uigridlayout containers), Resize=%s\n', ...
    numel(grids), char(fig.Resize));
nPass = nPass + 1;

%% 6. Does the default window fit the current screen?
screenW = ss(3); screenH = ss(4);
fits = (pos(1) >= 0) && (pos(2) >= 0) && ...
       (pos(1) + pos(3) <= screenW) && (pos(2) + pos(4) <= screenH);
fprintf('INFO window right edge     = %g (screen width %g)\n', pos(1) + pos(3), screenW);
fprintf('INFO window top edge       = %g (screen height %g)\n', pos(2) + pos(4), screenH);
fprintf('INFO fits on this screen   = %s\n', ternary(fits, 'yes', 'NO'));
% This is reported, not asserted: it depends on the machine the audit runs on.
nPass = nPass + 1;

app.delete();
fprintf('\nCHECKS: %d\n', nPass);
fprintf('ALL DRISHTI APP LAYOUT CHECKS PASS\n');

% -------------------------------------------------------------------------
function out = collect(h, x0, y0)
% Recursively collect absolute rectangles of every descendant.
out = struct('name', {}, 'pos', {});
kids = findall(h);
kids = kids(~ismember(kids, h));
for i = 1:numel(kids)
    k = kids(i);
    try
        p = k.Position;
    catch
        continue;
    end
    % Some component types (e.g. uilinearprogress) expose a 2-element Position.
    % Those carry no rectangle, so they are not part of a geometry audit.
    if numel(p) < 4
        continue;
    end
    nm = class(k);
    try
        if isprop(k, 'Text') && ischar(k.Text) && ~isempty(k.Text)
            nm = sprintf('%s "%s"', class(k), strtrim(k.Text));
        end
    catch
    end
    out(end+1) = struct('name', nm, 'pos', [p(1) + x0, p(2) + y0, p(3), p(4)]); %#ok<AGROW>
    out = [out, collect(k, p(1) + x0, p(2) + y0)]; %#ok<AGROW>
end
end

% -------------------------------------------------------------------------
function r = absPos(h, fig)
% Absolute rectangle of h relative to fig, by summing the parent chain.
% Stops AT fig: a uifigure is not matched by ancestor(...,'figure'), so the
% walk has to be terminated against the figure handle explicitly. Otherwise the
% figure's own Position gets folded in and every band is displaced.
x0 = 0; y0 = 0;
cur = h;
while ~isempty(cur) && isvalid(cur) && ~isequal(cur, fig)
    p = cur.Position;
    if numel(p) >= 4
        x0 = x0 + p(1);
        y0 = y0 + p(2);
    end
    if isempty(cur.Parent)
        break;
    end
    cur = cur.Parent;
end
% h's own position is already included by the first loop iteration, so the
% origin is the accumulated sum and the extent comes straight from h.
p = h.Position;
r = [x0, y0, p(3), p(4)];
end

% -------------------------------------------------------------------------
function rects = bandRects(fig)
%BANDRECTS Absolute rectangles of the app's top-level layout bands.
%   A band is a uipanel sitting directly on the root grid, or directly on a grid
%   that sits directly on the root grid. Panels nested deeper (inside a band) are
%   interiors, not bands.
grids = findall(fig, 'Type', 'uigridlayout');
rects = [];
for g = 1:numel(grids)
    % Do not depend on which shape findall happens to return: normalise to a
    % cell array and filter with cellfun throughout, so the discovery reports a
    % layout defect rather than an unrelated exception if that shape ever changes.
    kids = findall(grids(g));
    if ~iscell(kids)
        kids = num2cell(kids);
    end
    isPanel = cellfun(@(c) isa(c, 'matlab.ui.container.Panel') && ...
        ~isa(c, 'matlab.ui.container.GridLayout'), kids);
    kids = kids(isPanel);
    % keep only direct children of this grid
    kids = kids(cellfun(@(c) isequal(c.Parent, grids(g)), kids));
    for i = 1:numel(kids)
        rects(end+1, :) = absPos(kids{i}, fig); %#ok<AGROW>
    end
end
end

% -------------------------------------------------------------------------
function s = ternary(c, a, b)
if c, s = a; else, s = b; end
end
