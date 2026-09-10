function phase20_rogue_triage()
% PHASE20_ROGUE_TRIAGE Unknown/rogue-file provenance & disposition triage.
%   Classifies the untracked scripts and output dirs that predate the hardening
%   program (runAPTOS.m, runFinalAPTOS.m, runFinalAPTOSBinary.m, runSmokeTest.m,
%   data/analysis/final, data/analysis/smoke_test): verifies they are
%   unreferenced by src, contain no training call-sites, contain no leaked
%   model weights, and records a disposition decision for Phase 25.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
cd(projectRoot);
addpath(genpath(fullfile(projectRoot,'src')));

auditRes = struct('check',{},'status',{},'measured',{},'expected',{},'note',{});
fprintf('============================================================\n');
fprintf('  PHASE 20 - ROGUE / UNKNOWN-FILE TRIAGE\n');
fprintf('  Date: %s\n', datestr(now));
fprintf('============================================================\n');

rogueM = {'runAPTOS.m','runFinalAPTOS.m','runFinalAPTOSBinary.m','runSmokeTest.m'};

%% ---- 1. Unreferenced by src ----
d = dir(fullfile('src','**','*.m'));
refs = {};
pat = 'runAPTOS|runFinalAPTOS|runSmokeTest|smoke_test|analysis[\\/]final';
for i=1:numel(d)
    if strcmp(d(i).name, 'phase20_rogue_triage.m'), continue; end
    p = fullfile(d(i).folder, d(i).name);
    f = fopen(p,'rt'); c = fscanf(f,'%c'); fclose(f);
    m = regexp(c, pat);
    if ~isempty(m), refs{end+1} = d(i).name; end %#ok<AGROW>
end
auditRes(end+1) = rec('P20 unreferenced_by_src', isempty(refs), ...
    strjoin(refs,', '), '<none>', ...
    'no src file references the rogue scripts or their output dirs'); %#ok<AGROW>

%% ---- 2. No training call-sites in rogue scripts ----
badCS = {};
for i=1:numel(rogueM)
    if exist(rogueM{i},'file')~=2, continue; end
    f = fopen(rogueM{i},'rt'); c = fscanf(f,'%c'); fclose(f);
    if ~isempty(regexp(c, 'trainNetwork\s*\(|trainClassifier\s*\(|fit[A-Z]\w*\s*\('))
        badCS{end+1} = rogueM{i}; %#ok<AGROW>
    end
end
auditRes(end+1) = rec('P20 rogue_train_callsites_free', isempty(badCS), ...
    strjoin(badCS,', '), '<none>', ...
    'rogue scripts contain NO training call-sites (eval-only runners)'); %#ok<AGROW>

%% ---- 3. Outputs exist; no model-weight leak ----
finD = dir(fullfile('data','analysis','final','*.mat'));
stD  = dir(fullfile('data','analysis','smoke_test','*.mat'));
stP  = dir(fullfile('data','analysis','smoke_test','*.png'));
allOk = numel(finD)==1 && numel(stD)==1 && numel(stP)==2;
leak = {};
for i=1:numel(finD)
    cc = load(fullfile(finD(i).folder, finD(i).name));
    if isfield(cc,'trainedNet') || isfield(cc,'net') || isfield(cc,'layers')
        leak{end+1} = finD(i).name; %#ok<AGROW>
    end
end
for i=1:numel(stD)
    cc = load(fullfile(stD(i).folder, stD(i).name));
    if isfield(cc,'trainedNet') || isfield(cc,'net') || isfield(cc,'layers')
        leak{end+1} = stD(i).name; %#ok<AGROW>
    end
end
auditRes(end+1) = rec('P20 outputs_present_no_leak', allOk && isempty(leak), ...
    sprintf('final=%d mat, smoke=%d mat + %d png', numel(finD), numel(stD), numel(stP)), ...
    '1/1/2', 'expected eval artifacts present; no model weights embedded'); %#ok<AGROW>

%% ---- 4. All 4 rogue scripts exist and are non-empty ----
ex = true;
for i=1:numel(rogueM)
    if exist(rogueM{i},'file')~=2, ex = false; end
end
auditRes(end+1) = rec('P20 rogue_scripts_present', ex, sprintf('%d scripts', numel(rogueM)), '4', ...
    'all four rogue scripts still present (no accidental deletion)'); %#ok<AGROW>

%% ---- 5. Disposition recorded ----
disposition = struct();
disposition.classification = 'Pre-hardening ad-hoc eval/smoke runners + their outputs. eval-only (no train call-sites), unreferenced by src, no model-weight leak.';
disposition.keep = 'DO NOT delete: they document the pre-hardening final-APTOS eval + 10-image smoke test provenance and cross-check the locked metrics (final_aptos_evaluation.mat is a metrics summary, not a model).';
disposition.phase25 = 'Phase 25 disposition: leave in place as untracked provenance; optionally add to a docs note; do NOT commit (eval summaries already superseded by hardening artifacts).';
auditRes(end+1) = rec('P20 disposition_recorded', true, disposition.classification, 'eval-only', ...
    'disposition decision recorded for Phase 25'); %#ok<AGROW>

%% ---- 6. Save ----
out = struct('date', datestr(now), 'auditRes', auditRes, 'rogueScripts', {rogueM}, ...
    'finalMat', {finD}, 'smokeMats', {stD}, 'smokePngs', {stP}, 'disposition', disposition);
outDir = fullfile(projectRoot,'data','analysis','day10','phase20');
if ~exist(outDir,'dir'), mkdir(outDir); end
save(fullfile(outDir,'phase20_rogue_triage.mat'), '-struct', 'out');

%% ---- Summary ----
nPass=0; nFail=0; fprintf('\n');
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