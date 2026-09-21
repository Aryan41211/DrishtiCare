function details = quality_failure_detail(checks, config)
% QUALITY_FAILURE_DETAIL Explain exactly which quality thresholds were missed
%   details = quality_failure_detail(checks, config)
%
%   Inputs:
%       checks - result.checks struct array from assessImageQuality()
%       config - defaultQualityConfig() struct
%
%   Output:
%       details - struct array (one entry per non-PASS check) with fields:
%           .metric    metric name ('focus', 'brightness', ...)
%           .value     measured value (NaN if not computable)
%           .status    'WARNING' or 'FAIL'
%           .bound     violated bound name ('lowerFail', 'upperWarn', ...)
%           .threshold configured threshold value for that bound (NaN if n/a)
%           .message   human-readable message from the gate
%
%   This is a DISPLAY/AUDIT helper only. It reads the configured thresholds;
%   it never changes them and never influences the gate decision.
%
%   ENGINEERING prototype thresholds - NOT clinically validated.

    details = struct('metric', {}, 'value', {}, 'status', {}, 'bound', {}, ...
                     'threshold', {}, 'message', {});

    if nargin < 2 || isempty(config)
        config = defaultQualityConfig();
    end

    for i = 1:numel(checks)
        c = checks(i);
        if strcmp(c.status, 'PASS')
            continue;
        end
        entry = struct('metric', c.metric, 'value', c.value, 'status', c.status, ...
                       'bound', '', 'threshold', NaN, 'message', c.message);

        if isfield(config.thresholds, c.metric) && isnumeric(c.value) && isscalar(c.value) && isfinite(c.value)
            th = config.thresholds.(c.metric);
            if isfield(th, 'lowerFail') && c.value < th.lowerFail
                entry.bound = 'lowerFail'; entry.threshold = th.lowerFail;
            elseif isfield(th, 'upperFail') && c.value > th.upperFail
                entry.bound = 'upperFail'; entry.threshold = th.upperFail;
            elseif isfield(th, 'lowerWarn') && c.value < th.lowerWarn
                entry.bound = 'lowerWarn'; entry.threshold = th.lowerWarn;
            elseif isfield(th, 'upperWarn') && c.value > th.upperWarn
                entry.bound = 'upperWarn'; entry.threshold = th.upperWarn;
            end
        end

        details(end+1) = entry; %#ok<AGROW>
    end
end
