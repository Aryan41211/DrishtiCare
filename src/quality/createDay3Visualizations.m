function createDay3Visualizations()
% CREATEDAY3VISUALIZATIONS Create quality distribution plots for Day 3
%   createDay3Visualizations()
%
%   Reads the full batch evaluation results and creates visualization
%   plots showing quality metric distributions and threshold boundaries.
%
%   Output:
%       - Figure 1: Quality metric histograms with threshold lines
%       - Figure 2: Quality status distribution by diagnosis
%       - Figure 3: Failure mode breakdown

    %% Setup
    script_dir = fileparts(mfilename('fullpath'));
    project_root = fileparts(fileparts(script_dir));
    cd(project_root);

    addpath(fullfile(project_root, 'src', 'quality'));
    addpath(fullfile(project_root, 'data', 'analysis', 'day3'));

    fprintf('============================================\n');
    fprintf('   Creating Day 3 Quality Visualizations    \n');
    fprintf('============================================\n\n');

    %% Load data
    csvPath = fullfile(project_root, 'data', 'analysis', 'day3', 'quality_assessment_results.csv');
    results = readtable(csvPath);
    config = defaultQualityConfig();

    fprintf('Loaded %d images\n', height(results));

    %% Figure 1: Quality Metric Histograms
    figure('Name', 'Day 3 Quality Metrics Distribution', 'NumberTitle', 'off', ...
        'Position', [100, 100, 1200, 800]);

    metrics = {'brightness', 'contrast', 'focus_score', 'foreground_fraction'};
    metricNames = {'Brightness', 'Contrast', 'Focus Score', 'Foreground Fraction'};
    thresholds = {'brightness', 'contrast', 'focus', 'foreground'};

    for i = 1:4
        subplot(2, 2, i);

        values = results.(metrics{i});
        values = values(~isnan(values));

        % Create histogram
        histogram(values, 50, 'FaceColor', [0.2, 0.4, 0.8], 'FaceAlpha', 0.7);
        hold on;

        % Add threshold lines
        thresh = config.thresholds.(thresholds{i});
        xline(thresh.lowerFail, 'r--', 'LineWidth', 2, 'Label', 'FAIL');
        xline(thresh.lowerWarn, 'y--', 'LineWidth', 1.5, 'Label', 'WARN');
        xline(thresh.upperWarn, 'y--', 'LineWidth', 1.5);
        xline(thresh.upperFail, 'r--', 'LineWidth', 2);

        % Add mean and median lines
        xline(mean(values), 'g-', 'LineWidth', 2, 'Label', 'Mean');
        xline(median(values), 'm-', 'LineWidth', 1.5, 'Label', 'Median');

        xlabel(metricNames{i});
        ylabel('Count');
        title(sprintf('%s Distribution (n=%d)', metricNames{i}, length(values)));
        legend('Histogram', 'Location', 'best');
        hold off;
    end

    sgtitle('Day 3 Quality Metric Distributions with Threshold Boundaries');

    % Save figure
    figPath = fullfile(project_root, 'data', 'analysis', 'day3', 'quality_distributions.png');
    saveas(gcf, figPath);
    fprintf('Saved: %s\n', figPath);

    %% Figure 2: Quality Status by Diagnosis
    figure('Name', 'Quality Status by Diagnosis', 'NumberTitle', 'off', ...
        'Position', [100, 100, 800, 600]);

    classNames = {'0-NoDR', '1-Mild', '2-Moderate', '3-Severe', '4-Prolif'};
    statusNames = {'PASS', 'WARNING', 'FAIL'};
    colors = [0.2, 0.8, 0.2; 1.0, 0.8, 0.0; 0.8, 0.2, 0.2];  % Green, Yellow, Red

    % Count by diagnosis and status
    counts = zeros(5, 3);
    for d = 0:4
        diagMask = results.diagnosis == d;
        for s = 1:3
            counts(d+1, s) = sum(strcmp(results.quality_status(diagMask), statusNames{s}));
        end
    end

    % Create stacked bar chart
    b = bar(counts, 'stacked');
    for s = 1:3
        b(s).FaceColor = colors(s, :);
    end

    xlabel('DR Grade');
    ylabel('Number of Images');
    title('Quality Status Distribution by DR Grade');
    xticklabels(classNames);
    legend(statusNames, 'Location', 'best');

    % Save figure
    figPath = fullfile(project_root, 'data', 'analysis', 'day3', 'status_by_diagnosis.png');
    saveas(gcf, figPath);
    fprintf('Saved: %s\n', figPath);

    %% Figure 3: Failure Mode Breakdown
    figure('Name', 'Failure Mode Breakdown', 'NumberTitle', 'off', ...
        'Position', [100, 100, 800, 600]);

    % Extract failure reasons
    failMask = strcmp(results.quality_status, 'FAIL');
    failReasons = results.failure_reason(failMask);

    % Parse failure reasons
    reasonCounts = struct();
    for i = 1:length(failReasons)
        reasons = strsplit(failReasons{i}, '; ');
        for j = 1:length(reasons)
            reason = strtrim(reasons{j});
            if ~isempty(reason)
                % Simplify reason (use valid MATLAB field names)
                if contains(reason, 'blurry')
                    key = 'Blur';
                elseif contains(reason, 'overexposed')
                    key = 'Overexposed';
                elseif contains(reason, 'too dark')
                    key = 'Underexposed';
                elseif contains(reason, 'foreground detection')
                    key = 'MaskFailed';
                elseif contains(reason, 'foreground')
                    key = 'LowForeground';
                elseif contains(reason, 'contrast')
                    key = 'LowContrast';
                elseif contains(reason, 'illumination')
                    key = 'UnevenIllumination';
                elseif contains(reason, 'sharpness')
                    key = 'HighSharpness';
                else
                    key = 'Other';
                end

                if isfield(reasonCounts, key)
                    reasonCounts.(key) = reasonCounts.(key) + 1;
                else
                    reasonCounts.(key) = 1;
                end
            end
        end
    end

    % Convert to arrays
    reasonNames = fieldnames(reasonCounts);
    reasonValues = zeros(length(reasonNames), 1);
    for i = 1:length(reasonNames)
        reasonValues(i) = reasonCounts.(reasonNames{i});
    end

    % Create readable labels
    readableNames = cell(length(reasonNames), 1);
    for i = 1:length(reasonNames)
        switch reasonNames{i}
            case 'Blur'
                readableNames{i} = 'Blur';
            case 'Overexposed'
                readableNames{i} = 'Overexposure';
            case 'Underexposed'
                readableNames{i} = 'Underexposure';
            case 'MaskFailed'
                readableNames{i} = 'Mask Failure';
            case 'LowForeground'
                readableNames{i} = 'Low Foreground';
            case 'LowContrast'
                readableNames{i} = 'Low Contrast';
            case 'UnevenIllumination'
                readableNames{i} = 'Uneven Illumination';
            case 'HighSharpness'
                readableNames{i} = 'High Sharpness';
            otherwise
                readableNames{i} = 'Other';
        end
    end
    reasonNames = readableNames;

    % Sort by count
    [reasonValues, sortIdx] = sort(reasonValues, 'descend');
    reasonNames = reasonNames(sortIdx);

    % Create bar chart
    barh(reasonValues, 'FaceColor', [0.8, 0.4, 0.2]);
    yticks(1:length(reasonNames));
    yticklabels(reasonNames);
    xlabel('Count');
    title('Failure Mode Breakdown (Top Reasons)');
    grid on;

    % Save figure
    figPath = fullfile(project_root, 'data', 'analysis', 'day3', 'failure_breakdown.png');
    saveas(gcf, figPath);
    fprintf('Saved: %s\n', figPath);

    %% Figure 4: Quality Score Distribution
    figure('Name', 'Quality Score Distribution', 'NumberTitle', 'off', ...
        'Position', [100, 100, 800, 600]);

    histogram(results.quality_score, 20, 'FaceColor', [0.4, 0.6, 0.8], 'FaceAlpha', 0.7);
    hold on;

    % Add status boundaries
    xline(0.5, 'y--', 'LineWidth', 2, 'Label', 'PASS/WARN Boundary');
    xline(0.2, 'r--', 'LineWidth', 2, 'Label', 'WARN/FAIL Boundary');

    xlabel('Quality Score');
    ylabel('Count');
    title('Quality Score Distribution');
    legend('Histogram', 'Location', 'best');
    hold off;

    % Save figure
    figPath = fullfile(project_root, 'data', 'analysis', 'day3', 'quality_score_dist.png');
    saveas(gcf, figPath);
    fprintf('Saved: %s\n', figPath);

    fprintf('\n=== Visualizations Complete ===\n');
end