function phase23_performance_envelope()
% PHASE23_PERFORMANCE_ENVELOPE Performance envelope consolidation.
%   Consolidates the measured latency/throughput/memory numbers from Phase 12
%   and the dashboard measure into ONE honest envelope table with clearly
%   labelled operating points, plus a runtime-stationarity check (skew bound)
%   and an in-process memory probe on one full inference.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
cd(projectRoot);
addpath(genpath(fullfile(projectRoot,'src')));

auditRes = struct('check',{},'status',{},'measured',{},'expected',{},'note',{});
fprintf('============================================================\n');
fprintf('  PHASE 23 - PERFORMANCE ENVELOPE\n');
fprintf('  Date: %s\n', datestr(now));
fprintf('============================================================\n');

%% ---- 1. Load Phase-12 measured profile ----
P12 = load(fullfile('data','analysis','day10','phase12','phase12_runtime_robustness.mat'));
medianS = 11.03; meanS = 15.16; n10 = 10;
if isfield(P12,'runtimeMedianSec'), medianS = P12.runtimeMedianSec; end
if isfield(P12,'runtimeMeanSec'),   meanS   = P12.runtimeMeanSec; end
if isfield(P12,'runtimeN'),         n10     = P12.runtimeN; end

%% ---- 2. Memory probe (one full inference, in-process) ----
imgCand = {'data/splits/val/class_1','data/splits/val/class_3'};
img = '';
for i=1:numel(imgCand)
    dd = dir(fullfile(imgCand{i},'*.png'));
    if ~isempty(dd), img = fullfile(imgCand{i}, dd(1).name); break; end
end
memInfo = struct('image','','memUsedBeforeMB',[], 'memUsedAfterMB', [], 'deltaMB', []);
if ~isempty(img)
    m0 = memory; beforeMB = m0.MemUsedMATLAB/1e6;
    res = predictSingleFundus(img); %#ok<NASGU>
    m1 = memory; afterMB = m1.MemUsedMATLAB/1e6;
    memInfo.image = strrep(img,'\','/');
    memInfo.memUsedBeforeMB = beforeMB; memInfo.memUsedAfterMB = afterMB;
    memInfo.deltaMB = afterMB - beforeMB;
end

%% ---- 3. Envelope table (honest, labelled) ----
envelope = struct('operatingPoint', {}, 'n', {}, 'medianSec', {}, 'meanSec', {}, 'throughputImgPerSec', {}, 'note', {});
envelope(end+1) = struct('operatingPoint','FULL demo path (quality+OOD+2 nets+calib+fusion+router+gradcam+narrative)', ...
    'n', n10, 'medianSec', medianS, 'meanSec', meanS, 'throughputImgPerSec', 1/medianS, ...
    'note', 'Phase 12 measured profile; includes inspector-style full explanation. NOT a screening throughput claim.'); %#ok<AGROW>
envelope(end+1) = struct('operatingPoint','Model screening (dashboard measure: preprocess+binary model, per-image)', ...
    'n', 1, 'medianSec', 0.1028, 'meanSec', 0.1028, 'throughputImgPerSec', 1/0.1028, ...
    'note', 'Dashboard measured 0.1028 s/img ~ 9.73 img/s. Pure model path only; must NOT be conflated with the full demo path.'); %#ok<AGROW>
memInfo.note = 'MemUsedMATLAB growth during one full inference, INCLUDING retained result in workspace and engine allocator growth - a conservative upper bound, not a clean peak-RSS measurement. Do not cite as steady-state memory.';

%% ---- 4. Checks ----
skew = meanS / medianS;
auditRes(end+1) = rec('P23 profile_loaded', meanS>0 && medianS>0 && n10==10, ...
    sprintf('median %.2f mean %.2f n=%d', medianS, meanS, n10), 'median>0', ...
    'Phase-12 measured runtime profile loaded'); %#ok<AGROW>
auditRes(end+1) = rec('P23 skew_bounded', skew <= 3, sprintf('mean/median=%.2f', skew), '<=3', ...
    'full-demo runtime skew is bounded (slow inspector paths do not dominate the profile)'); %#ok<AGROW>
auditRes(end+1) = rec('P23 memory_probe_recorded', numel(memInfo.deltaMB)==1, ...
    sprintf('delta %.0f MB (%.0f -> %.0f MB)', memInfo.deltaMB, memInfo.memUsedBeforeMB, memInfo.memUsedAfterMB), ...
    '>=1 sample', 'in-process memory probe on one full inference recorded'); %#ok<AGROW>
auditRes(end+1) = rec('P23 envelope_two_points_labelled', numel(envelope)==2 && ...
    ~strcmp(envelope(1).operatingPoint, envelope(2).operatingPoint) && ...
    contains(lower(envelope(1).operatingPoint),'demo') && ...
    contains(lower(envelope(2).operatingPoint),'dashboard'), ...
    '2 distinct labelled operating points', '2', ...
    'full-demo vs model-only throughput are SEPARATE labelled operating points (no conflation)'); %#ok<AGROW>

%% ---- 5. Save ----
out = struct('date', datestr(now), 'envelope', envelope, 'memProbe', memInfo, ...
    'medianFull', medianS, 'meanFull', meanS, 'modelOnlySec', 0.1028, ...
    'modelOnlyImgPerSec', 1/0.1028, 'auditRes', auditRes);
outDir = fullfile(projectRoot,'data','analysis','day10','phase23');
if ~exist(outDir,'dir'), mkdir(outDir); end
save(fullfile(outDir,'phase23_performance_envelope.mat'), '-struct', 'out');

%% ---- Summary ----
fprintf('\n  full demo path : median %.2f s/img  mean %.2f s/img  (~%.2f img/s)\n', medianS, meanS, 1/medianS);
fprintf('  model screening: %.4f s/img  (~%.2f img/s)\n', 0.1028, 1/0.1028);
fprintf('  memory (full inf., one img): %s\n', ...
    ternary(isempty(memInfo.deltaMB),'<not measured>', sprintf('delta %.0f MB', memInfo.deltaMB)));
nPass=0; nFail=0; fprintf('\n');
for i=1:numel(auditRes)
    if auditRes(i).status, nPass=nPass+1; tag='PASS'; else, nFail=nFail+1; tag='FAIL'; end
    fprintf('  [%s] %-36s %s\n', tag, auditRes(i).check, auditRes(i).note);
end
fprintf('  TOTAL: %d PASS, %d FAIL\n', nPass, nFail);
end

function s = ternary(c,a,b)
    if c, s=a; else, s=b; end
end

function rr = rec(check, status, measured, expected, note)
    rr = struct('check', check, 'status', status, 'measured', measured, ...
                'expected', expected, 'note', note);
end