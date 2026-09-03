function createVisualizations(metricsTable, sampleInfo, dataRoot)
% CREATEVISUALIZATIONS Create all Day 2 visualizations
%   createVisualizations(metricsTable, sampleInfo, dataRoot)
%
%   Inputs:
%       metricsTable - Table of quality metrics
%       sampleInfo   - Sampling information struct
%       dataRoot     - Path to aptos2019 folder

    if nargin < 3
        script_dir = fileparts(mfilename('fullpath'));
        project_root = fileparts(fileparts(script_dir));
        dataRoot = fullfile(project_root, 'data', 'aptos2019');
    end

    trainDir = fullfile(dataRoot, 'train_images');
    classNames = sampleInfo.classNames;

    fprintf('Creating visualizations...\n');

    %% Figure 1: Class Distribution
    figure('Name', 'Day 2 - Class Distribution', 'NumberTitle', 'off', ...
           'Position', [50, 50, 800, 500]);

    classCounts = sampleInfo.classCounts;
    bar(classCounts, 'FaceColor', [0.2 0.6 0.8]);
    set(gca, 'XTickLabel', classNames);
    xtickangle(45);
    ylabel('Number of Images');
    title(sprintf('APTOS Class Distribution (Sampled: %d images)', ...
        sampleInfo.numAnalyzed));
    grid on;

    % Add count labels
    for i = 1:length(classCounts)
        text(i, classCounts(i)+5, num2str(classCounts(i)), ...
            'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    end

    fprintf('[PASS] Class distribution plot\n');

    %% Figure 2: Image Dimensions
    figure('Name', 'Day 2 - Image Dimensions', 'NumberTitle', 'off', ...
           'Position', [50, 50, 1200, 500]);

    subplot(1,3,1);
    histogram(metricsTable.width, 30, 'FaceColor', [0.2 0.6 0.8]);
    xlabel('Width (pixels)');
    ylabel('Count');
    title('Width Distribution');
    grid on;

    subplot(1,3,2);
    histogram(metricsTable.height, 30, 'FaceColor', [0.8 0.4 0.2]);
    xlabel('Height (pixels)');
    ylabel('Count');
    title('Height Distribution');
    grid on;

    subplot(1,3,3);
    histogram(metricsTable.aspect_ratio, 30, 'FaceColor', [0.4 0.7 0.4]);
    xlabel('Aspect Ratio (W/H)');
    ylabel('Count');
    title('Aspect Ratio Distribution');
    grid on;

    sgtitle('Image Dimension Analysis', 'FontSize', 14, 'FontWeight', 'bold');
    fprintf('[PASS] Dimension plots\n');

    %% Figure 3: Quality Metrics Distributions
    figure('Name', 'Day 2 - Quality Metrics', 'NumberTitle', 'off', ...
           'Position', [50, 50, 1400, 800]);

    % Brightness
    subplot(2,3,1);
    histogram(metricsTable.brightness, 30, 'FaceColor', [0.8 0.6 0.2]);
    xlabel('Brightness (Mean Intensity)');
    ylabel('Count');
    title('Brightness Distribution');
    grid on;

    % Contrast
    subplot(2,3,2);
    histogram(metricsTable.contrast, 30, 'FaceColor', [0.4 0.7 0.4]);
    xlabel('Contrast (Std Dev)');
    ylabel('Count');
    title('Contrast Distribution');
    grid on;

    % Focus Score
    subplot(2,3,3);
    histogram(metricsTable.focus_score, 30, 'FaceColor', [0.7 0.3 0.7]);
    xlabel('Focus Score (Var of Laplacian)');
    ylabel('Count');
    title('Focus Score Distribution');
    grid on;

    % Foreground Fraction
    subplot(2,3,4);
    histogram(metricsTable.foreground_fraction, 30, 'FaceColor', [0.2 0.6 0.8]);
    xlabel('Foreground Fraction');
    ylabel('Count');
    title('Retinal Foreground Coverage');
    grid on;

    % Illumination Metric
    subplot(2,3,5);
    illumValid = ~isnan(metricsTable.illumination_metric);
    histogram(metricsTable.illumination_metric(illumValid), 30, ...
        'FaceColor', [0.8 0.4 0.2]);
    xlabel('Illumination Ratio (Center/Edge)');
    ylabel('Count');
    title('Illumination Uniformity');
    grid on;

    % File Size
    subplot(2,3,6);
    histogram(metricsTable.file_size_mb, 30, 'FaceColor', [0.4 0.4 0.4]);
    xlabel('File Size (MB)');
    ylabel('Count');
    title('PNG File Size Distribution');
    grid on;

    sgtitle('Quality Metrics Distributions', 'FontSize', 14, 'FontWeight', 'bold');
    fprintf('[PASS] Quality metrics plots\n');

    %% Figure 4: Scatter plots
    figure('Name', 'Day 2 - Metric Relationships', 'NumberTitle', 'off', ...
           'Position', [50, 50, 1200, 500]);

    subplot(1,2,1);
    scatter(metricsTable.focus_score, metricsTable.brightness, ...
        20, metricsTable.diagnosis, 'filled');
    colormap(gca, jet(5));
    cb = colorbar;
    cb.Ticks = 0:4;
    cb.TickLabels = classNames;
    xlabel('Focus Score');
    ylabel('Brightness');
    title('Focus vs Brightness by Class');
    grid on;

    subplot(1,2,2);
    scatter(metricsTable.contrast, metricsTable.brightness, ...
        20, metricsTable.diagnosis, 'filled');
    colormap(gca, jet(5));
    cb = colorbar;
    cb.Ticks = 0:4;
    cb.TickLabels = classNames;
    xlabel('Contrast');
    ylabel('Brightness');
    title('Contrast vs Brightness by Class');
    grid on;

    sgtitle('Metric Relationships', 'FontSize', 14, 'FontWeight', 'bold');
    fprintf('[PASS] Scatter plots\n');

    %% Print Summary Statistics
    fprintf('\n--- Summary Statistics ---\n');
    fprintf('Width:  Min=%d, Max=%d, Mean=%.0f, Median=%d\n', ...
        min(metricsTable.width), max(metricsTable.width), ...
        mean(metricsTable.width), median(metricsTable.width));
    fprintf('Height: Min=%d, Max=%d, Mean=%.0f, Median=%d\n', ...
        min(metricsTable.height), max(metricsTable.height), ...
        mean(metricsTable.height), median(metricsTable.height));
    fprintf('Brightness: Min=%.4f, Max=%.4f, Mean=%.4f, Median=%.4f\n', ...
        min(metricsTable.brightness), max(metricsTable.brightness), ...
        mean(metricsTable.brightness), median(metricsTable.brightness));
    fprintf('Contrast: Min=%.4f, Max=%.4f, Mean=%.4f, Median=%.4f\n', ...
        min(metricsTable.contrast), max(metricsTable.contrast), ...
        mean(metricsTable.contrast), median(metricsTable.contrast));
    fprintf('Focus: Min=%.6e, Max=%.6e, Mean=%.6e, Median=%.6e\n', ...
        min(metricsTable.focus_score), max(metricsTable.focus_score), ...
        mean(metricsTable.focus_score), median(metricsTable.focus_score));
    fprintf('Foreground: Min=%.4f, Max=%.4f, Mean=%.4f, Median=%.4f\n', ...
        min(metricsTable.foreground_fraction), max(metricsTable.foreground_fraction), ...
        mean(metricsTable.foreground_fraction), median(metricsTable.foreground_fraction));
    fprintf('Background: Min=%.4f, Max=%.4f, Mean=%.4f, Median=%.4f\n', ...
        min(metricsTable.background_fraction), max(metricsTable.background_fraction), ...
        mean(metricsTable.background_fraction), median(metricsTable.background_fraction));
    illumValid = ~isnan(metricsTable.illumination_metric);
    if any(illumValid)
        fprintf('Illumination: Min=%.4f, Max=%.4f, Mean=%.4f, Median=%.4f\n', ...
            min(metricsTable.illumination_metric(illumValid)), ...
            max(metricsTable.illumination_metric(illumValid)), ...
            mean(metricsTable.illumination_metric(illumValid)), ...
            median(metricsTable.illumination_metric(illumValid)));
    end

    % Percentiles
    fprintf('\n--- Percentiles ---\n');
    metrics = {'brightness', 'contrast', 'focus_score', 'foreground_fraction'};
    metricNames = {'Brightness', 'Contrast', 'Focus', 'Foreground'};

    for m = 1:length(metrics)
        vals = metricsTable.(metrics{m});
        vals = vals(~isnan(vals));
        if ~isempty(vals)
            if strcmp(metrics{m}, 'focus_score')
                % Use scientific notation for very small focus scores
                fprintf('%s: P5=%.6e, P25=%.6e, P50=%.6e, P75=%.6e, P95=%.6e\n', ...
                    metricNames{m}, ...
                    prctile(vals, 5), prctile(vals, 25), ...
                    prctile(vals, 50), prctile(vals, 75), prctile(vals, 95));
            else
                fprintf('%s: P5=%.4f, P25=%.4f, P50=%.4f, P75=%.4f, P95=%.4f\n', ...
                    metricNames{m}, ...
                    prctile(vals, 5), prctile(vals, 25), ...
                    prctile(vals, 50), prctile(vals, 75), prctile(vals, 95));
            end
        end
    end

    fprintf('\n[OK] All visualizations created\n');
end
