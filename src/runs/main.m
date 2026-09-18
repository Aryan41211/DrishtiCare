% Main Entry Point - DrishtiCare DR Screening Pipeline
% SIH 26038 | MathWorks | Internal Round: Sep 12, 2026
%
% Pipeline: Raw Image -> Quality Check -> Enhancement -> Classification -> Grad-CAM -> Report
%
% Usage:
%   main()                    - Run full pipeline on sample image
%   main('path/to/image.png') - Run pipeline on specific image

function main(image_path)
    fprintf('=== DrishtiCare DR Screening Pipeline ===\n');
    fprintf('Version: 0.1.0 (Day 1 - Setup)\n\n');
    
    % Default to a sample image if none provided
    if nargin < 1
        sample_dir = fullfile('..', 'data', 'aptos2019', 'train_images');
        if exist(sample_dir, 'dir')
            files = dir(fullfile(sample_dir, '*.png'));
            if ~isempty(files)
                image_path = fullfile(sample_dir, files(1).name);
                fprintf('Using sample image: %s\n\n', files(1).name);
            else
                error('No images found in %s', sample_dir);
            end
        else
            error('Dataset directory not found. Run inspect_dataset.m first.');
        end
    end
    
    % Check image exists
    if ~exist(image_path, 'file')
        error('Image not found: %s', image_path);
    end
    
    % Load image
    fprintf('Loading image...\n');
    img = imread(image_path);
    fprintf('  Size: %dx%d, Channels: %d\n', size(img, 1), size(img, 2), size(img, 3));
    
    % Display original
    figure('Name', 'DrishtiCare Pipeline', 'NumberTitle', 'off');
    subplot(1, 2, 1);
    imshow(img);
    title('Original Image');
    
    % TODO: Pipeline stages will be added in Days 3-9
    % Stage 1: Quality Assessment (Day 3)
    % Stage 2: Image Enhancement (Day 4)
    % Stage 3: Classification (Days 5-6)
    % Stage 4: Grad-CAM Explainability (Day 7)
    % Stage 5: Report Generation (Day 9)
    
    fprintf('\n[STUB] Pipeline stages not yet implemented.\n');
    fprintf('See schedule/ for daily tasks.\n');
    
    subplot(1, 2, 2);
    imshow(img);
    title('Pipeline Output (Coming Soon)');
    
    fprintf('\n=== End Pipeline ===\n');
end
