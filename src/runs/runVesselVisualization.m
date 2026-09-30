%% runVesselVisualization.m
% DrishtiCare - Enhanced + Vessel Visualization
% 10 random retinal images
% NO TRAINING / NO RETRAINING

clear; clc; close all;

fprintf('\n============================================\n');
fprintf(' DRISHTICARE - RETINA VESSEL VISUALIZATION\n');
fprintf('============================================\n');

%% Setup
projectRoot = 'C:\projects\DrishtiCare';
cd(projectRoot);
addpath(genpath(fullfile(projectRoot,'src')));

rng('shuffle');

%% Load validation images
valRoot = fullfile( ...
    projectRoot, ...
    'data','splits','val');

imds = imageDatastore( ...
    valRoot, ...
    'IncludeSubfolders',true, ...
    'LabelSource','foldernames');

%% Select 10 random images
N = 10;

if numel(imds.Files) < N
    error('Not enough validation images.');
end

idx = randperm(numel(imds.Files),N);

%% Create output folder
outDir = fullfile( ...
    projectRoot, ...
    'data','analysis','vessel_visualization');

if ~exist(outDir,'dir')
    mkdir(outDir);
end

%% Process images
for i = 1:N

    %% Read original
    img = imread(imds.Files{idx(i)});

    %% Convert to RGB if needed
    if size(img,3) == 1
        img = repmat(img,[1 1 3]);
    end

    %% ------------------------------------------------
    % ENHANCEMENT
    % -------------------------------------------------
    try
        enhanced = enhanceImage(img);
    catch
        % Fallback enhancement
        enhanced = adapthisteq( ...
            rgb2gray(img));
        
        enhanced = repmat(enhanced,[1 1 3]);
    end

    %% ------------------------------------------------
    % VESSEL EXTRACTION
    % -------------------------------------------------

    % Use green channel - vessels are generally more
    % visible in the green retinal channel.
    green = enhanced(:,:,2);

    green = im2uint8(mat2gray(green));

    % Improve local contrast
    greenEnhanced = adapthisteq(green);

    % Detect dark vessel structures
    vesselDark = ...
        imbothat(greenEnhanced, ...
        strel('disk',8));

    % Normalize
    vesselDark = mat2gray(vesselDark);

    % Threshold
    vesselMask = vesselDark > graythresh(vesselDark);

    % Remove tiny noise
    vesselMask = bwareaopen(vesselMask,20);

    % Slight morphological cleanup
    vesselMask = imclose( ...
        vesselMask, ...
        strel('disk',1));

    %% Create vessel-only image

    vesselOnly = uint8(vesselMask) * 255;

    %% Optional skeleton
    vesselSkeleton = bwmorph( ...
        vesselMask, ...
        'skel', ...
        Inf);

    skeletonImage = uint8(vesselSkeleton) * 255;

    %% ------------------------------------------------
    % DISPLAY
    % -------------------------------------------------

    figure( ...
        'Name',sprintf('Image %d',i), ...
        'NumberTitle','off', ...
        'Position',[100 100 1400 750]);

    subplot(1,4,1);
    imshow(img);
    title('Original');

    subplot(1,4,2);
    imshow(enhanced);
    title('Enhanced');

    subplot(1,4,3);
    imshow(vesselOnly);
    title('Vessel Mask');

    subplot(1,4,4);
    imshow(skeletonImage);
    title('Vessel Skeleton');

    %% Save
    saveas( ...
        gcf, ...
        fullfile(outDir, ...
        sprintf('vessel_%02d.png',i)));

    close(gcf);

    fprintf( ...
        '%2d/10 processed: %s\n', ...
        i, ...
        imds.Files{idx(i)});

end

fprintf('\n============================================\n');
fprintf('Visualization complete.\n');
fprintf('Saved to:\n%s\n',outDir);
fprintf('============================================\n');