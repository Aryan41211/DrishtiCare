function strip = gradcamColorbarStrip(varargin)
%GRADCAMCOLORBARSTRIP Vertical colorbar strip for Grad-CAM heatmaps.
%   strip = gradcamColorbarStrip()
%   strip = gradcamColorbarStrip('Pixels', 20)
%
%   Returns a uint8 image of size [256 x px x 3] with the theme Grad-CAM
%   colormap running vertically:
%       top row    = HIGH activation  (warm, colormap index 256)
%       bottom row = LOW  activation  (cool/dark, colormap index 1)
%   so a 1 (high, on top) layout matches the value labels in the dashboard.
%
%   The strip uses the SAME drishtiColormap()/theme as every other Grad-CAM
%   surface, so the colorbar always matches the actual heatmap colors.

    p = inputParser;
    addParameter(p, 'Pixels', 20, @(x) isnumeric(x) && isscalar(x) && x > 0);
    parse(p, varargin{:});
    px = p.Results.Pixels;

    cm = drishtiColormap(drishtiTheme().gradcam.colormap);   % 256 x 3, low->high
    strip = repmat(flipud(cm), [1 px 1]);                    % row 1 = high activation
    strip = im2uint8(strip);
end