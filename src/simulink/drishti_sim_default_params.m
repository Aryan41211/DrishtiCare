function drishti_sim_default_params()
% DRISHTI_SIM_DEFAULT_PARAMS  Default base-workspace parameters for the
% DrishtiCare district screening Simulink model.
%
%   Called from the model InitFcn/PreLoadFcn. Variables are set ONLY if they
%   are not already present in the base workspace, so a scenario driver can
%   override any parameter before calling sim().
%
%   ENGINEERING / RESOURCE-PLANNING SIMULATION - NOT clinical validation.

defaults = struct( ...
    'sim_patientsPerDay', 400, ...          % 100000 patients/year / 250 days (assumption)
    'sim_qUsable', 0.6548 + 0.2668, ...     % PASS + WARNING (measured, n=3662)
    'sim_qFail',   0.0784, ...              % FAIL (measured, n=3662)
    'sim_recapture', 0.50, ...              % recapture rate (assumption)
    'sim_prevalence', 0.4065, ...           % referable proportion (simulation assumption)
    'sim_sens', 0.9060, ...                 % locked sensitivity @0.60 (measured)
    'sim_spec', 0.9471, ...                 % locked specificity @0.60 (measured)
    'sim_specCapacity', 60);                % 3 specialists x 20 cases/day (assumption)

fn = fieldnames(defaults);
for i = 1:numel(fn)
    if evalin('base', sprintf('exist(''%s'',''var'')', fn{i})) == 0
        assignin('base', fn{i}, defaults.(fn{i}));
    end
end
end