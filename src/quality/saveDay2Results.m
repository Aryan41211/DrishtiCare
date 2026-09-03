function saveDay2Results(metricsTable, sampleInfo, projectRoot)
% SAVEDAY2RESULTS Save Day 2 analysis results
%   saveDay2Results(metricsTable, sampleInfo, projectRoot)
%
%   Saves:
%       - quality_metrics.csv
%       - quality_metrics.mat
%       - day2_summary.mat

    if nargin < 3
        script_dir = fileparts(mfilename('fullpath'));
        projectRoot = fileparts(fileparts(script_dir));
    end

    % Create analysis directory
    analysisDir = fullfile(projectRoot, 'data', 'analysis', 'day2');
    if ~exist(analysisDir, 'dir')
        mkdir(analysisDir);
    end

    fprintf('Saving Day 2 results...\n');

    %% Save metrics table as CSV
    csvPath = fullfile(analysisDir, 'quality_metrics.csv');
    writetable(metricsTable, csvPath);
    fprintf('[OK] Saved quality_metrics.csv\n');

    %% Save metrics table as MAT
    matPath = fullfile(analysisDir, 'quality_metrics.mat');
    save(matPath, 'metricsTable', 'sampleInfo');
    fprintf('[OK] Saved quality_metrics.mat\n');

    %% Create and save summary
    summary.project = 'DrishtiCare';
    summary.day = 2;
    summary.date = datestr(now);
    summary.dataset = 'APTOS 2019';
    summary.numAnalyzed = sampleInfo.numAnalyzed;
    summary.mode = sampleInfo.mode;
    summary.classDistribution = sampleInfo.classCounts;

    % Compute summary statistics
    validTable = metricsTable(metricsTable.mask_valid, :);

    summary.stats.width.min = min(metricsTable.width);
    summary.stats.width.max = max(metricsTable.width);
    summary.stats.width.mean = mean(metricsTable.width);
    summary.stats.width.median = median(metricsTable.width);

    summary.stats.height.min = min(metricsTable.height);
    summary.stats.height.max = max(metricsTable.height);
    summary.stats.height.mean = mean(metricsTable.height);
    summary.stats.height.median = median(metricsTable.height);

    summary.stats.brightness.min = min(validTable.brightness);
    summary.stats.brightness.max = max(validTable.brightness);
    summary.stats.brightness.mean = mean(validTable.brightness);
    summary.stats.brightness.median = median(validTable.brightness);
    summary.stats.brightness.std = std(validTable.brightness);

    summary.stats.contrast.min = min(validTable.contrast);
    summary.stats.contrast.max = max(validTable.contrast);
    summary.stats.contrast.mean = mean(validTable.contrast);
    summary.stats.contrast.median = median(validTable.contrast);
    summary.stats.contrast.std = std(validTable.contrast);

    summary.stats.focus.min = min(validTable.focus_score);
    summary.stats.focus.max = max(validTable.focus_score);
    summary.stats.focus.mean = mean(validTable.focus_score);
    summary.stats.focus.median = median(validTable.focus_score);
    summary.stats.focus.std = std(validTable.focus_score);

    summary.stats.foreground.min = min(validTable.foreground_fraction);
    summary.stats.foreground.max = max(validTable.foreground_fraction);
    summary.stats.foreground.mean = mean(validTable.foreground_fraction);
    summary.stats.foreground.median = median(validTable.foreground_fraction);

    summary.stats.background.min = min(validTable.background_fraction);
    summary.stats.background.max = max(validTable.background_fraction);
    summary.stats.background.mean = mean(validTable.background_fraction);
    summary.stats.background.median = median(validTable.background_fraction);

    illumValid = ~isnan(validTable.illumination_metric);
    if any(illumValid)
        summary.stats.illumination.min = min(validTable.illumination_metric(illumValid));
        summary.stats.illumination.max = max(validTable.illumination_metric(illumValid));
        summary.stats.illumination.mean = mean(validTable.illumination_metric(illumValid));
        summary.stats.illumination.median = median(validTable.illumination_metric(illumValid));
        summary.stats.illumination.std = std(validTable.illumination_metric(illumValid));
    end

    % Percentiles
    summary.percentiles.brightness = prctile(validTable.brightness, [5 25 50 75 95]);
    summary.percentiles.contrast = prctile(validTable.contrast, [5 25 50 75 95]);
    summary.percentiles.focus = prctile(validTable.focus_score, [5 25 50 75 95]);
    summary.percentiles.foreground = prctile(validTable.foreground_fraction, [5 25 50 75 95]);

    summaryPath = fullfile(analysisDir, 'day2_summary.mat');
    save(summaryPath, 'summary');
    fprintf('[OK] Saved day2_summary.mat\n');

    %% Print save locations
    fprintf('\nResults saved to:\n');
    fprintf('  %s\n', analysisDir);
    fprintf('    - quality_metrics.csv\n');
    fprintf('    - quality_metrics.mat\n');
    fprintf('    - day2_summary.mat\n');

    %% Check .gitignore
    gitignorePath = fullfile(projectRoot, '.gitignore');
    if exist(gitignorePath, 'file')
        gitignoreContent = fileread(gitignorePath);
        if contains(gitignoreContent, 'data/analysis')
            fprintf('\n[INFO] data/analysis/ is in .gitignore (will not be committed)\n');
        else
            fprintf('\n[NOTE] data/analysis/ is NOT in .gitignore\n');
            fprintf('       Generated analysis files may be committed if you git add.\n');
        end
    end
end
