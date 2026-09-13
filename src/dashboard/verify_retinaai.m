% verify_retinaai.m
% Headless verification for the RETINA-AI single-image screening app.
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(projectRoot);
addpath(genpath(fullfile(projectRoot, 'src')));

fprintf('== DRISHTI app verification ==\n');

%% 1. App lifecycle
a = RetinaAIApp();
drawnow;
assert(isvalid(a.UIFigure), 'UIFigure valid');
assert(strcmp(a.UIFigure.Name, 'DRISHTI'), 'title is DRISHTI');
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

 % Find the quality badge label (judge terms among all labels)
allLabels = findall(a.UIFigure, 'Type', 'uilabel');
badgeOk = false;
for k = 1:numel(allLabels)
    if any(strcmp(allLabels(k).Text, {'ACCEPT (PASS)', 'BORDERLINE (WARNING)', 'REJECT (FAIL)'}))
        badgeOk = true;
    end
end
assert(badgeOk, 'judge-terms quality badge populated');
fprintf('OK  3b. judge-terms badge present\n');

% Four explainability view buttons must exist
viewBtns = findall(a.UIFigure, 'Type', 'uibutton');
viewTexts = cell(numel(viewBtns), 1);
for k = 1:numel(viewBtns), viewTexts{k} = char(viewBtns(k).Text); end
for v = {'Original', 'Enhanced', 'Grad-CAM', 'Overlay'}
    assert(any(strcmp(viewTexts, v{1})), ['view button missing: ' v{1}]);
end
fprintf('OK  3c. 4 view buttons present (Original/Enhanced/Grad-CAM/Overlay)\n');
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
assert(any(contains(rep, 'DRISHTI Analysis Report')), 'report header');
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

%% 5c. WITHHELD-on-FAIL contract (reject path runs no classifier)
failPath = '';
clsDirs = {'class_0', 'class_1', 'class_2', 'class_3', 'class_4'};
for c = 1:numel(clsDirs)
    dd2 = dir(fullfile(projectRoot, 'data', 'splits', 'val', clsDirs{c}, '*.png'));
    for i = 1:min(6, numel(dd2))
        p2 = fullfile(projectRoot, 'data', 'splits', 'val', clsDirs{c}, dd2(i).name);
        q2 = assessImageQuality(imread(p2));
        if strcmp(q2.overall, 'FAIL'), failPath = p2; break; end
    end
    if ~isempty(failPath), break; end
end
assert(~isempty(failPath), 'a FAIL val image exists for the reject test');
rF = predictSingleFundus(failPath, 'ShowFigure', false, 'SkipModelOnFail', true);
assert(startsWith(rF.binaryDecision, 'WITHHELD'), 'FAIL decision withheld');
assert(isnan(rF.grade), 'FAIL grade withheld');
fprintf('OK  5c. reject path verified on %s\n', failPath);

%% 6. Cleanup
a.delete();
fprintf('OK  6. closed cleanly\n');
fprintf('\nALL DRISHTI APP CHECKS PASS\n');