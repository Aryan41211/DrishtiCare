% verify_environment.m - Day 1: Check MATLAB setup and toolboxes
% Run this script on EVERY teammate's machine
% Expected output: All checks pass, or clear error messages

fprintf('=== DrishtiCare Environment Verification ===\n');
fprintf('Date: %s\n\n', datestr(now));

%% 1. MATLAB Version
fprintf('--- MATLAB Version ---\n');
v = version;
fprintf('MATLAB Version: %s\n', v);
if contains(v, '2023') || contains(v, '2024') || contains(v, '2025') || contains(v, '2026')
    fprintf('[PASS] MATLAB version is recent enough.\n');
else
    fprintf('[WARN] MATLAB version may be outdated. Recommended: R2023a or later.\n');
end
fprintf('\n');

%% Required Toolboxes
fprintf('\n--- Required Toolboxes ---\n');

all_toolboxes_ok = true;

% Image Processing Toolbox
if exist('adapthisteq', 'file') == 2
    fprintf('[PASS] Image Processing Toolbox - AVAILABLE\n');
else
    fprintf('[FAIL] Image Processing Toolbox - NOT AVAILABLE\n');
    all_toolboxes_ok = false;
end

% Computer Vision Toolbox
try
    vision.CascadeObjectDetector;
    fprintf('[PASS] Computer Vision Toolbox - AVAILABLE\n');
catch
    fprintf('[FAIL] Computer Vision Toolbox - NOT AVAILABLE\n');
    all_toolboxes_ok = false;
end

% Deep Learning Toolbox
if exist('trainNetwork', 'file') == 2
    fprintf('[PASS] Deep Learning Toolbox - AVAILABLE\n');
else
    fprintf('[FAIL] Deep Learning Toolbox - NOT AVAILABLE\n');
    all_toolboxes_ok = false;
end

% Simulink
if exist('sim', 'builtin') == 5 || exist('sim', 'file') == 2
    fprintf('[PASS] Simulink - AVAILABLE\n');
else
    fprintf('[FAIL] Simulink - NOT AVAILABLE\n');
    all_toolboxes_ok = false;
end

% Statistics and Machine Learning Toolbox
if exist('fitcsvm', 'file') == 2
    fprintf('[PASS] Statistics and Machine Learning Toolbox - AVAILABLE\n');
else
    fprintf('[FAIL] Statistics and Machine Learning Toolbox - NOT AVAILABLE\n');
    all_toolboxes_ok = false;
end

%% 3. Simulink
fprintf('--- Simulink ---\n');
try
    simulink_info = ver('simulink');
    fprintf('[PASS] Simulink %s\n', simulink_info.Version);
catch
    fprintf('[WARN] Simulink not available. Needed for Day 8 throughput model.\n');
    fprintf('       Fallback: Use MATLAB script with assumed numbers.\n');
end
fprintf('\n');

%% GPU
fprintf('\n--- GPU ---\n');

% GPU is optional for DrishtiCare.
% Default to zero so gpu_count always exists.

gpu_count = 0;

if exist('gpuDeviceCount', 'file') == 2

    try
        gpu_count = gpuDeviceCount;

        if gpu_count > 0
            fprintf('[PASS] GPU available: %d device(s)\n', gpu_count);

            try
                gpu_info = gpuDevice;
                fprintf('       GPU: %s\n', gpu_info.Name);
                fprintf('       Memory: %.2f GB\n', ...
                    gpu_info.TotalMemory / 1e9);
            catch
                fprintf('[INFO] GPU detected, but device details unavailable.\n');
            end

        else
            fprintf('[INFO] No compatible GPU detected.\n');
            fprintf('       CPU execution will be used.\n');
        end

    catch e
        gpu_count = 0;
        fprintf('[INFO] GPU check failed: %s\n', e.message);
        fprintf('       CPU execution will be used.\n');
    end

else

    fprintf('[INFO] GPU functionality not available.\n');
    fprintf('       CPU execution will be used.\n');

end

%% 5. Disk Space
fprintf('--- Disk Space ---\n');
current_dir = pwd;
try
    info = dir(current_dir);
    % Just check if we can access the directory
    fprintf('[PASS] Current directory accessible: %s\n', current_dir);
catch
    fprintf('[WARN] Could not check disk space.\n');
end
fprintf('\n');

%% 6. Memory
fprintf('--- System Memory ---\n');
try
    mem_info = memory;
    total_gb = mem_info.PhysicalMemory.Total / 1e9;
    available_gb = mem_info.PhysicalMemory.Available / 1e9;
    fprintf('Total RAM: %.1f GB\n', total_gb);
    fprintf('Available: %.1f GB\n', available_gb);
    if available_gb > 4
        fprintf('[PASS] Sufficient memory for development.\n');
    else
        fprintf('[WARN] Low available memory. Close other applications.\n');
    end
catch
    fprintf('[INFO] Could not retrieve memory info.\n');
end
fprintf('\n');

%% Summary
fprintf('=== SUMMARY ===\n');
if ~all_toolboxes_ok
    fprintf('[ACTION REQUIRED] Missing toolboxes. See above for details.\n');
else
    fprintf('[PASS] All required toolboxes are available.\n');
end

if gpu_count == 0
    fprintf('[NOTE] No GPU. Consider using Colab for training.\n');
end

fprintf('\nNext step: Run inspect_dataset.m to verify APTOS data.\n');
fprintf('=== End Verification ===\n');
