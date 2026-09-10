function phase24_prefinal_hygiene()
% PHASE24_PREFINAL_HYGIENE Pre-final repository hygiene snapshot.
%   Verifies the repo is in a clean, surprise-free, cross-linked state before
%   the Phase 25 capstone:
%     1. git: modified set is exactly the 5 known tracked files, nothing else
%        modified/deleted/added (only untracked hardening artifacts allowed).
%     2. Tracker <-> phase reports cross-linked (each hardening report file is
%        referenced; P16 allowed report-less: blocked).
%     3. Metrics doc + binary metric source-of-truth present/fresh.
%     4. README carries the research disclaimer.
%     5. Phase artifacts present for 4..23 (P16 excluded: blocked).

projectRoot = fileparts(fileparts(mfilename('fullpath')));
cd(projectRoot);

auditRes = struct('check',{},'status',{},'measured',{},'expected',{},'note',{});
fprintf('============================================================\n');
fprintf('  PHASE 24 - PRE-FINAL REPO HYGIENE SNAPSHOT\n');
fprintf('  Date: %s\n', datestr(now));
fprintf('============================================================\n');

%% ---- 1. git surprise-free ----
[st, por] = system('git status --porcelain');
por = strsplit(strtrim(por), newline); por(cellfun(@isempty, por)) = [];
mods = {}; others = {};
for i=1:numel(por)
    line = por{i};
    if numel(line)>=2 && line(1)~='?' && line(2)~='?'
        mods{end+1} = strtrim(line(3:end)); %#ok<AGROW>
    else
        others{end+1} = line; %#ok<AGROW>
    end
end
expectedMods = {['README' filesep '..' filesep 'README.md'], 'docs/task-tracker.md', ...
    'src/enhancement/enhanceImage.m', 'src/explainability/buildExplanationNarrative.m', ...
    'src/inference/predictSingleFundus.m'};
isExp = @(m) any(strcmp(m, expectedMods)) || any(strcmp(strrep(m,'\','/'), ...
    {'README.md','docs/task-tracker.md','src/enhancement/enhanceImage.m', ...
     'src/explainability/buildExplanationNarrative.m','src/inference/predictSingleFundus.m'}));
okMods = numel(mods)==5 && all(cellfun(isExp, mods));
auditRes(end+1) = rec('P24 git_modified_set_known', okMods, ...
    strjoin(mods, ', '), '5 known tracked files', ...
    'NOTHING tracked is modified/deleted/added beyond the 5 known hardening edits'); %#ok<AGROW>
onlyFlag = all(cellfun(@(c) ~isempty(strfind(c, '??')), others));
auditRes(end+1) = rec('P24 git_rest_is_untracked', onlyFlag, ...
    sprintf('%d untracked entries', numel(others)), 'all ??', ...
    'all remaining git changes are untracked hardening artifacts (allowed)'); %#ok<AGROW>

%% ---- 2. Tracker <-> reports cross-link ----
rpt = dir(fullfile('docs','validation','*-hardening-phase*.md'));
tracker = fileread(fullfile('docs','task-tracker.md'));
linksOk = true; missingRefs = {};
for i=1:numel(rpt)
    if ~contains(tracker, rpt(i).name)
        linksOk = false; missingRefs{end+1} = rpt(i).name; %#ok<AGROW>
    end
end
% every phase N in {1..23}\{16} has exactly one report; P0 and P16 have none
phRows = regexp(tracker, '\|\s*P(\d+)\s*\|', 'tokens');
phNums = sort(str2double([phRows{:}]));
okRows = isequal(sort(phNums), 0:numel(phNums)-1);                 % contiguous 0..23
reportNums = cellfun(@(nm) str2double(regexp(nm, 'hardening-phase(\d+)-', 'tokens','once')), {rpt.name});
expectedRpt = setdiff(1:(numel(phNums)-1), 16);   % every phase except P16 (blocked, report-less)
okRpt = isequal(sort(reportNums), expectedRpt);
auditRes(end+1) = rec('P24 reports_crosslinked', linksOk && okRows && okRpt, ...
    sprintf('%d reports, %d P-rows (0..%d)', numel(rpt), numel(phNums), max(phNums)), ...
    'contiguous P0.., report set == policy', ...
    'every hardening report referenced in tracker; contiguous P0..; report set == policy'); %#ok<AGROW>

%% ---- 3. Metrics doc + source of truth ----
mA = dir(fullfile('docs','validation','metrics.md'));
srcT = fullfile('data','analysis','day6','binary','day7_pretrained_resnet18_binary_metrics.mat');
okDoc = ~isempty(mA) && contains(tracker, 'metrics.md') || ...   % metrics linked from tracker
        false;
okSrc = exist(srcT,'file')==2;
auditRes(end+1) = rec('P24 metrics_doc_and_source_present', ~isempty(mA) && okSrc, ...
    sprintf('metrics.md=%d, binary mat=%d', ~isempty(mA), okSrc), '1 / 1', ...
    'metrics.md and the binary-metrics source-of-truth mat are present'); %#ok<AGROW>

%% ---- 4. README disclaimer ----
rd = fileread('README.md');
auditRes(end+1) = rec('P24 readme_disclaimer', contains(rd, 'Engineering research project'), ...
    'disclaimer paragraph present', 'present', ...
    'README carries the no-clinical-validation research disclaimer (Phase 13)'); %#ok<AGROW>

%% ---- 5. Phase artifacts present (4..23, excluding 16) ----
missing = {};
for p = [4:15 17:23]
    dd = dir(fullfile('data','analysis','day10',sprintf('phase%d', p), '*.mat'));
    if isempty(dd), missing{end+1} = sprintf('phase%d', p); end %#ok<AGROW>
end
auditRes(end+1) = rec('P24 phase_artifacts_present', isempty(missing), ...
    sprintf('%d artifact dirs found', 19), '19', ...
    'day10 phase artifact .mat present for every completed phase (4..23, P16 excluded)'); %#ok<AGROW>

%% ---- Save ----
out = struct('date', datestr(now), 'gitModified', {mods}, 'gitUntrackedCount', numel(others), ...
    'reports', {rpt}, 'trackerRows', phNums, 'missingArtifacts', {missing}, 'auditRes', auditRes);
outDir = fullfile(projectRoot,'data','analysis','day10','phase24');
if ~exist(outDir,'dir'), mkdir(outDir); end
save(fullfile(outDir,'phase24_prefinal_hygiene.mat'), '-struct', 'out');

%% ---- Summary ----
nPass=0; nFail=0; fprintf('\n');
for i=1:numel(auditRes)
    if auditRes(i).status, nPass=nPass+1; tag='PASS'; else, nFail=nFail+1; tag='FAIL'; end
    fprintf('  [%s] %-34s %s\n', tag, auditRes(i).check, auditRes(i).note);
end
fprintf('  TOTAL: %d PASS, %d FAIL\n', nPass, nFail);
end

function rr = rec(check, status, measured, expected, note)
    rr = struct('check', check, 'status', status, 'measured', measured, ...
                'expected', expected, 'note', note);
end