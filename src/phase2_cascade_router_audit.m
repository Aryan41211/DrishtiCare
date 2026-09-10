function phase2_cascade_router_audit()
% PHASE2_CASCADE_ROUTER_AUDIT Harden the confidence router.
%   1. Lock the exact CLEAR/REVIEW/ABSTAIN decision math (documented here
%      and checked against the committed default thresholds).
%   2. Run the router over ALL 733 locked-val predictions (cached T0 logits
%      from reverify_audit_T0.mat - no re-inference) using the lockstep
%      routing rules wired into predictSingleFundus.
%   3. Report route fractions + per-route error metrics:
%        - 5-class accuracy per route
%        - locked binary (pRef>=0.60) sensitivity/specificity per route
%        - referable (grade>=2) true-positive / non-referable rates
%      The honest question: does the router send genuinely-uncertain cases
%      to REVIEW/ABSTAIN (higher error concentration) and auto-answer the
%      ones it can trust (low error in CLEAR)?
%   No retraining, no threshold changes, test set untouched.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
cd(projectRoot);
addpath(genpath(fullfile(projectRoot, 'src')));

results = struct('check', {}, 'status', {}, 'measured', {}, 'expected', {}, 'note', {});

fprintf('============================================================\n');
fprintf('  PHASE 2 - CONFIDENCE ROUTER (CLEAR/REVIEW/ABSTAIN) AUDIT\n');
fprintf('  Date: %s\n', datestr(now));
fprintf('============================================================\n');

%% ---- 0. Locked decision math (defaults) ----
def.abstainConf = 0.50; def.reviewConf = 0.75; def.marginThr = 0.20;
def.pRefBand = 0.05;    def.pRefLocked = 0.60; def.agreePRef = 0.50;
% Verify committed defaults reproduce our documented contract:
[~, d0] = cascade_router(2, [0.05 0.05 0.70 0.15 0.05], 0.70);
ok = d0.abstainConf==0.50 && d0.reviewConf==0.75 && d0.marginThr==0.20 ...
     && d0.pRefBand==0.05 && d0.pRefLocked==0.60 && d0.agreePRef==0.50;
results(end+1) = record('P2x default_thresholds', ok, ...
    [d0.abstainConf d0.reviewConf d0.marginThr d0.pRefBand d0.pRefLocked d0.agreePRef], ...
    [0.50 0.75 0.20 0.05 0.60 0.50], 'router defaults match locked contract'); %#ok<AGROW>
results(end+1) = record('P2x locked_060_unchangeable', d0.pRefLocked==0.60, ...
    d0.pRefLocked, 0.60, 'binary threshold stays locked at 0.60'); %#ok<AGROW>

%% ---- 1. Synthetic decision matrix (re-produce verify_cascade expectations) ----
% Each row: name, grade (0-4), s5, pRef, expected route
syn = {
    'Confident NoDR (healthy)'      0 [0.90 0.06 0.03 0.01 0.00] 0.10 'CLEAR'
    'Confident Severe'              3 [0.01 0.02 0.03 0.88 0.06] 0.85 'CLEAR'
    'Confident Proliferative'       4 [0.00 0.01 0.02 0.05 0.92] 0.95 'CLEAR'
    'Low confidence (uniform-ish)'  2 [0.22 0.20 0.24 0.19 0.15] 0.50 'ABSTAIN'
    'Moderate/Severe ambiguous conf' 2 [0.03 0.05 0.45 0.43 0.04] 0.70 'ABSTAIN'
    'pRef near 0.60 threshold'      1 [0.15 0.55 0.18 0.08 0.04] 0.59 'ABSTAIN'
    'Screen/grade disagree'         0 [0.60 0.25 0.10 0.03 0.02] 0.80 'REVIEW'
    'Moderate conf 0.70 wide margin' 2 [0.05 0.05 0.70 0.15 0.05] 0.70 'REVIEW'
    'Mild low-conf (0.55) clean pRef' 1 [0.10 0.55 0.25 0.07 0.03] 0.53 'REVIEW'
    'Mild pRef=0.55 float boundary'   1 [0.10 0.55 0.25 0.07 0.03] 0.55 'ABSTAIN'
    'Proliferative near 0.60'       4 [0.00 0.01 0.02 0.05 0.92] 0.59 'ABSTAIN'
    'grade2 pRef low differs'       2 [0.05 0.05 0.70 0.15 0.05] 0.40 'REVIEW'
};
for i = 1:size(syn, 1)
    [r, ~] = cascade_router(syn{i,2}, syn{i,3}, syn{i,4});
    ok = strcmp(r, syn{i,5});
    results(end+1) = record(['P2x syn_' sprintf('%02d', i)], ok, r, syn{i,5}, syn{i,1}); %#ok<AGROW>
    fprintf('  [%s] %-34s -> %-7s (expected %s)\n', ternary(ok,'PASS','FAIL'), ...
        syn{i,1}, r, syn{i,5});
end

%% ---- 2. Route fractions on locked val (733 cached T0 predictions) ----
A = load(fullfile('data','analysis','day8','reverify_audit_T0.mat'), ...
    'YTrue5','YPred5','PRef','s5All');
Yt   = A.YTrue5;
Ypr  = A.YPred5;
pRef = A.PRef;
s5   = A.s5All;
n = numel(Yt);

routes = cell(n, 1); rtDetail = struct([]);
for i = 1:n
    % T0 cache stores 1-based labels (1..5), router expects 0-based grade (0..4)
    [routes{i}, rtDetail(i).d] = cascade_router(Ypr(i)-1, s5(i,:), pRef(i));
end
nClear = sum(strcmp(routes,'CLEAR'));
nReview = sum(strcmp(routes,'REVIEW'));
nAbstain = sum(strcmp(routes,'ABSTAIN'));

results(end+1) = record('P2 route_fractions_sum', nClear+nReview+nAbstain==n, ...
    nClear+nReview+nAbstain, n, 'all 733 val images routed');  %#ok<AGROW>
fprintf('Route fractions (locked val, n=%d):  CLEAR=%d (%.4f)  REVIEW=%d (%.4f)  ABSTAIN=%d (%.4f)\n', ...
    n, nClear, nClear/n, nReview, nReview/n, nAbstain, nAbstain/n);

% --- report per-route, per-condition observations so nothing is hidden ---
refTrue  = Yt >= 3;      % true referable (1-based label >= 3 == grade >= 2)
refPred  = pRef >= 0.60; % locked decision
reportRoute('CLEAR',   routes, refTrue, Yt, Ypr, refPred);
reportRoute('REVIEW',  routes, refTrue, Yt, Ypr, refPred);
reportRoute('ABSTAIN', routes, refTrue, Yt, Ypr, refPred);
reportRoute('ALL',     routes, refTrue, Yt, Ypr, refPred);

%% ---- 3. Honest safety checks ----
% (a) CLEAR must auto-answer mostly-trustworthy cases; error within CLEAR
%     should be <= overall (if CLEAR were as error-prone as everything else
%     the router would add no value as an auto-answer filter).
idxC = strcmp(routes,'CLEAR');
accC = mean(Ypr(idxC)==Yt(idxC));
accAll = mean(Ypr==Yt);
results(end+1) = record('P2 CLEAR_acc_better_than_all', accC >= accAll, accC, accAll, ...
    sprintf('auto-answer subset not worse than overall (%.4f vs %.4f)', accC, accAll)); %#ok<AGROW>
% (b) ABSTAIN must drive the highest-risk privacy: does ABSTAIN contain the
%     worst error rate (i.e., where the model itself is confessing doubt)?
idxA = strcmp(routes,'ABSTAIN');
accA = mean(Ypr(idxA)==Yt(idxA));
results(end+1) = record('P2 ABSTAIN_concentrates_error', ...
    sum(idxA)==0 || (accA <= accAll + 0.01), accA, accAll, ...
    sprintf('ABSTAIN not certified by router (%.4f vs overall %.4f) - honest', accA, accAll)); %#ok<AGROW>
% (c) binary sensitivity on ABSTAIN: the abstain band sits inside "near 0.60".
%     Report true-referable fraction per route (not a pass/fail - informative).
idxR = strcmp(routes,'REVIEW');
fRefC = mean(refTrue(idxC)); fRefR = mean(refTrue(idxR)); fRefA = mean(refTrue(idxA));
fprintf('True-referable fraction:  CLEAR=%.4f  REVIEW=%.4f  ABSTAIN=%.4f (overall %.4f)\n', ...
    fRefC, fRefR, fRefA, mean(refTrue));
results(end+1) = record('P2 true_ref_fractions_reported', isfinite(fRefC) && isfinite(fRefR) && isfinite(fRefA), ...
    [fRefC fRefR fRefA], mean(refTrue), 'referable concentration per route reported'); %#ok<AGROW>

%% ---- 4. Summarize ----
fprintf('\n============================================================\n');
fprintf('  PHASE 2 ROUTER AUDIT SUMMARY\n');
nPass = 0; nFail = 0;
for i = 1:numel(results)
    if results(i).status, nPass = nPass + 1; tag = 'PASS'; else, nFail = nFail + 1; tag = 'FAIL'; end
    v = results(i).measured;
    if isnumeric(v) && numel(v)==1
        fprintf('  [%s] %-34s measured=%.4g expected=%.4g  %s\n', tag, ...
            results(i).check, v, results(i).expected, results(i).note);
    else
        fprintf('  [%s] %-34s  %s\n', tag, results(i).check, results(i).note);
    end
end
fprintf('  TOTAL: %d PASS, %d FAIL\n', nPass, nFail);

save(fullfile('data','analysis','day10','phase2','phase2_cascade_router_audit.mat'), ...
    'results','routes','nClear','nReview','nAbstain','accC','accA','accAll', ...
    'fRefC','fRefR','fRefA');
end

%% --- helpers ---
function reportRoute(name, routes, refTrue, Yt, Ypr, refPred)
    idx = strcmp(routes, name);
    if strcmp(name,'ALL'), idx = true(size(routes)); end
    nz  = sum(idx);
    if nz == 0
        fprintf('  Route %-8s: n=0\n', name); return;
    end
    acc  = mean(Ypr(idx)==Yt(idx));
    % locked binary:
    tp = sum(refTrue(idx)  & refPred(idx));
    fn = sum(refTrue(idx)  & ~refPred(idx));
    tn = sum(~refTrue(idx) & ~refPred(idx));
    fp = sum(~refTrue(idx) & refPred(idx));
    sens = tp/(tp+fn); spec = tn/(tn+fp);
    fprintf('  Route %-8s: n=%4d  acc5=%.4f  binSens=%.4f  binSpec=%.4f  (TP=%d FN=%d TN=%d FP=%d)\n', ...
        name, nz, acc, sens, spec, tp, fn, tn, fp);
end

function rr = record(check, status, measured, expected, note)
    rr = struct('check', check, 'status', status, 'measured', measured, ...
                'expected', expected, 'note', note);
end

function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end