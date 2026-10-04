function map = drishtiColormap(name)
%DRISHTICOLORMAP Centralized Grad-CAM colormap resolver.
%   map = drishtiColormap()
%   map = drishtiColormap('hot')
%
%   The no-arg call takes the theme's Grad-CAM colormap, which is parula, so
%   the turbo fallback below is reached only when a caller passes a name that
%   matches no case. Against the gate's measured budgets parula and turbo both
%   clear; parula was chosen over turbo for perceptual uniformity and
%   colour-vision-deficiency safety. hot clears conditioning but blows the
%   endpoint ceiling, and copper fails both, so neither is offered.
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
        % retained for compatibility; fails the endpoint budget
        case 'hot'
            map = hot(256);
        otherwise
            map = turbo(256);
    end
end