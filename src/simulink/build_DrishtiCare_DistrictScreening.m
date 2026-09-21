function build_DrishtiCare_DistrictScreening()
% BUILD_DRISHTICARE_DISTRICTSCREENING  Programmatically construct the
% DrishtiCare district screening resource-allocation Simulink model.
%
%   ENGINEERING / RESOURCE-PLANNING SIMULATION - NOT clinical validation.
%
%   Architecture (daily aggregate flow, fixed-step discrete, 1-day step):
%
%     Patient Arrival & Image Capture
%        -> Quality Gate
%        -> AI Screening & Referral
%        -> Specialist Queue & Review
%        -> System Metrics
%
%   Parameters are read from base-workspace variables (sim_*) set by
%   drishti_sim_default_params.m and overridable per scenario by the driver.
%
%   Output: src/simulink/DrishtiCare_DistrictScreening.slx

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
cd(projectRoot);
addpath(fullfile(projectRoot,'src','simulink'));

mdl = 'DrishtiCare_DistrictScreening';
modelPath = fullfile('src','simulink',[mdl '.slx']);

if bdIsLoaded(mdl), close_system(mdl, 0); end
if exist(modelPath,'file'), delete(modelPath); end

new_system(mdl);
open_system(mdl);

% ---- Solver / logging configuration ----
set_param(mdl,'SolverType','Fixed-step');
set_param(mdl,'Solver','FixedStepDiscrete');
set_param(mdl,'FixedStep','1');
set_param(mdl,'StopTime','249');   % 250 daily samples (t=0..249) = 1 year
set_param(mdl,'SaveOutput','on');
set_param(mdl,'SaveFormat','Array');
set_param(mdl,'PreLoadFcn','drishti_sim_default_params');
set_param(mdl,'InitFcn','drishti_sim_default_params');

%% ===================== Subsystem A: Arrival & Capture =====================
A = [mdl '/Patient Arrival & Image Capture'];
add_block('built-in/Subsystem', A, 'Position',[40 70 240 160]);
add_block('built-in/Constant', [A '/DailyArrivals'], ...
    'Value','sim_patientsPerDay', 'Position',[40 55 110 95]);
add_block('built-in/Outport', [A '/arrivals'], 'Port','1', 'Position',[240 65 270 85]);
add_line(A,'DailyArrivals/1','arrivals/1','autorouting','on');

%% ===================== Subsystem B: Quality Gate =====================
B = [mdl '/Quality Gate'];
add_block('built-in/Subsystem', B, 'Position',[320 60 560 170]);
add_block('built-in/Inport',  [B '/arrivals'], 'Port','1', 'Position',[20 100 50 120]);
add_block('built-in/Constant',[B '/UsableFrac'], 'Value','sim_qUsable', 'Position',[20 25 70 45]);
add_block('built-in/Product', [B '/UsableProduct'], 'Position',[160 30 200 70]);
add_block('built-in/Constant',[B '/FailFrac'], 'Value','sim_qFail', 'Position',[20 175 70 195]);
add_block('built-in/Product', [B '/FailProduct'], 'Position',[160 175 200 215]);
add_block('built-in/Constant',[B '/RecaptureFrac'], 'Value','sim_recapture', 'Position',[250 250 300 270]);
add_block('built-in/Product', [B '/RecaptureProduct'], 'Position',[350 205 390 245]);
add_block('built-in/Sum',     [B '/UsablePlusRecaptured'], 'Inputs','++', 'Position',[460 90 490 130]);
add_block('built-in/Outport', [B '/usable'], 'Port','1', 'Position',[570 40 600 60]);
add_block('built-in/Outport', [B '/failures'], 'Port','2', 'Position',[570 185 600 205]);
add_block('built-in/Outport', [B '/recaptured'], 'Port','3', 'Position',[460 215 490 235]);
add_block('built-in/Outport', [B '/aiScreened'], 'Port','4', 'Position',[570 95 600 115]);
add_line(B,'arrivals/1','UsableProduct/1','autorouting','on');
add_line(B,'UsableFrac/1','UsableProduct/2','autorouting','on');
add_line(B,'arrivals/1','FailProduct/1','autorouting','on');
add_line(B,'FailFrac/1','FailProduct/2','autorouting','on');
add_line(B,'FailProduct/1','RecaptureProduct/1','autorouting','on');
add_line(B,'RecaptureFrac/1','RecaptureProduct/2','autorouting','on');
add_line(B,'UsableProduct/1','UsablePlusRecaptured/1','autorouting','on');
add_line(B,'RecaptureProduct/1','UsablePlusRecaptured/2','autorouting','on');
add_line(B,'UsableProduct/1','usable/1','autorouting','on');
add_line(B,'FailProduct/1','failures/1','autorouting','on');
add_line(B,'RecaptureProduct/1','recaptured/1','autorouting','on');
add_line(B,'UsablePlusRecaptured/1','aiScreened/1','autorouting','on');

%% ============= Subsystem C: AI Screening & Referral Decision =============
C = [mdl '/AI Screening & Referral'];
add_block('built-in/Subsystem', C, 'Position',[640 50 920 200]);
add_block('built-in/Inport',  [C '/aiScreened'], 'Port','1', 'Position',[20 100 50 120]);
add_block('built-in/Constant',[C '/Prevalence'], 'Value','sim_prevalence', 'Position',[20 25 70 45]);
add_block('built-in/Product', [C '/ReferableProduct'], 'Position',[150 55 190 95]);
add_block('built-in/Sum',     [C '/NonReferableSum'], 'Inputs','+-', 'Position',[250 55 280 95]);
add_block('built-in/Constant',[C '/Sensitivity'], 'Value','sim_sens', 'Position',[20 165 70 185]);
add_block('built-in/Product', [C '/TPProduct'], 'Position',[150 185 190 225]);
add_block('built-in/Sum',     [C '/FNSum'], 'Inputs','+-', 'Position',[250 185 280 225]);
add_block('built-in/Constant',[C '/SpecInv'], 'Value','1 - sim_spec', 'Position',[20 285 70 305]);
add_block('built-in/Product', [C '/FPProduct'], 'Position',[150 305 190 345]);
add_block('built-in/Sum',     [C '/TNSum'], 'Inputs','+-', 'Position',[250 305 280 345]);
add_block('built-in/Sum',     [C '/ReferralsSum'], 'Inputs','++', 'Position',[360 120 390 160]);
add_block('built-in/Outport', [C '/referable'], 'Port','1', 'Position',[470 45 500 65]);
add_block('built-in/Outport', [C '/nonreferable'], 'Port','2', 'Position',[470 75 500 95]);
add_block('built-in/Outport', [C '/tp'], 'Port','3', 'Position',[470 175 500 195]);
add_block('built-in/Outport', [C '/fn'], 'Port','4', 'Position',[470 205 500 225]);
add_block('built-in/Outport', [C '/fp'], 'Port','5', 'Position',[470 295 500 315]);
add_block('built-in/Outport', [C '/tn'], 'Port','6', 'Position',[470 325 500 345]);
add_block('built-in/Outport', [C '/referrals'], 'Port','7', 'Position',[470 120 500 140]);
add_line(C,'aiScreened/1','ReferableProduct/1','autorouting','on');
add_line(C,'Prevalence/1','ReferableProduct/2','autorouting','on');
add_line(C,'aiScreened/1','NonReferableSum/1','autorouting','on');
add_line(C,'ReferableProduct/1','NonReferableSum/2','autorouting','on');
add_line(C,'ReferableProduct/1','TPProduct/1','autorouting','on');
add_line(C,'Sensitivity/1','TPProduct/2','autorouting','on');
add_line(C,'ReferableProduct/1','FNSum/1','autorouting','on');
add_line(C,'TPProduct/1','FNSum/2','autorouting','on');
add_line(C,'NonReferableSum/1','FPProduct/1','autorouting','on');
add_line(C,'SpecInv/1','FPProduct/2','autorouting','on');
add_line(C,'NonReferableSum/1','TNSum/1','autorouting','on');
add_line(C,'FPProduct/1','TNSum/2','autorouting','on');
add_line(C,'TPProduct/1','ReferralsSum/1','autorouting','on');
add_line(C,'FPProduct/1','ReferralsSum/2','autorouting','on');
add_line(C,'ReferableProduct/1','referable/1','autorouting','on');
add_line(C,'NonReferableSum/1','nonreferable/1','autorouting','on');
add_line(C,'TPProduct/1','tp/1','autorouting','on');
add_line(C,'FNSum/1','fn/1','autorouting','on');
add_line(C,'FPProduct/1','fp/1','autorouting','on');
add_line(C,'TNSum/1','tn/1','autorouting','on');
add_line(C,'ReferralsSum/1','referrals/1','autorouting','on');

%% ================= Subsystem D: Specialist Queue & Review =================
D = [mdl '/Specialist Queue & Review'];
add_block('built-in/Subsystem', D, 'Position',[1000 50 1300 220]);
add_block('built-in/Inport',  [D '/referrals'], 'Port','1', 'Position',[20 60 50 80]);
add_block('built-in/UnitDelay',[D '/QueueState'], 'InitialCondition','0', 'SampleTime','1', 'Position',[120 250 170 290]);
add_block('built-in/Sum',     [D '/TotalWaiting'], 'Inputs','++', 'Position',[220 90 250 130]);
add_block('built-in/Constant',[D '/Capacity'], 'Value','sim_specCapacity', 'Position',[220 25 280 45]);
add_block('built-in/MinMax',  [D '/Reviewed'], 'Function','min', 'Inputs','2', 'Position',[340 55 380 95]);
add_block('built-in/Sum',     [D '/OverCapacity'], 'Inputs','+-', 'Position',[340 150 370 190]);
add_block('simulink/Discontinuities/Saturation',[D '/QueueFloor'], 'LowerLimit','0', 'UpperLimit','inf', 'Position',[420 155 460 185]);
add_block('built-in/Gain',    [D '/UtilGain'], 'Gain','1/sim_specCapacity', 'Position',[340 240 380 270]);
add_block('built-in/Outport', [D '/queue'], 'Port','1', 'Position',[520 110 550 130]);
add_block('built-in/Outport', [D '/reviewed'], 'Port','2', 'Position',[520 60 550 80]);
add_block('built-in/Outport', [D '/backlog'], 'Port','3', 'Position',[520 150 550 170]);
add_block('built-in/Outport', [D '/utilization'], 'Port','4', 'Position',[520 245 550 265]);
add_block('built-in/Outport', [D '/totalWaiting'], 'Port','5', 'Position',[520 195 550 215]);
add_line(D,'QueueState/1','TotalWaiting/1','autorouting','on');
add_line(D,'referrals/1','TotalWaiting/2','autorouting','on');
add_line(D,'TotalWaiting/1','Reviewed/1','autorouting','on');
add_line(D,'Capacity/1','Reviewed/2','autorouting','on');
add_line(D,'TotalWaiting/1','OverCapacity/1','autorouting','on');
add_line(D,'Capacity/1','OverCapacity/2','autorouting','on');
add_line(D,'OverCapacity/1','QueueFloor/1','autorouting','on');
add_line(D,'QueueFloor/1','QueueState/1','autorouting','on');
add_line(D,'Reviewed/1','UtilGain/1','autorouting','on');
add_line(D,'QueueFloor/1','queue/1','autorouting','on');
add_line(D,'Reviewed/1','reviewed/1','autorouting','on');
add_line(D,'QueueFloor/1','backlog/1','autorouting','on');
add_line(D,'UtilGain/1','utilization/1','autorouting','on');
add_line(D,'TotalWaiting/1','totalWaiting/1','autorouting','on');

%% ================= Subsystem E: System Metrics =================
E = [mdl '/System Metrics'];
add_block('built-in/Subsystem', E, 'Position',[1380 50 1620 250]);
metrics = {'arrivals','usable','failures','recaptured','aiScreened', ...
    'referable','nonreferable','tp','fn','fp','tn','referrals', ...
    'queue','reviewed','backlog','utilization'};
for i = 1:numel(metrics)
    y = 20 + (i-1)*22;
    add_block('built-in/Inport', [E '/' metrics{i}], 'Port', num2str(i), ...
        'Position',[20 y 50 y+16]);
end
add_block('built-in/Mux', [E '/MetricsMux'], 'Inputs','16', 'Position',[160 40 170 380]);
add_block('built-in/Outport', [E '/metrics'], 'Port','1', 'Position',[260 195 290 215]);
for i = 1:numel(metrics)
    add_line(E, sprintf('%s/1',metrics{i}), sprintf('MetricsMux/%d',i),'autorouting','on');
end
add_line(E,'MetricsMux/1','metrics/1','autorouting','on');

%% ================= Top-level wiring =================
add_line(mdl,'Patient Arrival & Image Capture/1','Quality Gate/1','autorouting','on');
add_line(mdl,'Quality Gate/4','AI Screening & Referral/1','autorouting','on');
add_line(mdl,'AI Screening & Referral/7','Specialist Queue & Review/1','autorouting','on');

% All signals into System Metrics (matches the input order above)
add_line(mdl,'Patient Arrival & Image Capture/1','System Metrics/1','autorouting','on');
add_line(mdl,'Quality Gate/1','System Metrics/2','autorouting','on');
add_line(mdl,'Quality Gate/2','System Metrics/3','autorouting','on');
add_line(mdl,'Quality Gate/3','System Metrics/4','autorouting','on');
add_line(mdl,'Quality Gate/4','System Metrics/5','autorouting','on');
add_line(mdl,'AI Screening & Referral/1','System Metrics/6','autorouting','on');
add_line(mdl,'AI Screening & Referral/2','System Metrics/7','autorouting','on');
add_line(mdl,'AI Screening & Referral/3','System Metrics/8','autorouting','on');
add_line(mdl,'AI Screening & Referral/4','System Metrics/9','autorouting','on');
add_line(mdl,'AI Screening & Referral/5','System Metrics/10','autorouting','on');
add_line(mdl,'AI Screening & Referral/6','System Metrics/11','autorouting','on');
add_line(mdl,'AI Screening & Referral/7','System Metrics/12','autorouting','on');
add_line(mdl,'Specialist Queue & Review/1','System Metrics/13','autorouting','on');
add_line(mdl,'Specialist Queue & Review/2','System Metrics/14','autorouting','on');
add_line(mdl,'Specialist Queue & Review/3','System Metrics/15','autorouting','on');
add_line(mdl,'Specialist Queue & Review/4','System Metrics/16','autorouting','on');

% Top-level output + named logs + scopes
add_block('built-in/Outport', [mdl '/metrics'], 'Port','1', 'Position',[1700 140 1730 160]);
add_line(mdl,'System Metrics/1','metrics/1','autorouting','on');

add_block('built-in/ToWorkspace', [mdl '/referralsLog'], 'VariableName','referralsLog', ...
    'SaveFormat','Array', 'Position',[1700 60 1770 80]);
add_line(mdl,'AI Screening & Referral/7','referralsLog/1','autorouting','on');
add_block('built-in/ToWorkspace', [mdl '/queueLog'], 'VariableName','queueLog', ...
    'SaveFormat','Array', 'Position',[1700 220 1770 240]);
add_line(mdl,'Specialist Queue & Review/1','queueLog/1','autorouting','on');
add_block('built-in/ToWorkspace', [mdl '/utilizationLog'], 'VariableName','utilizationLog', ...
    'SaveFormat','Array', 'Position',[1700 280 1770 300]);
add_line(mdl,'Specialist Queue & Review/4','utilizationLog/1','autorouting','on');

add_block('built-in/Scope', [mdl '/Scope Referrals per Day'], 'Position',[1820 50 1870 90]);
add_line(mdl,'AI Screening & Referral/7','Scope Referrals per Day/1','autorouting','on');
add_block('built-in/Scope', [mdl '/Scope Specialist Queue'], 'Position',[1820 130 1870 170]);
add_line(mdl,'Specialist Queue & Review/1','Scope Specialist Queue/1','autorouting','on');
add_block('built-in/Scope', [mdl '/Scope Utilization'], 'Position',[1820 210 1870 250]);
add_line(mdl,'Specialist Queue & Review/4','Scope Utilization/1','autorouting','on');

add_block('built-in/Note', [mdl '/ENGINEERING RESOURCE-PLANNING SIMULATION - NOT clinical validation'], ...
    'Position',[40 20 600 40]);

save_system(mdl, modelPath);
close_system(mdl, 0);

fprintf('Built model: %s\n', modelPath);
end