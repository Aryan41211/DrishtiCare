function run_day1()
% RUN_DAY1
% Automated Day 1 verification for DrishtiCare

fprintf('\n');
fprintf('============================================\n');
fprintf('       DrishtiCare - DAY 1 CHECK            \n');
fprintf('============================================\n\n');

%% Find project root

script_dir = fileparts(mfilename('fullpath'));

% run_day1.m is located at:
% DrishtiCare/src/setup/run_day1.m
%
% Therefore:
% setup -> src -> DrishtiCare

project_root = fileparts(fileparts(script_dir));

fprintf('Project root:\n');
fprintf('%s\n\n', project_root);

%% Set MATLAB working directory

cd(project_root);

fprintf('[PASS] Working directory set.\n');

%% Add setup folder

setup_dir = fullfile(project_root, 'src', 'setup');

addpath(setup_dir);

fprintf('[PASS] Setup folder added to MATLAB path.\n\n');

%% Check required scripts

fprintf('--- Required Scripts ---\n');

required_scripts = {
    'verify_environment.m'
    'inspect_dataset.m'
    'check_dataset_integrity.m'
};

all_scripts_found = true;

for i = 1:length(required_scripts)

    script_path = fullfile(setup_dir, required_scripts{i});

    if exist(script_path, 'file')
        fprintf('[PASS] %s found\n', required_scripts{i});
    else
        fprintf('[FAIL] %s not found\n', required_scripts{i});
        all_scripts_found = false;
    end

end

if ~all_scripts_found
    fprintf('\n[ABORT] Required scripts are missing.\n');
    return;
end

%% Environment check

fprintf('\n');
fprintf('============================================\n');
fprintf('          1. ENVIRONMENT CHECK              \n');
fprintf('============================================\n\n');

verify_environment;

%% Dataset inspection

fprintf('\n');
fprintf('============================================\n');
fprintf('           2. DATASET INSPECTION             \n');
fprintf('============================================\n\n');

inspect_dataset;

%% Dataset integrity

fprintf('\n');
fprintf('============================================\n');
fprintf('           3. DATASET INTEGRITY              \n');
fprintf('============================================\n\n');

check_dataset_integrity;

%% Complete

fprintf('\n');
fprintf('============================================\n');
fprintf('        DAY 1 AUTOMATION COMPLETE            \n');
fprintf('============================================\n\n');

fprintf('All Day 1 checks have been executed.\n');
fprintf('Project: %s\n\n', project_root);

end