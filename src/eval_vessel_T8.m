function eval_vessel_T8()
%EVAL_VESSEL_T8 Task 8: does adding DRIVE-trained vessel features help Branch B?
%   Two logistic referable classifiers are fit on the SAME 250-image
%   training subsample used originally by Branch B (data/analysis/day8/branch_b/
%   feat_cache.mat rows 1..250, images in data/aptos2019/train_images):
%     (a) baseline   : the original 10 lesion features  (sanity: must reproduce
%                      Branch B full-733 AUC ~0.8969)
%     (b) +vessel    : the 10 lesion features + 8 vessel features (extracted
%                      by the DRIVE-trained segmenter, SAME 250 images)
%   Both use IDENTICAL protocol (rng(7), lasso lambda 1e-3, sparsa, per-column
%   /max scaling from the FIT rows only, temperature fit by NLL on the SAME
%   50-image eval slice). Then scored on the FULL 733-val set.
%
%   Compares ROC-AUC (full 733), match-rate @0.60 vs Branch A, and fusion
%   agree/REVIEW counts (fuseEvidence rules, same as Task 7). Bootstrap
%   (B=500 resamples of the 733 rows) gives a percentile CI on the AUC
%   difference. Outputs data/analysis/day8/task8/branchb_comparison_T8.mat.

projectRoot = 'C:\projects\DrishtiCare';
cd(projectRoot);
addpath(genpath(fullfile(projectRoot, 'src')));
thr   = 0.60;   % locked decision threshold (for BOTH branches)
rng(7);         % same seed as trainBranchB.m (fitclinear)

%% ---- 1. Load inputs ----
B  = load(fullfile('data','analysis','day8','task7','branchb_cache_partial.mat'));  % X 733x10
A  = load(fullfile('data','analysis','day8','reverify_audit_T0.mat'), 'PRef','YTrue5','YPred5','s5All');
FC = load(fullfile('data','analysis','day8','branch_b','feat_cache.mat'));
VFv = load(fullfile('data','analysis','day8','task8','vessel_features_val733.mat'));
VFf = load(fullfile('data','analysis','day8','task8','vessel_features_train250.mat'));

Xall10 = double(B.X);                      % 733 x 10 (full val block)
ids733 = B.ids;
n = size(Xall10,1); assert(n == 733);
yRef = double(A.YTrue5 >= 3);              % referable = grade >= 2
goldGrade = A.YTrue5 - 1;

% --- align vessel val features to the 733 (full-path equality) ---
assert(all(strcmp(VFv.ids, ids733)), 'VFv ids != branchb ids (mismatch)');
VF733 = VFv.VF;                            % 733 x 8
assert(size(VF733,1) == n);

% --- fit rows: the original 250-image subsample ---
fitIdx = find(~FC.isVal);                  % 250 rows of feat_cache
ufit   = unique(fitIdx); assert(numel(ufit) == 250);
Xfit10 = double(FC.X(fitIdx, :));
yfit   = double(FC.grade(fitIdx) >= 2);

% --- vessel features for the SAME 250 fit images (name suffix match) ---
fitNames = cellfun(@(s) char(regexp(s,'[^\\/]+\.png$','match','once')), VFf.ids, 'uni', 0);
for k = 1:numel(fitNames)                  % strip trailing \r if any
    fitNames{k} = regexprep(fitNames{k}, '[\r\n]', '');
end
fcNames = cellstr(FC.ids);
fcNames = cellfun(@(s) regexprep(s, '[\r\n]', ''), fcNames, 'uni', 0);
[tf, locFit] = ismember(fcNames, fitNames);
assert(all(tf(1:250)), 'vessel fit features missing some of the 250 fit images');
ordFit = zeros(250,1);
for k = 1:250
    ordFit(k) = locFit(k);
end
VFfit = VFf.VF(ordFit, :);                 % 250 x 8, VFf rows reordered to feat_cache order
assert(size(VFfit,1) == 250);

% --- eval slice for temperature fit: the original 50 hold-out images ---
eidx = find(FC.isVal);                    % rows of feat_cache
assert(numel(eidx) == 50);
[eTf, eLoc] = ismember(fcNames(eidx), fitNames2(ids733));
assert(all(eTf), 'temp eval images not found in the 733 block');
tempRows = eLoc(:);                       % indices into the 733 block

%% ---- 2. Alignment cross-checks (grade vs audit gold) ----
alignMiss = sum(goldGrade ~= B.grade);
fprintf('grade vs YTrue5-1 mismatches: %d / 733\n', alignMiss);
if alignMiss > 0, error('alignment broken'); end

%% ---- 3. Model fit helper (identical protocol) ----
% fitTwo(Xfit, Xeval, yfit, yEvalRows, tempRows)
% returns scores on the full 733 (already /max-scaled + temperature-scaled)
scoresBaseline = fitAndScore(Xfit10, Xall10, yfit, yRef, tempRows, 'baseline ');
scoresVessel   = fitAndScore([Xfit10 VFfit], [Xall10 VF733], yfit, yRef, tempRows, '+vessel  ');

pBase = scoresBaseline; pVes = scoresVessel;

%% ---- 4. Main metrics on full 733 ----
[~,~,~,aucBase] = perfcurve(yRef, pBase, true);
[~,~,~,aucVes ] = perfcurve(yRef, pVes , true);
matchBase = mean((pBase >= thr) == (A.PRef >= thr));
matchVes  = mean((pVes  >= thr) == (A.PRef >= thr));

fprintf('\nFULL 733: baseline AUC=%.4f match@0.60=%.4f | +vessel AUC=%.4f match=%.4f\n', ...
    aucBase, matchBase, aucVes, matchVes);

%% ---- 5. Bootstrap CI on the AUC difference (resample scored rows) ----
Bx = 500; rng(11);
d = zeros(Bx,1); dMatch = zeros(Bx,1);
for b = 1:Bx
    ir = randsample(n, n, true);
    [~,~,~,a1] = perfcurve(yRef(ir), pBase(ir), true);
    [~,~,~,a2] = perfcurve(yRef(ir), pVes(ir), true);
    d(b) = a2 - a1;
    dMatch(b) = mean((pVes(ir)>=thr)==(A.PRef(ir)>=thr)) - mean((pBase(ir)>=thr)==(A.PRef(ir)>=thr));
end
ciLo = prctile(d, 2.5); ciHi = prctile(d, 97.5);
ciMLo = prctile(dMatch, 2.5); ciMHi = prctile(dMatch, 97.5);
pVesWin = mean(d > 0);
fprintf('AUC diff (vessel - baseline): %.4f  [95%% CI %.4f .. %.4f]  P(diff>0)=%.3f\n', ...
    mean(d), ciLo, ciHi, pVesWin);
fprintf('Match-rate diff: %.4f [95%% CI %.4f .. %.4f]\n', mean(dMatch), ciMLo, ciMHi);

%% ---- 6. Fusion counts (same fuseEvidence pipeline as Task 7) ----
Tcal = loadTemperatureParams();
[agreeBase, revBase, detBase] = fusionCounts(pBase, A, Tcal, thr);
[agreeVes,  revVes,  detVes ] = fusionCounts(pVes,  A, Tcal, thr);
fprintf('FUSION baseline : agree=%d REVIEW=%d (%d agree/733) | per-class counts %s\n', ...
    agreeBase, revBase, agreeBase, mat2str(detBase));
fprintf('FUSION +vessel  : agree=%d REVIEW=%d (%d agree/733) | per-class counts %s\n', ...
    agreeVes, revVes, agreeVes, mat2str(detVes));

%% ---- 7. Vessel feature diagnostics ----
vadd = VF733;
corrGrade = corr(vadd, goldGrade, 'rows','pairwise');
fprintf('vessel feature corr with grade: %s\n', sprintf('%.3f ', corrGrade));
Cx = abs(corr(Xall10, vadd, 'rows','pairwise'));
fprintf('max |corr(vessel feat, lesion feat)| = %.3f (mean %.3f)\n', max(Cx(:)), mean(Cx(:)));
leg1 = fitclinearDouble([Xfit10 VFfit], yfit);   % coefficient ride for report

%% ---- 8. Report + save ----
fprintf('\n==============================================================\n');
fprintf('  TASK 8 - VESSEL-EXTENDED BRANCH B (full 733) RESULT\n');
fprintf('==============================================================\n');
fprintf('  Baseline (10 lesion feats)   AUC = %.4f  (sanity ~0.8969)\n', aucBase);
fprintf('  Baseline + 8 vessel feats    AUC = %.4f\n', aucVes);
fprintf('  Delta (bootstrap B=500)      %.4f  [%s]\n', mean(d), sprintf('%.4f .. %.4f', ciLo, ciHi));
fprintf('  Match-rate @0.60 vs Branch A : %.4f -> %.4f\n', matchBase, matchVes);
fprintf('  Fusion agree  : %d -> %d   REVIEW : %d -> %d\n', agreeBase, agreeVes, revBase, revVes);
fprintf('==============================================================\n');

outFile = fullfile('data','analysis','day8','task8','branchb_comparison_T8.mat');
save(outFile, 'aucBase','aucVes','d','ciLo','ciHi','pVesWin', ...
     'matchBase','matchVes','dMatch','ciMLo','ciMHi', ...
     'agreeBase','revBase','agreeVes','revVes','detBase','detVes', ...
     'pBase','pVes','VF733','VFfit','corrGrade','Cx','leg1', ...
     'alignMiss','tempRows');
fprintf('Saved %s\n', outFile);
end

function p = fitAndScore(Xfit, Xall, yfit, yRef, tempRows, tag)
% Same fit/eval protocol as trainBranchB.m; Xall rows correspond to the 733.
    mx = max(Xfit, [], 1); mx(mx == 0) = 1;
    Xf = Xfit ./ mx; Xa = Xall ./ mx;
    rng(7);
    mdl = fitclinear(Xf, yfit, 'Learner','logistic', ...
        'Regularization','lasso', 'Lambda', 1e-3, 'Solver','sparsa');
    [~, scT] = predict(mdl, Xa);
    s = scT(:, double(mdl.ClassNames) == 1);
    % temperature fit on the SAME 50-image NLL slice used originally
    fT = @(T) mean(-(yRef(tempRows) .* log(max(temperatureScale(s(tempRows), T), 1e-9)) ...
                  + (1-yRef(tempRows)) .* log(max(1-temperatureScale(s(tempRows), T), 1e-9))));
    T = 1.0;
    try, T = fminbnd(fT, 0.1, 8.0); catch, T = 1.0; end
    p = temperatureScale(s, T);
    [~,~,~,a] = perfcurve(yRef, s, true);
    fprintf('%s: fitAUC(fit rows) not computed; full-733 pre-temp AUC=%.4f, T=%.3f\n', tag, a, T);
end

function [agree, rev, det] = fusionCounts(pRefB, A, Tcal, thr)
% Same fuseEvidence pipeline as eval_branchb_fullval_T7.m
    n = numel(pRefB);
    agree = 0; rev = 0; det = zeros(5,1);
    for i = 1:n
        aInfo.grade     = A.YPred5(i) - 1;
        aInfo.pRefCal   = temperatureScale(A.PRef(i), Tcal);
        aInfo.confident = max(A.s5All(i,:)) >= 0.80;
        bInfo.pRefB     = pRefB(i);
        bInfo.available = true;
        [ag, dis, ~] = fuseEvidence(aInfo, bInfo);
        agree = agree + double(ag);
        rev = rev + double(dis);
        det(A.YTrue5(i)-1+1) = det(A.YTrue5(i)-1+1) + double(dis);
    end
end

function names = fitNames2(ids)
    names = cell(numel(ids),1);
    for i = 1:numel(ids)
        m = regexp(ids{i}, '[^\\/]+\.png$', 'match', 'once');
        names{i} = regexprep(m, '[\r\n]', '');
    end
end

function leg1 = fitclinearDouble(X, y)
% Quick auxiliary fit to expose coefficient loadings (report only).
    Xn = X ./ max(max(X, [], 1), 1);
    rng(7);
    mdl = fitclinear(Xn, y, 'Learner','logistic', ...
        'Regularization','lasso', 'Lambda', 1e-3, 'Solver','sparsa');
    leg1 = mdl.Beta(:)';
end