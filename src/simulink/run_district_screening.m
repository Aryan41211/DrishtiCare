function run_district_screening()
% RUN_DISTRICT_SCREENING  Driver for the DrishtiCare district-level screening
% and resource-allocation simulation.
%
%   ENGINEERING / RESOURCE-PLANNING SIMULATION - NOT clinical validation.
%
%   What it does:
%     1. Builds the centralized config from the project's saved, verified
%        evaluation artifacts (no hard-coded model performance).
%     2. Runs a transparent daily aggregate (mean-field) reference engine for
%        the baseline and for all scenarios.
%     3. Runs the Simulink model (DrishtiCare_DistrictScreening.slx) for the
%        baseline and verifies it matches the reference engine.
%     4. Runs sanity checks.
%     5. Writes figures, results (.mat/.csv), and reports.
%
%   Outputs (data/analysis/simulink_resource_simulation/):
%     simulation_config.mat, baseline_results.mat, scenario_results.csv
%     figures/*.png, reports/*.md, README.md

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
cd(projectRoot);
addpath(fullfile(projectRoot,'src','simulink'));

fprintf('\n############################################################\n');
fprintf('#  DRISHTICARE DISTRICT SCREENING SIMULATION\n');
fprintf('#  ENGINEERING / RESOURCE-PLANNING SIMULATION (not clinical)\n');
fprintf('############################################################\n');

%% ---- 1. Configuration ----
create_simulation_config();
S = load(fullfile('data','analysis','simulink_resource_simulation','simulation_config.mat'));
config = S.config;
m = config.measuredInputs;
a = config.assumptions;

outDir = fullfile('data','analysis','simulink_resource_simulation');
figDir = fullfile(outDir,'figures');
repDir = fullfile(outDir,'reports');
if ~exist(figDir,'dir'), mkdir(figDir); end
if ~exist(repDir,'dir'), mkdir(repDir); end

baseP = struct( ...
    'days', a.simulationDays, ...
    'patientsPerDay', a.patientsPerDay, ...
    'qUsable', m.qualityGate.passRate + m.qualityGate.warningRate, ...
    'qFail', m.qualityGate.failRate, ...
    'recapture', a.recaptureRate, ...
    'prevalence', a.prevalence, ...
    'sens', m.sensitivity, ...
    'spec', m.specificity, ...
    'specCapacity', a.totalSpecialistCapacityPerDay);

%% ---- 2. Baseline reference run ----
fprintf('\n--- Baseline reference run (t=0.60, 100k/yr) ---\n');
baseline = ref_engine(baseP);
print_summary(baseline, a, m);

%% ---- 3. Sanity checks ----
fprintf('\n--- Sanity checks ---\n');
sanity = run_sanity_checks(baseP, m, a);

%% ---- 4. Scenarios ----
fprintf('\n--- Scenarios ---\n');
scen = build_scenarios(config);
scenRows = struct([]);
for i = 1:numel(scen)
    sc = scen(i);
    p = baseP;
    p.patientsPerDay = sc.volume / a.screeningDaysPerYear;
    p.sens = sc.sens; p.spec = sc.spec;
    p.specCapacity = sc.capPerDay;
    R = ref_engine(p);
    row = summarize_scenario(sc, R, a, p);
    scenRows = [scenRows; row]; %#ok<AGROW>
end
scenTable = struct2table(scenRows);
disp(scenTable(:,{'id','label','annualVolume','threshold','annualReferrals', ...
    'referralsPerDay','capPerDay','utilizationPct','specialistsRequired','flag'}));

%% ---- 5. Simulink baseline + verification ----
fprintf('\n--- Simulink baseline run + verification ---\n');
slx = run_simulink_baseline(baseP, baseline, config);

%% ---- 6. Figures ----
fprintf('\n--- Figures ---\n');
make_figures(baseline, scenTable, config, figDir);

%% ---- 7. Save results ----
baseline_results = struct();
baseline_results.label = config.label;
baseline_results.generated = config.generated;
baseline_results.measuredInputs = m;
baseline_results.assumptions = a;
baseline_results.baseline = baseline;
baseline_results.sanity = sanity;
baseline_results.simulinkVerification = slx;
baseline_results.scenarios = scenTable;
save(fullfile(outDir,'baseline_results.mat'), 'baseline_results');

writetable(scenTable, fullfile(outDir,'scenario_results.csv'));
fprintf('Saved: baseline_results.mat, scenario_results.csv\n');

%% ---- 8. Reports ----
write_readme(outDir, config, baseline, scenTable, sanity, slx);
write_baseline_report(repDir, config, baseline, sanity, slx);
write_scenario_report(repDir, config, scenTable, baseline);
fprintf('Saved: README.md, reports/baseline_report.md, reports/scenario_report.md\n');

fprintf('\nDONE.\n');
end

%% ======================================================================
%  Reference engine (transparent daily aggregate / mean-field flow model)
%  ======================================================================
function R = ref_engine(p)
days = p.days;
arrivals  = repmat(p.patientsPerDay, 1, days);
usable    = arrivals .* p.qUsable;
failures  = arrivals .* p.qFail;
recaptured= failures .* p.recapture;
aiScreened= usable + recaptured;
referable = aiScreened .* p.prevalence;
nonref    = aiScreened - referable;
tp = referable .* p.sens;
fn = referable - tp;
fp = nonref .* (1 - p.spec);
tn = nonref - fp;
referrals = tp + fp;

queue = zeros(1,days); reviewed = zeros(1,days); totalWaiting = zeros(1,days);
qprev = 0;
for k = 1:days
    tw = qprev + referrals(k);
    totalWaiting(k) = tw;
    reviewed(k) = min(tw, p.specCapacity);
    queue(k) = max(tw - p.specCapacity, 0);
    qprev = queue(k);
end
utilization = reviewed ./ p.specCapacity;
utilization(~isfinite(utilization)) = 0;

R = struct();
R.p = p;
R.daily = struct('arrivals',arrivals,'usable',usable,'failures',failures, ...
    'recaptured',recaptured,'aiScreened',aiScreened,'referable',referable, ...
    'nonreferable',nonref,'tp',tp,'fn',fn,'fp',fp,'tn',tn,'referrals',referrals, ...
    'queue',queue,'reviewed',reviewed,'backlog',queue,'totalWaiting',totalWaiting, ...
    'utilization',utilization);
R.totals = struct( ...
    'patientsArrived', sum(arrivals), ...
    'usableImages', sum(usable), ...
    'qualityFailures', sum(failures), ...
    'recaptured', sum(recaptured), ...
    'aiScreened', sum(aiScreened), ...
    'referable', sum(referable), ...
    'nonReferable', sum(nonref), ...
    'tp', sum(tp), 'fn', sum(fn), 'fp', sum(fp), 'tn', sum(tn), ...
    'referrals', sum(referrals), ...
    'reviewed', sum(reviewed), ...
    'yearEndBacklog', queue(end), ...
    'peakQueue', max(queue), ...
    'meanQueue', mean(queue), ...
    'referralRate', sum(referrals)/max(sum(aiScreened),eps), ...
    'referralsPerDay', mean(referrals), ...
    'specialistCapacityPerDay', p.specCapacity, ...
    'utilizationPct', 100*mean(utilization), ...
    'specialistsRequired', mean(referrals)/20, ...
    'demandCapacityRatio', mean(referrals)/max(p.specCapacity,eps));
if R.totals.demandCapacityRatio > 1
    R.totals.capacityFlag = 'Specialist capacity exceeded';
elseif queue(end) > 0
    R.totals.capacityFlag = 'Backlog accumulating';
else
    R.totals.capacityFlag = 'Review capacity sufficient under current assumptions';
end
end

%% ======================================================================
function print_summary(R, a, m)
t = R.totals;
fprintf('  Measured sensitivity/specificity: %.4f / %.4f @t=%.2f (n=%d)\n', ...
    m.sensitivity, m.specificity, m.referralThreshold, m.validationN);
fprintf('  Patients arrived/year : %.0f\n', t.patientsArrived);
fprintf('  AI-screened/year      : %.0f\n', t.aiScreened);
fprintf('  Referable (true)      : %.0f\n', t.referable);
fprintf('  TP / FN               : %.0f / %.0f\n', t.tp, t.fn);
fprintf('  FP / TN               : %.0f / %.0f\n', t.fp, t.tn);
fprintf('  Specialist referrals  : %.0f/year (%.1f/day)\n', t.referrals, t.referralsPerDay);
fprintf('  Specialist capacity   : %.0f/day -> utilization %.1f%%\n', ...
    t.specialistCapacityPerDay, t.utilizationPct);
fprintf('  Specialists required  : %.2f (at %.0f cases/specialist/day)\n', ...
    t.specialistsRequired, a.specialistCasesPerDay);
fprintf('  Year-end backlog      : %.0f   peak queue: %.0f\n', ...
    t.yearEndBacklog, t.peakQueue);
fprintf('  FLAG                  : %s\n', t.capacityFlag);
end

%% ======================================================================
function sanity = run_sanity_checks(p, m, a) %#ok<INUSD>
sanity = struct('check',{},'pass',{},'detail',{});
R = ref_engine(p);
tol = 1e-6;
sanity = sanity_add(sanity,'TP+FN = referable', all(abs((R.daily.tp+R.daily.fn)-R.daily.referable)<tol), ...
    sprintf('max err %.2e', max(abs((R.daily.tp+R.daily.fn)-R.daily.referable))));
sanity = sanity_add(sanity,'TN+FP = non-referable', all(abs((R.daily.tn+R.daily.fp)-R.daily.nonreferable)<tol), ...
    sprintf('max err %.2e', max(abs((R.daily.tn+R.daily.fp)-R.daily.nonreferable))));
sanity = sanity_add(sanity,'TP+TN+FP+FN = AI-screened', ...
    all(abs((R.daily.tp+R.daily.tn+R.daily.fp+R.daily.fn)-R.daily.aiScreened)<tol), ...
    sprintf('max err %.2e', max(abs((R.daily.tp+R.daily.tn+R.daily.fp+R.daily.fn)-R.daily.aiScreened))));
sanity = sanity_add(sanity,'referrals = TP+FP', all(abs(R.daily.referrals-(R.daily.tp+R.daily.fp))<tol), ...
    sprintf('max err %.2e', max(abs(R.daily.referrals-(R.daily.tp+R.daily.fp)))));
sanity = sanity_add(sanity,'no negative counts', all(R.daily.tp>=0 & R.daily.tn>=0 & R.daily.fp>=0 & R.daily.fn>=0), ...
    'all TP/TN/FP/FN >= 0');
sanity = sanity_add(sanity,'utilization >= 0', all(R.daily.utilization>=0), ...
    sprintf('min %.4f', min(R.daily.utilization)));
sanity = sanity_add(sanity,'queue never negative', all(R.daily.queue>=0), ...
    sprintf('min %.4f', min(R.daily.queue)));
% zero volume
p0 = p; p0.patientsPerDay = 0; R0 = ref_engine(p0);
sanity = sanity_add(sanity,'zero volume -> all zero', ...
    all(R0.daily.referrals==0) && all(R0.daily.aiScreened==0) && all(R0.daily.queue==0), ...
    'all outputs zero at volume=0');
% infinite capacity
pinf = p; pinf.specCapacity = inf; Rp = ref_engine(pinf);
sanity = sanity_add(sanity,'infinite capacity -> no backlog', all(Rp.daily.queue==0), ...
    sprintf('max queue %.4f', max(Rp.daily.queue)));
% totals consistency
sanity = sanity_add(sanity,'annual TP+FN = annual referable', ...
    abs(R.totals.tp+R.totals.fn - R.totals.referable) < 1e-3, ...
    sprintf('TP+FN=%.1f ref=%.1f', R.totals.tp+R.totals.fn, R.totals.referable));
sanity = sanity_add(sanity,'annual referrals = TP+FP', ...
    abs(R.totals.referrals - (R.totals.tp+R.totals.fp)) < 1e-3, ...
    sprintf('ref=%.1f TP+FP=%.1f', R.totals.referrals, R.totals.tp+R.totals.fp));

nPass = sum([sanity.pass]); nFail = numel(sanity)-nPass;
for i=1:numel(sanity)
    tag = 'PASS'; if ~sanity(i).pass, tag='FAIL'; end
    fprintf('  [%s] %-34s %s\n', tag, sanity(i).check, sanity(i).detail);
end
fprintf('  SANITY: %d PASS / %d FAIL\n', nPass, nFail);
end

function sanity = sanity_add(sanity, name, pass, detail)
sanity(end+1) = struct('check',name,'pass',logical(pass),'detail',detail);
end

%% ======================================================================
function scen = build_scenarios(config)
m = config.measuredInputs; a = config.assumptions;
td = m.thresholdData;
getT = @(t) deal(td.sensitivity(abs(td.thresholds-t)<1e-9), ...
                 td.specificity(abs(td.thresholds-t)<1e-9));
[s50,s50p] = getT(0.50);
[s70,s70p] = getT(0.70);

scen = struct('id',{},'label',{},'volume',{},'threshold',{},'sens',{}, ...
    'spec',{},'source',{},'capPerDay',{},'capNote',{});

% A - baseline
scen(end+1) = mk('A','Baseline (t=0.60, 100k/yr)',100000,0.60,m.sensitivity, ...
    m.specificity,'measured @0.60 (locked)',a.totalSpecialistCapacityPerDay,'3 specialists x 20/day (assumption)');
% B - lower threshold
scen(end+1) = mk('B','Lower threshold (t=0.50)',100000,0.50,s50,s50p, ...
    'measured @0.50 (from locked PRef)',a.totalSpecialistCapacityPerDay,'3 specialists x 20/day (assumption)');
% C - higher threshold
scen(end+1) = mk('C','Higher threshold (t=0.70)',100000,0.70,s70,s70p, ...
    'measured @0.70 (from locked PRef)',a.totalSpecialistCapacityPerDay,'3 specialists x 20/day (assumption)');
% D - volume scaling
vols = [50000 100000 150000 200000];
for v = vols
    scen(end+1) = mk(sprintf('D%d',v/1000),sprintf('Volume scaling %dk/yr',v/1000), ...
        v,0.60,m.sensitivity,m.specificity,'measured @0.60 (locked)', ...
        a.totalSpecialistCapacityPerDay,'3 specialists x 20/day (assumption)'); %#ok<AGROW>
end
% Capacity sensitivity
caps = [60 120 180];
for c = caps
    scen(end+1) = mk(sprintf('E%d',c),sprintf('Capacity %d/day',c), ...
        100000,0.60,m.sensitivity,m.specificity,'measured @0.60 (locked)', ...
        c,sprintf('%d specialists x 20/day (assumption)',c/20)); %#ok<AGROW>
end
end

function s = mk(id,label,vol,thr,sens,spec,source,cap,capNote)
s = struct('id',id,'label',label,'volume',vol,'threshold',thr,'sens',sens, ...
    'spec',spec,'source',source,'capPerDay',cap,'capNote',capNote);
end

%% ======================================================================
function row = summarize_scenario(sc, R, a, p)
t = R.totals;
if t.demandCapacityRatio > 1
    flag = 'Specialist capacity exceeded';
elseif t.yearEndBacklog > 0
    flag = 'Backlog accumulating';
else
    flag = 'Review capacity sufficient';
end
row = struct( ...
    'id', sc.id, 'label', sc.label, ...
    'annualVolume', sc.volume, 'threshold', sc.threshold, ...
    'sensitivity', round(sc.sens,4), 'specificity', round(sc.spec,4), ...
    'metricsSource', sc.source, ...
    'annualAiScreened', round(t.aiScreened,1), ...
    'annualReferrals', round(t.referrals,1), ...
    'referralsPerDay', round(t.referralsPerDay,2), ...
    'capPerDay', sc.capPerDay, 'capNote', sc.capNote, ...
    'utilizationPct', round(t.utilizationPct,1), ...
    'specialistsRequired', round(t.referralsPerDay / a.specialistCasesPerDay, 2), ...
    'reviewedAnnual', round(t.reviewed,1), ...
    'yearEndBacklog', round(t.yearEndBacklog,1), ...
    'peakQueue', round(t.peakQueue,1), ...
    'flag', flag);
end

%% ======================================================================
function slx = run_simulink_baseline(p, baseline, config)
mdl = 'DrishtiCare_DistrictScreening';
slx = struct('ran',false,'note','');
try
    assignin('base','sim_patientsPerDay', p.patientsPerDay);
    assignin('base','sim_qUsable', p.qUsable);
    assignin('base','sim_qFail', p.qFail);
    assignin('base','sim_recapture', p.recapture);
    assignin('base','sim_prevalence', p.prevalence);
    assignin('base','sim_sens', p.sens);
    assignin('base','sim_spec', p.spec);
    assignin('base','sim_specCapacity', p.specCapacity);

    if bdIsLoaded(mdl), close_system(mdl,0); end
    load_system(mdl);
    set_param(mdl,'StopTime',num2str(p.days-1));   % 250 daily samples
    out = sim(mdl,'ReturnWorkspaceOutputs','on');
    Y = out.get('yout');                            % [days x 16]
    close_system(mdl,0);

    ref = [baseline.daily.arrivals; baseline.daily.usable; baseline.daily.failures; ...
           baseline.daily.recaptured; baseline.daily.aiScreened; baseline.daily.referable; ...
           baseline.daily.nonreferable; baseline.daily.tp; baseline.daily.fn; ...
           baseline.daily.fp; baseline.daily.tn; baseline.daily.referrals; ...
           baseline.daily.queue; baseline.daily.reviewed; baseline.daily.backlog; ...
           baseline.daily.utilization]';
    n = min(size(Y,1), size(ref,1));
    maxAbsDiff = max(abs(Y(1:n,:) - ref(1:n,:)), [], 'all');
    slx.ran = true;
    slx.samples = size(Y,1);
    slx.maxAbsDiffVsReference = maxAbsDiff;
    slx.matchTolerance = 1e-6;
    slx.matchesReference = maxAbsDiff < 1e-6;
    slx.finalDay = struct( ...
        'referralsPerDay', Y(end,12), 'queue', Y(end,13), ...
        'reviewed', Y(end,14), 'utilization', Y(end,16));
    fprintf('  Simulink ran: %d daily samples\n', slx.samples);
    fprintf('  Max |Simulink - reference| = %.3e (tolerance 1e-6)\n', maxAbsDiff);
    fprintf('  Match reference: %d\n', slx.matchesReference);
catch err
    slx.note = err.message;
    fprintf('  Simulink run FAILED: %s\n', err.message);
end
end

%% ======================================================================
function make_figures(baseline, scenTable, config, figDir)
a = config.assumptions; t = baseline.totals;
% ---- Fig 1: patient flow ----
f = figure('Visible','off','Position',[100 100 900 500]);
cats = {'Patients arrived','Quality FAIL (recapture/manual)','AI-screened', ...
    'Referable (true)','Specialist referrals (TP+FP)','Reviewed by specialists','Year-end backlog'};
vals = [t.patientsArrived, t.qualityFailures, t.aiScreened, t.referable, ...
    t.referrals, t.reviewed, t.yearEndBacklog];
barh(vals);
set(gca,'YTickLabel',cats,'YDir','reverse');
xlabel('Patients / year'); title('Patient flow over 1 year (100,000 patients/yr, t=0.60)');
grid on; text(vals, 1:numel(vals), compose(' %.0f', vals), 'VerticalAlignment','middle');
exportgraphics(f, fullfile(figDir,'patient_flow.png'), 'Resolution',150); close(f);

% ---- Fig 2: annual volume vs specialist referrals ----
f = figure('Visible','off','Position',[100 100 800 480]);
vols = [50000 100000 150000 200000];
sel = startsWith(scenTable.id, 'D') & cellfun(@(x) isscalar(str2double(regexprep(x,'\D',''))), scenTable.id);
drows = scenTable(sel,:);
[~,ord] = sort(drows.annualVolume); drows = drows(ord,:);
bar(drows.annualVolume, drows.annualReferrals);
set(gca,'XTick',drows.annualVolume,'XTickLabel',compose('%dk',drows.annualVolume/1000));
xlabel('Annual screening volume (patients/yr)'); ylabel('Specialist referrals / year');
title('Annual screening volume vs specialist referrals (t=0.60)'); grid on;
text(drows.annualVolume, drows.annualReferrals, compose('%.0f',drows.annualReferrals), ...
    'HorizontalAlignment','center','VerticalAlignment','bottom');
exportgraphics(f, fullfile(figDir,'referral_volume.png'), 'Resolution',150); close(f);

% ---- Fig 3: specialist queue over time ----
f = figure('Visible','off','Position',[100 100 800 480]);
plot(1:numel(baseline.daily.queue), baseline.daily.queue, 'LineWidth',1.5);
xlabel('Day'); ylabel('Specialist review queue (patients)');
title('Specialist review queue over 1 year (capacity 60/day)'); grid on;
exportgraphics(f, fullfile(figDir,'specialist_queue.png'), 'Resolution',150); close(f);

% ---- Fig 4: specialist utilization over time ----
f = figure('Visible','off','Position',[100 100 800 480]);
plot(1:numel(baseline.daily.utilization), 100*baseline.daily.utilization, 'LineWidth',1.5);
xlabel('Day'); ylabel('Specialist utilization (%)'); ylim([0 105]);
title('Specialist review utilization over 1 year (capacity 60/day)'); grid on;
exportgraphics(f, fullfile(figDir,'specialist_utilization.png'), 'Resolution',150); close(f);

% ---- Fig 5: threshold / workload relationship (MEASURED) ----
f = figure('Visible','off','Position',[100 100 800 480]);
td = config.measuredInputs.thresholdData;
% Use measured threshold table directly for referrals/day, recompute annual
p = baseline.p; 
annRefs = zeros(size(td.thresholds));
for i=1:numel(td.thresholds)
    pp = p; pp.sens = td.sensitivity(i); pp.spec = td.specificity(i);
    R = ref_engine(pp);
    annRefs(i) = R.totals.referrals;
end
yyaxis left
plot(td.thresholds, annRefs, '-o','LineWidth',1.5); ylabel('Specialist referrals / year');
yyaxis right
plot(td.thresholds, 100*td.sensitivity, '--s', td.thresholds, 100*td.specificity, ':^','LineWidth',1.2);
ylabel('Measured sensitivity / specificity (%)');
xlabel('Referral threshold'); grid on;
title('Referral threshold vs referral volume (measured sens/spec from locked PRef)');
legend({'Annual referrals','Sensitivity','Specificity'},'Location','best');
exportgraphics(f, fullfile(figDir,'threshold_workload.png'), 'Resolution',150); close(f);
end

%% ======================================================================
function write_readme(outDir, config, baseline, scenTable, sanity, slx)
m = config.measuredInputs; a = config.assumptions; t = baseline.totals;
fid = fopen(fullfile(outDir,'README.md'),'w');
c = onCleanup(@() fclose(fid));
w = @(varargin) fprintf(fid, varargin{:});
w('# DrishtiCare - District Screening & Resource-Allocation Simulation\n\n');
w('> **ENGINEERING / RESOURCE-PLANNING SIMULATION - NOT clinical validation.**\n\n');
w('This simulation connects the project''s *verified* screening performance to\n');
w('district-scale patient flow and specialist review workload. It is a planning\n');
w('tool, not evidence of clinical effectiveness or real staffing requirements.\n\n');

w('## 1. Purpose\n\n');
w('Answer: how many patients can be screened, how many are referred, how many\n');
w('referable cases are caught, how many false referrals are created, how workload\n');
w('scales with volume and threshold, and whether specialist review capacity is\n');
w('sufficient - using the model''s validated sensitivity/specificity as inputs.\n\n');

w('## 2. Architecture\n\n');
w('Daily aggregate (mean-field) flow model, 1-day step, 250 days = 1 year:\n\n');
w('```\n');
w('[Patient Arrival & Image Capture]\n');
w('        -> [Quality Gate]            (PASS/WARNING usable, FAIL -> recapture/manual)\n');
w('        -> [AI Screening & Referral] (sensitivity/specificity -> TP/FP/FN/TN)\n');
w('        -> [Specialist Queue & Review] (queue, daily review capacity)\n');
w('        -> [System Metrics]\n');
w('```\n\n');
w('Simulink model: `src/simulink/DrishtiCare_DistrictScreening.slx`\n');
w('(built by `src/simulink/build_DrishtiCare_DistrictScreening.m`).\n');
w('Reference engine + driver: `src/simulink/run_district_screening.m`.\n');
w('Configuration: `src/simulink/create_simulation_config.m` -> `simulation_config.mat`.\n\n');

w('## 3. Measured Inputs\n\n');
w('| Input | Value | Source |\n|---|---|---|\n');
w('| Sensitivity @0.60 | %.2f%% | `reverify_audit_T0.mat` (locked 733-val) |\n', 100*m.sensitivity);
w('| Specificity @0.60 | %.2f%% | `reverify_audit_T0.mat` (locked 733-val) |\n', 100*m.specificity);
w('| Referral threshold | %.2f (locked) | project config |\n', m.referralThreshold);
w('| Validation population | %d | held-out APTOS validation |\n', m.validationN);
w('| ROC-AUC / PR-AUC | %.4f / %.4f | `reverify_audit_T0.mat` |\n', m.rocAUC, m.prAUC);
w('| Quality gate PASS/WARN/FAIL | %.2f%% / %.2f%% / %.2f%% | `quality_assessment_summary.mat` (n=%d) |\n', ...
    100*m.qualityGate.passRate, 100*m.qualityGate.warningRate, 100*m.qualityGate.failRate, m.qualityGate.n);
w('| Threshold-specific sens/spec | computed from locked PRef | `reverify_audit_T0.mat` |\n\n');

w('### Threshold-specific operating points (measured from locked PRef)\n\n');
w('| t | sens | spec | PPV | val referrals |\n|---|---|---|---|---|\n');
td = m.thresholdData;
for i=1:numel(td.thresholds)
    w('| %.2f | %.4f | %.4f | %.4f | %d |\n', td.thresholds(i), td.sensitivity(i), ...
        td.specificity(i), td.ppv(i), td.referrals(i));
end
w('\n');

w('## 4. Simulation Assumptions\n\n');
w('All values below are **assumptions**, clearly labeled, not measurements.\n\n');
w('| Assumption | Value | Note |\n|---|---|---|\n');
w('| Annual patient volume | %d patients/yr | planning assumption |\n', a.annualPatientVolume);
w('| Screening days | %d /yr | working-days assumption |\n', a.screeningDaysPerYear);
w('| Patients / day | %.1f | derived |\n', a.patientsPerDay);
w('| Prevalence | %.2f%% | **simulation assumption** - from validation composition, not clinical prevalence |\n', 100*a.prevalence);
w('| Specialist capacity | %d cases/day | %d specialists x %d/day (assumption) |\n', ...
    a.totalSpecialistCapacityPerDay, a.numberOfSpecialists, a.specialistCasesPerDay);
w('| AI processing capacity | %d images/day | %d img/hr x %d hr (assumption) |\n', ...
    a.dailyProcessingCapacity, a.imagesPerHour, a.workingHoursPerDay);
w('| Recapture rate | %.2f | assumption |\n', a.recaptureRate);
w('| Simulation length | %d days @ %d-day step | daily aggregate |\n\n', ...
    a.simulationDays, a.timeStepDays);

w('## 5. Patient Flow\n\n');
w('For each day: arrivals -> quality gate (usable vs FAIL) -> AI screening ->\n');
w('referable/non-referable -> probabilistic TP/FP/FN/TN (expected flows) ->\n');
w('specialist referral queue -> review capacity -> outcome/backlog.\n\n');

w('## 6. Specialist Queue Model\n\n');
w('Per day: `total_waiting = backlog_prev + referrals`;\n');
w('`reviewed = min(total_waiting, capacity)`; `backlog = max(total_waiting - capacity, 0)`.\n');
w('Utilization = `reviewed / capacity`. If demand > capacity, the backlog accumulates.\n\n');

w('## 7. Scenario Definitions\n\n');
w('- **A** baseline: 100k/yr, t=0.60, measured sens/spec, 60/day capacity.\n');
w('- **B** lower threshold t=0.50 (measured), same volume/capacity.\n');
w('- **C** higher threshold t=0.70 (measured), same volume/capacity.\n');
w('- **D** volume scaling: 50k / 100k / 150k / 200k per year at t=0.60.\n');
w('- **E** capacity sensitivity: 60 / 120 / 180 reviews/day at baseline.\n\n');

w('## 8. Results (baseline)\n\n');
w('| Quantity | Value |\n|---|---|\n');
w('| Patients arrived / year | %.0f |\n', t.patientsArrived);
w('| AI-screened / year | %.0f |\n', t.aiScreened);
w('| True referable | %.0f |\n', t.referable);
w('| True positives (referred) | %.0f |\n', t.tp);
w('| False negatives | %.0f |\n', t.fn);
w('| False positives | %.0f |\n', t.fp);
w('| True negatives | %.0f |\n', t.tn);
w('| Specialist referrals | %.0f / year (%.1f / day) |\n', t.referrals, t.referralsPerDay);
w('| Referral rate | %.2f%% of AI-screened |\n', 100*t.referralRate);
w('| Reviewed / year | %.0f |\n', t.reviewed);
w('| Year-end backlog | %.0f |\n', t.yearEndBacklog);
w('| Peak queue | %.0f |\n', t.peakQueue);
w('| Specialist utilization | %.1f%% |\n', t.utilizationPct);
w('| Specialists required | %.2f |\n', t.specialistsRequired);
w('| Status | **%s** |\n\n', t.capacityFlag);

w('## 9. Scenario Results\n\n');
w('| id | scenario | vol/yr | t | sens | spec | referrals/yr | ref/day | cap/day | util%% | specialists | backlog | status |\n');
w('|---|---|---|---|---|---|---|---|---|---|---|---|---|\n');
for i=1:height(scenTable)
    r = scenTable(i,:);
    w('| %s | %s | %d | %.2f | %.4f | %.4f | %.0f | %.1f | %d | %.1f | %.2f | %.0f | %s |\n', ...
        r.id{1}, r.label{1}, r.annualVolume, r.threshold, r.sensitivity, r.specificity, ...
        r.annualReferrals, r.referralsPerDay, r.capPerDay, r.utilizationPct, ...
        r.specialistsRequired, r.yearEndBacklog, r.flag{1});
end
w('\n');

w('## 10. Scaling Behaviour\n\n');
w('Referral demand scales linearly with screening volume. At 100k/yr the AI\n');
w('generates ~%.0f referrals/year (~%.1f/day); at 200k/yr roughly double. Under\n', t.referrals, t.referralsPerDay);
w('the assumed %d/day review capacity, demand exceeds capacity at all volumes\n', a.totalSpecialistCapacityPerDay);
w('(the %d/day capacity scenario is the first that clears the queue).\n\n', 180);

w('## 11. Limitations\n\n');
w('- This is an **engineering simulation**, not a clinical trial or deployment.\n');
w('- Specialist capacity values are **assumptions** unless externally sourced.\n');
w('- Disease prevalence is an **assumption** unless directly measured.\n');
w('- The simulation does **not** establish clinical effectiveness.\n');
w('- It does **not** establish actual staffing requirements.\n');
w('- Real deployment requires prospective clinical and operational validation.\n');
w('- Queue behaviour depends on the assumptions used.\n');
w('- Threshold scenarios are evidence-based only where threshold-specific\n');
w('  validation data exists (here, computed from the locked 733-val PRef scores).\n\n');

w('## 12. Interpretation\n\n');
w('Sensitivity/specificity are not only ML metrics: they drive patient flow,\n');
w('referral volume, specialist workload, and review capacity. False positives\n');
w('(not just missed cases) consume specialist time; at 100k/yr, false positives\n');
w('add ~%.0f referrals/year on top of the ~%.0f true positives.\n\n', t.fp, t.tp);

w('## 13. Presentation (20-30 s)\n\n');
w('> "DRISHTI doesn''t stop at model accuracy. Using our validated sensitivity\n');
w('> (%.2f%%) and specificity (%.2f%%) at the locked 0.60 threshold, we simulated\n', 100*m.sensitivity, 100*m.specificity);
w('> the screening workflow at district scale. For 100,000 patients per year,\n');
w('> about %.0f images reach AI screening and roughly %.0f referrals per year\n', t.aiScreened, t.referrals);
w('> (~%.1f per working day) enter the specialist review queue - versus an\n', t.referralsPerDay);
w('> assumed %d/day review capacity. This connects model performance to real\n', a.totalSpecialistCapacityPerDay);
w('> resource planning. It is an engineering simulation, not proof of real-world\n');
w('> staffing needs."\n\n');

w('## 14. Sanity Checks\n\n');
w('| check | result | detail |\n|---|---|---|\n');
for i=1:numel(sanity)
    tag = 'PASS'; if ~sanity(i).pass, tag='FAIL'; end
    w('| %s | %s | %s |\n', sanity(i).check, tag, sanity(i).detail);
end
w('\nSimulink verification: `matchesReference = %d` (max abs diff %.2e).\n\n', ...
    slx.matchesReference, slx.maxAbsDiffVsReference);
w('---\n*Generated by `src/simulink/run_district_screening.m`.*\n');
end

%% ======================================================================
function write_baseline_report(repDir, config, baseline, sanity, slx)
m = config.measuredInputs; a = config.assumptions; t = baseline.totals;
fid = fopen(fullfile(repDir,'baseline_report.md'),'w');
c = onCleanup(@() fclose(fid));
w = @(varargin) fprintf(fid, varargin{:});
w('# Baseline Report - District Screening Simulation\n\n');
w('**ENGINEERING / RESOURCE-PLANNING SIMULATION - NOT clinical validation.**\n\n');
w('## Measured Inputs\n\n');
w('| Input | Value |\n|---|---|\n');
w('| Sensitivity | %.2f%% |\n', 100*m.sensitivity);
w('| Specificity | %.2f%% |\n', 100*m.specificity);
w('| Referral threshold | %.2f |\n', m.referralThreshold);
w('| Validation population | %d |\n', m.validationN);
w('| Quality gate PASS/WARN/FAIL | %.2f%% / %.2f%% / %.2f%% |\n\n', ...
    100*m.qualityGate.passRate, 100*m.qualityGate.warningRate, 100*m.qualityGate.failRate);
w('## Simulation Assumptions\n\n');
w('| Assumption | Value |\n|---|---|\n');
w('| Annual volume | %d |\n', a.annualPatientVolume);
w('| Working days | %d |\n', a.screeningDaysPerYear);
w('| Patients/day | %.1f |\n', a.patientsPerDay);
w('| Prevalence (assumption) | %.2f%% |\n', 100*a.prevalence);
w('| Specialist capacity | %d/day |\n', a.totalSpecialistCapacityPerDay);
w('| Recapture rate | %.2f |\n\n', a.recaptureRate);
w('## Baseline Results (1 year)\n\n');
w('- Patients arrived: **%.0f**\n', t.patientsArrived);
w('- AI-screened: **%.0f**\n', t.aiScreened);
w('- Referable (true): **%.0f**\n', t.referable);
w('- TP / FN: **%.0f / %.0f**\n', t.tp, t.fn);
w('- FP / TN: **%.0f / %.0f**\n', t.fp, t.tn);
w('- Specialist referrals: **%.0f / year (%.1f / day)**\n', t.referrals, t.referralsPerDay);
w('- Reviewed: **%.0f**; year-end backlog: **%.0f**; peak queue: **%.0f**\n', ...
    t.reviewed, t.yearEndBacklog, t.peakQueue);
w('- Specialist utilization: **%.1f%%**; specialists required: **%.2f**\n', ...
    t.utilizationPct, t.specialistsRequired);
w('- Status: **%s**\n\n', t.capacityFlag);
w('## Queue Behaviour\n\n');
w('Daily demand (%.1f referrals/day) exceeds the assumed review capacity\n', t.referralsPerDay);
w('(%d/day), so the backlog grows roughly linearly across the year to ~%.0f.\n', ...
    t.specialistCapacityPerDay, t.yearEndBacklog);
w('This is the expected bottleneck: specialist review, not AI processing.\n\n');
w('## Sanity Checks\n\n');
for i=1:numel(sanity)
    tag='PASS'; if ~sanity(i).pass, tag='FAIL'; end
    w('- [%s] %s (%s)\n', tag, sanity(i).check, sanity(i).detail);
end
w('\n## Simulink Verification\n\n');
w('- Model: `src/simulink/DrishtiCare_DistrictScreening.slx`\n');
w('- Ran: %d; daily samples: %d\n', slx.ran, slx.samples);
w('- Max abs difference vs reference engine: %.3e (tolerance 1e-6)\n', slx.maxAbsDiffVsReference);
w('- Matches reference: %d\n', slx.matchesReference);
end

%% ======================================================================
function write_scenario_report(repDir, config, scenTable, baseline)
a = config.assumptions; t = baseline.totals;
fid = fopen(fullfile(repDir,'scenario_report.md'),'w');
c = onCleanup(@() fclose(fid));
w = @(varargin) fprintf(fid, varargin{:});
w('# Scenario Report - District Screening Simulation\n\n');
w('**ENGINEERING / RESOURCE-PLANNING SIMULATION - NOT clinical validation.**\n\n');
w('All threshold-specific sensitivity/specificity values are **measured** from\n');
w('the locked 733-val PRef scores. Capacity/volume values are assumptions.\n\n');
w('| id | scenario | vol/yr | t | sens | spec | referrals/yr | ref/day | cap/day | util%% | specialists req. | backlog | status |\n');
w('|---|---|---|---|---|---|---|---|---|---|---|---|---|\n');
for i=1:height(scenTable)
    r = scenTable(i,:);
    w('| %s | %s | %d | %.2f | %.4f | %.4f | %.0f | %.1f | %d | %.1f | %.2f | %.0f | %s |\n', ...
        r.id{1}, r.label{1}, r.annualVolume, r.threshold, r.sensitivity, r.specificity, ...
        r.annualReferrals, r.referralsPerDay, r.capPerDay, r.utilizationPct, ...
        r.specialistsRequired, r.yearEndBacklog, r.flag{1});
end
w('\n## Key readings\n\n');
w('- **Threshold effect (A/B/C):** lower threshold increases referrals (higher\n');
w('  sensitivity, lower specificity); higher threshold reduces referrals.\n');
w('- **Volume effect (D):** referral demand scales ~linearly with volume.\n');
w('- **Capacity effect (E):** at %d/day demand (%.1f/day) the queue clears only\n', ...
    a.totalSpecialistCapacityPerDay, t.referralsPerDay);
w('  when capacity exceeds demand; the 180/day scenario is sufficient under\n');
w('  these assumptions.\n\n');
w('Specialists required is computed as referrals/day divided by the assumed\n');
w('%d cases/specialist/day. It is an engineering estimate, not a staffing plan.\n', ...
    a.specialistCasesPerDay);
end