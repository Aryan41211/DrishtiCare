%% launchRetinaAI.m
% DrishtiCare - DRISHTI Single-Image Screening App
% Launch the App Designer demonstration front-end (wraps predictSingleFundus).

clear; clc; close all;

projectRoot = fileparts(mfilename('fullpath'));
cd(projectRoot);
addpath(projectRoot);
addpath(genpath(fullfile(projectRoot,'src')));

fprintf('\n============================================\n');
fprintf('   DRISHTI - Screening App (demo)\n');
fprintf('============================================\n');
fprintf('ENGINEERING DEMO - NOT a clinical device.\n\n');

app = RetinaAIApp();
disp('DRISHTI launched. Select a sample image or upload one, then press ANALYZE.');