%% DrishtiCare - APTOS Runner

clear;
clc;
close all;

%% Project
PROJECT_ROOT = 'C:\projects\DrishtiCare';
cd(PROJECT_ROOT);

%% Add source code
addpath(genpath(fullfile(PROJECT_ROOT,'src')));

fprintf('\n============================================\n');
fprintf('       DRISHTICARE - APTOS\n');
fprintf('============================================\n\n');

%% Check APTOS
aptosDir = fullfile(PROJECT_ROOT,'data','aptos2019');
trainCsv = fullfile(aptosDir,'train.csv');

fprintf('Checking APTOS dataset...\n');

if ~isfile(trainCsv)

    fprintf('\n[ERROR] train.csv not found.\n');
    fprintf('Expected:\n%s\n\n',trainCsv);

    fprintf('Searching project for train.csv...\n');

    files = dir(fullfile(PROJECT_ROOT,'**','train.csv'));

    if isempty(files)
        error('No train.csv found anywhere in the project.');
    end

    for k = 1:numel(files)
        fprintf('%s\n',fullfile(files(k).folder,files(k).name));
    end

    error('APTOS path is incorrect in the project.');
end

fprintf('[PASS] APTOS labels found\n');
fprintf('%s\n',trainCsv);

%% Load labels
data = readtable(trainCsv);

fprintf('\n============================================\n');
fprintf('APTOS DATASET\n');
fprintf('============================================\n');

fprintf('Total labeled images: %d\n',height(data));

if any(strcmpi(data.Properties.VariableNames,'diagnosis'))

    labels = data.diagnosis;

    fprintf('\nClass distribution:\n');

    for c = 0:4
        fprintf('Grade %d: %d images\n',c,sum(labels == c));
    end
end

%% Function checks
fprintf('\n============================================\n');
fprintf('FUNCTION CHECK\n');
fprintf('============================================\n');

fprintf('\nprepareData:\n');
which prepareData -all

fprintf('\nQuality assessment:\n');
which assessImageQuality -all

fprintf('\nEnhancement:\n');
which enhanceImage -all

fprintf('\nClassifier evaluation:\n');
which evaluateClassifier -all

%% Finish
fprintf('\n============================================\n');
fprintf('APTOS CHECK COMPLETE\n');
fprintf('============================================\n\n');

fprintf('The dataset was found successfully.\n');
fprintf('No model was retrained by this script.\n');