% verify_retinaai.m
% Headless verification for the RETINA-AI single-image screening app.
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(projectRoot, 'src')));

fprintf('== RETINA-AI app verification ==\n');

%% 1. App lifecycle
a = RetinaAIApp();
drawnow;
assert(isvalid(a.UIFigure), 'UIFigure valid');
assert(strcmp(a.UIFigure.Name, 'RETINA-AI'), 'title');
fprintf('OK  1. app instantiated\n');

%% 2. Sample list populated from val split
dd = findobj(a.UIFigure, 'Type', 'uidropdown');
assert(numel(dd) == 1, 'one sample dropdown');
assert(numel(dd.Items) > 1, 'sample list populated');
assert(strcmp(dd.Items{1}, '(no samples)'), 'placeholder first item');
fprintf('OK  2. sample list has %d entries\n', numel(dd.Items));

%% 3. Select a sample and run the REAL analyze callback
dd.Value = dd.Items{2};
if ~isempty(dd.ValueChangedFcn)
    dd.ValueChangedFcn(dd);
end
drawnow;
analyzeBtns = findall(a.UIFigure, 'Type', 'uibutton');
assert(~isempty(analyzeBtns), 'buttons exist');
analyzeBtn = [];
for k = 1:numel(analyzeBtns)
    if strcmp(analyzeBtns(k).Text, 'ANALYZE IMAGE')
        analyzeBtn = analyzeBtns(k);
    end
end
assert(~isempty(analyzeBtn), 'ANALYZE button found');
assert(strcmp(analyzeBtn.Enable, 'on'), 'analyze enabled after selecting sample');

% Drive the real callback on a val image
analyzeBtn.ButtonPushedFcn(analyzeBtn);
drawnow;

% Find the quality badge label (ACCEPT/WARNING/REJECT among all labels)
allLabels = findall(a.UIFigure, 'Type', 'uilabel');
badgeOk = false;
for k = 1:numel(allLabels)
    if any(strcmp(allLabels(k).Text, {'ACCEPT', 'WARNING', 'REJECT'}))
        badgeOk = true;
    end
end
assert(badgeOk, 'quality badge populated');
fprintf('OK  3. analyze path ran through real callback (pipeline comment below)\n');

%% 4. Inference contract check (matches predictSingleFundus fields)
% Pull the inspection from a val image path derived from the dropdown.
sel = dd.Value;                     % e.g. "class_2/000c... (Moderate)"
parts = strsplit(sel, '/');
cls = parts{1};
rest = strsplit(parts{2}, ' ');
imgPath = fullfile(projectRoot, 'data', 'splits', 'val', cls, rest{1});
assert(exist(imgPath, 'file') == 2, 'val image exists');
r = predictSingleFundus(imgPath, 'ShowFigure', false, 'RunLesions', true, 'RunBranchB', true);
assert(isfield(r, 'qualityStatus'), 'qualityStatus field');
assert(isfield(r, 'qualityScore'), 'qualityScore field');
assert(isfield(r, 'grade'), 'grade field');
assert(isfield(r, 'gradeLabel'), 'gradeLabel field');
assert(isfield(r, 'binaryDecision'), 'binaryDecision field');
assert(isfield(r, 'binaryProbability'), 'binaryProbability field');
assert(isfield(r, 'confidence'), 'confidence field');
assert(isfield(r, 'gradCAM'), 'gradCAM field');
assert(size(r.gradCAM, 3) == 3 || size(r.gradCAM, 1) > 0, 'gradCAM image');
assert(isfield(r, 'cascade'), 'cascade field');
assert(isfield(r, 'lesions'), 'lesions field');
assert(isfield(r, 'explanation'), 'explanation field');
assert(isfield(r, 'runtimeSec'), 'runtimeSec field');
fprintf('OK  4. predictSingleFundus contract verified: %s qual=%s grade=%d route=%s\n', ...
    rest{1}, r.qualityStatus, r.grade, r.cascade.route);

%% 5. Report generation (textarea populated with a full report)
areas = findall(a.UIFigure, 'Type', 'uitextarea');
assert(numel(areas) >= 1, 'report textarea exists');
rep = areas(1).Value;
assert(numel(rep) >= 10, 'report has many lines');
assert(any(contains(rep, 'RETINA-AI Analysis Report')), 'report header');
assert(any(contains(rep, {'ACCEPT', 'WARNING', 'REJECT'}, 'IgnoreCase', true)) || ...
    any(contains(rep, 'Quality')), 'quality line present');
fprintf('OK  5. report textarea populated (%d lines)\n', numel(rep));

%% 5b. Recommendation banner populated
recOk = false;
for k = 1:numel(allLabels)
    if ~isempty(allLabels(k).Text) && any(contains(allLabels(k).Text, ...
            {'REFER', 'ROUTINE FOLLOW-UP', 'RECAPTURE', 'SPECIALIST CHECK'}))
        fprintf('OK  5b. recommendation banner: %s\n', allLabels(k).Text);
        recOk = true;
    end
end
assert(recOk, 'recommendation banner populated');

%% 6. Cleanup
a.delete();
fprintf('OK  6. closed cleanly\n');
fprintf('\nALL RETINA-AI APP CHECKS PASS\n');