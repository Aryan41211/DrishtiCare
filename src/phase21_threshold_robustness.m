function phase21_threshold_robustness()
% PHASE21_THRESHOLD_ROBUSTNESS Locked-threshold robustness disclosure.
%   Sweeps the binary decision threshold around the locked 0.60 (0.55..0.65,
%   step 0.01) on the locked 733-val predictions (referable = 1-based label>=3,
%   frozen Phase-7 definitions) and documents the operating-point trade-off.
%   Purpose: prove the decision is NOT knife-edge and quantify what a ±0.05
%   threshold shift would cost in sensitivity/specificity and referral load.
%   NO tuning: this is a disclosure, not an optimisation.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
cd(projectRoot);
addpath(genpath(fullfile(projectRoot,'src')));

auditRes = struct('check',{},'status',{},'measured',{},'expected',{},'note',{});
fprintf('============================================================\n');
fprintf('  PHASE 21 - THRESHOLD-ROBUSTNESS DISCLOSURE\n');
fprintf('  Date: %s\n', datestr(now));
fprintf('============================================================\n');

S = load(fullfile('data','analysis','day8','reverify_audit_T0.mat'));
pRef = S.PRef; yT = S.YTrue5; ref = yT >= 3;
n = numel(ref);

ts = 0.55:0.01:0.65;
rows = struct('t', {}, 'sens', {}, 'spec', {}, 'ppv', {}, 'f1', {}, 'obj', {}, 'referrals', {});
for t = ts
    dec = pRef >= t;
    tp = sum(dec & ref); fp = sum(dec & ~ref); fn = sum(ref & ~dec); tn = sum(~ref & ~dec);
    sens = tp/(tp+fn+eps); spec = tn/(tn+fp+eps);
    ppv  = tp/(tp+fp+eps);
    f1   = 2*tp/(2*tp+fp+fn+eps);
    rows(end+1) = struct('t', t, 'sens', sens, 'spec', spec, 'ppv', ppv, 'f1', f1, ...
        'obj', sens+spec, 'referrals', sum(dec)); %#ok<AGROW>
end

tbl = table([rows.t]', [rows.sens]', [rows.spec]', [rows.ppv]', [rows.f1]', ...
    [rows.referrals]', 'VariableNames', {'t','sens','spec','ppv','f1','referrals'});

% index of t==0.60
i60 = find(abs(ts-0.60)<1e-9);
r60sens = rows(i60).sens; r60spec = rows(i60).spec;

%% ---- Checks ----
auditRes(end+1) = rec('P21 T60_reproduces_frozen', ...
    abs(r60sens-0.9060)<=5e-4 && abs(r60spec-0.9471)<=5e-4, ...
    sprintf('sens %.4f spec %.4f', r60sens, r60spec), '0.9060 / 0.9471', ...
    'threshold-0.60 operating point reproduces frozen binary metrics'); %#ok<AGROW>

deltaSens = abs(rows(i60).sens - rows(end).sens);   % 0.60 -> 0.65
deltaSpec = abs(rows(i60).spec - rows(end).spec);
sensRise  = abs(rows(1).sens - rows(i60).sens);     % 0.55 -> 0.60
specRise  = abs(rows(1).spec - rows(i60).spec);
auditRes(end+1) = rec('P21 sens_stability_window', ...
    deltaSens <= 0.05 && sensRise <= 0.05, ...
    sprintf('0.60->0.65 dSens=%.4f; 0.55->0.60 dSens=%.4f', deltaSens, sensRise), '<=0.05', ...
    'within +/-0.05 of the locked threshold, sensitivity moves by <5 points (not knife-edge)'); %#ok<AGROW>
auditRes(end+1) = rec('P21 spec_stability_window', ...
    deltaSpec <= 0.05 && specRise <= 0.05, ...
    sprintf('0.60->0.65 dSpec=%.4f; 0.55->0.60 dSpec=%.4f', deltaSpec, specRise), '<=0.05', ...
    'within +/-0.05 of the locked threshold, specificity moves by <5 points'); %#ok<AGROW>

% referral-load gradient per 0.01 threshold step (mid-range)
grad = (rows(end).referrals - rows(1).referrals) / (numel(ts)-1);
auditRes(end+1) = rec('P21 referral_gradient_recorded', isfinite(grad), ...
    sprintf('%.1f img per 0.01 step', grad), 'finite', ...
    'referral-load gradient per 0.01 threshold step recorded (disclosure, not tuning)'); %#ok<AGROW>

%% ---- Save ----
out = struct('date', datestr(now), 'thresholds', ts, 'sweep', tbl, ...
    'frozenT60', struct('sens', r60sens, 'spec', r60spec), ...
    'report', struct('sensWindow', deltaSens, 'specWindow', deltaSpec, ...
        'sensRisen', sensRise, 'specRisen', specRise, 'referralGradient', grad), ...
    'n', n, 'auditRes', auditRes);
outDir = fullfile(projectRoot,'data','analysis','day10','phase21');
if ~exist(outDir,'dir'), mkdir(outDir); end
save(fullfile(outDir,'phase21_threshold_robustness.mat'), '-struct', 'out');

%% ---- Summary ----
fprintf('\n  t     sens    spec     ppv     f1   referrals\n');
for i=1:numel(rows)
    flag='';
    if abs(rows(i).t-0.60)<1e-9, flag='  <locked>'; end
    fprintf('  %.2f  %.4f  %.4f  %.4f  %.4f  %4d%s\n', rows(i).t, rows(i).sens, ...
        rows(i).spec, rows(i).ppv, rows(i).f1, rows(i).referrals, flag);
end
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