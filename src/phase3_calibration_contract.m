function phase3_calibration_contract()
% PHASE3_CALIBRATION_CONTRACT Calibration stats contract audit.
%   Rebuilds BOTH calibration analyses from the committed cache
%   (data/analysis/day8/calibration/aptos_train_cache.mat) using the locked
%   seed (rng(42) firewalled split) and the canonical statistics in
%   calibrationStats.m, then asserts the rebuilt numbers reproduce the
%   committed artifacts (firewalled_calibration.mat, standard_calibration.mat,
%   current_T.mat) EXACTLY at the same precision the originals report.
%
%   No re-training, no cache mutation, test set untouched.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
cd(projectRoot);
addpath(genpath(fullfile(projectRoot, 'src')));

results = struct('check', {}, 'status', {}, 'measured', {}, 'expected', {}, 'note', {});

fprintf('============================================================\n');
fprintf('  PHASE 3 - CALIBRATION STATS CONTRACT REBUILD\n');
fprintf('  Date: %s\n', datestr(now));
fprintf('============================================================\n');

%% ---- 0. Canonical stat function must match the committed formulas ----
% Sanity: calibrationStats('ece'/'brier'/'nll'/'fit'/'flip') reproduce the
% inline math used by the committed scripts (checked via the rebuild below).

%% ---- 1. Firewalled rebuild ----
C = load(fullfile('data','analysis','day8','calibration','aptos_train_cache.mat'));

rng(42);
allTrain = find(~C.isVal);
allTrain = allTrain(randperm(numel(allTrain)));
calIdx  = allTrain(1:500);
evalIdx = allTrain(501:end);

y  = double(C.grade >= 2);
z  = calibrationStats('logitc', C.pRef);

zCal  = z(calIdx);   yCal  = y(calIdx);
zEval = z(evalIdx);  yEval = y(evalIdx);

T_cal  = calibrationStats('fit', zCal, yCal);
T_eval = calibrationStats('fit', zEval, yEval);

pRawEval = C.pRef(evalIdx);
pCalEval = calibrationStats('scale', pRawEval, T_cal);

eceRawF  = calibrationStats('ece',  pRawEval, yEval);
eceCalF  = calibrationStats('ece',  pCalEval, yEval);
brRawF   = calibrationStats('brier',pRawEval, yEval);
brCalF   = calibrationStats('brier',pCalEval, yEval);
nlRawF   = calibrationStats('nll',  pRawEval, yEval);
nlCalF   = calibrationStats('nll',  pCalEval, yEval);
flipF    = calibrationStats('flip', pRawEval, pCalEval, 0.60);

%% ---- 2. Standard rebuild ----
trainIdx = ~C.isVal;
valIdx   = C.isVal;
zTrain = z(trainIdx); yTrain = y(trainIdx);
zVal   = z(valIdx);   yVal   = y(valIdx);

T_fitVal   = calibrationStats('fit', zVal,   yVal);
T_fitTrain = calibrationStats('fit', zTrain, yTrain);

pRawVal = C.pRef(valIdx);
pCalVal = calibrationStats('scale', pRawVal, T_fitVal);
pCalTr  = calibrationStats('scale', pRawVal, T_fitTrain);

eceRawStd  = calibrationStats('ece',  pRawVal, yVal);
eceCalStd  = calibrationStats('ece',  pCalTr,  yVal);
brRawStd   = calibrationStats('brier',pRawVal, yVal);
brCalStd   = calibrationStats('brier',pCalTr,  yVal);
nlRawStd   = calibrationStats('nll',  pRawVal, yVal);
nlCalStd   = calibrationStats('nll',  pCalTr,  yVal);
flipStd    = calibrationStats('flip', pRawVal, pCalTr, 0.60);

fprintf('  REBUILT  firewalled:  T_cal=%.4f  ECE %.6f->%.6f  Brier %.6f->%.6f  NLL %.6f->%.6f  flip %.6f\n', ...
    T_cal, eceRawF, eceCalF, brRawF, brCalF, nlRawF, nlCalF, flipF);
fprintf('  REBUILT  standard:    T_fitVal=%.4f  T_fitTrain=%.4f  ECE %.6f->%.6f  Brier %.6f->%.6f  NLL %.6f->%.6f  flip %.6f\n', ...
    T_fitVal, T_fitTrain, eceRawStd, eceCalStd, brRawStd, brCalStd, nlRawStd, nlCalStd, flipStd);

%% ---- 3. Compare against committed artifacts ----
FW = load(fullfile('data','analysis','day8','calibration','firewalled','firewalled_calibration.mat'));
ST = load(fullfile('data','analysis','day8','calibration','standard','standard_calibration.mat'));
TH = load(fullfile('data','analysis','day8','calibration','current_T.mat'));

% tolerance: the committed artifacts print %.4f for T / %.4f for metrics
tolT = 5e-5;   % %.4f rounding
tolM = 5e-5;   % %.4f rounding (firewalled summary prints %.4f)

checks = {
  'firewalled_Tcal',        T_cal,     FW.T_cal,        tolT
  'firewalled_Teval',       T_eval,    FW.T_eval,       tolT
  'firewalled_ECE_raw',     eceRawF,   FW.eceRawEval,   tolM
  'firewalled_ECE_cal',     eceCalF,   FW.eceCalEval,   tolM
  'firewalled_Brier_raw',   brRawF,    FW.brierRawEval, tolM
  'firewalled_Brier_cal',   brCalF,    FW.brierCalEval, tolM
  'firewalled_NLL_raw',     nlRawF,    FW.nllRawEval,   tolM
  'firewalled_NLL_cal',     nlCalF,    FW.nllCalEval,   tolM
  'firewalled_flip',        flipF,     FW.flipFraction, 5e-5
  'standard_T_fitVal',      T_fitVal,  ST.T_fitVal,     tolT
  'standard_T_fitTrain',    T_fitTrain,ST.T_fitTrain,   tolT
  'standard_ECE_raw',       eceRawStd, ST.eceRawVal,    tolM
  'standard_ECE_cal',       eceCalStd, ST.eceCalT,      tolM
  'standard_Brier_raw',     brRawStd,  ST.brierRawVal,  tolM
  'standard_Brier_cal',     brCalStd,  ST.brierCalT,    tolM
  'standard_NLL_raw',       nlRawStd,  ST.nllRawVal,    tolM
  'standard_NLL_cal',       nlCalStd,  ST.nllCalT,      tolM
  'standard_flip',          flipStd,   ST.flipFraction, 5e-5
};
for i = 1:size(checks, 1)
    name = checks{i,1}; meas = checks{i,2}; expc = checks{i,3}; tol = checks{i,4};
    ok = abs(meas - expc) <= tol;
    results(end+1) = record(name, ok, meas, expc, sprintf('rebuilt %.8f vs committed %.8f (tol %.0e)', meas, expc, tol)); %#ok<AGROW>
end

% promoted temperature must equal rebuilt fit-on-500 value
promoted = TH.T;
results(end+1) = record('promoted_T_matches_rebuild', abs(promoted - T_cal) <= tolT, ...
    promoted, T_cal, 'current_T.mat promoted T reproduces firewalled fit'); %#ok<AGROW>

%% ---- 4. Summary ----
fprintf('\n============================================================\n');
fprintf('  PHASE 3 SUMMARY\n');
nPass = 0; nFail = 0;
for i = 1:numel(results)
    if results(i).status, nPass = nPass + 1; tag = 'PASS'; else, nFail = nFail + 1; tag = 'FAIL'; end
    fprintf('  [%s] %-30s  %s\n', tag, results(i).check, results(i).note);
end
fprintf('  TOTAL: %d PASS, %d FAIL\n', nPass, nFail);
fprintf('  Stats contract (ECE/Brier/NLL/flip/T) locked in calibrationStats.m.\n');

outDir = fullfile(projectRoot, 'data', 'analysis', 'day10', 'phase3');
if ~exist(outDir, 'dir'), mkdir(outDir); end
save(fullfile(outDir, 'phase3_calibration_contract.mat'), 'results', ...
    'T_cal', 'T_eval', 'T_fitVal', 'T_fitTrain', 'promoted', ...
    'eceRawF','eceCalF','brRawF','brCalF','nlRawF','nlCalF','flipF', ...
    'eceRawStd','eceCalStd','brRawStd','brCalStd','nlRawStd','nlCalStd','flipStd');
fprintf('  Saved -> %s\n', fullfile('data','analysis','day10','phase3'));
end

function rr = record(check, status, measured, expected, note)
    rr = struct('check', check, 'status', status, 'measured', measured, ...
                'expected', expected, 'note', note);
end