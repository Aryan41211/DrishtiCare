function phase7_metric_freeze()
% PHASE7_METRIC_FREEZE Metric definition freeze.
%   Locks the EXACT formulas used by the committed evaluation path
%   (re_verify_audit.m, evaluateClassifier.m, evaluateBinaryClassifier.m,
%   computeQWK) and shows they reproduce every headline number on the cached
%   locked-val arrays. Downstream reports and audits MUST use these
%   definitions; the registry is the single source of truth.
%
%   Frozen definitions (all 1-based labels 1..5, classes
%   {NoDR, Mild, Moderate, Severe, Proliferative}):
%     accuracy       = mean(YPred==YTrue)                         (per-image)
%     per-class recall c : tp_c/(tp_c+fn_c+eps),  tp from conf(c,c)
%     per-class F1   c : 2*tp_c/(2*tp_c+fp_c+fn_c+eps)
%     macroF1        = mean(per-F1)
%     QWK            : weights W=(i-j)^2/(5-1)^2, O=confmat, E=row*col/n,
%                      qwk = 1 - sum(W.*O)/sum(W.*E + eps)
%     referable      = true grade >= 2  (1-based label >= 3)
%     binary decision: PRef >= 0.60 (PRef = 2nd output, P(referable))
%     bin sens       = TP/(TP+FN+eps); bin spec = TN/(TN+FP+eps)
%     ROC-AUC / PR-AUC: perfcurve(posclass=true)

projectRoot = fileparts(fileparts(mfilename('fullpath')));
cd(projectRoot);
addpath(genpath(fullfile(projectRoot, 'src')));

results = struct('check', {}, 'status', {}, 'measured', {}, 'expected', {}, 'note', {});

fprintf('============================================================\n');
fprintf('  PHASE 7 - METRIC DEFINITION FREEZE\n');
fprintf('  Date: %s\n', datestr(now));
fprintf('============================================================\n');

A = load(fullfile('data','analysis','day8','reverify_audit_T0.mat'), ...
    'YTrue5','YPred5','PRef','s5All');
Yt = A.YTrue5; Yp = A.YPred5; pRef = A.PRef;

%% ---- 1. 5-class metrics with frozen formulas ----
acc  = mean(Yp == Yt);
perRec = zeros(5,1); perF1 = zeros(5,1);
for c = 1:5
    tp = sum(Yt==c & Yp==c);
    fp = sum(~(Yt==c) & Yp==c);
    fn = sum(Yt==c & ~(Yp==c));
    perRec(c) = tp/(tp+fn+eps);
    perF1(c)  = 2*tp/(2*tp+fp+fn+eps);
end
mac = mean(perF1);
qwk = qwkLocked(Yt, Yp);

nms = {'NoDR','Mild','Moderate','Severe','Proliferative'};
headlines = {'acc_5cls', acc, 0.8281;
             'macroF1',  mac, 0.6805;
             'qwk',      qwk, 0.8914};
results(end+1) = record('P7 acc_5cls',     abs(acc-0.8281)<5e-4, acc, 0.8281, 'frozen formulas'); %#ok<AGROW>
results(end+1) = record('P7 macroF1',      abs(mac-0.6805)<5e-4, mac, 0.6805, 'frozen formulas'); %#ok<AGROW>
results(end+1) = record('P7 qwk',          abs(qwk-0.8914)<5e-4, qwk, 0.8914, 'frozen formulas'); %#ok<AGROW>
expRec = [0.9834 0.6081 0.7850 0.4872 0.5254];
for c = 1:5
    results(end+1) = record(['P7 recall_' nms{c}], abs(perRec(c)-expRec(c))<5e-4, ...
        perRec(c), expRec(c), 'frozen per-class recall'); %#ok<AGROW>
end

%% ---- 2. Binary metrics with frozen formulas ----
refTrue = Yt >= 3;             % referable = Moderate/Severe/Proliferative
dec = pRef >= 0.60;            % locked binary decision
tp = sum(refTrue & dec); fp = sum(~refTrue & dec);
fn = sum(refTrue & ~dec); tn = sum(~refTrue & ~dec);
sens = tp/(tp+fn+eps); spec = tn/(tn+fp+eps);
[Xr, Yr, ~, rauc] = perfcurve(refTrue, pRef, true);
[Xp, Rp, ~, prauc] = perfcurve(refTrue, pRef, true, 'XCrit','tpr','YCrit','prec');
results(end+1) = record('P7 bin_sens', abs(sens-0.9060)<5e-4, sens, 0.9060, 'frozen formulas @0.60'); %#ok<AGROW>
results(end+1) = record('P7 bin_spec', abs(spec-0.9471)<5e-4, spec, 0.9471, 'frozen formulas @0.60'); %#ok<AGROW>
results(end+1) = record('P7 bin_auc',  abs(rauc-0.9796)<1e-3,  rauc, 0.9796, 'perfcurve, posclass=referable'); %#ok<AGROW>
results(end+1) = record('P7 bin_prauc',abs(prauc-0.7821)<1e-3, prauc, 0.7821, 'perfcurve PR (tpr/prec)'); %#ok<AGROW>

%% ---- 3. Emit machine-readable metric registry ----
reg = struct();
reg.date = datestr(now);
reg.classLabels = {'NoDR','Mild','Moderate','Severe','Proliferative'};
reg.labelEncoding = '1-based (1..5); referable = label>=3 = grade>=2';
reg.accuracy     = 'mean(YPred==YTrue) over the evaluation set (per-image)';
reg.macroF1      = 'mean over classes of 2*tp/(2*tp+fp+fn+eps), tp/fp/fn from 5x5 confusion';
reg.perClassRecall = 'tp_c/(tp_c+fn_c+eps)';
reg.qwk          = 'W=(i-j)^2/(5-1)^2; O=conf; E=row*col/n; 1 - sum(W.*O)/(sum(W.*E)+eps)';
reg.binDecision  = 'PRef >= 0.60; PRef is output channel 2 (P(referable)) of binary screener';
reg.binSens      = 'TP/(TP+FN+eps)';
reg.binSpec      = 'TN/(TN+FP+eps)';
reg.rocAuc       = 'perfcurve(posclass=true)';
reg.prAuc        = 'perfcurve(XCrit=tpr, YCrit=prec)';
reg.epsPolicy    = 'eps() added to denominators as in committed evaluators';
reg.mandate      = 'All reports and audits MUST recompute metrics via these frozen definitions; no alternative macro-average or QWK normalization may be substituted.';

outDir = fullfile(projectRoot,'data','analysis','day10','phase7');
if ~exist(outDir,'dir'), mkdir(outDir); end
outMat = fullfile(outDir,'phase7_metric_freeze.mat');
outJson = fullfile(outDir,'phase7_metric_freeze.json');
try, save(outMat,'reg','results','perRec','perF1','qwk','acc','mac','sens','spec','rauc','prauc'); catch, save(outMat,'reg'); end
fid = fopen(outJson,'w'); fprintf(fid,'%s', jsonencode(reg)); fclose(fid);
fprintf('  [DONE] metric registry saved -> %s\n', strrep(outMat,filesep,'/'));

%% ---- Summary ----
fprintf('\n============================================================\n');
nPass=0; nFail=0;
for i=1:numel(results)
    if results(i).status, nPass=nPass+1; tag='PASS'; else, nFail=nFail+1; tag='FAIL'; end
    if isnumeric(results(i).measured) && numel(results(i).measured)==1
        fprintf('  [%s] %-20s measured=%.4g expected=%.4g  %s\n', tag, ...
            results(i).check, results(i).measured, results(i).expected, results(i).note);
    else
        fprintf('  [%s] %-20s  %s\n', tag, results(i).check, results(i).note);
    end
end
fprintf('  TOTAL: %d PASS, %d FAIL\n', nPass, nFail);
end

function k = qwkLocked(a, b)
    nc = 5;
    W = zeros(nc);
    for i = 1:nc, for j = 1:nc, W(i,j) = (i-j)^2/(nc-1)^2; end, end
    n = numel(a);
    O = zeros(nc);
    for i = 1:n, O(a(i), b(i)) = O(a(i), b(i)) + 1; end
    E = sum(O,2) * sum(O,1) / n;
    k = 1 - sum(W(:).*O(:)) / (sum(W(:).*E(:)) + eps);
end

function rr = record(check, status, measured, expected, note)
    rr = struct('check', check, 'status', status, 'measured', measured, ...
                'expected', expected, 'note', note);
end