% CAPTURE_UI_STATES Drive RetinaAIApp through key states and export screenshots.
%   Run:  matlab -batch "run('capture_ui_states.m')"
%
addpath(genpath('src'));

% Find a real sample image for testing.
valDir = fullfile(pwd, 'data', 'splits', 'val');
sample = '';
if exist(valDir, 'dir')
    d = dir(fullfile(valDir, 'class_0', '*.png'));
    if ~isempty(d)
        sample = fullfile(valDir, 'class_0', d(1).name);
    end
end
if isempty(sample)
    error('No sample image found in data/splits/val/class_0/');
end
fprintf('Using sample: %s\n', sample);

% ---- State 1: initial empty state ----
fprintf('\n=== STATE 1: Initial empty state ===\n');
app = RetinaAIApp();
drawnow;
pause(1);
exportapp(app.UIFigure, fullfile(pwd, 'docs', 'ui-reference', 'actual-01-initial.png'));
fprintf('  Saved actual-01-initial.png\n');

% ---- State 2: image loaded ----
fprintf('\n=== STATE 2: Image loaded ===\n');
imgAxes = findobj(app.UIFigure, 'Tag', 'fundusAxes');
img = imread(sample);
if size(img, 3) == 1, img = repmat(img, 1, 1, 3); end
cla(imgAxes);
imshow(img, 'Parent', imgAxes);
title(imgAxes, '');
[rows, cols, ~] = size(img);
h = findobj(app.UIFigure, 'Text', 'Resolution: —  ·  Quality: —');
if ~isempty(h), h.Text = sprintf('Resolution: %d x %d px   Quality: —', cols, rows); end
[~, fname] = fileparts(sample);
h = findobj(app.UIFigure, 'Text', 'Image ID: —');
if ~isempty(h), h.Text = ['Image ID: ' fname]; end
h = findobj(app.UIFigure, 'Text', 'ANALYZE IMAGE');
if ~isempty(h), h.Enable = 'on'; end
h = findobj(app.UIFigure, 'Text', 'NEW SCREENING');
if ~isempty(h), h.Enable = 'on'; end
h = findobj(app.UIFigure, 'Text', 'System Ready');
if ~isempty(h), h.Text = ['Loaded: ' fname]; end
drawnow;
pause(1);
exportapp(app.UIFigure, fullfile(pwd, 'docs', 'ui-reference', 'actual-02-loaded.png'));
fprintf('  Saved actual-02-loaded.png\n');

% ---- State 3: analysis complete (Screening tab, Overlay view) ----
fprintf('\n=== STATE 3: Analysis complete (Screening tab) ===\n');
result = predictSingleFundus(sample, 'ShowFigure', false, 'RunLesions', true, ...
    'RunBranchB', true, 'SkipModelOnFail', true);
h = findobj(app.UIFigure, 'Text', '—');
if ~isempty(h), h.Text = result.gradeLabel; end
h = findobj(app.UIFigure, 'Text', '— / 4');
if ~isempty(h), h.Text = sprintf('%d / 4', result.grade); end
if strcmp(result.binaryDecision, 'REFERABLE')
    h = findobj(app.UIFigure, 'Text', '—');
    if ~isempty(h), h(1).Text = 'REFERABLE'; end
else
    h = findobj(app.UIFigure, 'Text', '—');
    if ~isempty(h), h(1).Text = 'NOT REFERABLE'; end
end
h = findobj(app.UIFigure, 'Text', 'Run an analysis to see the referral decision');
if ~isempty(h), h.Text = 'Specialist review advised by the model.'; end
h = findobj(app.UIFigure, 'Text', '—');
if ~isempty(h) && numel(h) > 1, h(2).Text = sprintf('%.2f%%   (P referable)', result.binaryProbability * 100); end
h = findobj(app.UIFigure, 'Text', 'Awaiting analysis');
if ~isempty(h), h.Text = sprintf('Margin %.1fpp · %s · TTA off · SO n/a', ...
    abs(1 - 2 * result.binaryProbability) * 100, 'medium'); end
h = findobj(app.UIFigure, 'Text', 'Run an analysis to see the screening advice');
if ~isempty(h), h.Text = 'ROUTINE SCREENING\nNo immediate specialist referral indicated by the model.'; end
h = findobj(app.UIFigure, 'Text', 'Resolution: —  ·  Quality: —');
if ~isempty(h), h.Text = sprintf('Resolution: %d x %d px   Quality: %s', cols, rows, result.qualityStatus); end
h = findobj(app.UIFigure, 'Text', '—');
if ~isempty(h) && numel(h) > 2, h(3).Text = 'ACCEPT'; end
if ~isempty(result.gradCAMMap) && ~isempty(app.ViewOverlay)
    allAxes = findobj(app.UIFigure, 'Type', 'axes');
    imshow(app.ViewOverlay, 'Parent', allAxes(2));
end
tg = findobj(app.UIFigure, 'Type', 'uitabgroup');
tabs = findobj(tg, 'Type', 'uitab');
for k = 1:numel(tabs)
    if strcmp(tabs(k).Title, 'Screening')
        tg.SelectedTab = tabs(k);
    end
end
drawnow;
pause(1);
exportapp(app.UIFigure, fullfile(pwd, 'docs', 'ui-reference', 'actual-03-screening-overlay.png'));
fprintf('  Saved actual-03-screening-overlay.png\n');

% ---- State 4: Grad-CAM view ----
fprintf('\n=== STATE 4: Grad-CAM view ===\n');
if ~isempty(app.ViewHeatmap)
    allAxes = findobj(app.UIFigure, 'Type', 'axes');
    imshow(app.ViewHeatmap, 'Parent', allAxes(2));
end
drawnow;
pause(1);
exportapp(app.UIFigure, fullfile(pwd, 'docs', 'ui-reference', 'actual-04-gradcam.png'));
fprintf('  Saved actual-04-gradcam.png\n');

% ---- State 5: Lesion Evidence tab (MA overlay) ----
fprintf('\n=== STATE 5: Lesion Evidence (MA overlay) ===\n');
tg = findobj(app.UIFigure, 'Type', 'uitabgroup');
tabs = findobj(tg, 'Type', 'uitab');
for k = 1:numel(tabs)
    if strcmp(tabs(k).Title, 'Lesion Evidence')
        tg.SelectedTab = tabs(k);
    end
end
allAxes = findobj(app.UIFigure, 'Type', 'axes');
imshow(img, 'Parent', allAxes(end));
title(allAxes(end), '');
drawnow;
pause(1);
exportapp(app.UIFigure, fullfile(pwd, 'docs', 'ui-reference', 'actual-05-lesion-ma.png'));
fprintf('  Saved actual-05-lesion-ma.png\n');

% ---- State 6: Report tab ----
fprintf('\n=== STATE 6: Report tab ===\n');
tg = findobj(app.UIFigure, 'Type', 'uitabgroup');
tabs = findobj(tg, 'Type', 'uitab');
for k = 1:numel(tabs)
    if strcmp(tabs(k).Title, 'Report')
        tg.SelectedTab = tabs(k);
    end
end
drawnow;
pause(1);
exportapp(app.UIFigure, fullfile(pwd, 'docs', 'ui-reference', 'actual-06-report.png'));
fprintf('  Saved actual-06-report.png\n');

app.delete();
fprintf('\nAll states captured.\n');
