% run_drishti_visual_qa.m
% Headless VISUAL QA for the redesigned RetinaAIApp dashboard + PDF report.
%
% Drives the REAL RetinaAIApp callbacks (dropdown sample selection, ANALYZE,
% view buttons, Save PDF Report) against three quality routes -- PASS,
% WARNING and FAIL -- captures PNG screenshots of the dashboard and each of
% the four explainability views into results/visual_qa/, then renders the
% generated report HTML to a PNG via headless Edge (same engine the PDF uses)
% so the PDF layout can be inspected as an image.
%
% Everything is driven through REAL UI callbacks (no internal state pokes);
% the only exception is adding the requested sample names to the dropdown so
% the specific PASS/WARNING/FAIL images can be selected.
%
% Usage: run_drishti_visual_qa()   (project root inferred)

function run_drishti_visual_qa()

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(projectRoot);
addpath(genpath(fullfile(projectRoot, 'src')));

qaDir = fullfile(projectRoot, 'results', 'visual_qa');
if ~exist(qaDir, 'dir'), mkdir(qaDir); end

% ---- discover PASS / WARNING / FAIL real val images ---------------------
warningPath = fullfile(projectRoot, 'data', 'splits', 'val', 'class_0', '005b95c28852.png');
failPath    = fullfile(projectRoot, 'data', 'splits', 'val', 'class_2', '026dcd9af143.png');
passPath    = discoverPassImage(projectRoot);

fprintf('QA cases:\n  PASS    %s\n  WARNING %s\n  FAIL    %s\n', passPath, warningPath, failPath);

% ---- instantiate the real app ------------------------------------------
a = RetinaAIApp();
drawnow;

saveShot(a.UIFigure, qaDir, '01_dashboard_idle.png', [1360 760]);

cases = {passPath, 'PASS'; warningPath, 'WARNING'; failPath, 'FAIL'};
for i = 1:size(cases, 1)
    imgPath = cases{i, 1};
    tag     = cases{i, 2};
    driveAnalyze(a, imgPath);
    drawnow;
    saveShot(a.UIFigure, qaDir, sprintf('02_%s_dashboard.png', tag), [1360 760]);
    % walk all four explainability views through their REAL button callbacks
    for vname = {'Original', 'Enhanced', 'Grad-CAM', 'Overlay'}
        driveView(a, vname{1});
        drawnow;
        saveShot(a.UIFigure, qaDir, sprintf('03_%s_%s.png', tag, vname{1}), [1360 760]);
    end
    % snapshot the left image panel alone (large fundus view)
    driveView(a, 'Original');
    drawnow;
    axesH = findall(a.UIFigure, 'Type', 'axes');
    fundusAx = [];
    for k = 1:numel(axesH)
        p = axesH(k).Parent;
        if isa(p, 'matlab.ui.container.Panel') && p.Position(1) < 50
            fundusAx = axesH(k);
            break;
        end
    end
    if ~isempty(fundusAx)
        saveShot(fundusAx, qaDir, sprintf('04_%s_fundus.png', tag), []);
    end
end

% ---- generate the REAL PDF report for the WARNING case ------------------
driveAnalyze(a, warningPath);
drawnow;
drivePdfReport(a);
drawnow;

% ---- render the report HTML -> PNG via the same headless Edge engine -----
renderReportPreview(projectRoot, qaDir);

a.delete();
fprintf('\nVISUAL QA SHOTS -> %s\n', qaDir);
end

% -------------------------------------------------------------------------
function passPath = discoverPassImage(projectRoot)
passPath = '';
classes = {'class_0', 'class_1', 'class_2', 'class_3', 'class_4'};
for c = 1:numel(classes)
    d = dir(fullfile(projectRoot, 'data', 'splits', 'val', classes{c}, '*.png'));
    for i = 1:min(8, numel(d))
        p = fullfile(d(i).folder, d(i).name);
        q = assessImageQuality(imread(p));
        if strcmp(q.overall, 'PASS')
            passPath = p;
            return;
        end
    end
end
if isempty(passPath)
    error('no PASS-quality val image discovered');
end
end

% -------------------------------------------------------------------------
function driveAnalyze(a, imgPath)
% Select the requested image through the REAL dropdown callback, then fire the
% REAL ANALYZE button callback (full inference pipeline on that image).
dd = findobj(a.UIFigure, 'Type', 'uidropdown');
[~, fname, fext] = fileparts(imgPath);
[~, clsFolder] = fileparts(fileparts(imgPath));
itemLabel = sprintf('%s/%s%s (QA)', clsFolder, fname, fext);
items = dd.Items;
if ~any(strcmp(items, itemLabel))
    dd.Items = [items, itemLabel];
end
dd.Value = itemLabel;
if ~isempty(dd.ValueChangedFcn)
    dd.ValueChangedFcn(dd);
end
drawnow;

btns = findall(a.UIFigure, 'Type', 'uibutton');
for k = 1:numel(btns)
    if strcmp(char(btns(k).Text), 'ANALYZE IMAGE')
        fprintf('  [analyze %s]\n', fname);
        try
            btns(k).ButtonPushedFcn(btns(k));
            fprintf('  [analyze done, figure valid=%d]\n', isvalid(a.UIFigure));
        catch err
            fprintf('  [analyze THREW: %s]\n', err.message);
            for s = 1:numel(err.stack)
                fprintf('    at %s:%d\n', err.stack(s).name, err.stack(s).line);
            end
        end
        break;
    end
end
drawnow;
end

% -------------------------------------------------------------------------
function driveView(a, viewName)
btns = findall(a.UIFigure, 'Type', 'uibutton');
for k = 1:numel(btns)
    if strcmp(char(btns(k).Text), viewName)
        btns(k).ButtonPushedFcn(btns(k));
        return;
    end
end
end

% -------------------------------------------------------------------------
function drivePdfReport(a)
btns = findall(a.UIFigure, 'Type', 'uibutton');
for k = 1:numel(btns)
    if strcmp(char(btns(k).Text), 'Save PDF Report')
        btns(k).ButtonPushedFcn(btns(k));
        return;
    end
end
end

% -------------------------------------------------------------------------
function renderReportPreview(projectRoot, qaDir)
% Headless Edge (same engine used for the PDF) renders the most recent report
% HTML to a PNG so the visual result can be inspected as an image.
htmlFile = '';
d = dir(fullfile(projectRoot, 'results', 'DrishtiScreeningReport_*.html'));
if isempty(d), return; end
latest = 0;
for k = 1:numel(d)
    if d(k).datenum > latest, latest = d(k).datenum; htmlFile = fullfile(d(k).folder, d(k).name); end
end
edge = '';
cand = {
    'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
    'C:\Program Files\Microsoft\Edge\Application\msedge.exe'
    'C:\Program Files\Google\Chrome\Application\chrome.exe'};
for k = 1:numel(cand)
    if exist(cand{k}, 'file') == 2, edge = cand{k}; break; end
end
if isempty(edge), return; end
out = fullfile(qaDir, '05_report_preview.png');
cmd = sprintf('"%s" --headless --disable-gpu --no-sandbox --screenshot="%s" --window-size=900,1400 "file:///%s"', ...
    edge, out, strrep(htmlFile, '\', '/'));
system(cmd);
end

% -------------------------------------------------------------------------
function saveShot(target, qaDir, name, ~)
outPath = fullfile(qaDir, name);
if ~isvalid(target)
    fprintf('shot %s SKIPPED (target invalid)\n', name);
    return;
end
try
    if isa(target, 'matlab.ui.Figure')
        % getframe is reliable for uifigures in headless -batch runs; the
        % app exporter intermittently times out waiting for a new window.
        fr = getframe(target);
        imwrite(fr.cdata, outPath);
    else
        exportgraphics(target, outPath, 'Resolution', 150);
    end
    fprintf('shot %s\n', name);
catch err
    fprintf('shot %s FAILED: %s\n', name, err.message);
end
end