function reviewExtremeExamples(metricsTable, sampleInfo)
% REVIEWEXTREMEEXAMPLES Display images at metric extremes for visual review
%   reviewExtremeExamples(metricsTable, sampleInfo)
%
%   Purpose:
%       Show representative images from metric extremes to support
%       visual sanity checking of whether metrics make sense.
%
%   Displays examples for:
%       - Lowest/highest focus scores
%       - Lowest/highest brightness
%       - Lowest/highest contrast
%       - Lowest foreground coverage
%       - Most uneven illumination

    fprintf('=== Reviewing Metric Extremes ===\n\n');

    % Filter valid rows
    validIdx = metricsTable.mask_valid;
    validTable = metricsTable(validIdx, :);

    fprintf('Valid images for review: %d / %d\n\n', ...
        sum(validIdx), height(metricsTable));

    %% 1. Focus Score Extremes
    fprintf('--- Focus Score Extremes ---\n');
    [~, sortIdx] = sort(validTable.focus_score, 'ascend');

    numExamples = min(3, floor(length(sortIdx)/4));
    lowIdx = sortIdx(1:numExamples);
    midIdx = sortIdx(round(length(sortIdx)/2):round(length(sortIdx)/2)+numExamples-1);
    highIdx = sortIdx(end-numExamples+1:end);

    displayImageGroup(validTable, lowIdx, 'Low Focus', 'focus_score');
    displayImageGroup(validTable, midIdx, 'Median Focus', 'focus_score');
    displayImageGroup(validTable, highIdx, 'High Focus', 'focus_score');

    %% 2. Brightness Extremes
    fprintf('\n--- Brightness Extremes ---\n');
    [~, sortIdx] = sort(validTable.brightness, 'ascend');

    lowIdx = sortIdx(1:numExamples);
    midIdx = sortIdx(round(length(sortIdx)/2):round(length(sortIdx)/2)+numExamples-1);
    highIdx = sortIdx(end-numExamples+1:end);

    displayImageGroup(validTable, lowIdx, 'Low Brightness', 'brightness');
    displayImageGroup(validTable, midIdx, 'Median Brightness', 'brightness');
    displayImageGroup(validTable, highIdx, 'High Brightness', 'brightness');

    %% 3. Contrast Extremes
    fprintf('\n--- Contrast Extremes ---\n');
    [~, sortIdx] = sort(validTable.contrast, 'ascend');

    lowIdx = sortIdx(1:numExamples);
    highIdx = sortIdx(end-numExamples+1:end);

    displayImageGroup(validTable, lowIdx, 'Low Contrast', 'contrast');
    displayImageGroup(validTable, highIdx, 'High Contrast', 'contrast');

    %% 4. Foreground Coverage Extremes
    fprintf('\n--- Foreground Coverage Extremes ---\n');
    [~, sortIdx] = sort(validTable.foreground_fraction, 'ascend');

    lowIdx = sortIdx(1:numExamples);
    highIdx = sortIdx(end-numExamples+1:end);

    displayImageGroup(validTable, lowIdx, 'Low Foreground', 'foreground_fraction');
    displayImageGroup(validTable, highIdx, 'High Foreground', 'foreground_fraction');

    %% 5. Illumination Extremes
    fprintf('\n--- Illumination Extremes ---\n');
    illumValid = ~isnan(validTable.illumination_metric);
    illumTable = validTable(illumValid, :);

    if height(illumTable) >= numExamples
        [~, sortIdx] = sort(illumTable.illumination_metric, 'ascend');

        lowIdx = sortIdx(1:numExamples);
        highIdx = sortIdx(end-numExamples+1:end);

        displayImageGroup(illumTable, lowIdx, 'Uneven Illumination', 'illumination_metric');
        displayImageGroup(illumTable, highIdx, 'Uniform Illumination', 'illumination_metric');
    end

    fprintf('\n=== Review Complete ===\n');
    fprintf('Visual inspection of these examples helps validate whether\n');
    fprintf('the metrics are capturing meaningful image characteristics.\n');
end

function displayImageGroup(table, indices, titleStr, metricName)
% Display a group of images with their metrics
    fprintf('\n%s (%s):\n', titleStr, metricName);

    numShow = min(3, length(indices));
    if numShow == 0
        fprintf('  No examples available\n');
        return;
    end

    figure('Name', sprintf('Extreme Review - %s', titleStr), ...
           'NumberTitle', 'off', 'Position', [50, 50, 1200, 300]);

    for i = 1:numShow
        idx = indices(i);
        imgPath = table.image_path{idx};

        if exist(imgPath, 'file')
            img = imread(imgPath);
            subplot(1, numShow, i);
            imshow(img);

            metricVal = table.(metricName)(idx);
            diag = table.diagnosis(idx);

            % Use appropriate format based on metric type
            if strcmp(metricName, 'focus_score')
                metricStr = sprintf('%.6e', metricVal);
            elseif strcmp(metricName, 'foreground_fraction') || ...
                   strcmp(metricName, 'background_fraction')
                metricStr = sprintf('%.4f', metricVal);
            elseif strcmp(metricName, 'illumination_metric')
                metricStr = sprintf('%.4f', metricVal);
            else
                metricStr = sprintf('%.4f', metricVal);
            end

            title(sprintf('%s\nClass: %d\nMetric: %s', ...
                table.id_code{idx}, diag, metricStr), ...
                'FontSize', 8);

            fprintf('  %s: Class=%d, %s=%s\n', ...
                table.id_code{idx}, diag, metricName, metricStr);
        end
    end
end
