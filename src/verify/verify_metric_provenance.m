function verify_metric_provenance(projectRoot)
%VERIFY_METRIC_PROVENANCE  Locate the authoritative source of 3 disputed numbers.
%
%   Investigates ONLY these three documented discrepancies (ROADMAP P6):
%     1. DRIVE task8 mean Dice      : doc 0.2576  vs artifact 0.2541
%     2. Human inter-observer Dice  : doc 0.7881  vs artifact 0.7902
%     3. Day-7 scratch baseline row : 0.8307/0.8667  vs 0.8322/0.9080
%
%   Method: load the authoritative .mat artifacts, recursively search every
%   numeric leaf for each disputed value (tolerance 5e-4, matching the
%   project's own committed-precision tolerance used in Phase 4), and report
%   which artifact actually holds which value.
%
%   This script is READ-ONLY. It trains nothing, tunes nothing, and touches no
%   model. It does not choose a value because it looks better.

if nargin < 1 || isempty(projectRoot)
    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end

tol = 5e-4;
outDir = fullfile(projectRoot, 'data', 'analysis', 'day11', 'provenance');
if ~isfolder(outDir), mkdir(outDir); end

targets = { ...
    'data/analysis/day8/task8/drive_test_dice.mat', ...
    'data/analysis/vessel/drive_vessel_metrics.mat', ...
    'data/analysis/vessel/final_test_results.mat', ...
    'data/analysis/vessel/champion_config.mat', ...
    'data/analysis/day5/day5_resnet18_baseline_results.mat', ...
    'data/analysis/day7/eval_fixed_day5_resnet18_baseline_stage2.mat', ...
    'data/analysis/day7/day7_pretrained_5class_metrics.mat', ...
    'data/analysis/day5/day8_5class_v2a_metrics.mat'};

claims = { ...
    'T8_DRIVE_DICE_DOC',    0.2576; ...
    'T8_DRIVE_DICE_ART',    0.2541; ...
    'T8_HUMAN_DICE_DOC',    0.7881; ...
    'T8_HUMAN_DICE_ART',    0.7902; ...
    'SCRATCH_ACC_A',        0.8307; ...
    'SCRATCH_QWK_A',        0.8667; ...
    'SCRATCH_ACC_B',        0.8322; ...
    'SCRATCH_QWK_B',        0.9080};

results = struct('claim', {}, 'value', {}, 'found', {}, 'locations', {});
for c = 1:size(claims, 1)
    results(c).claim    = claims{c, 1};
    results(c).value    = claims{c, 2};
    results(c).found    = false;
    results(c).locations = {};
end

claimVals = cell2mat(claims(:, 2));

fprintf('=== PROVENANCE SEARCH (tol %.0e) ===\n', tol);
for t = 1:numel(targets)
    f = fullfile(projectRoot, strrep(targets{t}, '/', filesep));
    if ~isfile(f)
        fprintf('MISSING  %s\n', targets{t});
        continue
    end
    fprintf('\n--- %s ---\n', targets{t});
    S = load(f);
    names = fieldnames(S);
    for n = 1:numel(names)
        printScalarish(S.(names{n}), names{n}, 0);
        hits = searchValue(S.(names{n}), names{n}, claimVals, tol);
        for h = 1:numel(hits)
            hv = hits(h).val;
            for c = 1:size(claims, 1)
                if abs(hv - claimVals(c)) <= tol
                    results(c).found = true;
                    results(c).locations{end+1} = sprintf('%s :: %s', targets{t}, hits(h).path);
                end
            end
        end
    end
end

fprintf('\n\n=== CLAIM RESOLUTION ===\n');
for c = 1:numel(results)
    if results(c).found
        fprintf('FOUND    %-22s %.4f\n', results(c).claim, results(c).value);
        for L = 1:numel(results(c).locations)
            fprintf('           -> %s\n', results(c).locations{L});
        end
    else
        fprintf('NOTFOUND %-22s %.4f  (no artifact holds this value)\n', results(c).claim, results(c).value);
    end
end

save(fullfile(outDir, 'provenance_findings.mat'), 'results', 'targets', 'claims', 'tol');
fprintf('\nSaved: data/analysis/day11/provenance/provenance_findings.mat\n');
end

% -------------------------------------------------------------------------
function printScalarish(v, name, depth)
if depth > 2, return, end
if isstruct(v)
    fn = fieldnames(v);
    for i = 1:numel(fn)
        printScalarish(v.(fn{i}), [name '.' fn{i}], depth + 1);
    end
elseif iscell(v)
    for i = 1:numel(v)
        printScalarish(v{i}, sprintf('%s{%d}', name, i), depth + 1);
    end
elseif isnumeric(v) || islogical(v)
    if isscalar(v)
        fprintf('  %-52s = %g\n', name, double(v));
    else
        dv = double(v(:));
        fprintf('  %-52s : %s  size %s  min %g max %g mean %.6f\n', name, class(v), ...
            mat2str(size(v)), min(dv), max(dv), mean(dv));
    end
end
end

% -------------------------------------------------------------------------
function hits = searchValue(v, path, claimVals, tol)
hits = struct('path', {}, 'val', {});
if isnumeric(v) || islogical(v)
    d = double(v(:));
    for k = 1:numel(claimVals)
        idx = find(abs(d - claimVals(k)) <= tol);
        for i = 1:numel(idx)
            hits(end+1) = struct('path', sprintf('%s(%d)', path, idx(i)), 'val', d(idx(i)));
        end
    end
elseif isstruct(v)
    fn = fieldnames(v);
    for i = 1:numel(fn)
        hits = [hits, searchValue(v.(fn{i}), [path '.' fn{i}], claimVals, tol)]; %#ok<AGROW>
    end
elseif iscell(v)
    for i = 1:numel(v)
        hits = [hits, searchValue(v{i}, sprintf('%s{%d}', path, i), claimVals, tol)]; %#ok<AGROW>
    end
end
end
