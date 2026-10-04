function map = drishtiColormap(name)
%DRISHTICOLORMAP Centralized Grad-CAM colormap resolver.
%   map = drishtiColormap()
%   map = drishtiColormap('parula')
%
%   One place decides what colormap every Grad-CAM surface uses (dashboard
%   heatmap, overlay, colorbar and generated report), so no two panels can
%   drift onto different colors. Defaults to the theme Grad-CAM colormap.
%
%   Returns a 256x3 double map from LOW activation (row 1) to HIGH
%   activation (row 256): low = cool/dark, high = warm/bright.
%
%   Presentation-only. Never alters Grad-CAM values.

    if nargin < 1 || isempty(name)
        name = drishtiTheme().gradcam.colormap;
    end

    switch lower(name)
        case 'parula'
            map = parula(256);
        case 'hot'
            map = hot(256);
        case 'bone'
            map = bone(256);
        case 'copper'
            map = copper(256);
        otherwise
            map = turbo(256);
    end
end