function phase5_error_analysis()
% PHASE5_ERROR_ANALYSIS Error-tree analysis on the locked 733-val set.
%   Assumption-first methodology: every error MIGHT signal a problem. Build
%   an error tree, then verify each branch with data from the cached T0
%   predictions (no re-inference, no retraining).
%
%   Error tree (root = all 733 val images):
%     all 733
%      |-- correct (acc 0.8281 -> 607)
%      `-- error (126)
%           |-- adjacent-grade confusions (pred == true +/- 1)
%           |-- far-grade confusions (|pred-true| >= 2)
%           `-- also overlap with: binary-direction errors (referable flip)
%     then per-node diagnostics:
%       - quality correlation (PASS/WARNING/FAIL)
%       - router route of the error (CLEAR auto-answered?)
%       - confidence distribution (low-conf errors?)
%       - per-class error profile (which true classes get misread)
%
%   Each observed pattern is checked against the committed numbers to ensure
%   the story is DATA-backed, not assumed.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
cd(projectRoot);
addpath(genpath(fullfile(projectRoot, 'src')));

results = struct('check', {}, 'status', {}, 'measured', {}, 'expected', {}, 'note', {});

fprintf('============================================================\n');
fprintf('  PHASE 5 - ERROR ANALYSIS (locked 733 val)\n');
fprintf('  Date: %s\n', datestr(now));
fprintf('============================================================\n');

%% ---- Load committed predictions + fresh quality scan ----
A = load(fullfile('data','analysis','day8','reverify_audit_T0.mat'), ...
    'YTrue5','YPred5','PRef','s5All');
Yt = A.YTrue5; Yp = A.YPred5; pRef = A.PRef; s5 = A.s5All;
n = numel(Yt);
% quality: reuse Phase 1's fresh full-val scan (committed this phase)
P1 = load(fullfile('data','analysis','day10','phase1','phase1_quality_gate.mat'), 'valQuality');
qg = P1.valQuality.overall;   % 733x1 cell aligned to sorted-Files order
assert(numel(qg)==n, 'quality scan size mismatch');

err = Yp ~= Yt;
nErr = sum(err);
results(end+1) = record('P5 err_count', nErr == 126, nErr, 126, ...
    sprintf('%d errors on 733 (acc %.4f)', nErr, 1-nErr/n)); %#ok<AGROW>

%% ---- Level 1: accuracy tree ----
fprintf('\n[1] Accuracy tree (root n=%d)\n', n);
fprintf('    correct        : %d  (%.4f)\n', n-nErr, (n-nErr)/n);
fprintf('    error          : %d  (%.4f)\n', nErr, nErr/n);

%% ---- Level 2: error severity (adjacent vs far) ----
gap = abs(Yp - Yt);
adj = err & gap == 1;
far = err & gap >= 2;
results(end+1) = record('P5 adjacent_majority', sum(adj) > sum(far), sum(adj), sum(far), ...
    sprintf('adjacent-grade errors (%d) vs far errors (%d)', sum(adj), sum(far))); %#ok<AGROW>
fprintf('[2] Error composition: adjacent ±1 = %d, far |gap|>=2 = %d\n', sum(adj), sum(far));

% far errors by true class (the serious ones)
farT = find(far);
for c = 1:5
    k = far & Yt==c;
    fprintf('    far errors from true class %d: %d\n', c, sum(k));
end

%% ---- Level 3: binary-direction errors (referable flips) ----
refTrue = Yt >= 3;      % 1-based: referable means true grade >= 3 (Moderate+)
dec = pRef >= 0.60;
fp = ~refTrue & dec;    % false alarm (auto-refer a healthy/mild eye)
fn = refTrue & ~dec;    % missed referral (referable eye sent home)
results(end+1) = record('P5 fp_count', sum(fp)==23, sum(fp), 23, 'false positives match committed'); %#ok<AGROW>
results(end+1) = record('P5 fn_count', sum(fn)==28, sum(fn), 28, 'false negatives match committed'); %#ok<AGROW>
fprintf('[3] Binary errors: FP=%d FN=%d (committed 23/28)\n', sum(fp), sum(fn));

% Breakdown of binary errors by quality bucket (hypothesis: poor quality ->
% more binary errors). Verify with data.
for pq = 1:3
    names = {'PASS','WARNING','FAIL'};
    m = strcmp(qg, names{pq});
    if sum(m)>0
        fpQ = sum(m & fp)/sum(m);
        fnQ = sum(m & fn)/sum(m);
        fprintf('    [%s (n=%d)] FP rate=%.4f FN rate=%.4f\n', names{pq}, sum(m), fpQ, fnQ);
    end
end

%% ---- Level 4: router intersect (errors auto-answered as CLEAR?) ----
% This is the crux: how many errors would have been AUTO-ANSWERED (CLEAR) vs
% sent to REVIEW/ABSTAIN?  Per Phase 2, route fractions were CLEAR 648 etc.
% Recompute routes here (committed function, locked defaults).
routes = cell(n,1);
for i = 1:n
    [routes{i}, ~] = cascade_router(Yp(i)-1, s5(i,:), pRef(i));
end
idxC = strcmp(routes,'CLEAR');
errCleared = err & idxC;
errReview  = err & strcmp(routes,'REVIEW');
errAbstain = err & strcmp(routes,'ABSTAIN');
fprintf('[4] Errors by router (committed router, locked defaults):\n');
fprintf('    errors in CLEAR=%d  REVIEW=%d  ABSTAIN=%d  (total %d)\n', ...
    sum(errCleared), sum(errReview), sum(errAbstain), nErr);
results(end+1) = record('P5 clear_error_rate', sum(errCleared)/(sum(idxC)+eps) < nErr/n, ...
    sum(errCleared)/sum(idxC), nErr/n, ...
    sprintf('CLEAR error rate %.4f < overall %.4f (router filters)', sum(errCleared)/sum(idxC), nErr/n)); %#ok<AGROW>

% Error-by-true-class profile (which true grades the model confuses)
cm = confusionmat(Yt, Yp, 'Order', 1:5);
fprintf('[5] Per-class error profile (true class -> misreads):\n');
for c = 1:5
    tot = sum(cm(c,:));
    if tot>0
        fprintf('    true class %d (n=%d): correct %d, misread %d (%.4f)\n', ...
            c, tot, cm(c,c), tot-cm(c,c), 1-cm(c,c)/tot);
    end
end

%% ---- Level 5: confidence of errors (are errors low-confidence?) ----
conf = max(s5, [], 2);           % per-image confidence (argmax prob)
for bIdx = 1:3
    switch bIdx
        case 1, mm = conf >= 0.75;
        case 2, mm = conf >= 0.50 & conf < 0.75;
        case 3, mm = conf < 0.50;
    end
    if sum(mm)>0
        bands = {'high(>=.75)','mid(.50-.75)','low(<.50)'};
        fprintf('    conf %-12s n=%4d  err-rate=%.4f\n', bands{bIdx}, sum(mm), sum(err&mm)/sum(mm));
    end
end

%% ---- Summary ----
fprintf('\n============================================================\n');
nPass=0; nFail=0;
for i=1:numel(results)
    if results(i).status, nPass=nPass+1; tag='PASS'; else, nFail=nFail+1; tag='FAIL'; end
    if isnumeric(results(i).measured) && numel(results(i).measured)==1
        fprintf('  [%s] %-28s measured=%.4g expected=%.4g  %s\n', tag, ...
            results(i).check, results(i).measured, results(i).expected, results(i).note);
    else
        fprintf('  [%s] %-28s  %s\n', tag, results(i).check, results(i).note);
    end
end
fprintf('  TOTAL: %d PASS, %d FAIL\n', nPass, nFail);

outDir = fullfile(projectRoot, 'data','analysis','day10','phase5');
if ~exist(outDir, 'dir'), mkdir(outDir); end
save(fullfile(outDir, 'phase5_error_analysis.mat'), ...
    'results','err','adj','far','fp','fn','errCleared','errReview','errAbstain','cm');
fprintf('  Saved -> data/analysis/day10/phase5/phase5_error_analysis.mat\n');
end

function rr = record(check, status, measured, expected, note)
    rr = struct('check', check, 'status', status, 'measured', measured, ...
                'expected', expected, 'note', note);
end