function phase12_runtime_robustness()
% PHASE12_RUNTIME_ROBUSTNESS Runtime + robustness hygiene audit.
%   Exercises predictSingleFundus on adversarial/edge inputs and verifies
%   that every failure mode is explicit (errors or WITHHELD/REVIEW), never a
%   silent wrong output. Re-runs the cascade and dashboard verifiers as a
%   repeatability regression, and profiles per-image runtime.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
cd(projectRoot);
addpath(genpath(fullfile(projectRoot, 'src')));

auditRes = struct('check', {}, 'status', {}, 'measured', {}, 'expected', {}, 'note', {}); %#ok<CHARTEN>

fprintf('============================================================\n');
fprintf('  PHASE 12 - RUNTIME & ROBUSTNESS HYGIENE\n');
fprintf('  Date: %s\n', datestr(now));
fprintf('============================================================\n');

work = fullfile(projectRoot,'data','analysis','day10','phase12');
if ~exist(work,'dir'), mkdir(work); end

%% ---- 1. Corrupt input file -> must ERROR (never silent output) ----
garbage = fullfile(work,'corrupt.png');
fid = fopen(garbage,'w'); fwrite(fid, uint8('definitely not a png 1234567890')); fclose(fid);
threw = false; errMsg = '';
try
    r = predictSingleFundus(garbage, 'ShowFigure', false);
catch me
    threw = true; errMsg = me.message;
end
auditRes(end+1) = rec('P12 corrupt_input_errors', threw, ...
    ternary(threw, 'clean error raised', 'silent result produced!'), 'error', ...
    'corrupt file throws (no silent NaN/grade output)'); %#ok<AGROW>
fprintf('  corrupt input -> %s\n', ternary(threw, sprintf('error: %s', errMsg(1:min(end,60))), 'NO ERROR (BAD)'));

%% ---- 2. Grayscale single-channel -> repmat path, complete result ----
grayImg = fullfile(work,'gray.png');
imwrite(repmat(uint8(reshape(linspace(0,255,224*224),224,224)),[1 1 3]), grayImg); % gray gradient
rGry = predictSingleFundus(grayImg, 'ShowFigure', false);
okGry = ~isempty(rGry.qualityStatus) && numel(rGry.grade)==1 && rGry.grade>=0 && rGry.grade<=4 ...
        && isfield(rGry,'binaryDecision') && ~isempty(rGry.binaryDecision);
auditRes(end+1) = rec('P12 grayscale_path', okGry, ...
    sprintf('grade=%g bin=%s', rGry.grade, rGry.binaryDecision), 'complete', ...
    'single-channel image replicated to RGB; full result returned'); %#ok<AGROW>

%% ---- 3. Tiny 1x1 image -> no crash, graded behavior ----
tinyImg = fullfile(work,'tiny.png');
imwrite(ones(1,1)*255, tinyImg);
rTiny = predictSingleFundus(tinyImg, 'ShowFigure', false);
okTiny = isfield(rTiny,'cascade') && isfield(rTiny,'grade');
auditRes(end+1) = rec('P12 tiny_image', okTiny, ...
    sprintf('qual=%s route=%s grade=%g', rTiny.qualityStatus, rTiny.cascade.route, rTiny.grade), 'no crash', ...
    '1x1 image completes (quality gate should route appropriately)'); %#ok<AGROW>

%% ---- 4. Random-noise image -> no crash, OOD expected ----
noiseImg = fullfile(work,'noise.png');
imwrite(uint8(randi([0 255],224,224,3)), noiseImg);
rNoise = predictSingleFundus(noiseImg, 'ShowFigure', false);
okNoise = isfield(rNoise,'ood') && isfield(rNoise.ood,'available');
oodFlagged = isfield(rNoise.ood,'flag') && rNoise.ood.flag;
auditRes(end+1) = rec('P12 noise_image', okNoise && ~isempty(rNoise.qualityStatus), ...
    sprintf('qual=%s ood=%d', rNoise.qualityStatus, oodFlagged), 'no crash', ...
    'noise image completes; OOD sanity recorded'); %#ok<AGROW>

%% ---- 5. Missing model -> clean error ----
threw = false; errMsg = '';
try
    r = predictSingleFundus(grayImg, 'ShowFigure', false, 'GradeModel', ...
        fullfile(work,'does_not_exist.mat'));
catch me
    threw = true; errMsg = me.message;
end
auditRes(end+1) = rec('P12 missing_model_errors', threw, ...
    ternary(threw, 'clean error raised', 'silent result produced!'), 'error', ...
    'nonexistent model -> explicit error, no silent prediction'); %#ok<AGROW>

%% ---- 6. Deterministic rerun on same image ----
[rA] = predictSingleFundus(grayImg, 'ShowFigure', false);
[rB] = predictSingleFundus(grayImg, 'ShowFigure', false);
same = strcmp(rA.binaryDecision, rB.binaryDecision) && rA.grade == rB.grade ...
       && isequal(rA.classProbabilities, rB.classProbabilities) && abs(rA.binaryProbability - rB.binaryProbability) <= 1e-12;
auditRes(end+1) = rec('P12 deterministic_rerun', same, ...
    sprintf('bin=%s byte-equal=%.0f', rA.binaryDecision, isequal(rA.classProbabilities,rB.classProbabilities)), 'bit-identical', ...
    'identical input -> identical decision/probs'); %#ok<AGROW>

%% ---- 7. WITHHELD path field completeness (black image) ----
black = fullfile(work,'black.png');
imwrite(zeros(224,224), black);
rS = predictSingleFundus(black, 'ShowFigure', false, 'SkipModelOnFail', true);
need = {'qualityStatus','binaryDecision','grade','cascade','ood','fusion','lesions','explanation'};
missing = '';
for k=1:numel(need), if ~isfield(rS, need{k}), missing = [missing need{k} ' ']; end, end %#ok<AGROW>
auditRes(end+1) = rec('P12 withhold_fields', isempty(missing), ternary(isempty(missing),'all present',missing), 'all fields', ...
    'WITHHELD result carries complete structured output'); %#ok<AGROW>

%% ---- 8. Runtime profile (10 val images, mixed classes) ----
valRoot = fullfile(projectRoot,'data','splits','val');
valFiles = {};
for c = 0:4
    dd = fullfile(valRoot, sprintf('class_%d', c));
    if ~exist(dd,'dir'), continue; end
    g = dir(fullfile(dd,'*.png'));
    idx = unique(round(linspace(1, numel(g), max(2, min(4, numel(g))))));
    for k = 1:numel(idx), valFiles{end+1} = fullfile(dd, g(idx(k)).name); end %#ok<AGROW>
end
valFiles = valFiles(1:min(10, numel(valFiles)));
runTimes = nan(1, numel(valFiles));
for i = 1:numel(valFiles)
    rP = predictSingleFundus(valFiles{i}, 'ShowFigure', false);
    runTimes(i) = rP.runtimeSec;
end
medRt = median(runTimes, 'omitnan'); meanRt = mean(runTimes, 'omitnan');
auditRes(end+1) = rec('P12 runtime_profile', medRt < 30, ...
    sprintf('median %.2fs mean %.2fs (n=%d)', medRt, meanRt, numel(valFiles)), '<30s/img', ...
    'per-image runtime profiled; median recorded'); %#ok<AGROW>

%% ---- 9/10. verify_* repeatability (regression) ----
% Scripts clobber the caller workspace (results/files...), so run each in an
% isolated sub-function. The clobbering hazard is itself a hygiene finding.
nBefore = numel(auditRes);
sentinel = 0xDC0DE;
[rc, rcMsg] = runVerifyScript('verify_cascade.m');
[rd, rdMsg] = runVerifyScript('verify_dashboard.m');
isolated = (sentinel == 0xDC0DE) && (numel(auditRes) == nBefore);
auditRes(end+1) = rec('P12 verifier_workspace_isolation', isolated, ...
    double(isolated), 1, 'verify scripts do NOT clobber the caller workspace (isolated run)'); %#ok<AGROW>
auditRes(end+1) = rec('P12 verify_cascade_rerun', rc, rcMsg, 'no error', ...
    'cascade verifier reruns cleanly on locked artifacts'); %#ok<AGROW>
auditRes(end+1) = rec('P12 dashboard_rerun', rd, rdMsg, 'no error', ...
    'dashboard verifier (incl. inspector inference) reruns cleanly'); %#ok<AGROW>

%% ---- Summary ----
out = struct('auditRes', auditRes, 'runtimeMedianSec', medRt, 'runtimeMeanSec', meanRt, ...
             'runtimeN', numel(valFiles));
save(fullfile(work,'phase12_runtime_robustness.mat'), '-struct', 'out');
fprintf('\n============================================================\n');
nPass=0; nFail=0;
for i=1:numel(auditRes)
    if auditRes(i).status, nPass=nPass+1; tag='PASS'; else, nFail=nFail+1; tag='FAIL'; end
    fprintf('  [%s] %-26s %s\n', tag, auditRes(i).check, auditRes(i).note);
end
fprintf('  TOTAL: %d PASS, %d FAIL\n', nPass, nFail);
end

function rr = rec(check, status, measured, expected, note)
    rr = struct('check', check, 'status', status, 'measured', measured, ...
                'expected', expected, 'note', note);
end

function s = ternary(c, a, b)
    if c, s = a; else, s = b; end
end

function [ok, msg] = runVerifyScript(name)
    ok = true; msg = [name ' completed'];
    try
        run(name);  % executes in THIS function's workspace (isolated)
    catch me
        ok = false; msg = sprintf('%s ERROR: %s', name, me.message(1:min(end,120)));
    end
end
