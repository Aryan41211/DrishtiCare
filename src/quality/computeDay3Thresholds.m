function computeDay3Thresholds()
% COMPUTEDAY3THRESHOLDS Derive thresholds from full 3,662 dataset
%   computeDay3Thresholds()
%
%   Reads the full batch evaluation results and computes new thresholds
%   based on P5-P95 ranges from all 3,662 images.
%
%   Output:
%       - Prints new threshold values
%       - Updates defaultQualityConfig.m with new thresholds

    %% Setup
    script_dir = fileparts(mfilename('fullpath'));
    project_root = fileparts(fileparts(script_dir));
    cd(project_root);

    addpath(fullfile(project_root, 'src', 'quality'));

    fprintf('============================================\n');
    fprintf('   Computing Day 3 Thresholds from Full     \n');
    fprintf('         Dataset (3,662 images)             \n');
    fprintf('============================================\n\n');

    %% Load full dataset results
    csvPath = fullfile(project_root, 'data', 'analysis', 'day3', 'quality_assessment_results.csv');
    results = readtable(csvPath);

    fprintf('Loaded %d images\n', height(results));
    fprintf('PASS: %d, WARNING: %d, FAIL: %d\n\n', ...
        sum(strcmp(results.quality_status, 'PASS')), ...
        sum(strcmp(results.quality_status, 'WARNING')), ...
        sum(strcmp(results.quality_status, 'FAIL')));

    %% Compute statistics for each metric
    metrics = {'brightness', 'contrast', 'focus_score', 'foreground_fraction', 'illumination_metric'};
    metricNames = {'Brightness', 'Contrast', 'Focus Score', 'Foreground Fraction', 'Illumination'};

    fprintf('Full Dataset Statistics:\n');
    fprintf('%-20s %-10s %-10s %-10s %-10s %-10s %-10s %-10s\n', ...
        'Metric', 'Min', 'P5', 'P25', 'P50', 'P75', 'P95', 'Max');
    fprintf('%s\n', repmat('-', 1, 90));

    newThresholds = struct();

    for i = 1:length(metrics)
        metric = metrics{i};
        values = results.(metric);
        values = values(~isnan(values));  % Remove NaN values

        % Compute percentiles
        p5 = prctile(values, 5);
        p25 = prctile(values, 25);
        p50 = prctile(values, 50);
        p75 = prctile(values, 75);
        p95 = prctile(values, 95);

        fprintf('%-20s %-10.4f %-10.4f %-10.4f %-10.4f %-10.4f %-10.4f %-10.4f\n', ...
            metricNames{i}, min(values), p5, p25, p50, p75, p95, max(values));

        % Store new thresholds
        newThresholds.(metric) = struct(...
            'min', min(values), ...
            'p5', p5, ...
            'p25', p25, ...
            'p50', p50, ...
            'p75', p75, ...
            'p95', p95, ...
            'max', max(values));
    end

    %% Compute new threshold bounds
    fprintf('\n\nNew Threshold Derivation:\n');
    fprintf('%-20s %-10s %-10s %-10s %-10s\n', ...
        'Metric', 'FAIL Lower', 'WARN Lower', 'WARN Upper', 'FAIL Upper');
    fprintf('%s\n', repmat('-', 1, 55));

    % Brightness: FAIL at P1 and P99, WARNING at P5 and P95
    brightness = newThresholds.brightness;
    bFailLower = prctile(results.brightness, 1);
    bWarnLower = prctile(results.brightness, 5);
    bWarnUpper = prctile(results.brightness, 95);
    bFailUpper = prctile(results.brightness, 99);
    fprintf('%-20s %-10.4f %-10.4f %-10.4f %-10.4f\n', ...
        'Brightness', bFailLower, bWarnLower, bWarnUpper, bFailUpper);

    % Contrast: FAIL at P1 and P99, WARNING at P5 and P95
    cFailLower = prctile(results.contrast, 1);
    cWarnLower = prctile(results.contrast, 5);
    cWarnUpper = prctile(results.contrast, 95);
    cFailUpper = prctile(results.contrast, 99);
    fprintf('%-20s %-10.4f %-10.4f %-10.4f %-10.4f\n', ...
        'Contrast', cFailLower, cWarnLower, cWarnUpper, cFailUpper);

    % Focus: FAIL at P1 and P99, WARNING at P5 and P95
    fFailLower = prctile(results.focus_score, 1);
    fWarnLower = prctile(results.focus_score, 5);
    fWarnUpper = prctile(results.focus_score, 95);
    fFailUpper = prctile(results.focus_score, 99);
    fprintf('%-20s %-10.2e %-10.2e %-10.2e %-10.2e\n', ...
        'Focus Score', fFailLower, fWarnLower, fWarnUpper, fFailUpper);

    % Foreground: FAIL at P1 and P99, WARNING at P5 and P95
    fgFailLower = prctile(results.foreground_fraction, 1);
    fgWarnLower = prctile(results.foreground_fraction, 5);
    fgWarnUpper = prctile(results.foreground_fraction, 95);
    fgFailUpper = prctile(results.foreground_fraction, 99);
    fprintf('%-20s %-10.4f %-10.4f %-10.4f %-10.4f\n', ...
        'Foreground', fgFailLower, fgWarnLower, fgWarnUpper, fgFailUpper);

    % Illumination: FAIL at P1 and P99, WARNING at P5 and P95
    illumValues = results.illumination_metric(~isnan(results.illumination_metric));
    iFailLower = prctile(illumValues, 1);
    iWarnLower = prctile(illumValues, 5);
    iWarnUpper = prctile(illumValues, 95);
    iFailUpper = prctile(illumValues, 99);
    fprintf('%-20s %-10.4f %-10.4f %-10.4f %-10.4f\n', ...
        'Illumination', iFailLower, iWarnLower, iWarnUpper, iFailUpper);

    %% Save new thresholds to config
    fprintf('\n\nUpdating defaultQualityConfig.m with new thresholds...\n');

    % Create new config with updated thresholds
    configPath = fullfile(project_root, 'src', 'quality', 'defaultQualityConfig.m');

    % Read existing file
    fid = fopen(configPath, 'r');
    configContent = fread(fid, '*char')';
    fclose(fid);

    % Update version
    configContent = strrep(configContent, "config.version = '1.1.0';", "config.version = '2.0.0';");

    % Update derivedFrom
    configContent = strrep(configContent, ...
        "config.derivedFrom = 'Day 2 APTOS analysis (500-image stratified sample)';", ...
        "config.derivedFrom = 'Day 3 full dataset analysis (3,662 images)';");

    % Update brightness thresholds
    configContent = strrep(configContent, ...
        "config.thresholds.brightness.lowerWarn = 0.20;", ...
        sprintf("config.thresholds.brightness.lowerWarn = %.4f;", bWarnLower));
    configContent = strrep(configContent, ...
        "config.thresholds.brightness.lowerFail = 0.15;", ...
        sprintf("config.thresholds.brightness.lowerFail = %.4f;", bFailLower));
    configContent = strrep(configContent, ...
        "config.thresholds.brightness.upperWarn = 0.50;", ...
        sprintf("config.thresholds.brightness.upperWarn = %.4f;", bWarnUpper));
    configContent = strrep(configContent, ...
        "config.thresholds.brightness.upperFail = 0.55;", ...
        sprintf("config.thresholds.brightness.upperFail = %.4f;", bFailUpper));

    % Update contrast thresholds
    configContent = strrep(configContent, ...
        "config.thresholds.contrast.lowerWarn = 0.03;", ...
        sprintf("config.thresholds.contrast.lowerWarn = %.4f;", cWarnLower));
    configContent = strrep(configContent, ...
        "config.thresholds.contrast.lowerFail = 0.02;", ...
        sprintf("config.thresholds.contrast.lowerFail = %.4f;", cFailLower));
    configContent = strrep(configContent, ...
        "config.thresholds.contrast.upperWarn = 0.20;", ...
        sprintf("config.thresholds.contrast.upperWarn = %.4f;", cWarnUpper));
    configContent = strrep(configContent, ...
        "config.thresholds.contrast.upperFail = 0.25;", ...
        sprintf("config.thresholds.contrast.upperFail = %.4f;", cFailUpper));

    % Update focus thresholds
    configContent = strrep(configContent, ...
        "config.thresholds.focus.lowerWarn = 2.0e-4;", ...
        sprintf("config.thresholds.focus.lowerWarn = %.2e;", fWarnLower));
    configContent = strrep(configContent, ...
        "config.thresholds.focus.lowerFail = 1.5e-4;", ...
        sprintf("config.thresholds.focus.lowerFail = %.2e;", fFailLower));
    configContent = strrep(configContent, ...
        "config.thresholds.focus.upperWarn = 2.0e-3;", ...
        sprintf("config.thresholds.focus.upperWarn = %.2e;", fWarnUpper));
    configContent = strrep(configContent, ...
        "config.thresholds.focus.upperFail = 2.5e-3;", ...
        sprintf("config.thresholds.focus.upperFail = %.2e;", fFailUpper));

    % Update foreground thresholds
    configContent = strrep(configContent, ...
        "config.thresholds.foreground.lowerWarn = 0.35;", ...
        sprintf("config.thresholds.foreground.lowerWarn = %.4f;", fgWarnLower));
    configContent = strrep(configContent, ...
        "config.thresholds.foreground.lowerFail = 0.25;", ...
        sprintf("config.thresholds.foreground.lowerFail = %.4f;", fgFailLower));
    configContent = strrep(configContent, ...
        "config.thresholds.foreground.upperWarn = 0.90;", ...
        sprintf("config.thresholds.foreground.upperWarn = %.4f;", fgWarnUpper));
    configContent = strrep(configContent, ...
        "config.thresholds.foreground.upperFail = 0.95;", ...
        sprintf("config.thresholds.foreground.upperFail = %.4f;", fgFailUpper));

    % Update illumination thresholds
    configContent = strrep(configContent, ...
        "config.thresholds.illumination.lowerWarn = 0.85;", ...
        sprintf("config.thresholds.illumination.lowerWarn = %.4f;", iWarnLower));
    configContent = strrep(configContent, ...
        "config.thresholds.illumination.lowerFail = 0.75;", ...
        sprintf("config.thresholds.illumination.lowerFail = %.4f;", iFailLower));
    configContent = strrep(configContent, ...
        "config.thresholds.illumination.upperWarn = 1.40;", ...
        sprintf("config.thresholds.illumination.upperWarn = %.4f;", iWarnUpper));
    configContent = strrep(configContent, ...
        "config.thresholds.illumination.upperFail = 1.50;", ...
        sprintf("config.thresholds.illumination.upperFail = %.4f;", iFailUpper));

    % Write updated config
    fid = fopen(configPath, 'w');
    fprintf(fid, '%s', configContent);
    fclose(fid);

    fprintf('Updated defaultQualityConfig.m with new thresholds\n');
    fprintf('\n=== Threshold Computation Complete ===\n');
end