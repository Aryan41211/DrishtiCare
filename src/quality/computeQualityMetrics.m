function metrics = computeQualityMetrics(img, varargin)
% COMPUTEQUALITYMETRICS Compute image quality metrics for fundus images
%   metrics = computeQualityMetrics(img)
%   metrics = computeQualityMetrics(img, 'AnalysisSize', [512 512])
%
%   Input:
%       img - RGB fundus image
%
%   Optional Parameters:
%       'AnalysisSize' - Size to resize for consistent focus analysis
%                        Default: [512 512]
%
%   Output:
%       metrics - Struct containing:
%           .width          - Image width
%           .height         - Image height
%           .aspectRatio    - Width/Height ratio
%           .brightness     - Mean intensity over retinal foreground
%           .contrast       - Std dev of intensities over foreground
%           .focusScore     - Variance of Laplacian (resized)
%           .foregroundFrac - Fraction of image that is foreground
%           .illumination   - Illumination uniformity metric
%           .maskValid      - Whether foreground mask was successful
%
%   Method:
%       - Uses retinal foreground mask to avoid black border bias
%       - Focus computed on resized image for consistency
%       - Illumination: ratio of local to global brightness variation

    % Parse optional arguments
    p = inputParser;
    addParameter(p, 'AnalysisSize', [512 512], @(x) isnumeric(x) && length(x)==2);
    parse(p, varargin{:});
    analysisSize = p.Results.AnalysisSize;

    % Initialize metrics
    metrics = struct();
    metrics.maskValid = false;

    try
        % Get image dimensions
        [h, w, c] = size(img);
        metrics.width = w;
        metrics.height = h;
        metrics.aspectRatio = w / h;

        % Create foreground mask
        [fgMask, maskValid] = createRetinalMask(img);
        metrics.maskValid = maskValid;

        % Calculate foreground fraction
        metrics.foregroundFrac = sum(fgMask(:)) / numel(fgMask);
        metrics.backgroundFrac = 1 - metrics.foregroundFrac;

        % Convert to grayscale
        if c == 3
            gray = rgb2gray(img);
        else
            gray = img;
        end

        % Convert to double
        if isa(gray, 'uint8')
            grayDouble = double(gray) / 255;
        else
            grayDouble = double(gray);
        end

        % Get foreground pixels
        fgPixels = grayDouble(fgMask);
        if isempty(fgPixels)
            fgPixels = grayDouble(:);
        end

        % 1. BRIGHTNESS (over foreground)
        metrics.brightness = mean(fgPixels);

        % 2. CONTRAST (over foreground)
        metrics.contrast = std(fgPixels);

        % 3. FOCUS SCORE (variance of Laplacian on resized image)
        % Resize for consistent comparison across different image sizes
        resizedGray = imresize(grayDouble, analysisSize);
        laplacianKernel = fspecial('laplacian', 0);
        laplacian = imfilter(resizedGray, laplacianKernel);
        metrics.focusScore = var(laplacian(:));

        % 4. ILLUMINATION UNIFORMITY
        % Compare brightness in center vs edges of foreground
        % Lower value = more uneven illumination
        if maskValid
            % Get center region (middle 50%)
            centerY = round(h/4):round(3*h/4);
            centerX = round(w/4):round(3*w/4);
            centerMask = false(h, w);
            centerMask(centerY, centerX) = true;
            centerMask = centerMask & fgMask;

            % Get edge region (outer ring)
            edgeMask = fgMask & ~centerMask;

            centerPixels = grayDouble(centerMask);
            edgePixels = grayDouble(edgeMask);

            if ~isempty(centerPixels) && ~isempty(edgePixels)
                centerMean = mean(centerPixels);
                edgeMean = mean(edgePixels);

                % Illumination uniformity: ratio of means
                % Value close to 1 = uniform
                % Value far from 1 = uneven (vignetting or center hotspot)
                if edgeMean > 0
                    metrics.illumination = centerMean / edgeMean;
                else
                    metrics.illumination = NaN;
                end
            else
                metrics.illumination = NaN;
            end
        else
            metrics.illumination = NaN;
        end

    catch
        % If anything fails, return NaN metrics
        metrics.width = NaN;
        metrics.height = NaN;
        metrics.aspectRatio = NaN;
        metrics.brightness = NaN;
        metrics.contrast = NaN;
        metrics.focusScore = NaN;
        metrics.foregroundFrac = NaN;
        metrics.backgroundFrac = NaN;
        metrics.illumination = NaN;
        metrics.maskValid = false;
    end
end
