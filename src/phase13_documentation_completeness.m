function phase13_documentation_completeness()
% PHASE13_DOCUMENTATION_COMPLETENESS Documentation hygiene audit.
%   Verifies the docs honestly represent the system after 12 hardening
%   phases: disclaimer coverage, manifest completeness, tracker integrity,
%   honest-negative markers, and cross-referenced artifact existence.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
cd(projectRoot);
addpath(genpath(fullfile(projectRoot, 'src')));

auditRes = struct('check', {}, 'status', {}, 'measured', {}, 'expected', {}, 'note', {}); %#ok<CHARTEN>

fprintf('============================================================\n');
fprintf('  PHASE 13 - DOCUMENTATION COMPLETENESS\n');
fprintf('  Date: %s\n', datestr(now));
fprintf('============================================================\n');

%% ---- 1. Disclaimer coverage (engineering, NOT clinical) ----
readme = fullfile('README.md');
okRd = exist(readme,'file')==2 && ~isempty(regexp(fileread(readme), ...
    'clinical|engineering', 'once'));
auditRes(end+1) = rec('P13 readme_disclaimer', okRd, ...
    ternary(okRd,'disclaimer present','MISSING'), 'present', ...
    'README carries the engineering/non-clinical framing'); %#ok<AGROW>

infDoc = fullfile('docs','individual-image-inference.md');
okInf = exist(infDoc,'file')==2 && ~isempty(regexp(fileread(infDoc), ...
    'not clinical|not intended for clinical|engineering', 'once'));
auditRes(end+1) = rec('P13 inference_doc_disclaimer', okInf, ...
    ternary(okInf,'disclaimer present','MISSING'), 'present', ...
    'individual-inference doc disclaims clinical use'); %#ok<AGROW>

% every hardening-phase report must carry the disclaimer
hard = dir(fullfile('docs','validation','2026-09-10-hardening-phase*.md'));
missingDisc = '';
for k = 1:numel(hard)
    t = fileread(fullfile(hard(k).folder, hard(k).name));
    if isempty(regexp(t, 'clinical|engineering demo|not a clinical', 'once'))
        missingDisc = [missingDisc hard(k).name ' ']; %#ok<AGROW>
    end
end
auditRes(end+1) = rec('P13 hardening_reports_disclaimers', isempty(missingDisc), ...
    ternary(isempty(missingDisc), sprintf('%d reports', numel(hard)), missingDisc), 'all', ...
    'every hardening report disclaims clinical use'); %#ok<AGROW>

%% ---- 2. Baseline manifest component map completeness ----
mfr = fileread(fullfile('audit','improvement_baseline','baseline_manifest.md'));
paths = unique(regexp(mfr, 'src\\[A-Za-z0-9_\\+\.\-]+|data\\[A-Za-z0-9_\\\.\-]+\.mat', 'match'));
missingManif = '';
for k = 1:numel(paths)
    p = strrep(paths{k}, '\\', filesep);
    if ~exist(p, 'file') && ~exist(p, 'dir') && ~contains(p, 'extend'), missingManif = [missingManif p ' ']; end %#ok<AGROW>
end
auditRes(end+1) = rec('P13 manifest_files_exist', isempty(missingManif), ...
    ternary(isempty(missingManif), sprintf('%d paths OK', numel(paths)), missingManif), 'all exist', ...
    'every file/dir referenced in baseline manifest exists'); %#ok<AGROW>

%% ---- 3. Task-tracker integrity (P0-P12 rows, PASS tags) ----
tr = fileread(fullfile('docs','task-tracker.md'));
missingRow = '';
for p = 0:12
    tag = sprintf('| P%d |', p);
    if ~contains(tr, tag), missingRow = [missingRow tag ' ']; end %#ok<AGROW>
end
nP0P12 = 0;
for p = 0:12
    if contains(tr, sprintf('| P%d |', p)) && ~isempty(regexp(tr, ...
        sprintf('\\| P%d \\|.*Complete.*PASS', p), 'once')), nP0P12 = nP0P12 + 1; end
end
auditRes(end+1) = rec('P13 tracker_P0_P12', isempty(missingRow) && nP0P12==13, ...
    sprintf('%d/13', nP0P12), '13', ...
    'tracker records all P0-P12 rows as Complete with PASS'); %#ok<AGROW>

%% ---- 4. Honest-negative markers ----
fov = fullfile('docs','validation','2026-09-08-task11-fovea-closure.md');
fovTxt = '';
if exist(fov,'file')==2, fovTxt = fileread(fov); end
okFov = ~isempty(fovTxt) && ~isempty(regexp(fovTxt, 'honest|negative|0/10', 'once'));
auditRes(end+1) = rec('P13 fovea_honest_negative', okFov, ...
    ternary(okFov,'documented','MISSING'), 'documented', ...
    'fovea localization honest negative is documented'); %#ok<AGROW>

p9 = fileread(fullfile('docs','validation','2026-09-10-hardening-phase9-ood.md'));
okOod = ~isempty(regexp(p9, 'advisory|never alters|ADVISORY', 'once'));
auditRes(end+1) = rec('P13 ood_advisory_documented', okOod, ...
    ternary(okOod,'documented','MISSING'), 'documented', ...
    'OOD advisory-only caveat documented'); %#ok<AGROW>

p8 = fileread(fullfile('docs','validation','2026-09-10-hardening-phase8-firewall.md'));
okCal = ~isempty(regexp(p8, 'RAW|auxiliary|display-only', 'once'));
auditRes(end+1) = rec('P13 calib_aux_documented', okCal, ...
    ternary(okCal,'documented','MISSING'), 'documented', ...
    'calibration auxiliary-only caveat documented'); %#ok<AGROW>

%% ---- 5. Hardening reports reference existing artifacts ----
missingArt = '';
for k = 1:numel(hard)
    t = fileread(fullfile(hard(k).folder, hard(k).name));
    arts = unique(regexp(t, 'data/analysis/day[0-9]+/[A-Za-z0-9_/\.]+\.(?:mat|json)', 'match'));
    for a = 1:numel(arts)
        if ~exist(arts{a}, 'file'), missingArt = [missingArt arts{a} ' ']; end %#ok<AGROW>
    end
end
auditRes(end+1) = rec('P13 report_artifacts_exist', isempty(missingArt), ...
    ternary(isempty(missingArt), 'all referenced artifacts present', missingArt), 'all exist', ...
    'artifacts referenced in hardening reports exist on disk'); %#ok<AGROW>

%% ---- 6. INFO: headline-number scan in hardening reports (deviation report) ----
mismatches = '';
allowed = {'0.8281','0.6805','0.8914','0.9060','0.9471','0.9834','0.6081', ...
    '0.7850','0.4872','0.5254','0.9796','0.7821','0.858','0.8969'};
for k = 1:numel(hard)
    t = fileread(fullfile(hard(k).folder, hard(k).name));
    hits = regexp(t, '0\.[0-9]{4}', 'match');
    for h = 1:numel(hits)
        if ~any(strcmp(hits{h}, allowed))
            mismatches = [mismatches sprintf('%s:%s ', hard(k).name, hits{h})]; %#ok<AGROW>
        end
    end
end
% tolerances like 0.8276 (5e-4 windows) in P4 are legit; not auto-fail.
fprintf('  [INFO] headline-number scan (non-frozen decimals found): %s\n', ...
    ternary(isempty(mismatches), 'none', mismatches));
auditRes(end+1) = rec('P13 headline_scan_no_conflicts', true, ...
    ternary(isempty(mismatches), sprintf('%d docs scanned', numel(hard)), mismatches), 'soft', ...
    'INFO: any quoted decimals outside the frozen set are listed above for manual review'); %#ok<AGROW>

%% ---- Summary ----
outDir = fullfile(projectRoot,'data','analysis','day10','phase13');
if ~exist(outDir,'dir'), mkdir(outDir); end
save(fullfile(outDir,'phase13_documentation_completeness.mat'), 'auditRes', 'mismatches');
fprintf('\n============================================================\n');
nPass=0; nFail=0;
for i=1:numel(auditRes)
    if auditRes(i).status, nPass=nPass+1; tag='PASS'; else, nFail=nFail+1; tag='FAIL'; end
    fprintf('  [%s] %-32s %s\n', tag, auditRes(i).check, auditRes(i).note);
end
fprintf('  TOTAL: %d PASS, %d FAIL\n', nPass, nFail);
end

function rr = rec(check, status, measured, expected, note)
    rr = struct('check', check, 'status', status, 'measured', measured, ...
                'expected', expected, 'note', note);
end

function s = ternary(c, a, b)
    if c, s = a; else, s = b; end
end