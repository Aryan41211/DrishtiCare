function [result, metrics] = assessImageQuality(img, varargin)
% ASSESSIMAGEQUALITY Evaluate image quality against engineering thresholds
%   result = assessImageQuality(img)
%   result = assessImageQuality(img, 'Config', config)
%   [result, metrics] = assessImageQuality(img)
%
%   Input:
%       img - RGB fundus image (uint8 or double)
%
%   Optional Parameters:
%       'Config' - Quality config struct (default: defaultQualityConfig())
%
%   Outputs:
%       result  - Struct containing:
%           .overall       - 'PASS', 'WARNING', or 'FAIL'
%           .checks        - Per-metric results (struct array)
%           .numPass       - Count of metrics passing
%           .numWarning    - Count of metrics with warnings
%           .numFail       - Count of metrics failing
%           .failureReasons - Cell array of human-readable failure reasons
%           .recaptureAdvice - Overall recapture guidance
%       metrics - Raw quality metrics from computeQualityMetrics()
%
%   Method:
%       1. Compute quality metrics using Day 2 functions
%       2. Compare each metric against configured thresholds
%       3. Classify as PASS/WARNING/FAIL per metric
%       4. Aggregate into overall decision
%       5. Generate human-readable feedback
%
%   IMPORTANT: This is an ENGINEERING quality gate, NOT a clinical
%   diagnostic system. Thresholds are prototype values derived from
%   statistical analysis of the APTOS dataset. Clinical validation
%   requires ophthalmologist review.

    %% Parse arguments
    p = inputParser;
    addParameter(p, 'Config', [], @(x) isstruct(x));
    parse(p, varargin{:});
    config = p.Results.Config;

    if isempty(config)
        config = defaultQualityConfig();
    end

    %% Compute quality metrics
    metrics = computeQualityMetrics(img);

    %% Initialize result
    result = struct();
    result.overall = 'PASS';
    result.qualityScore = 1.0;  % 1.0 = perfect, 0.0 = worst
    result.checks = struct('metric', {}, 'value', {}, 'status', {}, 'message', {}, 'inRange', {});
    result.numPass = 0;
    result.numWarning = 0;
    result.numFail = 0;
    result.failureReasons = {};
    result.failureCategories = {};  % Simplified failure categories
    result.recaptureAdvice = '';

    %% Evaluate each enabled check
    checks = {};

    % 1. Mask validity check
    if config.enabled.maskValid
        check = evaluateCheck('maskValid', metrics.maskValid, config);
        checks{end+1} = check;
    end

    % 2. Brightness check
    if config.enabled.brightness
        check = evaluateRangeCheck('brightness', metrics.brightness, ...
            config.thresholds.brightness, config.feedback, 'brightness');
        checks{end+1} = check;
    end

    % 3. Contrast check
    if config.enabled.contrast
        check = evaluateRangeCheck('contrast', metrics.contrast, ...
            config.thresholds.contrast, config.feedback, 'contrast');
        checks{end+1} = check;
    end

    % 4. Focus check
    if config.enabled.focus
        check = evaluateRangeCheck('focus', metrics.focusScore, ...
            config.thresholds.focus, config.feedback, 'focus');
        checks{end+1} = check;
    end

    % 5. Foreground fraction check
    if config.enabled.foreground
        check = evaluateRangeCheck('foreground', metrics.foregroundFrac, ...
            config.thresholds.foreground, config.feedback, 'foreground');
        checks{end+1} = check;
    end

    % 6. Illumination check
    if config.enabled.illumination
        check = evaluateRangeCheck('illumination', metrics.illumination, ...
            config.thresholds.illumination, config.feedback, 'illumination');
        checks{end+1} = check;
    end

    %% Aggregate results
    for i = 1:length(checks)
        check = checks{i};
        result.checks(end+1) = check;

        switch check.status
            case 'PASS'
                result.numPass = result.numPass + 1;
            case 'WARNING'
                result.numWarning = result.numWarning + 1;
            case 'FAIL'
                result.numFail = result.numFail + 1;
                result.failureReasons{end+1} = check.message;
        end
    end

    %% Determine overall status
    if result.numFail > 0
        result.overall = 'FAIL';
    elseif result.numWarning > 0
        result.overall = 'WARNING';
    else
        result.overall = 'PASS';
    end

    %% Categorize failures
    result.failureCategories = categorizeFailures(result.failureReasons);

    %% Calculate weighted quality score (0.0 to 1.0)
    % Weights reflect relative importance of each metric
    weights = struct();
    weights.focus = 0.30;        % Most critical for DR screening
    weights.brightness = 0.25;   % Exposure affects lesion visibility
    weights.contrast = 0.20;     % Contrast affects feature detection
    weights.foreground = 0.15;   % Retinal coverage affects field of view
    weights.illumination = 0.10; % Uniformity affects consistency
    weights.maskValid = 0.00;    % Binary check, doesn't contribute to score

    weightedScore = 0.0;
    totalWeight = 0.0;

    for i = 1:length(checks)
        check = checks{i};
        if isfield(weights, check.metric)
            w = weights.(check.metric);
            totalWeight = totalWeight + w;

            % Score: PASS = 1.0, WARNING = 0.5, FAIL = 0.0
            switch check.status
                case 'PASS'
                    weightedScore = weightedScore + w * 1.0;
                case 'WARNING'
                    weightedScore = weightedScore + w * 0.5;
                case 'FAIL'
                    weightedScore = weightedScore + w * 0.0;
            end
        end
    end

    if totalWeight > 0
        result.qualityScore = weightedScore / totalWeight;
    else
        result.qualityScore = 0.0;
    end

    %% Generate recapture advice
    if result.numFail > 0
        result.recaptureAdvice = 'Image quality is insufficient for reliable analysis. ';
        
        % Extract metric names from checks
        metricNames = cellfun(@(c) c.metric, checks, 'UniformOutput', false);
        
        if any(strcmp(metricNames, 'focus'))
            result.recaptureAdvice = [result.recaptureAdvice, ...
                'Check camera focus and patient positioning. '];
        end
        if any(strcmp(metricNames, 'brightness'))
            result.recaptureAdvice = [result.recaptureAdvice, ...
                'Check camera exposure settings. '];
        end
        if any(strcmp(metricNames, 'foreground'))
            result.recaptureAdvice = [result.recaptureAdvice, ...
                'Ensure the retina fills most of the image frame. '];
        end
    elseif result.numWarning > 0
        result.recaptureAdvice = 'Image is usable but may benefit from recapture. ';
    else
        result.recaptureAdvice = config.feedback.allPass;
    end
end

%% Helper functions

function check = evaluateCheck(metricName, value, config)
    check = struct();
    check.metric = metricName;
    check.value = value;

    if islogical(value)
        if value
            check.status = 'PASS';
            check.message = sprintf('%s: OK', metricName);
            check.inRange = true;
        else
            check.status = config.severity.maskValid;
            check.message = config.feedback.maskFailed;
            check.inRange = false;
        end
    end
end

function check = evaluateRangeCheck(metricName, value, thresholds, feedback, prefix)
    check = struct();
    check.metric = metricName;
    check.value = value;

    if isnan(value)
        check.status = 'FAIL';
        check.message = sprintf('%s: Could not compute metric', metricName);
        check.inRange = false;
        return;
    end

    % Determine status based on thresholds
    % Format: [lowerWarn, lowerFail, upperWarn, upperFail]
    lowerWarn = thresholds.lowerWarn;
    lowerFail = thresholds.lowerFail;
    upperWarn = thresholds.upperWarn;
    upperFail = thresholds.upperFail;

    if value < lowerFail || value > upperFail
        check.status = 'FAIL';
        check.inRange = false;
        if value < lowerFail
            check.message = feedback.([prefix, 'Low']);
        else
            check.message = feedback.([prefix, 'High']);
        end
    elseif value < lowerWarn || value > upperWarn
        check.status = 'WARNING';
        check.inRange = false;
        if value < lowerWarn
            check.message = feedback.([prefix, 'Low']);
        else
            check.message = feedback.([prefix, 'High']);
        end
    else
        check.status = 'PASS';
        check.message = sprintf('%s: OK (%.4f)', metricName, value);
        check.inRange = true;
    end
end

function categories = categorizeFailures(failureReasons)
    % CATEGORIZEFAILURES Group failure reasons into simplified categories
    %   categories = categorizeFailures(failureReasons)
    %
    %   Input:
    %       failureReasons - Cell array of detailed failure messages
    %
    %   Output:
    %       categories - Cell array of simplified failure categories

    categories = {};

    for i = 1:length(failureReasons)
        reason = failureReasons{i};

        % Categorize based on keywords
        if contains(reason, 'blurry', 'IgnoreCase', true)
            categories{end+1} = 'Blur';
        elseif contains(reason, 'overexposed', 'IgnoreCase', true)
            categories{end+1} = 'Overexposure';
        elseif contains(reason, 'too dark', 'IgnoreCase', true)
            categories{end+1} = 'Underexposure';
        elseif contains(reason, 'foreground', 'IgnoreCase', true) && ...
               contains(reason, 'detection', 'IgnoreCase', true)
            categories{end+1} = 'Mask Failure';
        elseif contains(reason, 'foreground', 'IgnoreCase', true)
            categories{end+1} = 'Low Foreground';
        elseif contains(reason, 'contrast', 'IgnoreCase', true)
            categories{end+1} = 'Low Contrast';
        elseif contains(reason, 'illumination', 'IgnoreCase', true)
            categories{end+1} = 'Uneven Illumination';
        elseif contains(reason, 'sharpness', 'IgnoreCase', true)
            categories{end+1} = 'High Sharpness';
        else
            categories{end+1} = 'Other';
        end
    end

    % Remove duplicates
    categories = unique(categories);
end