function viewVessels()
%VIEWVESSELS Interactive viewer for the classical retinal vessel segmenter.
%   Run just:  viewVessels
%
%   A file picker opens; select any retinal image; a three-panel figure is
%   shown:
%       Original Retina  |  Vessel Map  |  Vessel Overlay
%
%   The overlay colours detected vessels green on top of the original image.
%
%   NOTE: research prototype, not a clinically validated system.

scriptDir = fileparts(mfilename('fullpath'));
addpath(scriptDir);      % make sure extractVessels is found (idempotent)

[file, pathDir] = uigetfile( ...
    {'*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff', ...
     'Retinal images (*.png,*.jpg,*.jpeg,*.bmp,*.tif,*.tiff)'}, ...
    'Select a retinal image');

if isequal(file, 0)
    fprintf('No image selected; nothing to do.\n');
    return;
end

img = imread(fullfile(pathDir, file));
[vessels, ~, fov] = extractVessels(img);

figure('Name', sprintf('Vessel Segmentation - %s', file), 'NumberTitle', 'off');

subplot(1, 3, 1);
imshow(img);
title('Original Retina');

subplot(1, 3, 2);
imshow(vessels);
title('Vessel Map');

subplot(1, 3, 3);
imshow(buildVesselOverlay(img, vessels));
title('Vessel Overlay');

frac = sum(vessels(:)) / max(sum(fov(:)), 1);
fprintf('%s: %d vessel pixels, %.1f%% of FOV area\n', file, ...
    sum(vessels(:)), 100 * frac);

end

%% ============================ LOCAL FUNCTIONS ===============================

function ov = buildVesselOverlay(img, mask)
%BUILDVESSELOVERLAY Render detected vessels (green) on top of the original.
    if size(img, 3) == 1
        ov = repmat(im2double(img), [1 1 3]);
    else
        ov = im2double(img);
    end
    r = ov(:,:,1); g = ov(:,:,2); b = ov(:,:,3);
    r(mask) = 0.15 * r(mask);
    g(mask) = 0.90;                % bright green over detected vessels
    b(mask) = 0.15 * b(mask);
    ov = cat(3, r, g, b);
    ov = im2uint8(ov);
end