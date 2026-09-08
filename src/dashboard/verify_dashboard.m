% verify_dashboard.m
% Headless verification for the T12 screening dashboard.
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(projectRoot, 'src')));

fprintf('== T12 dashboard verification ==\n');

% 2. Data layer matches committed artifacts
D = load_dashboard_data();
assert(D.quality.n == 3662, 'quality n');
assert(abs(D.quality.passPct - 65.48) < 0.01, 'passPct');
assert(abs(D.quality.warningPct - 26.68) < 0.01, 'warningPct');
assert(abs(D.quality.failPct - 7.84) < 0.01, 'failPct');
assert(abs(D.champion.accuracy - 0.8281) < 1e-4, 'champion acc');
assert(abs(D.champion.macroF1 - 0.6805) < 1e-4, 'champion macroF1');
assert(abs(D.champion.qwk - 0.8914) < 1e-4, 'champion qwk');
assert(D.referable.valN == 733, 'val n');
assert(abs(D.referable.valFrac - 0.4065) < 1e-3, 'val referable frac');
assert(height(D.ablation) == 3, 'ablation rows');
assert(~any(isnan([D.ablation.acc D.ablation.macroF1 D.ablation.qwk D.ablation.sens D.ablation.spec D.ablation.n]), 'all'), 'ablation NaN');
assert(size(D.failureReasons, 1) >= 5, 'failure reasons populated');
assert(D.branchB.available, 'branchB available');
assert(abs(D.branchB.evalAUC - 0.858) < 1e-3, 'branchB evalAUC');
fprintf('OK  1. data layer matches committed artifacts\n');

%% 2. App lifecycle
a = DRScreeningDashboard();
drawnow;
assert(isvalid(a.UIFigure), 'UIFigure valid');
assert(strcmp(a.UIFigure.Name, 'DrishtiCare Screening Dashboard'), 'title');
tg = findobj(a.UIFigure, 'Type', 'uitabgroup');
assert(numel(tg) == 1, 'one tab group');
tabs = findobj(tg, 'Type', 'uitab');
assert(numel(tabs) == 5, 'five tabs');
fprintf('OK  2. app instantiated: %d tabs (%s)\n', numel(tabs), strjoin({tabs.Title}, ', '));

%% 3. Workload math on the app (via slider round-trip)
sld = findobj(a.UIFigure, 'Type', 'uislider');
assert(numel(sld) == 1, 'one workload slider');
sld.Value = 1000;
if ~isempty(sld.ValueChangedFcn)
    sld.ValueChangedFcn(sld);  % drive the label through the real callback
end
drawnow;
outLbl = findobj(a.UIFigure, 'Type', 'uilabel', '-and', ...
    'VerticalAlignment', 'top');
assert(numel(outLbl) >= 1, 'workload output label');
txt = outLbl(1).Text;
ref = D.referable.valFrac; wP = D.quality.warningPct / 100; fL = D.quality.failPct / 100;
expLoad = 1000 * ref + 1000 * fL + 0.25 * 1000 * wP;
assert(contains(txt, sprintf('Manual-review load (est.):'), 'IgnoreCase', true), 'workload header');
assert(contains(txt, sprintf('%.0f', round(expLoad))), 'workload math');
fprintf('OK  3. workload math @1000 img/day = ~%d reviews\n', round(expLoad));

%% 4. Inspector inference path (val image through predictSingleFundus)
drop = findobj(a.UIFigure, 'Type', 'uidropdown');
lst = findobj(a.UIFigure, 'Type', 'uilistbox');
dr = [];
for k = 1:numel(drop)
    if contains(drop(k).Items{1}, 'NoDR'), dr = drop(k); break; end
end
assert(~isempty(dr), 'class dropdown found');
dr.Value = dr.Items{1};
if ~isempty(dr.ValueChangedFcn)
    dr.ValueChangedFcn(dr);  % programmatic set does not fire callback
end
drawnow;
assert(~isempty(lst.Items), 'val image list populated');
imgPath = fullfile(projectRoot, 'data', 'splits', 'val', 'class_0', char(lst.Value));
assert(exist(imgPath, 'file') == 2, 'val image exists');
r = predictSingleFundus(imgPath, 'ShowFigure', false);
assert(isfield(r, 'qualityStatus') && ~isempty(r.qualityStatus), 'qualityStatus');
assert(isfield(r, 'binaryDecision') && ~isempty(r.binaryDecision), 'binaryDecision');
assert(isfield(r, 'grade') && numel(r.grade) == 1, 'grade');
assert(isfield(r, 'cascade') && isfield(r.cascade, 'route'), 'cascade route');
assert(isfield(r, 'lesions') && isfield(r.lesions, 'foveaSupplied'), 'lesions fovea flag');
fprintf('OK  4. inspector inference path: %s qual=%s route=%s\n', ...
    char(lst.Value), r.qualityStatus, r.cascade.route);

%% 5. Cleanup
a.delete();
fprintf('OK  5. closed cleanly\n');
fprintf('\nALL T12 DASHBOARD CHECKS PASS\n');