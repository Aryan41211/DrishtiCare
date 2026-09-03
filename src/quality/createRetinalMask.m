function [mask, maskValid] = createRetinalMask(img)
% CREATERETINALMASK Create a simple foreground mask for fundus images
%   [mask, maskValid] = createRetinalMask(img)
%
%   Purpose:
%       Separate retinal foreground from dark background to prevent
%       black borders from biasing quality metrics.
%
%   Input:
%       img - RGB fundus image (uint8 or double)
%
%   Outputs:
%       mask     - Binary mask (true = retinal foreground)
%       maskValid - logical flag indicating if mask is usable
%
%   Method:
%       1. Convert to grayscale
%       2. Threshold to identify dark background
%       3. Find largest connected component (retina)
%       4. Fill holes and clean small artifacts
%
%   Notes:
%       This is NOT retinal segmentation. It is a simple foreground
%       detector to prevent black borders from dominating metrics.
%       The mask may fail on very unusual images; such failures are
%       recorded rather than crashing the analysis.

    maskValid = true;

    try
        % Convert to grayscale
        if size(img, 3) == 3
            gray = rgb2gray(img);
        else
            gray = img;
        end

        % Convert to double for processing
        if isa(gray, 'uint8')
            grayDouble = double(gray) / 255;
        else
            grayDouble = double(gray);
        end

        % Step 1: Simple threshold to separate dark background
        % Fundus images typically have dark borders and bright retina
        threshold = 0.15;  % Conservative threshold
        binaryMask = grayDouble > threshold;

        % Step 2: Find largest connected component
        cc = bwconncomp(binaryMask);
        if cc.NumObjects == 0
            % No foreground found - mask failed
            mask = false(size(gray));
            maskValid = false;
            return;
        end

        % Get sizes of all components
        numPixels = cellfun(@numel, cc.PixelIdxList);

        % Find largest component (should be the retina)
        [~, maxIdx] = max(numPixels);
        mask = false(size(gray));
        mask(cc.PixelIdxList{maxIdx}) = true;

        % Step 3: Fill holes in the mask
        mask = imfill(mask, 'holes');

        % Step 4: Clean small artifacts (morphological opening)
        se = strel('disk', 5);
        mask = imopen(mask, se);

        % Step 5: Validate mask
        % Check if mask covers reasonable portion of image
        coverage = sum(mask(:)) / numel(mask);
        if coverage < 0.1
            % Mask covers less than 10% - likely failed
            maskValid = false;
        elseif coverage > 0.95
            % Mask covers almost everything - might have failed
            % (fundus images typically have some black border)
            % Keep it but flag as potentially problematic
            maskValid = true;
        end

    catch
        % If anything fails, return empty mask
        if ~isempty(img)
            mask = false(size(img, 1), size(img, 2));
        else
            mask = false(1, 1);
        end
        maskValid = false;
    end
end
