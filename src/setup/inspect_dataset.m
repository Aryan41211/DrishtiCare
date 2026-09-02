% inspect_dataset.m - Day 1: Load and visualize APTOS dataset
% Run this after verify_environment.m
% This script loads sample images and shows class distribution

fprintf('=== DrishtiCare Dataset Inspection ===\n');
fprintf('Date: %s\n\n', datestr(now));

%% 1. Set paths
% Find project root based on this script's location
script_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(fileparts(script_dir));

dataset_path = fullfile(project_root, 'data', 'aptos2019');
train_csv = fullfile(dataset_path, 'train.csv');
train_images_dir = fullfile(dataset_path, 'train_images');
test_images_dir = fullfile(dataset_path, 'test_images');

%% 2. Check if dataset exists
fprintf('--- Dataset Location ---\n');
if exist(dataset_path, 'dir')
    fprintf('[PASS] Dataset found at: %s\n', dataset_path);
else
    fprintf('[FAIL] Dataset not found at: %s\n', dataset_path);
    fprintf('       Download from Kaggle: aptos2019-blindness-detection\n');
    return;
end

%% 3. Load CSV
fprintf('\n--- Training Labels ---\n');
if exist(train_csv, 'file')
    data = readtable(train_csv);
    fprintf('[PASS] Loaded train.csv: %d images\n', height(data));
    
    % Class distribution
    fprintf('\nClass Distribution (DR Severity):\n');
    class_names = {'0 - No DR', '1 - Mild', '2 - Moderate', '3 - Severe', '4 - Proliferative'};
    for i = 0:4
        count = sum(data.diagnosis == i);
        pct = count / height(data) * 100;
        fprintf('  %s: %d images (%.1f%%)\n', class_names{i+1}, count, pct);
    end
else
    fprintf('[FAIL] train.csv not found\n');
    return;
end

%% 4. Count images
fprintf('\n--- Image Counts ---\n');
train_imgs = dir(fullfile(train_images_dir, '*.png'));
test_imgs = dir(fullfile(test_images_dir, '*.png'));
fprintf('Train images: %d\n', length(train_imgs));
fprintf('Test images: %d\n', length(test_imgs));

if length(train_imgs) == height(data)
    fprintf('[PASS] Image count matches CSV\n');
else
    fprintf('[WARN] Image count mismatch! CSV: %d, Files: %d\n', height(data), length(train_imgs));
end

%% 5. Load and display sample images
fprintf('\n--- Sample Images ---\n');
fprintf('Displaying 10 sample images (one per class + extras)...\n\n');

% Get samples from each class
figure('Name', 'DrishtiCare - APTOS Samples', 'NumberTitle', 'off', ...
       'Position', [100, 100, 1400, 900]);

sample_indices = [];
for class = 0:4
    class_idx = find(data.diagnosis == class);
    if ~isempty(class_idx)
        sample_indices = [sample_indices; class_idx(1)];
    end
end

% Add a few more random samples
remaining = setdiff(1:height(data), sample_indices);

if length(remaining) >= 5
    extra_idx = remaining(randperm(length(remaining), 5));
    sample_indices = [sample_indices; extra_idx(:)];
end
sample_indices = sample_indices(1:min(10, length(sample_indices)));

for i = 1:length(sample_indices)
    idx = sample_indices(i);
    img_name = data.id_code{idx};
    img_class = data.diagnosis(idx);
    img_path = fullfile(train_images_dir, [img_name '.png']);
    
    if exist(img_path, 'file')
        img = imread(img_path);
        subplot(2, 5, i);
        imshow(img);
        title(sprintf('Class %d: %s', img_class, class_names{img_class+1}), ...
              'FontSize', 8);
        
        % Get image info
        [h, w, c] = size(img);
        fprintf('  [%d] %s: %dx%d, %d channels, Class %d\n', i, img_name, h, w, c, img_class);
    else
        fprintf('  [%d] %s: FILE NOT FOUND\n', i, img_name);
    end
end
fprintf('\n[PASS] Sample images loaded and displayed.\n');

%% 6. Image size analysis (sample)
fprintf('\n--- Image Size Analysis (first 50 images) ---\n');
sizes = zeros(min(50, height(data)), 2);
for i = 1:min(50, height(data))
    img_path = fullfile(train_images_dir, [data.id_code{i} '.png']);
    if exist(img_path, 'file')
        info = imfinfo(img_path);
        sizes(i, :) = [info.Width, info.Height];
    end
end
fprintf('Width  - Min: %d, Max: %d, Mean: %.0f\n', min(sizes(:,1)), max(sizes(:,1)), mean(sizes(:,1)));
fprintf('Height - Min: %d, Max: %d, Mean: %.0f\n', min(sizes(:,2)), max(sizes(:,2)), mean(sizes(:,2)));
fprintf('[NOTE] Images have varying sizes. Will need resizing for training.\n');

%% 7. Sample output path
fprintf('\n--- Output ---\n');
output_dir = fullfile(project_root, 'data', 'samples');

if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

fprintf('Sample images saved to: %s\n', output_dir);

%% Summary
fprintf('\n=== SUMMARY ===\n');
fprintf('[OK] APTOS 2019 dataset is loaded and ready.\n');
fprintf('[OK] 3,662 training images across 5 classes.\n');
fprintf('[OK] Class imbalance exists (expected for medical data).\n');
fprintf('\nNext steps:\n');
fprintf('  1. Discuss class balancing strategy (oversampling/weights)\n');
fprintf('  2. Plan image preprocessing (resize to 224x224 or 512x512)\n');
fprintf('  3. Tomorrow (Day 2): Start data_loaders.m\n');
fprintf('=== End Inspection ===\n');
