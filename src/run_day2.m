% run_day2.m - Master script for Day 2
% Runs all Day 2 tasks in sequence
%
% Usage:
%   run_day2           % Run everything
%   run_day2('skip_train')  % Skip training, just explore

fprintf('============================================\n');
fprintf('       DrishtiCare - DAY 2 EXECUTION       \n');
fprintf('============================================\n\n');

%% Setup paths
script_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(script_dir);
cd(project_root);
addpath(fullfile(project_root, 'src', 'data_loaders'));
addpath(fullfile(project_root, 'src', 'grading'));
addpath(fullfile(project_root, 'src', 'quality'));

fprintf('Project root: %s\n\n', project_root);

%% Parse arguments
skipTrain = false;
if nargin > 0 && strcmpi(varargin{1}, 'skip_train')
    skipTrain = true;
    fprintf('[INFO] Skipping training (exploration only)\n\n');
end

%% Step 1: Data Exploration
fprintf('============================================\n');
fprintf('         STEP 1: DATA EXPLORATION            \n');
fprintf('============================================\n\n');

try
    explore_data;
    fprintf('\n[OK] Data exploration complete\n\n');
catch e
    fprintf('[ERROR] Data exploration failed: %s\n', e.message);
end

%% Step 2: Quality Analysis
fprintf('============================================\n');
fprintf('         STEP 2: QUALITY ANALYSIS            \n');
fprintf('============================================\n\n');

try
    quality_analysis;
    fprintf('\n[OK] Quality analysis complete\n\n');
catch e
    fprintf('[ERROR] Quality analysis failed: %s\n', e.message);
end

%% Step 3: Training (optional)
if ~skipTrain
    fprintf('============================================\n');
    fprintf('         STEP 3: MODEL TRAINING             \n');
    fprintf('============================================\n\n');

    % Training options
    trainOpts = struct();
    trainOpts.Network = 'resnet18';      % Start with smaller network
    trainOpts.MaxEpochs = 10;           % Quick training first
    trainOpts.MiniBatchSize = 32;
    trainOpts.InitialLearnRate = 0.001;

    fprintf('Training Configuration:\n');
    fprintf('  Network: %s\n', trainOpts.Network);
    fprintf('  Epochs: %d\n', trainOpts.MaxEpochs);
    fprintf('  Batch Size: %d\n\n', trainOpts.MiniBatchSize);

    try
        tic;
        [net, info] = trainClassifier([], trainOpts);
        trainTime = toc;
        fprintf('\n[OK] Training complete (%.1f minutes)\n\n', trainTime/60);
    catch e
        fprintf('[ERROR] Training failed: %s\n', e.message);
        fprintf('       Check if Deep Learning Toolbox is available\n');
    end

    %% Step 4: Evaluation
    fprintf('============================================\n');
    fprintf('         STEP 4: MODEL EVALUATION           \n');
    fprintf('============================================\n\n');

    try
        results = evaluateClassifier;
        fprintf('\n[OK] Evaluation complete\n');
    catch e
        fprintf('[ERROR] Evaluation failed: %s\n', e.message);
    end
else
    fprintf('\n[INFO] Training skipped. Run trainClassifier() manually.\n');
end

%% Summary
fprintf('\n============================================\n');
fprintf('            DAY 2 COMPLETE                   \n');
fprintf('============================================\n\n');

fprintf('Files created:\n');
fprintf('  src/data_loaders/loadAptos.m\n');
fprintf('  src/data_loaders/createDatastores.m\n');
fprintf('  src/data_loaders/explore_data.m\n');
fprintf('  src/data_loaders/quality_analysis.m\n');
fprintf('  src/grading/trainClassifier.m\n');
fprintf('  src/grading/evaluateClassifier.m\n');

fprintf('\nNext steps:\n');
fprintf('  1. Review visualizations\n');
fprintf('  2. Check accuracy metrics\n');
fprintf('  3. Decide if more training needed\n');
fprintf('  4. Prepare for Day 3: Quality Assessment Module\n');

fprintf('\n=== End Day 2 ===\n');
