% check_dataset_integrity.m - Verify dataset completeness and quality
% Run this to ensure all files are present and not corrupted

fprintf('=== Dataset Integrity Check ===\n\n');

%% Paths
% Find project root based on this script's location
script_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(fileparts(script_dir));

dataset_path = fullfile(project_root, 'data', 'aptos2019');
train_dir = fullfile(dataset_path, 'train_images');
test_dir = fullfile(dataset_path, 'test_images');
train_csv = fullfile(dataset_path, 'train.csv');

%% Check 1: Directory structure
fprintf('--- Directory Structure ---\n');
dirs_to_check = {dataset_path, train_dir, test_dir};
dir_names = {'Root', 'Train Images', 'Test Images'};

all_dirs_ok = true;
for i = 1:length(dirs_to_check)
    if exist(dirs_to_check{i}, 'dir')
        fprintf('[PASS] %s exists\n', dir_names{i});
    else
        fprintf('[FAIL] %s not found\n', dir_names{i});
        all_dirs_ok = false;
    end
end

if ~all_dirs_ok
    fprintf('\n[ABORT] Missing directories. Download dataset first.\n');
    return;
end

%% Check 2: File counts
fprintf('\n--- File Counts ---\n');
train_files = dir(fullfile(train_dir, '*.png'));
test_files = dir(fullfile(test_dir, '*.png'));
fprintf('Train images: %d (expected: 3662)\n', length(train_files));
fprintf('Test images:  %d (expected: 1928)\n', length(test_files));

count_ok = true;
if length(train_files) ~= 3662
    fprintf('[WARN] Train image count mismatch\n');
    count_ok = false;
end
if length(test_files) ~= 1928
    fprintf('[WARN] Test image count mismatch\n');
    count_ok = false;
end
if count_ok
    fprintf('[PASS] File counts match expected\n');
end

%% Check 3: CSV validation
fprintf('\n--- CSV Validation ---\n');
if exist(train_csv, 'file')
    data = readtable(train_csv);
    fprintf('CSV rows: %d\n', height(data));
    
    % Check all images in CSV exist
    missing = 0;
    for i = 1:height(data)
        img_path = fullfile(train_dir, [data.id_code{i} '.png']);
        if ~exist(img_path, 'file')
            missing = missing + 1;
            if missing <= 5
                fprintf('[WARN] Missing image: %s\n', data.id_code{i});
            end
        end
    end
    
    if missing == 0
        fprintf('[PASS] All CSV entries have matching images\n');
    else
        fprintf('[WARN] %d images missing from train directory\n', missing);
    end
    
    % Check class balance
    fprintf('\nClass Distribution:\n');
    for i = 0:4
        count = sum(data.diagnosis == i);
        bar_str = repmat('#', 1, round(count/100));
        fprintf('  Class %d: %5d %s\n', i, count, bar_str);
    end
else
    fprintf('[FAIL] train.csv not found\n');
end

%% Check 4: Sample file sizes
fprintf('\n--- Sample File Sizes ---\n');
sample_idx = randperm(length(train_files), min(5, length(train_files)));
total_size = 0;
for i = 1:length(sample_idx)
    file_path = fullfile(train_dir, train_files(sample_idx(i)).name);
    file_info = dir(file_path);
    file_size_mb = file_info.bytes / 1e6;
    total_size = total_size + file_info.bytes;
    fprintf('  %s: %.2f MB\n', train_files(sample_idx(i)).name, file_size_mb);
end
fprintf('Average sample size: %.2f MB\n', (total_size / length(sample_idx)) / 1e6);

%% Check 5: Image properties
fprintf('\n--- Image Properties (sample) ---\n');
sample_img_path = fullfile(train_dir, train_files(1).name);
try
    info = imfinfo(sample_img_path);
    fprintf('Format: %s\n', info.Format);
    fprintf('Dimensions: %d x %d\n', info.Width, info.Height);
    fprintf('Bit depth: %d\n', info.BitDepth);
    fprintf('[PASS] Images are readable\n');
catch e
    fprintf('[FAIL] Cannot read image: %s\n', e.message);
end

%% Summary
fprintf('\n=== INTEGRITY SUMMARY ===\n');
if all_dirs_ok && count_ok
    fprintf('[OK] Dataset integrity check passed.\n');
    fprintf('[OK] Ready for Day 2: Data exploration.\n');
else
    fprintf('[ACTION] Fix issues above before proceeding.\n');
end

fprintf('\n=== End Check ===\n');
