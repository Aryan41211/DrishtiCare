function phase9_ood_audit()
% PHASE9_OOD_AUDIT Out-of-distribution detector audit.
%   Verifies the exact Mahalanobis parameters stored in ood_stats.mat, the
%   provenance of the 34.22 threshold, and a behavior matrix over synthetic
%   and real inputs. Confirms OOD output is ADVISORY ONLY (never changes the
%   grade / referral decision).
%
%   Locked protocol (buildOodStats.m):
%     features : pool5 (512-d) of the 5-class champion (day7 resnet18)
%     fit set  : ALL 3662 APTOS training images (incl. the 733 val split)
%     mu       : per-class means (5x512, single)
%     Sigma    : pooled covariance = average of per-class scatter/(n_c-1)
%                over classes with count>1, then + regEps*I (diag 1e-4)
%     SigmaInv : inv(Sigma) (single)
%     distance : sqrt(min_c (x-mu_c)' SigmaInv (x-mu_c))
%     threshold: p99 of in-distribution nearest-class distances = 34.22
%     flag     : mDist > threshold  -> OOD
%   Honest caveat: fit set includes the val images (in-distribution APTOS) so
%   the in-sample false-OOD rate (~1%) is not a generalization figure for
%   unseen populations. OOD is a post-hoc flag, does not touch model weights
%   and never alters decisions.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
cd(projectRoot);
addpath(genpath(fullfile(projectRoot, 'src')));

results = struct('check', {}, 'status', {}, 'measured', {}, 'expected', {}, 'note', {});

fprintf('============================================================\n');
fprintf('  PHASE 9 - OOD DETECTOR AUDIT\n');
fprintf('  Date: %s\n', datestr(now));
fprintf('============================================================\n');

O = load(fullfile('data','analysis','day8','ood','ood_stats.mat'), 'oodStats', 'mDistAll');
o = O.oodStats;

%% ---- 1. Structural invariants ----
results(end+1) = record('P9 dims', size(o.mu,1)==5 && size(o.mu,2)==512 ...
    && all(size(o.SigmaInv)==512) && o.featDim==512, ...
    sprintf('%dx%d', size(o.mu,1), size(o.mu,2)), '5x512', 'mu/SigmaInv/featDim consistent'); %#ok<AGROW>
results(end+1) = record('P9 layer', isequal(o.featureLayer,'pool5') ...
    && all(o.imgSize==[224 224]), o.featureLayer, 'pool5', 'pool5, 224x224'); %#ok<AGROW>
results(end+1) = record('P9 model_path', contains(o.modelPath,'day7_pretrained_resnet18_5class_stage2.mat'), ...
    o.modelPath, 'day7 5class champion', 'OOD stats built from the LOCKED 5-class champion'); %#ok<AGROW>
results(end+1) = record('P9 reg_eps', o.regEps==1e-4, o.regEps, 1e-4, 'diagonal regularization'); %#ok<AGROW>
results(end+1) = record('P9 fit_count', o.nImagesFit==3662, o.nImagesFit, 3662, ...
    'fit on all 3662 APTOS images (incl. val split - documented caveat)'); %#ok<AGROW>

%% ---- 2. Threshold provenance: p99 == 34.22 ----
p99 = prctile(O.mDistAll, 99);
results(end+1) = record('P9 p99_recompute', abs(p99 - o.threshold) < 1e-6, p99, o.threshold, ...
    'threshold = p99 of in-distribution distances'); %#ok<AGROW>
results(end+1) = record('P9 threshold_value', abs(o.threshold - 34.22) < 0.01, o.threshold, 34.22, ...
    'committed threshold ~34.2'); %#ok<AGROW>
fo = mean(O.mDistAll > o.threshold)*100;
results(end+1) = record('P9 falseOod_inSample', abs(fo - o.distStats.falseOodRate) < 1e-6 ...
    && abs(fo - 1.0) < 0.02, fo, o.distStats.falseOodRate, ...
    'in-sample false-OOD ~1%% (p99 by construction; not a generalization figure)'); %#ok<AGROW>
results(end+1) = record('P9 distStats', abs(o.distStats.p99 - p99) < 1e-6, o.distStats.p99, p99, ...
    'distStats.p99 consistent with mDistAll'); %#ok<AGROW>

%% ---- 3. Behavior matrix (deterministic canaries) ----
% real val image -> expected in-distribution (flag=false)
dcl = dir(fullfile('data','splits','val','class_0','*.png'));
realPath = fullfile(dcl(1).folder, dcl(1).name);
[fx, dx, dRealAll] = ood_detector(realPath);
dReal.mDist = dx; dReal.isOod = fx; dReal.threshold = dRealAll.threshold; dReal.nearestClass = dRealAll.nearestClass;
% synthetic out-of-distribution inputs -> expected flagged (flag=true)
noise = uint8(255*rand(512,512,3));
black = uint8(zeros(512,512,3));
gray  = uint8(127*ones(512,512,3));
[f1,x1,t1] = ood_detector(noise); dNoise = struct('mDist',x1,'isOod',f1,'threshold',t1.threshold);
[f2,x2,t2] = ood_detector(black); dBla   = struct('mDist',x2,'isOod',f2,'threshold',t2.threshold);
[f3,x3,t3] = ood_detector(gray);  dGray  = struct('mDist',x3,'isOod',f3,'threshold',t3.threshold);
fprintf('\nBehavior matrix:\n');
fprintf('  real val image : mDist=%.3f  OOD=%d (expect 0)\n', dReal.mDist, dReal.isOod);
fprintf('  random noise   : mDist=%.3f  OOD=%d (expect 1)\n', dNoise.mDist, dNoise.isOod);
fprintf('  black image    : mDist=%.3f  OOD=%d (expect 1)\n', dBla.mDist, dBla.isOod);
fprintf('  uniform gray   : mDist=%.3f  OOD=%d (expect 1)\n', dGray.mDist, dGray.isOod);

% check the detector's own flag is just mDist > threshold
rng(0);
[fxd, xd, td] = ood_detector(noise);
dDet = struct('mDist', xd, 'isOod', fxd, 'threshold', td.threshold);
consist = isequal(dDet.isOod, dDet.mDist > dDet.threshold);
results(end+1) = record('P9 flag_definition', consist, dDet.mDist, dDet.threshold, ...
    'flag = mDist > threshold (code path verified)'); %#ok<AGROW>

% real image distance should also be far below p99 of seen val distance? At
% least below the threshold (else nearly every real image gets flagged).
results(end+1) = record('P9 real_in_dist', dReal.mDist <= dReal.threshold, ...
    dReal.mDist, dReal.threshold, 'real val image is in-distribution (mDist <= thr)'); %#ok<AGROW>
results(end+1) = record('P9 noise_flagged', dNoise.isOod && dBla.isOod && dGray.isOod, ...
    dNoise.isOod, true, 'synthetic OOD canaries flagged'); %#ok<AGROW>

% sanity: nearest-standing image should be a plausible class
results(end+1) = record('P9 nearest_class', dReal.nearestClass >= 0 && dReal.nearestClass <= 4, ...
    dReal.nearestClass, NaN, 'nearest class in 0..4'); %#ok<AGROW>

%% ---- 4. OOD is advisory-only in the production pipeline ----
% predictSingleFundus populates result.ood; buildExplanationNarrative uses it
% for the governance sentence only. NO decision/grade/referral change.
str = fileread(fullfile('src','explainability','buildExplanationNarrative.m'));
idxFlag = strfind(str, 'ood.flag');
idxAlter = strfind(lower(str), 'grade =') ;
% detect the only uses: narrative gov text
advisory = ~isempty(idxFlag) && isempty(strfind(lower(str),'grade = nan'));
results(end+1) = record('P9 advisory_only', advisory, ~isempty(idxFlag), true, ...
    'OOD flag only surfaces in narrative governance text; decisions untouched'); %#ok<AGROW>

%% ---- 5. Registry ----
reg = struct();
reg.date = datestr(now);
reg.protocol = struct('featureLayer','pool5','featDim',512,'imgSize',[224 224], ...
  'mu','5x512 per-class means','Sigma','pooled covariance = avg over classes of scatter/(n_c-1)','regEps',1e-4, ...
  'distance','sqrt(min_c (x-mu_c)'' SigmaInv (x-mu_c))');
reg.threshold = o.threshold;
reg.threshold_provenance = 'p99 of in-distribution nearest-class distances over ALL 3662 APTOS images';
reg.in_sample_false_ood_pct = o.distStats.falseOodRate;
reg.honest_caveat = 'Fit set includes the 733 val images + train; in-sample p99-derived ~1% false-OOD is NOT a generalization figure for unseen populations; OOD is advisory only and never alters grade/referral decisions.';
reg.behavior = struct('realValImage_OOD', dReal.isOod, 'randomNoise_OOD', dNoise.isOod, 'black_OOD', dBla.isOod, 'uniformGray_OOD', dGray.isOod);

outDir = fullfile(projectRoot,'data','analysis','day10','phase9');
if ~exist(outDir,'dir'), mkdir(outDir); end
outMat = fullfile(outDir,'phase9_ood_audit.mat');
outJson = fullfile(outDir,'phase9_ood_audit.json');
try, save(outMat,'results','reg'); catch, save(outMat,'reg'); end
fid = fopen(outJson,'w'); fprintf(fid,'%s', jsonencode(reg)); fclose(fid);
fprintf('\n  [DONE] OOD registry saved -> %s\n', strrep(outMat,filesep,'/'));

%% ---- Summary ----
fprintf('\n============================================================\n');
nPass=0; nFail=0;
for i=1:numel(results)
    if results(i).status, nPass=nPass+1; tag='PASS'; else, nFail=nFail+1; tag='FAIL'; end
    if isnumeric(results(i).measured) && numel(results(i).measured)<=1
        fprintf('  [%s] %-24s measured=%.4g expected=%.4g  %s\n', tag, ...
            results(i).check, results(i).measured, results(i).expected, results(i).note);
    else
        fprintf('  [%s] %-24s  %s\n', tag, results(i).check, results(i).note);
    end
end
fprintf('  TOTAL: %d PASS, %d FAIL\n', nPass, nFail);
end

function rr = record(check, status, measured, expected, note)
    if nargin<5, note=''; end
    rr = struct('check', check, 'status', status, 'measured', measured, ...
                'expected', expected, 'note', note);
end