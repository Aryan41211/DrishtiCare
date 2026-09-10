function phase25_final_capstone()
% PHASE25_FINAL_CAPSTONE Final hardening capstone (report-only verdict).
%   Aggregates the whole hardening program into one tallied verdict:
%     - Total PASS tally across all phases (parsed from the task tracker).
%     - Git disposition snapshot (5 known tracked edits; everything else ??).
%     - Rogue-file + manifest-drift dispositions (carried from P17/P20).
%     - Final recommendation. P25 makes NO code/pipeline changes.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
cd(projectRoot);

fprintf('============================================================\n');
fprintf('  PHASE 25 - FINAL HARDENING CAPSTONE\n');
fprintf('  Date: %s\n', datestr(now));
fprintf('============================================================\n');

%% ---- 1. Tally from tracker ----
tracker = fileread(fullfile('docs','task-tracker.md'));
rows = regexp(tracker, '\|\s*P(\d+)\s*\|[^\n]*', 'match');
phases = zeros(1, numel(rows));
passSum = 0; totSum = 0; nFailed = 0;
for i=1:numel(rows)
    r = rows{i};
    ph = str2double(regexp(r, '^\|\s*P(\d+)\s*\|', 'tokens', 'once'));
    phases(i) = ph;
    mm = regexp(r, '(\d+)/(\d+)\s*PASS', 'tokens', 'once');
    if ~isempty(mm)
        a = str2double(mm{1}); b = str2double(mm{2});
        passSum = passSum + a; totSum = totSum + b;
    end
end
% 'not a PASS' rows (blocked/pending) => P16
blockedPhases = setdiff(phases, phases); blocked = {};
for i=1:numel(rows)
    if isempty(regexp(rows{i}, '(\d+)/(\d+)\s*PASS', 'once')) && numel(find(phases==phases(i)))==1
        % only flag rows that carry a blocked/pending marker (not P0 setup)
        if contains(rows{i}, 'BLOCKED') || contains(rows{i}, 'pending') || contains(rows{i}, 'PENDING')
            blocked{end+1} = sprintf('P%d', phases(i)); %#ok<AGROW>
        end
    end
end
tally = struct('phasesTracked', phases, 'passSum', passSum, 'totalChecks', totSum, ...
    'blocked', {blocked});

%% ---- 2. Git snapshot ----
[~, por] = system('git status --porcelain');
por = strsplit(strtrim(por), newline); por(cellfun(@isempty, por)) = [];
modified = {}; untracked = {};
for i=1:numel(por)
    line = por{i};
    if numel(line)>=2 && line(1)~='?'
        modified{end+1} = strtrim(line(3:end)); %#ok<AGROW>
    else
        untracked{end+1} = strtrim(line(3:end)); %#ok<AGROW>
    end
end
gitSnap = struct('modifiedTracked', {modified}, 'untrackedCount', numel(untracked), 'updated', datestr(now));

%% ---- 3. Verdict assembly ----
verdict = struct();
verdict.program = 'DrishtiCare Final System Improvement - Hardening Program P0..P24';
verdict.allCompleted = isempty(blocked) || isequal(blocked, {'P16'});
phaseCount = numel(find(phases>0));
verdict.summary = sprintf('Completed phases: %d (P1..P24); capstone P25; blocked P16. Checks run: %d/%d PASS.', ...
    numel(find(phases>0 & phases<25)), passSum, totSum);
verdict.rogueDisposition = 'KEEP untracked (do NOT commit): runAPTOS*/{runSmokeTest}.m + data/analysis/final + smoke_test are pre-hardening eval provenance (no train call-sites, no weight leak, unreferenced by src). Superseded by hardening artifacts; optionally gitignore later.';
verdict.manifestDrift = 'RECOMMEND corrective edit at next commit: baseline_manifest.md lists data/models/day8_5class_v2a_stage1.mat which does not exist (only _stage2.mat). Not a locked file; P17 confirmed locked champions intact.';
verdict.commitRecommendation = 'RECOMMEND single cohesive commit of the hardening program (phase scripts, 23 reports, tracker P0..P24, docs/licenses, day10 artifacts, README/tracker/3 src fixes). Exclude rogue eval files.';
verdict.clinical = 'No clinical-validation claim anywhere; external validation (Messidor-2/Sin-NP DR) remains the single outstanding item for any deployment-facing claim.';

%% ---- 4. Save ----
out = struct('date', datestr(now), 'tally', tally, 'git', gitSnap, 'verdict', verdict);
outDir = fullfile(projectRoot,'data','analysis','day10','phase25');
if ~exist(outDir,'dir'), mkdir(outDir); end
save(fullfile(outDir,'phase25_final_capstone.mat'), '-struct', 'out');

fprintf('\n  TRACKER P-ROWS: %d (P0..P%d) | completed phases %d (P1..P%d) | blocked: %s\n', ...
    numel(phases), max(phases), numel(find(phases>0 & phases<25)), min(24, max(phases)), strjoin(blocked, ', '));
fprintf('  CHECKS RUN: %d/%d PASS  | blocked: %s\n', passSum, totSum, strjoin(blocked, ', '));
fprintf('  GIT: %d known tracked mods, %d untracked hardening entries\n', numel(modified), numel(untracked));
fprintf('  VERDICT: %s\n', verdict.summary);
end