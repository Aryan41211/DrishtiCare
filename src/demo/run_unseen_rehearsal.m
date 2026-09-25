function run_unseen_rehearsal(projectRoot)
%RUN_UNSEEN_REHEARSAL  Live end-to-end rehearsal on data NEVER used in training.
%
%   Purpose: the Grand Finale is judged on a live demo and judges may feed
%   surprise inputs. Every existing verification in this repo runs on the
%   labelled APTOS val split, which the models were selected on. This script
%   closes the "surprise-input case has never been tested" gap recorded in
%   docs/project-management/EXECUTION_CHECKLIST.md (Phase H) and ROADMAP P3.
%
%   Three genuinely unseen sources, none used to train or select the champions:
%     1. DRIVE test  - 20 retinal photographs (.tif) from a different camera and
%                     FOV convention. Used previously only for the (now
%                     excluded) vessel segmenter.
%     2. IDRiD B testing set - disease-grading fundus from a third camera.
%                     IDRiD fed the lesion/OD models, NOT the classifiers.
%     3. DRIMDB - real-world web fundus labelled Good / Bad / Outlier. The
%                     Outlier subset is the closest thing to a judge's surprise
%                     input available offline.
%
%   Contract under test: it must not CRASH, and a quality FAIL must still be
%   withheld before any model execution. A poor grade on unseen data is not a
%   defect - it is out of distribution and is reported honestly.
%
%   Frozen contract respected: no training, no tuning, no model modification,
%   BinaryThreshold left at its locked 0.60.

if nargin < 1 || isempty(projectRoot)
    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
P = @(varargin) fullfile(projectRoot, varargin{:});
outDir = P('data','analysis','day11','rehearsal');
if ~isfolder(outDir), mkdir(outDir); end

% Match the app's own path setup exactly (launchRetinaAI.m:9-10) so the
% rehearsal exercises the same resolution the live demo relies on.
addpath(projectRoot);
addpath(genpath(fullfile(projectRoot, 'src')));

cases = buildCaseList(projectRoot);
fprintf('=== UNSEEN-INPUT REHEARSAL: %d images from 3 unseen sources ===\n', numel(cases));
fprintf('%-14s %-30s %-8s %-6s %-7s %-8s %-13s %-6s %s\n', ...
    'SOURCE', 'FILE', 'QUALITY', 'GRADE', 'pRef', 'ROUTE', 'DECISION', 'OOD', 'SECS');

R = blank(numel(cases));
for i = 1:numel(cases)
    c = cases(i);
    R(i) = blank(0);
    R(i).source = c.source; R(i).file = c.file; R(i).path = c.path; R(i).bytes = c.bytes;
    t0 = tic;
    try
        res = predictSingleFundus(c.path, ...
            'EnforceQualityGate', true, 'SkipModelOnFail', true, ...
            'BinaryThreshold', 0.60, 'ShowFigure', false);
        R(i).ok = true;
        R(i).qualityStatus = char(string(res.qualityStatus));
        R(i).grade = double(res.grade);
        R(i).gradeLabel = char(string(res.gradeLabel));
        R(i).pRef = double(res.binaryProbability);
        R(i).decision = char(string(res.binaryDecision));
        if isfield(res, 'cascade') && isfield(res.cascade, 'route')
            R(i).route = char(string(res.cascade.route));
        end
        R(i).confidence = double(res.confidence);
        R(i).ood = readOod(res);
        if isnan(R(i).grade)
            R(i).note = 'WITHHELD (no grade emitted)';
        elseif isfield(res, 'qualityGate') && res.qualityGate.enforced
            R(i).note = 'gate enforced';
        else
            R(i).note = '';
        end
    catch err
        R(i).note = sprintf('ERROR: %s', err.message);
    end
    R(i).secs = toc(t0);
    nm = R(i).file; if numel(nm) > 30, nm = [nm(1:27) '...']; end
    fprintf('%-14s %-30s %-8s %-6s %-7s %-8s %-13s %-6s %.1f\n', ...
        R(i).source, nm, R(i).qualityStatus, grd(R(i).grade), ...
        sp(R(i).pRef), R(i).route, R(i).decision, R(i).ood, R(i).secs);
    if ~isempty(R(i).note)
        fprintf('               -> %s\n', R(i).note);
    end
end

% ---------------------------- contract checks ----------------------------
fprintf('\n=== CONTRACT CHECKS ===\n');
nErr = sum(~[R.ok]);
chk('no crash / no unhandled exception', nErr == 0, ...
    sprintf('%d/%d completed', numel(R) - nErr, numel(R)));

badRoute = false;
for i = 1:numel(R)
    if R(i).ok && ~any(strcmp(R(i).route, {'CLEAR', 'REVIEW', 'ABSTAIN'}))
        badRoute = true;
    end
end
chk('every completed run returned a valid route band', ~badRoute, 'CLEAR/REVIEW/ABSTAIN');

nFail = 0; withheld = true;
for i = 1:numel(R)
    if strcmp(R(i).qualityStatus, 'FAIL')
        nFail = nFail + 1;
        if R(i).ok && ~isnan(R(i).grade), withheld = false; end
    end
end
chk('quality FAIL never auto-answers (grade stays NaN)', withheld, ...
    sprintf('%d FAIL image(s) seen', nFail));

lockOK = true;
for i = 1:numel(R)
    if R(i).ok && ~isnan(R(i).pRef)
        expect = 'REFERABLE';
        if ~(R(i).pRef >= 0.60), expect = 'NON-REFERABLE'; end
        if ~strcmpi(R(i).decision, expect), lockOK = false; end
    end
end
chk('locked 0.60 rule still holds on unseen data', lockOK, ...
    'referable == raw pRef >= 0.60');

% ------------------------------ timing ----------------------------------
secs = [R([R.ok]).secs];
if ~isempty(secs)
    fprintf('\n=== TIMING (full demo path, UNSEEN data - not comparable to the 11.03 s/img APTOS figure) ===\n');
    fprintf('  n=%d  median %.2f s  mean %.2f s  min %.2f s  max %.2f s\n', ...
        numel(secs), median(secs), mean(secs), min(secs), max(secs));
end

srcs = string({R.source});
okm = [R.ok];
fprintf('\n=== PER-SOURCE MEDIAN SECONDS (completed runs only) ===\n');
for u = unique(srcs)
    sel = okm & (srcs == u);
    if any(sel)
        fprintf('  %-14s %5.2f s  (n=%d of %d)\n', char(u), median(secs(sel)), sum(sel), sum(srcs == u));
    end
end

routes = string({R.route});
fprintf('\n=== ROUTE DISTRIBUTION ON UNSEEN DATA ===\n');
for u = unique(routes)
    fprintf('  %-9s %d\n', char(u), sum(routes == u));
end
fprintf('\n=== QUALITY DISTRIBUTION ON UNSEEN DATA ===\n');
qs = string({R.qualityStatus});
for u = unique(qs)
    fprintf('  %-9s %d\n', char(u), sum(qs == u));
end

T = table(srcs', string({R.file})', [R.ok]', qs', [R.grade]', [R.pRef]', ...
    string({R.decision})', routes', [R.confidence]', string({R.ood})', ...
    [R.secs]', string({R.note})', 'VariableNames', ...
    {'source', 'file', 'completed', 'quality', 'grade', 'pRef', 'decision', ...
     'route', 'confidence', 'ood', 'seconds', 'note'});
writetable(T, fullfile(outDir, 'unseen_rehearsal_results.csv'));
save(fullfile(outDir, 'unseen_rehearsal_results.mat'), 'R', 'cases', 'T');
fprintf('\nSaved: data/analysis/day11/rehearsal/unseen_rehearsal_results.{csv,mat}\n');
end

% -------------------------------------------------------------------------
function v = blank(n)
v = struct('source', '', 'file', '', 'path', '', 'bytes', 0, 'ok', false, ...
    'qualityStatus', '', 'grade', NaN, 'gradeLabel', '', 'pRef', NaN, ...
    'decision', '', 'route', '', 'confidence', NaN, 'ood', '', ...
    'secs', NaN, 'note', '');
if n > 0, v = repmat(v, 1, n); end
end

function s = readOod(res)
s = '';
try
    if isfield(res, 'ood') && ~isempty(res.ood) && isfield(res.ood, 'available')
        if res.ood.available
            if res.ood.flag
                s = sprintf('OOD(%.1f)', res.ood.mahalanobis);
            else
                s = sprintf('in(%.1f)', res.ood.mahalanobis);
            end
        else
            s = 'n/a';
        end
    end
catch
    s = '?';
end
end

function cases = buildCaseList(projectRoot)
P = @(varargin) fullfile(projectRoot, varargin{:});
cases = struct('source', {}, 'file', {}, 'path', {}, 'bytes', {});

d = dir(P('data','drive','DRIVE','test','images','*.tif'));
for i = 1:min(5, numel(d))
    cases(end+1) = mk('DRIVE', d(i).name, fullfile(d(i).folder, d(i).name), d(i).bytes); %#ok<AGROW>
end

d = dir(P('data','idrid','B. Disease Grading','1. Original Images','b. Testing Set','*.jpg'));
for i = 1:min(5, numel(d))
    cases(end+1) = mk('IDRID_GRADING', d(i).name, fullfile(d(i).folder, d(i).name), d(i).bytes); %#ok<AGROW>
end

for grp = ["Good", "Bad", "Outlier"]
    d = dir(fullfile(P('data','drimdb','DRIMDB',char(grp)), '**', '*.jpg'));
    for i = 1:min(3, numel(d))
        cases(end+1) = mk(char("DRIMDB_" + grp), d(i).name, ...
            fullfile(d(i).folder, d(i).name), d(i).bytes); %#ok<AGROW>
    end
end
end

function c = mk(source, file, path, bytes)
c = struct('source', source, 'file', file, 'path', path, 'bytes', bytes);
end

function chk(label, ok, note)
if ok, s = 'PASS'; else, s = '**FAIL**'; end
fprintf('  %-52s %-8s %s\n', label, s, note);
end

function s = grd(g)
if isnan(g), s = 'NaN'; else, s = sprintf('%d', g); end
end

function s = sp(v)
if isnan(v), s = 'NaN'; else, s = sprintf('%.4f', v); end
end
