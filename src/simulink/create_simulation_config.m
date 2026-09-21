% SIMULINK DISTRICT SCREENING SIMULATION CONFIGURATION
% DrishtiCare - Engineering Resource Planning Simulation
% This file defines ALL simulation inputs, clearly separating measured
% project validation metrics from simulation assumptions.

clear; clc;

% ============================================================
% SECTION 1: MEASURED INPUTS (from project validation artifacts)
% ============================================================
%
% Source: VERIFIED_RESULTS_SIMPLE.md (fresh-tested 17-Sep-2026, n=733 val)
% Source: data/analysis/day7/day7_pretrained_resnet18_5class_referable_threshold.mat
% Source: data/analysis/day7/day7_binary_calibration.mat

measuredInputs = struct();

% Binary screening metrics at fixed referral threshold 0.60
% These are VALIDATED on held-out APTOS validation set (n=733)
measuredInputs.sensitivity = 0.9060;      % 90.60% (270/298 referable correctly identified)
measuredInputs.specificity = 0.9471;      % 94.71% (412/435 non-referable correctly identified)
measuredInputs.referralThreshold = 0.60;  % Fixed, locked threshold

% Threshold-specific metrics (VALIDATED from day7_pretrained_resnet18_5class_referable_threshold.mat)
% These are MEASURED at each threshold on the validation set
thresholdData = struct();
thresholdData.thresholds    = [0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.65, 0.70, 0.75, 0.80, 0.85, 0.90];
thresholdData.sensitivity   = [0.8115, 0.8019, 0.7891, 0.7891, 0.7827, 0.7764, 0.7732, 0.7636, 0.7604, 0.7540, 0.7412, 0.7380, 0.7284, 0.7252, 0.7061, 0.6933, 0.6805];
thresholdData.specificity   = [0.8571, 0.8619, 0.8643, 0.8643, 0.8667, 0.8667, 0.8667, 0.8667, 0.8690, 0.8690, 0.8690, 0.8690, 0.8714, 0.8714, 0.8738, 0.8738, 0.8738];
thresholdData.ppv           = [0.8089, 0.8123, 0.8125, 0.8125, 0.8140, 0.8127, 0.8121, 0.8102, 0.8123, 0.8110, 0.8084, 0.8077, 0.8085, 0.8078, 0.8066, 0.8037, 0.8008];
thresholdData.f1            = [0.8102, 0.8071, 0.8006, 0.8006, 0.7980, 0.7941, 0.7921, 0.7862, 0.7855, 0.7815, 0.7733, 0.7713, 0.7664, 0.7643, 0.7530, 0.7444, 0.7358];

measuredInputs.thresholdData = thresholdData;

% Quality gate metrics (from VERIFIED_RESULTS_SIMPLE.md, 3,662 images)
measuredInputs.qualityGate = struct();
measuredInputs.qualityGate.passRate   = 0.655;  % PASS 65.5%
measuredInputs.qualityGate.warningRate = 0.267; % WARNING 26.7%
measuredInputs.qualityGate.failRate   = 0.078;  % FAIL 7.8%

% ROC-AUC and PR-AUC (for reference)
measuredInputs.rocAUC = 0.9796;
measuredInputs.prAUC  = 0.7821;

% Validation set size
measuredInputs.validationN = 733;

% ============================================================
% SECTION 2: SIMULATION ASSUMPTIONS (explicitly labeled)
% ============================================================
%
% These are ENGINEERING ASSUMPTIONS for resource planning.
% They are NOT clinical measurements.
% Each is clearly labeled with its assumption basis.

simAssumptions = struct();

% --- Annual volume ---
simAssumptions.annualPatientVolume = 100000;    % patients/year
simAssumptions.screeningDaysPerYear = 250;      % working days/year (assumption)
simAssumptions.patientsPerDay = simAssumptions.annualPatientVolume / simAssumptions.screeningDaysPerYear;  % 400/day

% --- Disease prevalence ---
% IMPORTANT: This is a SIMULATION ASSUMPTION, not measured prevalence.
% The validation set has referable proportion = 298/733 = 40.6%.
% Real-world screening populations may have different prevalence.
simAssumptions.prevalence = 0.406;  % Simulation assumption - not measured clinical prevalence
simAssumptions.prevalenceNote = 'Simulation assumption - not measured clinical prevalence. Based on APTOS validation set referable proportion (298/733=40.6%).';

% --- Specialist review capacity ---
simAssumptions.specialistCasesPerDay = 20;      % cases/day per specialist (assumption)
simAssumptions.numberOfSpecialists = 3;         % number of specialists (assumption)
simAssumptions.totalSpecialistCapacityPerDay = simAssumptions.specialistCasesPerDay * simAssumptions.numberOfSpecialists;  % 60/day

% --- Processing capacity ---
simAssumptions.imagesPerHour = 60;              % AI screening throughput (assumption)
simAssumptions.workingHoursPerDay = 8;          % hours/day (assumption)
simAssumptions.dailyProcessingCapacity = simAssumptions.imagesPerHour * simAssumptions.workingHoursPerDay;  % 480/day

% --- Recapture ---
simAssumptions.recaptureRate = 0.50;            % 50% of FAIL images recaptured (assumption)

% --- Simulation time ---
simAssumptions.simulationDays = 250;            % 1 year simulation
simAssumptions.timeStepDays = 1;                % daily time step

% ============================================================
% SECTION 3: DERIVED PARAMETERS
% ============================================================

% Referable and non-referable patients per day (from prevalence)
simAssumptions.referablePerDay = simAssumptions.patientsPerDay * simAssumptions.prevalence;
simAssumptions.nonReferablePerDay = simAssumptions.patientsPerDay * (1 - simAssumptions.prevalence);

% Quality gate flow
simAssumptions.usableImagesPerDay = simAssumptions.patientsPerDay * (measuredInputs.qualityGate.passRate + measuredInputs.qualityGate.warningRate);
simAssumptions.failImagesPerDay = simAssumptions.patientsPerDay * measuredInputs.qualityGate.failRate;
simAssumptions.recapturedPerDay = simAssumptions.failImagesPerDay * simAssumptions.recaptureRate;

% ============================================================
% SAVE CONFIGURATION
% ============================================================
config = struct();
config.measuredInputs = measuredInputs;
config.simAssumptions = simAssumptions;
config.generated = datetime('now');
config.version = '1.0';
config.description = 'DrishtiCare District Screening Resource Simulation Configuration';

outDir = 'C:\projects\DrishtiCare\data\analysis\simulink_resource_simulation';
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
save(fullfile(outDir, 'simulation_config.mat'), 'config');

fprintf('=== SIMULATION CONFIGURATION ===\n');
fprintf('Measured Sensitivity: %.2f%%\n', measuredInputs.sensitivity * 100);
fprintf('Measured Specificity: %.2f%%\n', measuredInputs.specificity * 100);
fprintf('Referral Threshold: %.2f\n', measuredInputs.referralThreshold);
fprintf('Annual Volume: %d patients/year\n', simAssumptions.annualPatientVolume);
fprintf('Patients/Day: %.0f\n', simAssumptions.patientsPerDay);
fprintf('Prevalence (assumption): %.1f%%\n', simAssumptions.prevalence * 100);
fprintf('Specialist Capacity: %d cases/day (%d specialists x %d/day)\n', ...
    simAssumptions.totalSpecialistCapacityPerDay, ...
    simAssumptions.numberOfSpecialists, simAssumptions.specialistCasesPerDay);
fprintf('Config saved to data/analysis/simulink_resource_simulation/simulation_config.mat\n');