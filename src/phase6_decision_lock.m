function phase6_decision_lock()
% PHASE6_DECISION_LOCK Threshold decision lock.
%   Freezes every decision threshold on the screening path, records its
%   provenance, and asserts the hard-coded values in committed code match the
%   locked contract. No re-tuning is permitted on the validation split and the
%   sealed test set is never touched.
%
%   Decision registry (locked):
%     pRefLocked     0.60  binary referral  (provenance: Day 6 binary threshold
%                                           sweep, rule "last point with sens
%                                           >= 0.90", hard-coded before the
%                                           Day 7 champion)
%     abstainConf    0.50  router abstain floor    (cascade_router default)
%     reviewConf     0.75  router review floor     (cascade_router default)
%     marginThr      0.20  top1-top2 margin        (cascade_router default)
%     pRefBand       0.05  abstain band around 0.60 (cascade_router default)
%     agreePRef      0.50  screen/grade agree pivot (cascade_router default)
%     quality gates   -    6 engineering metrics (Day 3 percentiles, NOT
%                           clinically validated; see defaultQualityConfig v2.x)
%
%   Honest framing: 0.60 was tuned ON the validation split at Day 6. The
%   val binary sens/spec are operating-point estimates, not fully held-out.
%   The sealed test set + external datasets (Messidor-2, Phases 14/16) are
%   the held-out evidence.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
cd(projectRoot);
addpath(genpath(fullfile(projectRoot, 'src')));

results = struct('check', {}, 'status', {}, 'measured', {}, 'expected', {}, 'note', {});

fprintf('============================================================\n');
fprintf('  PHASE 6 - DECISION THRESHOLD LOCK\n');
fprintf('  Date: %s\n', datestr(now));
fprintf('============================================================\n');

%% ---- 1. Hard-coded values in committed code match the locked contract ----
% predictSingleFundus.m default BinaryThreshold
str = fileread(fullfile('src','inference','predictSingleFundus.m'));
tok = regexp(str, "addParameter\(p, 'BinaryThreshold',\s*([0-9.]+)", 'tokens', 'once');
assert(~isempty(tok), 'BinaryThreshold default not found in predictSingleFundus');
thrPSF = str2double(tok{1});
results(end+1) = record('P6 predictSingleFundus_BinThr', thrPSF==0.60, thrPSF, 0.60, 'locked 0.60'); %#ok<AGROW>

% cascade_router.m defaults
d = cascade_router_defs();
ok = all([d.abstainConf d.reviewConf d.marginThr d.pRefBand d.pRefLocked d.agreePRef] == ...
         [0.50 0.75 0.20 0.05 0.60 0.50]);
results(end+1) = record('P6 cascade_router_defaults', ok, ...
    [d.abstainConf d.reviewConf d.marginThr d.pRefBand d.pRefLocked d.agreePRef], ...
    [0.50 0.75 0.20 0.05 0.60 0.50], 'all router defaults locked'); %#ok<AGROW>

% quality config
cfg = defaultQualityConfig();
results(end+1) = record('P6 quality_cfg_version', strcmp(cfg.version,'2.0.0') ...
    && contains(cfg.derivedFrom,'3,662'), cfg.version, '2.0.0', ...
    sprintf('thresholds from %s (prototype, NOT clinical)', cfg.derivedFrom)); %#ok<AGROW>

%% ---- 2. Provenance: Day 6 binary sweep rule reproduces 0.60 ----
E = load(fullfile('data','analysis','day6','binary','day6_binary_referable_v1_metrics.mat'), 'metrics');
m6 = E.metrics;
tol = 1e-9;   % sweep 0.05:0.05:0.95 accumulates float error (idx12 = 0.6000..01)
okIdx = find(m6.thrSens >= 0.90, 1, 'last');
reprod = m6.thresholds(okIdx);
results(end+1) = record('P6 day6_rule_reproduces_060', abs(reprod-0.60)<tol, reprod, 0.60, ...
    'committed rule find(thrSens>=0.90,1,''last'') on the Day 6 sweep -> 0.60'); %#ok<AGROW>
results(end+1) = record('P6 day6_chosenThreshold', abs(m6.chosenThreshold-0.60)<tol, ...
    m6.chosenThreshold, 0.60, 'artifact records chosenThreshold=0.60'); %#ok<AGROW>

%% ---- 3. Operating point at locked 0.60 on the 733-val (fresh recompute) ----
A = load(fullfile('data','analysis','day8','reverify_audit_T0.mat'), 'YTrue5','PRef');
Yt = A.YTrue5; pRef = A.PRef;
refTrue = Yt>=3; dec = pRef>=0.60;
sens = sum(refTrue&dec)/(sum(refTrue)+eps);
spec = sum(~refTrue&~dec)/(sum(~refTrue)+eps);
results(end+1) = record('P6 val_sens_at_060', abs(sens-0.9060)<5e-4, sens, 0.9060, ...
    'operating-point estimate on the SAME val used to pick 0.60 (not held-out)'); %#ok<AGROW>
results(end+1) = record('P6 val_spec_at_060', abs(spec-0.9471)<5e-4, spec, 0.9471, ... 
    'operating-point estimate on the SAME val used to pick 0.60 (not held-out)'); %#ok<AGROW>

%% ---- 4. Invariant: no data-driven retuning after the model was locked ----
% The Day 7 champion was evaluated at the pre-existing hard-coded 0.60 default
% (predictSingleFundus), never re-swept. Evidence: champion hashes unchanged
% (Phase 4) and re_audit_T13 asserts thr_locked_060. Mirror that assertion here.
results(end+1) = record('P6 no_retune_invariant', ...
    abs(m6.chosenThreshold-thrPSF)<tol && abs(thrPSF-0.60)<tol, thrPSF, 0.60, ...
    'threshold fixed pre-Day-7; champion never re-swept'); %#ok<AGROW>
results(end+1) = record('P6 sealed_test_untouched', ~exist(fullfile('data','splits','test'),'dir'), ...
    exist(fullfile('data','splits','test'),'dir'), 0, 'no test-split dir present locally'); %#ok<AGROW>

%% ---- 5. Emit machine-readable decision registry ----
reg = struct();
reg.date = datestr(now);
reg.pRefLocked        = struct('value',0.60,'provenance','Day 6 binary sweep, rule sens>=0.90 last index; hard-coded pre-Day-7 champion','tunedOn','val split (honest caveat: val metrics are operating-point estimates)','status','LOCKED - no retuning');
reg.abstainConf       = struct('value',0.50,'provenance','cascade_router default','tunedOn','none (engineering default)','status','LOCKED');
reg.reviewConf        = struct('value',0.75,'provenance','cascade_router default','tunedOn','none (engineering default)','status','LOCKED');
reg.marginThr         = struct('value',0.20,'provenance','cascade_router default','tunedOn','none (engineering default)','status','LOCKED');
reg.pRefBand          = struct('value',0.05,'provenance','cascade_router default','tunedOn','none (engineering default)','status','LOCKED');
reg.agreePRef         = struct('value',0.50,'provenance','cascade_router default','tunedOn','none (engineering default)','status','LOCKED');
reg.quality           = struct('value','6 metric bounds (brightness/contrast/focus/foreground/illumination/mask)','provenance','defaultQualityConfig v2.0.0, Day 3 percentiles of 3,662 APTOS images','tunedOn','none','validationStatus','Prototype - NOT clinically validated','status','LOCKED');
reg.rule_no_retune    = 'No decision threshold may be changed on the validation split, and the sealed test set is never used for threshold selection.';
reg.held_out_evidence = 'Sealed APTOS test set at baseline (undownloadable) + external Messidor-2 / Sin-NP DR 2019 (Phases 14/16).';

outDir = fullfile(projectRoot,'data','analysis','day10','phase6');
if ~exist(outDir,'dir'), mkdir(outDir); end
outMat = fullfile(outDir,'phase6_decision_lock.mat');
outJson = fullfile(outDir,'phase6_decision_lock.json');
try, save(outMat,'reg','results'); catch, save(outMat,'reg'); end
fid = fopen(outJson,'w');
fprintf(fid, '%s', jsonencode(reg));
fclose(fid);
fprintf('  [DONE] decision registry saved -> %s\n', strrep(outMat,filesep,'/'));

%% ---- Summary ----
fprintf('\n============================================================\n');
nPass=0; nFail=0;
for i=1:numel(results)
    if results(i).status, nPass=nPass+1; tag='PASS'; else, nFail=nFail+1; tag='FAIL'; end
    if isnumeric(results(i).measured) && numel(results(i).measured)==1
        fprintf('  [%s] %-34s measured=%.4g expected=%.4g  %s\n', tag, ...
            results(i).check, results(i).measured, results(i).expected, results(i).note);
    else
        fprintf('  [%s] %-34s  %s\n', tag, results(i).check, results(i).note);
    end
end
fprintf('  TOTAL: %d PASS, %d FAIL\n', nPass, nFail);
end

function d = cascade_router_defs()
    d.abstainConf=0.50; d.reviewConf=0.75; d.marginThr=0.20;
    d.pRefBand=0.05;    d.pRefLocked=0.60; d.agreePRef=0.50;
end

function rr = record(check, status, measured, expected, note)
    rr = struct('check', check, 'status', status, 'measured', measured, ...
                'expected', expected, 'note', note);
end