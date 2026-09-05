function config = defaultQualityConfig()
% DEFAULTQUALITYCONFIG Configuration for quality assessment module
%   config = defaultQualityConfig()
%
%   Returns a struct with prototype engineering thresholds derived from
%   Day 2 empirical analysis of the APTOS 2019 dataset.
%
%   IMPORTANT: These are NOT clinically validated thresholds. They are
%   engineering prototypes based on statistical analysis of 3,662 fundus
%   images. Clinical validation requires ophthalmologist review.
%
%   Outputs:
%       config - Struct containing:
%           .thresholds   - Metric bounds (PASS/WARNING/FAIL)
%           .enabled      - Which checks are active
%           .severity     - Severity levels for each check
%           .feedback     - Human-readable failure messages
%           .version      - Configuration version
%           .derivedFrom  - Source of thresholds
%           .thresholdDocumentation - Detailed threshold derivation

    config = struct();

    %% Version tracking
    config.version = '2.0.0';
    config.derivedFrom = 'Day 3 full dataset analysis (3,662 images)';
    config.creationDate = '2026-09-03';
    config.validationStatus = 'Prototype - NOT clinically validated';

    %% Enabled checks (set false to disable a check)
    config.enabled = struct();
    config.enabled.brightness = true;
    config.enabled.contrast = true;
    config.enabled.focus = true;
    config.enabled.foreground = true;
    config.enabled.illumination = true;
    config.enabled.maskValid = true;

    %% Severity levels
    % PASS   = metric within acceptable range
    % WARNING = metric marginal, may affect downstream processing
    % FAIL   = metric outside acceptable range, image should be rejected
    config.severity = struct();
    config.severity.brightness = 'FAIL';      % Out-of-range brightness
    config.severity.contrast = 'FAIL';        % Out-of-range contrast
    config.severity.focus = 'FAIL';           % Out-of-range focus
    config.severity.foreground = 'FAIL';      % Insufficient foreground
    config.severity.illumination = 'WARNING'; % Uneven illumination (non-fatal)
    config.severity.maskValid = 'FAIL';       % Mask computation failed

    %% Thresholds (derived from Day 2 percentiles)
    % Format: [lowerWarn, lowerFail, upperWarn, upperFail]
    % WARNING range is between Warn and Fail bounds
    % FAIL is beyond Fail bounds
    %
    % Day 2 observed distributions (500-image stratified sample):
    %   brightness:      min=0.2165, P5=0.294, P25=0.361, P50=0.402, P75=0.428, P95=0.451, max=0.4644
    %   contrast:        min=0.0342, P5=0.044, P25=0.055, P50=0.063, P75=0.078, P95=0.129, max=0.1556
    %   focus_score:     min=2.16e-4, P5=3.50e-4, P25=5.52e-4, P50=7.60e-4, P75=9.90e-4, P95=1.34e-3, max=2.64e-3
    %   foreground_frac: min=0.474, P5=0.474, P25=0.474, P50=0.742, P75=0.787, P95=0.839, max=0.840
    %   illumination:    min=0.757, P5=0.95, P25=1.06, P50=1.14, P75=1.22, P95=1.28, max=1.293

    config.thresholds = struct();

    % Brightness: mean foreground intensity [0, 1]
    % Most images between 0.29 and 0.45. Very dark (<0.20) or very bright (>0.50)
    % images likely have exposure issues.
    config.thresholds.brightness.lowerWarn = 0.2145;
    config.thresholds.brightness.lowerFail = 0.1901;
    config.thresholds.brightness.upperWarn = 0.4586;
    config.thresholds.brightness.upperFail = 0.5154;

    % Contrast: std dev of foreground intensities [0, 1]
    % Most images between 0.04 and 0.13. Very low contrast (<0.03) indicates
    % washed-out or flat images.
    config.thresholds.contrast.lowerWarn = 0.0387;
    config.thresholds.contrast.lowerFail = 0.0315;
    config.thresholds.contrast.upperWarn = 0.1065;
    config.thresholds.contrast.upperFail = 0.1375;

    % Focus score: variance of Laplacian on 512x512 resized image
    % Most images between 3.5e-4 and 1.34e-3. Very low focus (<2.0e-4)
    % indicates significant blur.
    config.thresholds.focus.lowerWarn = 2.37e-04;
    config.thresholds.focus.lowerFail = 1.42e-04;
    config.thresholds.focus.upperWarn = 1.34e-03;
    config.thresholds.focus.upperFail = 1.75e-03;

    % Foreground fraction: proportion of image that is retinal tissue
    % Most images have >0.47 foreground. Very low foreground (<0.30) means
    % the image is mostly black border.
    config.thresholds.foreground.lowerWarn = 0.4736;
    config.thresholds.foreground.lowerFail = 0.2651;
    config.thresholds.foreground.upperWarn = 0.8833;
    config.thresholds.foreground.upperFail = 0.9758;

    % Illumination: ratio of center brightness to edge brightness
    % ~1.0 = uniform, >1.0 = center brighter (vignetting)
    % Most images between 0.95 and 1.28. Extreme values indicate lighting issues.
    config.thresholds.illumination.lowerWarn = 0.9200;
    config.thresholds.illumination.lowerFail = 0.8025;
    config.thresholds.illumination.upperWarn = 1.2615;
    config.thresholds.illumination.upperFail = 1.3541;

    %% Feedback messages (human-readable)
    config.feedback = struct();
    config.feedback.brightnessLow = 'Image is too dark. Consider retaking with better illumination.';
    config.feedback.brightnessHigh = 'Image is overexposed. Consider retaking with reduced flash.';
    config.feedback.contrastLow = 'Image has very low contrast. Lesions may be hard to detect.';
    config.feedback.contrastHigh = 'Image has unusually high contrast. May indicate artifacts.';
    config.feedback.focusLow = 'Image appears blurry. Please retake with steady camera.';
    config.feedback.focusHigh = 'Image has unusual sharpness. May contain noise or artifacts.';
    config.feedback.foregroundLow = 'Insufficient retinal area visible. Adjust camera position.';
    config.feedback.foregroundHigh = 'Unusually large foreground. May include non-retinal tissue.';
    config.feedback.illuminationLow = 'Uneven illumination (edges brighter than center).';
    config.feedback.illuminationHigh = 'Uneven illumination (center brighter than edges, vignetting).';
    config.feedback.maskFailed = 'Could not detect retinal foreground. Image may be corrupted.';
    config.feedback.allPass = 'Image quality is acceptable for analysis.';

    %% Detailed Threshold Documentation
    config.thresholdDocumentation = struct();

    % Brightness documentation
    config.thresholdDocumentation.brightness = struct(...
        'metric', 'Mean foreground intensity', ...
        'unit', '[0, 1] scale', ...
        'direction', 'Lower is darker, higher is brighter', ...
        'poorWhen', 'Too dark (<0.15) or too bright (>0.55)', ...
        'day2Stats', struct('min', 0.2165, 'P5', 0.294, 'P25', 0.361, ...
                           'P50', 0.402, 'P75', 0.428, 'P95', 0.451, 'max', 0.4644), ...
        'thresholdRationale', 'FAIL bounds set 10-15% outside P5-P95 range to catch extreme exposure issues', ...
        'lowerFail', 0.15, ...
        'lowerWarn', 0.20, ...
        'upperWarn', 0.50, ...
        'upperFail', 0.55);

    % Contrast documentation
    config.thresholdDocumentation.contrast = struct(...
        'metric', 'Std dev of foreground intensities', ...
        'unit', '[0, 1] scale', ...
        'direction', 'Lower is flatter, higher has more dynamic range', ...
        'poorWhen', 'Very low contrast (<0.02) indicates washed-out images', ...
        'day2Stats', struct('min', 0.0342, 'P5', 0.044, 'P25', 0.055, ...
                           'P50', 0.063, 'P75', 0.078, 'P95', 0.129, 'max', 0.1556), ...
        'thresholdRationale', 'FAIL lower bound set below P5 to catch severely degraded images', ...
        'lowerFail', 0.02, ...
        'lowerWarn', 0.03, ...
        'upperWarn', 0.20, ...
        'upperFail', 0.25);

    % Focus documentation
    config.thresholdDocumentation.focus = struct(...
        'metric', 'Variance of Laplacian on 512x512 resized image', ...
        'unit', 'Scientific notation', ...
        'direction', 'Lower is blurrier, higher is sharper', ...
        'poorWhen', 'Very low focus (<1.5e-4) indicates significant blur', ...
        'day2Stats', struct('min', 2.16e-4, 'P5', 3.50e-4, 'P25', 5.52e-4, ...
                           'P50', 7.60e-4, 'P75', 9.90e-4, 'P95', 1.34e-3, 'max', 2.64e-3), ...
        'thresholdRationale', 'FAIL lower bound set below P5 to catch severely blurred images', ...
        'lowerFail', 1.5e-4, ...
        'lowerWarn', 2.0e-4, ...
        'upperWarn', 2.0e-3, ...
        'upperFail', 2.5e-3);

    % Foreground fraction documentation
    config.thresholdDocumentation.foreground = struct(...
        'metric', 'Proportion of image that is retinal tissue', ...
        'unit', '[0, 1] scale', ...
        'direction', 'Lower means more black border, higher means more retina visible', ...
        'poorWhen', 'Very low foreground (<0.25) means image is mostly black border', ...
        'day2Stats', struct('min', 0.474, 'P5', 0.474, 'P25', 0.474, ...
                           'P50', 0.742, 'P75', 0.787, 'P95', 0.839, 'max', 0.840), ...
        'thresholdRationale', 'FAIL lower bound set conservatively to catch images with insufficient retinal area', ...
        'lowerFail', 0.25, ...
        'lowerWarn', 0.35, ...
        'upperWarn', 0.90, ...
        'upperFail', 0.95);

    % Illumination documentation
    config.thresholdDocumentation.illumination = struct(...
        'metric', 'Ratio of center brightness to edge brightness', ...
        'unit', 'Ratio (1.0 = uniform)', ...
        'direction', 'Lower means edges brighter, higher means center brighter (vignetting)', ...
        'poorWhen', 'Extreme values (<0.75 or >1.50) indicate severe lighting issues', ...
        'day2Stats', struct('min', 0.757, 'P5', 0.95, 'P25', 1.06, ...
                           'P50', 1.14, 'P75', 1.22, 'P95', 1.28, 'max', 1.293), ...
        'thresholdRationale', 'WARNING severity (non-fatal) since illumination issues rarely make images unusable', ...
        'lowerFail', 0.75, ...
        'lowerWarn', 0.85, ...
        'upperWarn', 1.40, ...
        'upperFail', 1.50);
end