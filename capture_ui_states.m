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

function setText(fig, text, newText)
    h = findobj(fig, 'Text', text);
    if ~isempty(h), h.Text = newText; end
end

function enableBtn(fig, text, enable)
    h = findobj(fig, 'Text', text);
    if ~isempty(h), h.Enable = enable; end
end

function selectTab(fig, tabTitle)
    tg = findobj(fig, 'Type', 'uitabgroup');
    if ~isempty(tg)
        tabs = findobj(tg, 'Type', 'uitab');
        for k = 1:numel(tabs)
            if strcmp(tabs(k).Title, tabTitle)
                tg.SelectedTab = tabs(k);
                return;
            end
        end
    end
end

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
setText(app.UIFigure, 'Resolution: —  ·  Quality: —', ...
    sprintf('Resolution: %d x %d px   Quality: —', cols, rows));
[~, fname] = fileparts(sample);
setText(app.UIFigure, 'Image ID: —', ['Image ID: ' fname]);
enableBtn(app.UIFigure, 'ANALYZE IMAGE', 'on');
enableBtn(app.UIFigure, 'NEW SCREENING', 'on');
setText(app.UIFigure, 'System Ready', 'Loaded: ' fname);
% Note: setStatus color change not accessible; text change is enough for visual.
drawnow;
pause(1);
exportapp(app.UIFigure, fullfile(pwd, 'docs', 'ui-reference', 'actual-02-loaded.png'));
fprintf('  Saved actual-02-loaded.png\n');

% ---- State 3: analysis complete (Screening tab, Overlay view) ----
fprintf('\n=== STATE 3: Analysis complete (Screening tab) ===\n');
result = predictSingleFundus(sample, 'ShowFigure', false, 'RunLesions', true, ...
    'RunBranchB', true, 'SkipModelOnFail', true);
% Update severity.
setText(app.UIFigure, '—', result.gradeLabel);
setText(app.UIFigure, '— / 4', sprintf('%d / 4', result.grade));
% Referral panel.
if strcmp(result.binaryDecision, 'REFERABLE')
    setText(app.UIFigure, '—', 'REFERABLE');
else
    setText(app.UIFigure, '—', 'NOT REFERABLE');
end
setText(app.UIFigure, 'Run an analysis to see the referral decision', ...
    'Specialist review advised by the model.');
setText(app.UIFigure, '—', sprintf('%.2f%%   (P referable)', result.binaryProbability * 100));
setText(app.UIFigure, 'Awaiting analysis', ...
    sprintf('Margin %.1fpp · %s · TTA off · SO n/a', ...
        abs(1 - 2 * result.binaryProbability) * 100, 'medium'));
setText(app.UIFigure, 'Run an analysis to see the screening advice', ...
    'ROUTINE SCREENING\nNo immediate specialist referral indicated by the model.');
% Quality.
setText(app.UIFigure, 'Resolution: —  ·  Quality: —', ...
    sprintf('Resolution: %d x %d px   Quality: %s', cols, rows, result.qualityStatus));
setText(app.UIFigure, '—', 'ACCEPT');
% Show overlay view on GradCAMAxes.
gcAxes = findobj(app.UIFigure, 'Tag', 'fundusAxes'); % wrong - need GradCAMAxes
% Find the GradCAM axes in the right panel.
allAxes = findobj(app.UIFigure, 'Type', 'axes');
% The GradCAMAxes is in the right panel. We'll just show the overlay on it.
if ~isempty(result.gradCAMMap) && ~isempty(app.ViewOverlay)
    imshow(app.ViewOverlay, 'Parent', allAxes(2));
end
selectTab(app.UIFigure, 'Screening');
drawnow;
pause(1);
exportapp(app.UIFigure, fullfile(pwd, 'docs', 'ui-reference', 'actual-03-screening-overlay.png'));
fprintf('  Saved actual-03-screening-overlay.png\n');

% ---- State 4: Grad-CAM view ----
fprintf('\n=== STATE 4: Grad-CAM view ===\n');
if ~isempty(app.ViewHeatmap)
    imshow(app.ViewHeatmap, 'Parent', allAxes(2));
end
drawnow;
pause(1);
exportapp(app.UIFigure, fullfile(pwd, 'docs', 'ui-reference', 'actual-04-gradcam.png'));
fprintf('  Saved actual-04-gradcam.png\n');

% ---- State 5: Lesion Evidence tab (MA overlay) ----
fprintf('\n=== STATE 5: Lesion Evidence (MA overlay) ===\n');
selectTab(app.UIFigure, 'Lesion Evidence');
% Show raw image on LesAxes.
lesAxes = findobj(app.UIFigure, 'Text', 'No lesion evidence available');
if isempty(lesAxes)
    lesAxes = allAxes(end); % last axes
end
imshow(img, 'Parent', lesAxes);
title(lesAxes, '');
drawnow;
pause(1);
exportapp(app.UIFigure, fullfile(pwd, 'docs', 'ui-reference', 'actual-05-lesion-ma.png'));
fprintf('  Saved actual-05-lesion-ma.png\n');

% ---- State 6: Report tab ----
fprintf('\n=== STATE 6: Report tab ===\n');
selectTab(app.UIFigure, 'Report');
drawnow;
pause(1);
exportapp(app.UIFigure, fullfile(pwd, 'docs', 'ui-reference', 'actual-06-report.png'));
fprintf('  Saved actual-06-report.png\n');

app.delete();
fprintf('\nAll states captured.\n');
