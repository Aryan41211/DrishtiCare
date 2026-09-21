function create_simulation_config()
% CREATE_SIMULATION_CONFIG  Central configuration for the DrishtiCare
% district-level screening / resource-allocation simulation.
%
%   ENGINEERING / RESOURCE-PLANNING SIMULATION - NOT clinical validation.
%
%   This function does NOT hard-code model performance. It READS the
%   project's saved, verified evaluation artifacts and derives the measured
%   inputs from them:
%     * data/analysis/day8/reverify_audit_T0.mat      (locked 733-val PRef)
%     * data/analysis/day3/quality_assessment_summary.mat (quality gate, n=3662)
%     * data/analysis/day10/phase21/phase21_threshold_robustness.mat
%
%   Threshold-specific sensitivity/specificity are COMPUTED from the saved
%   locked validation probabilities (PRef) at each requested threshold, so no
%   threshold operating point is invented.
%
%   The locked 0.60 threshold and the locked ResNet-18 models are NOT touched.

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
cd(projectRoot);

fprintf('============================================================\n');
fprintf('  DRISHTICARE DISTRICT SCREENING - SIMULATION CONFIG\n');
fprintf('  ENGINEERING / RESOURCE-PLANNING SIMULATION (not clinical)\n');
fprintf('  Generated: %s\n', datestr(now));
fprintf('============================================================\n');

%% ============================================================
%  SECTION 1: MEASURED INPUTS (derived from saved artifacts)
%  ============================================================

% ---- Locked binary screening operating point (threshold 0.60) ----
auditFile = fullfile('data','analysis','day8','reverify_audit_T0.mat');
assert(exist(auditFile,'file')==2, 'Missing locked validation artifact: %s', auditFile);
A = load(auditFile);
pRef   = A.PRef(:);          % saved P(referable) for the locked 733-val set
yTrue5 = A.YTrue5(:);        % true 5-class labels (1-based)
isRef  = yTrue5 >= 3;        % frozen definition: referable = 1-based label >= 3

measured = struct();
measured.sensitivity         = A.sens;                 % locked @0.60
measured.specificity         = A.spec;                 % locked @0.60
measured.referralThreshold   = 0.60;                   % locked
measured.validationN         = numel(pRef);
measured.rocAUC              = A.aucFresh;
measured.prAUC               = A.praucFresh;
measured.referableValCount   = sum(isRef);
measured.nonReferableValCount= sum(~isRef);
measured.sources = {
    'data/analysis/day8/reverify_audit_T0.mat (locked 733-val PRef, YTrue5)'
    'data/analysis/day3/quality_assessment_summary.mat (quality gate, n=3662)'
    'data/analysis/day10/phase21/phase21_threshold_robustness.mat (0.55-0.65 sweep)'
    };

% ---- Threshold-specific metrics COMPUTED from saved PRef scores ----
%   Option A of the task: use stored validation probabilities to calculate
%   sensitivity/specificity at several thresholds. Nothing is fabricated.
thresholds = [0.40 0.50 0.60 0.70 0.80];
tSens = zeros(size(thresholds));
tSpec = zeros(size(thresholds));
tPPV  = zeros(size(thresholds));
tRefs = zeros(size(thresholds));
for i = 1:numel(thresholds)
    dec = pRef >= thresholds(i);
    tp = sum(dec &  isRef); fp = sum(dec & ~isRef);
    fn = sum(~dec & isRef); tn = sum(~dec & ~isRef);
    tSens(i) = tp / max(tp+fn, eps);
    tSpec(i) = tn / max(tn+fp, eps);
    tPPV(i)  = tp / max(tp+fp, eps);
    tRefs(i) = sum(dec);
end
measured.thresholdData = struct( ...
    'thresholds', thresholds, 'sensitivity', tSens, ...
    'specificity', tSpec, 'ppv', tPPV, 'referrals', tRefs, ...
    'n', numel(pRef), ...
    'note', 'Computed from locked 733-val PRef; referable = YTrue5>=3.');

% ---- Quality-gate metrics from the saved Day-3 assessment ----
qFile = fullfile('data','analysis','day3','quality_assessment_summary.mat');
assert(exist(qFile,'file')==2, 'Missing quality-gate artifact: %s', qFile);
Q = load(qFile);
qStatus = string(Q.summary.resultsTable.quality_status);
measured.qualityGate = struct();
measured.qualityGate.passRate    = mean(qStatus=="PASS");
measured.qualityGate.warningRate = mean(qStatus=="WARNING");
measured.qualityGate.failRate    = mean(qStatus=="FAIL");
measured.qualityGate.n           = numel(qStatus);
measured.qualityGate.source      = 'data/analysis/day3/quality_assessment_summary.mat';

% ---- Cross-check the locked operating point against the saved PRef ----
dec60 = pRef >= measured.referralThreshold;
sens60 = sum(dec60 & isRef) / sum(isRef);
spec60 = sum(~dec60 & ~isRef) / sum(~isRef);
measured.thresholdReproducesFrozen = ...
    abs(sens60 - measured.sensitivity) < 5e-4 && abs(spec60 - measured.specificity) < 5e-4;
measured.recomputedSensAt060 = sens60;
measured.recomputedSpecAt060 = spec60;

%% ============================================================
%  SECTION 2: SIMULATION ASSUMPTIONS (explicitly labeled)
%  ============================================================

assumptions = struct();

% --- Screening volume ---
assumptions.annualPatientVolume   = 100000;   % patients/year  (assumption)
assumptions.screeningDaysPerYear  = 250;      % working days/year (assumption)
assumptions.patientsPerDay        = assumptions.annualPatientVolume / assumptions.screeningDaysPerYear;

% --- Disease prevalence ---
%   SIMULATION ASSUMPTION - not measured clinical prevalence.
%   Default derived from the locked validation set referable proportion.
assumptions.prevalence            = measured.referableValCount / measured.validationN;
assumptions.prevalenceNote        = ...
    'Simulation assumption - not measured clinical prevalence. Default = locked validation referable proportion (298/733).';

% --- Specialist review capacity ---
assumptions.specialistCasesPerDay = 20;       % cases/day per specialist (assumption)
assumptions.numberOfSpecialists   = 3;        % specialists (assumption)
assumptions.totalSpecialistCapacityPerDay = ...
    assumptions.specialistCasesPerDay * assumptions.numberOfSpecialists;

% --- Screening / processing capacity ---
assumptions.imagesPerHour         = 60;       % AI screening throughput (assumption)
assumptions.workingHoursPerDay    = 8;        % hours/day (assumption)
assumptions.dailyProcessingCapacity = ...
    assumptions.imagesPerHour * assumptions.workingHoursPerDay;

% --- Recapture ---
assumptions.recaptureRate         = 0.50;     % fraction of FAIL images recaptured (assumption)

% --- Simulation time resolution ---
assumptions.simulationDays        = 250;      % 1 year (assumption)
assumptions.timeStepDays          = 1;        % daily aggregate time step
assumptions.resolutionNote        = ...
    'Daily aggregate (mean-field) flow model; counts are expected flows, not per-patient events.';

assumptions.assumptionBasis = {
    'annual volume, working days, processing capacity: engineering planning assumptions'
    'specialist review capacity: engineering assumption, not a sourced staffing standard'
    'prevalence: simulation assumption derived from validation set composition'
    'recapture rate: engineering assumption'
    };

%% ============================================================
%  SECTION 3: PACKAGE + SAVE
%  ============================================================

config = struct();
config.measuredInputs = measured;
config.assumptions    = assumptions;
config.generated      = datetime('now');
config.version        = '2.0';
config.label          = 'ENGINEERING / RESOURCE-PLANNING SIMULATION - NOT clinical validation';
config.description    = 'DrishtiCare district screening resource simulation configuration';

outDir = fullfile('data','analysis','simulink_resource_simulation');
if ~exist(outDir,'dir'), mkdir(outDir); end
save(fullfile(outDir,'simulation_config.mat'), 'config');

%% ---- Report ----
fprintf('\nMEASURED INPUTS (from saved artifacts)\n');
fprintf('  Sensitivity @0.60     : %.4f  (%.2f%%)\n', measured.sensitivity, 100*measured.sensitivity);
fprintf('  Specificity @0.60     : %.4f  (%.2f%%)\n', measured.specificity, 100*measured.specificity);
fprintf('  Referral threshold    : %.2f (locked)\n', measured.referralThreshold);
fprintf('  Validation population : %d\n', measured.validationN);
fprintf('  ROC-AUC / PR-AUC      : %.4f / %.4f\n', measured.rocAUC, measured.prAUC);
fprintf('  Quality gate (n=%d)  : PASS %.4f / WARN %.4f / FAIL %.4f\n', ...
    measured.qualityGate.n, measured.qualityGate.passRate, ...
    measured.qualityGate.warningRate, measured.qualityGate.failRate);
fprintf('  Frozen @0.60 reproduced: %d (sens %.4f / spec %.4f)\n', ...
    measured.thresholdReproducesFrozen, sens60, spec60);

fprintf('\n  Threshold-specific metrics (computed from locked PRef):\n');
fprintf('    t      sens     spec     ppv    referrals\n');
for i = 1:numel(thresholds)
    fprintf('    %.2f   %.4f   %.4f   %.4f   %4d\n', ...
        thresholds(i), tSens(i), tSpec(i), tPPV(i), tRefs(i));
end

fprintf('\nSIMULATION ASSUMPTIONS (labeled)\n');
fprintf('  Annual volume         : %d patients/year\n', assumptions.annualPatientVolume);
fprintf('  Working days          : %d /year\n', assumptions.screeningDaysPerYear);
fprintf('  Patients / day        : %.1f\n', assumptions.patientsPerDay);
fprintf('  Prevalence (assump.)  : %.4f (%.2f%%)\n', assumptions.prevalence, 100*assumptions.prevalence);
fprintf('  Specialist capacity   : %d cases/day (%d specialists x %d/day)\n', ...
    assumptions.totalSpecialistCapacityPerDay, assumptions.numberOfSpecialists, ...
    assumptions.specialistCasesPerDay);
fprintf('  Processing capacity   : %d images/day\n', assumptions.dailyProcessingCapacity);
fprintf('  Recapture rate        : %.2f\n', assumptions.recaptureRate);
fprintf('  Simulation length     : %d days @ %d-day step\n', ...
    assumptions.simulationDays, assumptions.timeStepDays);

fprintf('\nConfig saved: %s\n', fullfile(outDir,'simulation_config.mat'));
end