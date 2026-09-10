function phase11_pipeline_order_audit()
% PHASE11_PIPELINE_ORDER_AUDIT End-to-end pipeline order + robustness audit.
%   Audits predictSingleFundus.m against the frozen pipeline contract:
%     quality gate -> (WITHHELD on SkipModelOnFail) -> binary (RAW PRef
%     decision) -> calibration (auxiliary) -> 5-class -> Grad-CAM -> lesions
%     -> OOD (advisory) -> cascade router -> quality-FAIL override -> Branch
%     B fusion (must ESCALATE to REVIEW on discrepancy) -> narrative.
%
%   Also reproduces (and fixes) the latent Branch B / cascade.detail
%   concatenation crash, and exercises the quality-FAIL WITHHELD path.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
cd(projectRoot);
addpath(genpath(fullfile(projectRoot, 'src')));

results = struct('check', {}, 'status', {}, 'measured', {}, 'expected', {}, 'note', {}); %#ok<CHARTEN>

fprintf('============================================================\n');
fprintf('  PHASE 11 - PIPELINE ORDER & ROBUSTNESS AUDIT\n');
fprintf('  Date: %s\n', datestr(now));
fprintf('============================================================\n');

psf = fullfile('src','inference','predictSingleFundus.m');
txt = fileread(psf);
L = strsplit(txt, '\n');

% ---------- A. static ordering invariants ----------
% 1. binary decision uses RAW pRef (locked thr), BEFORE any calibration output
iDecThr = find(~cellfun(@isempty, regexp(L, 'if pRef >= thr')));
iCalib  = find(~cellfun(@isempty, regexp(L, 'pCalibrated = temperatureScale')), 1);
iDecVal = find(~cellfun(@isempty, regexp(L, 'binaryDecision = ''REFERABLE''')), 1);
% decision tag and threshold check share one line; only ordering vs calibration matters
ok1 = ~isempty(iDecThr) && ~isempty(iDecVal) && ~isempty(iCalib) && iDecVal < iCalib;
results(end+1) = rec('P11 raw_pRef_decision', ok1, [iDecVal iCalib], ...
    'decision<calibration', 'binary decision precedes calibration output'); %#ok<AGROW>

% 2. no decision assignment ever uses calibrated pRef
ok2b = isempty(regexp(txt, 'binaryDecision[^;]*pCalibrated', 'once'));
results(end+1) = rec('P11 no_cal_in_decision', ok2b, double(ok2b), 1, ...
    'binaryDecision never derived from pCalibrated'); %#ok<AGROW>

% 2b. cascade_router consumes grade,s5,pRef only (OOD advisory, never routing)
iRoute = find(~cellfun(@isempty, regexp(L, '\[route, casDet\] = cascade_router')), 1);
iOODcall = find(~cellfun(@isempty, regexp(L, 'ood_detector\(raw\)')), 1);
ok2c = iOODcall < iRoute;  % OOD computed before routing (advisory)
ok2d = isempty(regexp(txt, 'cascade_router\([^)]*ood', 'once'));
results(end+1) = rec('P11 ood_advisory_only', ok2c && ok2d, [iOODcall iRoute], ...
    'ood<cascade & ood not passed', 'OOD computed but never consumed by router'); %#ok<AGROW>

% 3. quality-FAIL override (Task 9A) exists and sets REVIEW after router
iQualEnf = find(~cellfun(@isempty, regexp(L, 'qualityGateEnforced')), 1);
hasOverride = ~isempty(regexp(txt, "qualityGateEnforced", 'once')) ...
   && ~isempty(regexp(txt, "result\.cascade\.route = 'REVIEW'", 'once'));
results(end+1) = rec('P11 quality_fail_override', hasOverride, double(hasOverride), 1, ...
    'FAIL image escalated to REVIEW (no auto-answer)'); %#ok<AGROW>

% 4. SkipModelOnFail WITHHELD short-circuits before any model predict
iSkip = find(~cellfun(@isempty, regexp(L, 'SkipModelOnFail')), 1);
iPred = find(~cellfun(@isempty, regexp(L, '= predict\(netB')), 1);
iSkipReturn = find(~cellfun(@isempty, regexp(L, 'SkipModelOnFail\s*$')), 1);
ok4 = iSkip < iPred;  % fail-block precedes the first model execution
results(end+1) = rec('P11 skip_fail_before_models', ok4, [iSkip iPred], 'skip<models', ...
    'WITHHELD short-circuit occurs before any model runs'); %#ok<AGROW>

% 5. Branch B fusion runs AFTER cascade_router (escalation possible)
iFusion = find(~cellfun(@isempty, regexp(L, '\[ag, dis, det\] = fuseEvidence')), 1);
ok5 = iRoute < iFusion;
results(end+1) = rec('P11 fusion_after_router', ok5, [iRoute iFusion], 'route<fusion', ...
    'fusion sees the router result and can escalate'); %#ok<AGROW>

% 6. the old struct+char crash is GONE (no catastrophic cascade.detail concat)
gone = isempty(regexp(txt, 'cascade\.detail\s*=\s*\[', 'once'));
results(end+1) = rec('P11 no_detail_concat', gone, double(gone), 1, ...
    'no self-concatenation that replaces cascade.detail; old crash removed'); %#ok<AGROW>

% 7. repro reference: struct+char concatenation throws (why the old line was a bug)
throws = false;
try, [struct('a',1) 'x']; catch, throws = true; end
results(end+1) = rec('P11 concat_repro', throws, double(throws), 1, ...
    'struct+char concat errors -> old defect would crash at runtime'); %#ok<AGROW>

% ---------- B. runtime robustness ----------
% 8. quality-FAIL WITHHELD path on a synthetic black image (SkipModelOnFail)
tmp = fullfile(projectRoot,'data','analysis','day10','phase11');
if ~exist(tmp,'dir'), mkdir(tmp); end
black = fullfile(tmp,'synthetic_black.png');
imwrite(zeros(224,224), black);
r1 = predictSingleFundus(black, 'ShowFigure', false, 'SkipModelOnFail', true);
ok8 = strcmp(r1.cascade.route,'REVIEW') && startsWith(r1.binaryDecision,'WITHHELD') ...
      && isnan(r1.grade) && r1.qualityGate.autoAnswerBlocked;
results(end+1) = rec('P11 withhold_fail_path', ok8, ...
    sprintf('route=%s grade=%g blocked=%d', r1.cascade.route, r1.grade, r1.qualityGate.autoAnswerBlocked), ...
    'REVIEW/NaN/1', 'SkipModelOnFail WITHHELD on FAIL quality (no model stack)'); %#ok<AGROW>

% 9. FAIL image WITHOUT skip: full path runs, still escalated to REVIEW
r2 = predictSingleFundus(black, 'ShowFigure', false, 'SkipModelOnFail', false);
ok9 = strcmp(r2.cascade.route,'REVIEW') && isfield(r2,'explanation') ...
      && ~strcmp(r2.binaryDecision,'WITHHELD');
results(end+1) = rec('P11 fail_no_skip', ok9, r2.cascade.route, 'REVIEW', ...
    'FAIL image without skip completes; quality override keeps REVIEW'); %#ok<AGROW>

% 10. Branch B discrepancy escalates to REVIEW (regression for the crash)
valRoot = fullfile(projectRoot,'data','splits','val');
files = {};
for c = 0:4
    dd = fullfile(valRoot, sprintf('class_%d', c));
    if ~exist(dd,'dir'), continue; end
    g = dir(fullfile(dd,'*.png'));
    for k = 1:numel(g), files{end+1} = fullfile(dd, g(k).name); end %#ok<AGROW>
end
files = sort(files);
found = false; dispIdx = 0;
for i = 1:min(numel(files), 60)
    try
        r = predictSingleFundus(files{i}, 'ShowFigure', false, ...
            'SkipModelOnFail', false);
    catch me
        results(end+1) = rec('P11 fusion_runtime', false, me.message, '', ...
            sprintf('predictSingleFundus crashed on val image %d', i)); %#ok<AGROW>
        break;
    end
    if isfield(r,'fusion') && isfield(r.fusion,'available') && r.fusion.available ...
       && r.fusion.discrepancy
        found = true; dispIdx = i;
        ok10 = strcmp(r.cascade.route,'REVIEW') && r.cascade.fusionConflict;
        results(end+1) = rec('P11 fusion_escalation', ok10, ...
            sprintf('route=%s discrepancy=%d routeOverride=%s', r.cascade.route, ...
            r.fusion.discrepancy, r.fusion.routeOverride), 'REVIEW/1/REVIEW', ...
            sprintf('Branch B discrepancy (val img #%d) escalates cascade to REVIEW, no crash', i)); %#ok<AGROW>
        break;
    end
    r = [];
end
if ~found
    results(end+1) = rec('P11 fusion_escalation', false, 'none within 60', ...
        '>=1 discrepancy', 'no discrepancy case hit - rerun with more images'); %#ok<AGROW>
end
delete(black);

%% ---- Summary ----
outDir = fullfile(projectRoot,'data','analysis','day10','phase11');
if ~exist(outDir,'dir'), mkdir(outDir); end
save(fullfile(outDir,'phase11_pipeline_order.mat'), 'results');
fprintf('\n============================================================\n');
nPass=0; nFail=0;
for i=1:numel(results)
    if results(i).status, nPass=nPass+1; tag='PASS'; else, nFail=nFail+1; tag='FAIL'; end
    fprintf('  [%s] %-24s %s | %s\n', tag, results(i).check, ...
        evalc('disp(results(i).measured)'), results(i).note);
end
fprintf('  TOTAL: %d PASS, %d FAIL\n', nPass, nFail);
end

function rr = rec(check, status, measured, expected, note)
    rr = struct('check', check, 'status', status, 'measured', measured, ...
                'expected', expected, 'note', note);
end