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
app.CurrentImagePath = sample;
showImage(app, sample);
app.AnalyzeButton.Enable = 'on';
app.NewBtn.Enable = 'on';
[~, fname] = fileparts(sample);
app.FilenameLabel.Text = ['Image ID: ' fname];
app.setStatus(sprintf('Loaded: %s', fname), 'ok');
app.setPipelineState('loading');
app.resetResultDisplay();
drawnow;
pause(1);
exportapp(app.UIFigure, fullfile(pwd, 'docs', 'ui-reference', 'actual-02-loaded.png'));
fprintf('  Saved actual-02-loaded.png\n');

% ---- State 3: analysis complete (Screening tab, Overlay view) ----
fprintf('\n=== STATE 3: Analysis complete (Screening tab) ===\n');
result = predictSingleFundus(sample, 'ShowFigure', false, 'RunLesions', true, ...
    'RunBranchB', true, 'SkipModelOnFail', true);
app.CurrentResult = result;
cacheViews(app, result);
displayResults(app, result);
showView(app, 'Overlay');
app.TabGroup.SelectedTab = app.TabScreening;
drawnow;
pause(1);
exportapp(app.UIFigure, fullfile(pwd, 'docs', 'ui-reference', 'actual-03-screening-overlay.png'));
fprintf('  Saved actual-03-screening-overlay.png\n');

% ---- State 4: Grad-CAM view ----
fprintf('\n=== STATE 4: Grad-CAM view ===\n');
showView(app, 'Grad-CAM');
drawnow;
pause(1);
exportapp(app.UIFigure, fullfile(pwd, 'docs', 'ui-reference', 'actual-04-gradcam.png'));
fprintf('  Saved actual-04-gradcam.png\n');

% ---- State 5: Lesion Evidence tab (MA overlay) ----
fprintf('\n=== STATE 5: Lesion Evidence (MA overlay) ===\n');
app.TabGroup.SelectedTab = app.TabLesion;
showLesionView(app, 'MA overlay');
drawnow;
pause(1);
exportapp(app.UIFigure, fullfile(pwd, 'docs', 'ui-reference', 'actual-05-lesion-ma.png'));
fprintf('  Saved actual-05-lesion-ma.png\n');

% ---- State 6: Report tab ----
fprintf('\n=== STATE 6: Report tab ===\n');
app.TabGroup.SelectedTab = app.TabReport;
drawnow;
pause(1);
exportapp(app.UIFigure, fullfile(pwd, 'docs', 'ui-reference', 'actual-06-report.png'));
fprintf('  Saved actual-06-report.png\n');

app.delete();
fprintf('\nAll states captured.\n');
