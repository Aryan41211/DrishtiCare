%% launchRetinaAI.m
% DrishtiCare - RETINA-AI Single-Image Screening App
% Launch the App Designer demonstration front-end (wraps predictSingleFundus).

clear; clc; close all;

projectRoot = 'C:\projects\DrishtiCare';
cd(projectRoot);
addpath(genpath(fullfile(projectRoot,'src')));

fprintf('\n============================================\n');
fprintf('   RETINA-AI - Screening App (demo)\n');
fprintf('============================================\n');
fprintf('ENGINEERING DEMO - NOT a clinical device.\n\n');

app = RetinaAIApp();
disp('RETINA-AI launched. Select a sample image or upload one, then press ANALYZE.');