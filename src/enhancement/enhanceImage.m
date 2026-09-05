function [enhanced, qualityImprovement] = enhanceImage(img, varargin)
% ENHANCEIMAGE Apply advanced adaptive image enhancement to fundus images
%   enhanced = enhanceImage(img)
%   [enhanced, qualityImprovement] = enhanceImage(img)
%   enhanced = enhanceImage(img, 'Adaptive', true, 'AllChannels', true)
%
%   Input:
%       img - RGB fundus image (uint8 or double)
%
%   Optional Parameters:
%       'Adaptive'       - Use adaptive parameter selection (default: true)
%       'AllChannels'    - Enhance all RGB channels (default: true)
%       'CLAHE'          - Apply CLAHE contrast enhancement (default: true)
%       'IlluminationNorm' - Apply illumination normalization (default: true)
%       'Denoise'        - Apply denoising (default: true)
%       'GammaCorrection' - Apply gamma correction (default: true)
%       'Sharpen'        - Apply sharpening (default: true)
%       'HistogramMatch' - Apply histogram matching (default: true)
%       'VesselEnhance'  - Apply vessel enhancement (default: true)
%       'OpticDiscNorm'  - Apply optic disc normalization (default: true)
%       'NoiseAware'     - Use noise-aware processing (default: true)
%       'ClipLimit'      - CLAHE clip limit (default: auto)
%       'GaussianSigma'  - Sigma for illumination estimation (default: auto)
%       'DenoiseKernel'  - Median filter kernel size (default: auto)
%       'GammaValue'     - Gamma correction value (default: auto)
%
%   Outputs:
%       enhanced          - Enhanced RGB image
%       qualityImprovement - Struct with before/after quality metrics
%
%   Method:
%       1. Analyze image characteristics (brightness, contrast, noise)
%       2. Detect noise type and level
%       3. Select adaptive parameters based on analysis
%       4. Apply noise-aware preprocessing
%       5. Apply CLAHE contrast enhancement
%       6. Apply illumination normalization
%       7. Apply histogram matching
%       8. Apply gamma correction
%       9. Apply vessel enhancement
%       10. Apply optic disc normalization
%       11. Apply noise-aware denoising
%       12. Apply sharpening
%       13. Compute quality improvement metrics
%
%   IMPORTANT: This is an ENGINEERING enhancement module, NOT a clinical
%   image processing system. Enhancements are designed to improve
%   visibility of retinal structures for downstream analysis.

    %% Parse arguments
    p = inputParser;
    addParameter(p, 'Adaptive', true, @islogical);
    addParameter(p, 'AllChannels', true, @islogical);
    addParameter(p, 'CLAHE', true, @islogical);
    addParameter(p, 'IlluminationNorm', true, @islogical);
    addParameter(p, 'Denoise', true, @islogical);
    addParameter(p, 'GammaCorrection', true, @islogical);
    addParameter(p, 'Sharpen', true, @islogical);
    addParameter(p, 'HistogramMatch', true, @islogical);
    addParameter(p, 'VesselEnhance', true, @islogical);
    addParameter(p, 'OpticDiscNorm', true, @islogical);
    addParameter(p, 'NoiseAware', true, @islogical);
    addParameter(p, 'ClipLimit', [], @(x) isempty(x) || (isnumeric(x) && x > 0));
    addParameter(p, 'GaussianSigma', [], @(x) isempty(x) || (isnumeric(x) && x > 0));
    addParameter(p, 'DenoiseKernel', [], @(x) isempty(x) || (isnumeric(x) && x > 0));
    addParameter(p, 'GammaValue', [], @(x) isempty(x) || (isnumeric(x) && x > 0));
    parse(p, varargin{:});

    opts = struct();
    opts.adaptive = p.Results.Adaptive;
    opts.allChannels = p.Results.AllChannels;
    opts.clahe = p.Results.CLAHE;
    opts.illumNorm = p.Results.IlluminationNorm;
    opts.denoise = p.Results.Denoise;
    opts.gamma = p.Results.GammaCorrection;
    opts.sharpen = p.Results.Sharpen;
    opts.histogramMatch = p.Results.HistogramMatch;
    opts.vesselEnhance = p.Results.VesselEnhance;
    opts.opticDiscNorm = p.Results.OpticDiscNorm;
    opts.noiseAware = p.Results.NoiseAware;

    %% Convert to uint8 if needed
    if isa(img, 'double')
        if max(img(:)) <= 1.0
            img = uint8(img * 255);
        else
            img = uint8(img);
        end
    end

    %% Analyze image characteristics for adaptive parameter selection
    if opts.adaptive
        [params, noiseInfo] = analyzeImage(img);
    else
        [params, noiseInfo] = getDefaultParams();
    end

    % Override with user-specified parameters
    if ~isempty(p.Results.ClipLimit)
        params.clipLimit = p.Results.ClipLimit;
    end
    if ~isempty(p.Results.GaussianSigma)
        params.gaussianSigma = p.Results.GaussianSigma;
    end
    if ~isempty(p.Results.DenoiseKernel)
        params.denoiseKernel = p.Results.DenoiseKernel;
    end
    if ~isempty(p.Results.GammaValue)
        params.gammaValue = p.Results.GammaValue;
    end

    %% Start with original image
    enhanced = img;

    %% Noise-aware preprocessing
    if opts.noiseAware && noiseInfo.level > 0.5
        % Apply gentle denoising before enhancement for noisy images
        for ch = 1:3
            enhanced(:,:,ch) = wiener2(enhanced(:,:,ch), [5 5]);
        end
    end

    %% Determine which channels to process
    if opts.allChannels
        channels = 1:3;  % R, G, B
    else
        channels = 2;    % Green only
    end

    %% Apply enhancement to selected channels
    for ch = channels
        channel = enhanced(:,:,ch);

        % Step 1: CLAHE
        if opts.clahe
            channel = adapthisteq(channel, 'ClipLimit', params.clipLimit);
        end

        % Step 2: Illumination normalization
        if opts.illumNorm
            background = imgaussfilt(double(channel), params.gaussianSigma);
            normalized = double(channel) ./ (background + eps);
            normalized = normalized / max(normalized(:)) * 255;
            channel = uint8(normalized);
        end

        % Step 3: Histogram matching (match to ideal fundus histogram)
        if opts.histogramMatch
            channel = matchHistogram(channel, params.targetHistogram);
        end

        % Step 4: Gamma correction
        if opts.gamma
            channel = imadjust(channel, [], [], params.gammaValue);
        end

        enhanced(:,:,ch) = channel;
    end

    %% Vessel enhancement (applied to green channel)
    if opts.vesselEnhance
        enhanced = enhanceVessels(enhanced, params);
    end

    %% Optic disc normalization
    if opts.opticDiscNorm
        enhanced = normalizeOpticDisc(enhanced, params);
    end

    %% Noise-aware denoising
    if opts.denoise
        for ch = channels
            channel = enhanced(:,:,ch);
            
            % Select denoising method based on noise type
            if strcmp(noiseInfo.type, 'gaussian')
                % Gaussian noise - use Wiener filter
                channel = wiener2(channel, [params.denoiseKernel params.denoiseKernel]);
            elseif strcmp(noiseInfo.type, 'salt_pepper')
                % Salt & pepper noise - use median filter
                channel = medfilt2(channel, [params.denoiseKernel params.denoiseKernel]);
            else
                % Unknown noise - use median filter (safer)
                channel = medfilt2(channel, [params.denoiseKernel params.denoiseKernel]);
            end
            
            enhanced(:,:,ch) = channel;
        end
    end

    %% Sharpening
    if opts.sharpen
        for ch = channels
            channel = enhanced(:,:,ch);
            channel = imsharpen(channel, 'Radius', params.sharpenRadius, ...
                'Amount', params.sharpenAmount);
            enhanced(:,:,ch) = channel;
        end
    end

    %% Compute quality improvement
    if nargout > 1
        qualityImprovement = computeQualityImprovement(img, enhanced);
    end
end

%% Helper Functions

function [params, noiseInfo] = analyzeImage(img)
    % ANALYZEIMAGE Analyze image characteristics for adaptive parameters
    %   [params, noiseInfo] = analyzeImage(img)

    % Convert to grayscale for analysis
    if size(img, 3) == 3
        gray = rgb2gray(img);
    else
        gray = img;
    end

    % Compute image statistics
    meanBrightness = mean(gray(:)) / 255;
    stdBrightness = std(double(gray(:))) / 255;
    contrast = stdBrightness / (meanBrightness + eps);

    % Noise analysis
    noiseInfo = analyzeNoise(gray);

    % Adaptive parameter selection
    params = struct();

    % CLAHE clip limit: lower for low contrast, higher for high contrast
    if contrast < 0.1
        params.clipLimit = 0.01;  % Low contrast - gentle enhancement
    elseif contrast < 0.2
        params.clipLimit = 0.02;  % Medium contrast
    else
        params.clipLimit = 0.03;  % High contrast - stronger enhancement
    end

    % Gaussian sigma: larger for noisy images
    if noiseInfo.level > 1.0
        params.gaussianSigma = 30;  % Noisy - larger kernel
    elseif noiseInfo.level > 0.5
        params.gaussianSigma = 25;  % Medium noise
    else
        params.gaussianSigma = 20;  % Clean - smaller kernel
    end

    % Denoise kernel: larger for noisy images
    if noiseInfo.level > 1.0
        params.denoiseKernel = 5;   % Noisy - stronger denoising
    elseif noiseInfo.level > 0.5
        params.denoiseKernel = 3;   % Medium noise
    else
        params.denoiseKernel = 3;   % Clean - standard denoising
    end

    % Gamma value: adjust based on brightness
    if meanBrightness < 0.3
        params.gammaValue = 0.7;    % Dark - brighten
    elseif meanBrightness > 0.6
        params.gammaValue = 1.3;    % Bright - darken
    else
        params.gammaValue = 1.0;    % Normal - no adjustment
    end

    % Sharpening parameters: adjust based on noise
    if noiseInfo.level > 1.0
        params.sharpenRadius = 1;   % Noisy - gentle sharpening
        params.sharpenAmount = 0.3;
    else
        params.sharpenRadius = 1;   % Clean - standard sharpening
        params.sharpenAmount = 0.5;
    end

    % Target histogram for histogram matching (ideal fundus distribution)
    params.targetHistogram = createIdealFundusHistogram();
end

function noiseInfo = analyzeNoise(gray)
    % ANALYZENOISE Analyze noise characteristics
    %   noiseInfo = analyzeNoise(gray)

    % Compute noise estimates
    laplacian = fspecial('laplacian', 0);
    laplacianImg = imfilter(double(gray), laplacian);
    
    % Overall noise level
    noiseLevel = var(laplacianImg(:)) / 1e6;
    
    % Estimate noise type
    % Gaussian noise: smooth gradients
    % Salt & pepper: sudden intensity changes
    gradientMag = imgradient(double(gray));
    meanGrad = mean(gradientMag(:));
    stdGrad = std(gradientMag(:));
    
    % High std/mean ratio suggests salt & pepper noise
    if stdGrad / (meanGrad + eps) > 0.5
        noiseType = 'salt_pepper';
    else
        noiseType = 'gaussian';
    end
    
    noiseInfo = struct();
    noiseInfo.level = noiseLevel;
    noiseInfo.type = noiseType;
end

function targetHist = createIdealFundusHistogram()
    % CREATEIDEALFUNDUSHISTOGRAM Create ideal fundus image histogram
    %   targetHist = createIdealFundusHistogram()
    
    % Ideal fundus histogram: peak around 0.4-0.6, spread across range
    x = 0:255;
    % Gaussian centered at 100 (0.39 in normalized)
    targetHist = exp(-((x - 100).^2) / (2 * 30^2));
    % Add some spread
    targetHist = targetHist + 0.3 * exp(-((x - 150).^2) / (2 * 50^2));
    % Normalize
    targetHist = targetHist / sum(targetHist);
end

function matched = matchHistogram(channel, targetHist)
    % MATCHHISTOGRAM Match histogram to target distribution
    %   matched = matchHistogram(channel, targetHist)
    
    % Compute current histogram
    [counts, bins] = imhist(channel);
    currentHist = counts / sum(counts);
    
    % Compute CDFs
    currentCDF = cumsum(currentHist);
    targetCDF = cumsum(targetHist);
    
    % Create mapping
    mapping = zeros(256, 1);
    for i = 1:256
        % Find closest target CDF value
        [~, idx] = min(abs(targetCDF - currentCDF(i)));
        mapping(i) = idx - 1;
    end
    
    % Apply mapping
    matched = uint8(mapping(double(channel) + 1));
end

function enhanced = enhanceVessels(img, params)
    % ENHANCEVESSELS Enhance retinal blood vessels
    %   enhanced = enhanceVessels(img, params)
    
    % Work on green channel (best for vessels)
    green = img(:,:,2);
    
    % Create vessel-enhanced image using matched filtering
    % Simple approach: use morphological operations
    se = strel('disk', 1);
    tophat = imtophat(green, se);
    bothat = imbothat(green, se);
    
    % Combine top-hat and bottom-hat for vessel enhancement
    vesselEnhanced = imadd(tophat, imcomplement(bothat));
    
    % Blend with original
    alpha = 0.3;  % Blend factor
    enhancedGreen = imadd(uint8((1-alpha) * double(green)), ...
                          uint8(alpha * double(vesselEnhanced)));
    
    % Replace green channel
    enhanced = img;
    enhanced(:,:,2) = enhancedGreen;
end

function enhanced = normalizeOpticDisc(img, params)
    % NORMALIZEOPTICDISC Normalize optic disc region
    %   enhanced = normalizeOpticDisc(img, params)
    
    % Simple approach: detect bright region (likely optic disc)
    % and normalize its intensity
    gray = rgb2gray(img);
    
    % Threshold to find bright regions
    threshold = prctile(double(gray(:)), 95);
    brightMask = gray > threshold;
    
    % Dilate to smooth mask
    se = strel('disk', 10);
    brightMask = imdilate(brightMask, se);
    brightMask = imfill(brightMask, 'holes');
    
    % Compute mean intensity of bright region
    meanBright = mean(double(gray(brightMask)));
    
    % Normalize: scale bright region to match overall mean
    overallMean = mean(double(gray(:)));
    scaleFactor = overallMean / (meanBright + eps);
    
    % Apply normalization to bright regions
    enhanced = img;
    for ch = 1:3
        channel = double(enhanced(:,:,ch));
        channel(brightMask) = channel(brightMask) * scaleFactor;
        enhanced(:,:,ch) = uint8(min(channel, 255));
    end
end

function params = getDefaultParams()
    % GETDEFAULTPARAMS Get default enhancement parameters
    %   params = getDefaultParams()

    params = struct();
    params.clipLimit = 0.02;
    params.gaussianSigma = 25;
    params.denoiseKernel = 3;
    params.gammaValue = 1.0;
    params.sharpenRadius = 1;
    params.sharpenAmount = 0.5;
    params.targetHistogram = createIdealFundusHistogram();
    
    noiseInfo = struct();
    noiseInfo.level = 0.5;
    noiseInfo.type = 'gaussian';
end

function improvement = computeQualityImprovement(original, enhanced)
    % COMPUTEQUALITYIMPROVEMENT Compute quality improvement metrics
    %   improvement = computeQualityImprovement(original, enhanced)

    % Compute metrics for original
    metricsOrig = computeQualityMetrics(original);

    % Compute metrics for enhanced
    metricsEnh = computeQualityMetrics(enhanced);

    % Compute improvements
    improvement = struct();
    improvement.brightnessDelta = metricsEnh.brightness - metricsOrig.brightness;
    improvement.contrastDelta = metricsEnh.contrast - metricsOrig.contrast;
    improvement.focusDelta = metricsEnh.focusScore - metricsOrig.focusScore;
    improvement.foregroundDelta = metricsEnh.foregroundFrac - metricsOrig.foregroundFrac;

    % Compute overall improvement score
    % Positive = improvement, negative = degradation
    improvement.overallScore = ...
        improvement.brightnessDelta * 0.25 + ...
        improvement.contrastDelta * 0.20 + ...
        improvement.focusDelta * 100 * 0.30 + ...  % Scale focus for comparable magnitude
        improvement.foregroundDelta * 0.15;

    % Store raw metrics
    improvement.original = metricsOrig;
    improvement.enhanced = metricsEnh;
end