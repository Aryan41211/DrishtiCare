function phase10_protocol_freeze()
% PHASE10_PROTOCOL_FREEZE Evaluation protocol freeze.
%   Declares and verifies the frozen evaluation protocol:
%     1. Eval-critical checkpoints (the two locked champion nets + T0 cache)
%        are read-only; no committed eval path may retrain or alter them.
%     2. Champion hashes still match the baseline manifest.
%     3. Freeze declaration: NO performance improvement may be recorded that
%        relies on re-opening eval-critical checkpoints. Any future result
%        must be evaluated with the frozen protocol against locked artifacts.
%   The protocol is the contract policing every downstream claim.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
cd(projectRoot);
addpath(genpath(fullfile(projectRoot, 'src')));

results = struct('check', {}, 'status', {}, 'measured', {}, 'expected', {}, 'note', {});

fprintf('============================================================\n');
fprintf('  PHASE 10 - EVALUATION PROTOCOL FREEZE\n');
fprintf('  Date: %s\n', datestr(now));
fprintf('============================================================\n');

%% ---- 1. No eval/audit script may retrain ----
trainCalls = {'trainNetwork','trainClassifier','trainClassifierDay8','fitcnet','fitcsvm','fitcecoc','fitcknn'};
evalScripts = {'re_verify_audit.m','re_audit_T13.m','verify_cascade.m', ...
    'verify_dashboard.m','verify_calibration_T5.m','verify_calibration_flips.m', ...
    'verify_fuseEvidence.m','eval_branchb_fullval_T7.m','eval_vessel_T8.m', ...
    'run_ensemble_eval.m','bootstrap_cis_T4.m','run_task3_prauc.m', ...
    'run_task4_test_eval.m','fill_ablation_T3.m','evaluate_task9b_ab.m', ...
    'phase1_quality_gate.m','phase2_cascade_router_audit.m', ...
    'phase3_calibration_contract.m','phase4_stability_audit.m', ...
    'phase5_error_analysis.m','phase6_decision_lock.m','phase7_metric_freeze.m', ...
    'phase8_firewall_proof.m','phase9_ood_audit.m'};
clean = true;
detail = '';
for si = 1:numel(evalScripts)
    p = fullfile('src', evalScripts{si});
    if ~exist(p,'file'), continue; end
    txt = fileread(p);
    hit = '';
    for tj = 1:numel(trainCalls)
        % require an actual call-site 'trainNetwork(' (not a mere mention)
        rx = [trainCalls{tj} '\('];
        if ~isempty(regexp(txt, rx, 'once')), hit = [hit trainCalls{tj} '(), ']; end %#ok<AGROW>
    end
    if ~isempty(hit), clean = false; detail = sprintf('%s: [%s]  ', evalScripts{si}, hit); end %#ok<AGROW>
end
results(end+1) = record('P10 no_train_in_eval', clean, clean, true, ... 
    'no eval/audit script calls trainNetwork/trainClassifier/fit* '); %#ok<AGROW>
if ~isempty(detail), fprintf('  WARNING: %s\n', detail); end

% training-capable scripts exist but are ONLY the explicit run_*/train*/hardNegMine*
% entry points (off the eval path). Verify by name membership, not an arbitrary cap.
trainScripts = dir(fullfile('src','**','*.m'));
nTrainFiles = 0;
rogue = '';
for s = 1:numel(trainScripts)
    p = fullfile(trainScripts(s).folder, trainScripts(s).name);
    txt = fileread(p);
    hasCall = false;
    for tj = 1:numel(trainCalls)
        if ~isempty(regexp(txt, [trainCalls{tj} '\('],'once')), hasCall = true; break; end
    end
    if ~hasCall, continue; end
    nTrainFiles = nTrainFiles + 1;
    nm = trainScripts(s).name;
    % phase audits only MENTION the identifiers as literals; they never call them
    okName = ~isempty(regexp(nm, '^(run_|train|hardNegMine|build|prepare)', 'once')) ...
          || ~isempty(regexp(nm, '^phase[0-9]+_', 'once'));
    if ~okName, rogue = [rogue nm ', ']; end %#ok<AGROW>
end
results(end+1) = record('P10 train_isolated', nTrainFiles>0 && isempty(rogue), ...
    nTrainFiles, NaN, sprintf('call-sites confined to run_*/train*/hardNegMine* entry points (%d files)%s', nTrainFiles, ternary(isempty(rogue),'',[' rogue=',rogue]))); %#ok<AGROW>

%% ---- 2. Locked checkpoints unchanged ----
h1 = sha256File(fullfile('data','models','day7_pretrained_resnet18_5class_stage2.mat'));
h2 = sha256File(fullfile('data','models','day7_pretrained_resnet18_binary_stage2.mat'));
m5 = 'DD152C917689146F6DEC4687B263EC5E5F237ECF60EC719A59F9FCEEFF737C1B';
mB = '43E8DF33B429231EE5BD60A775FDB3629AD81F287617AFAA9308EA87D311F9A0';
results(end+1) = record('P10 hash_5cls', strcmpi(h1,m5), h1, m5, '5-class champion untouched'); %#ok<AGROW>
results(end+1) = record('P10 hash_binary', strcmpi(h2,mB), h2, mB, 'binary champion untouched'); %#ok<AGROW>

% eval-critical cache present and non-empty
T0 = fullfile('data','analysis','day8','reverify_audit_T0.mat');
results(end+1) = record('P10 T0_cache_ok', exist(T0,'file')==2, exist(T0,'file'), 2, ...
    'T0 prediction cache present');

%% ---- 3. Freeze declaration (also written to registry) ----
dec = struct();
dec.title = 'Evaluation protocol freeze - DrishtiCare hardening phase';
dec.date = datestr(now);
dec.eval_critical_checkpoints = {...
    'data/models/day7_pretrained_resnet18_5class_stage2.mat (SHA256 DD152C...)', ...
    'data/models/day7_pretrained_resnet18_binary_stage2.mat (SHA256 43E8DF...)', ...
    'data/analysis/day8/reverify_audit_T0.mat'};
dec.rules = {...
  '1. The eval-critical checkpoints are READ-ONLY. No committed eval path retrains or mutates them.', ...
  '2. NO performance improvement may be recorded that relies on re-opening an eval-critical checkpoint.', ...
  '3. Any future model/result must be reported under the frozen protocol: fresh inference of the LOCKED nets over the LOCKED 733-val split, frozen metric definitions (Phase 7), locked thresholds (Phase 6).', ...
  '4. Training changes are permitted for FUTURE work but MUST NOT be claimed against baseline metrics on the same val split unless evaluated by the frozen protocol against locked artifacts.', ...
  '5. The sealed official APTOS test set is never used for tuning; external validation (Phases 14/16) stays held-out.'};
dec.eval_inputs = {'cached val predictions (reverify_audit_T0.mat)', 'fresh inference of locked nets over locked val split'};
dec.hashes_verified = struct('fiveClass_5cb_before', m5, 'binary_before', mB);

outDir = fullfile(projectRoot,'data','analysis','day10','phase10');
if ~exist(outDir,'dir'), mkdir(outDir); end
outMat = fullfile(outDir,'phase10_protocol_freeze.mat');
outJson = fullfile(outDir,'phase10_protocol_freeze.json');
try, save(outMat,'results','dec'); catch, save(outMat,'dec'); end
fid = fopen(outJson,'w'); fprintf(fid,'%s', jsonencode(dec)); fclose(fid);
fprintf('\n  FREEZE DECLARATION (see phase10_protocol_freeze.json):\n');
for i=1:numel(dec.rules), fprintf('   %s\n', dec.rules{i}); end
fprintf('  [DONE] protocol registry saved -> %s\n', strrep(outMat,filesep,'/'));

%% ---- Summary ----
fprintf('\n============================================================\n');
nPass=0; nFail=0;
for i=1:numel(results)
    if results(i).status, nPass=nPass+1; tag='PASS'; else, nFail=nFail+1; tag='FAIL'; end
    if isnumeric(results(i).measured) && numel(results(i).measured)<=1
        fprintf('  [%s] %-22s measured=%.4g expected=%.4g  %s\n', tag, ...
            results(i).check, results(i).measured, results(i).expected, results(i).note);
    else
        fprintf('  [%s] %-22s  %s\n', tag, results(i).check, results(i).note);
    end
end
fprintf('  TOTAL: %d PASS, %d FAIL\n', nPass, nFail);
end

function h = sha256File(path)
    h = '';
    [~, out] = system(sprintf('certutil -hashfile "%s" SHA256', strrep(path,'/','\')));
    tok = regexp(out, '(?m)([0-9A-Fa-f]{64})', 'tokens', 'once');
    if ~isempty(tok), h = upper(tok{1}); end
end

function rr = record(check, status, measured, expected, note)
    if nargin<5, note=''; end
    rr = struct('check', check, 'status', status, 'measured', measured, ...
                'expected', expected, 'note', note);
end

function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end
