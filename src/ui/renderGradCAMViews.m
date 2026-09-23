function [overlay, heatRGB, heatmap] = renderGradCAMViews(gradCAMMap, baseImg, varargin)
%RENDERGRADCAMVIEWS Centralized Grad-CAM rendering for dashboard + report.
%   [overlay, heatRGB, heatmap] = renderGradCAMViews(gradCAMMap, baseImg)
%   [...] = renderGradCAMViews(gradCAMMap, baseImg, 'Name', value)
%
%   gradCAMMap  raw Grad-CAM map (HxW, any range; mat2gray-normalized here)
%   baseImg     RGB fundus image (uint8 or double) the overlay blends onto
%
%   Returns:
%     overlay  - uint8 RGB: heatmap alpha-blended over the fundus, at the
%                SAME resolution as baseImg (crisp, no postage-stamp look)
%     heatRGB  - uint8 RGB: standalone false-colour heatmap (theme colormap)
%     heatmap  - double [0,1] heatmap resized to baseImg resolution
%
%   Both outputs use the SAME colormap + alpha policy from drishtiTheme() so
%   the dashboard, standalone figure and generated PDF always agree.
%
%   Name-Value overrides (all optional):
%     'Theme'     struct from drishtiTheme() (default)
%     'Colormap'  colormap name override (default from theme)
%     'Alpha'     [lo hi] activation-based opacity range (default theme)
%     'Interp'    heatmap resize interpolation (default theme 'bicubic')
%
%   Rendering rules (checked against the pipeline):
%     - heatmap normalized once with mat2gray -> [0 1] (limits from theme)
%     - colormap applied AFTER resize (never before) on 256 levels
%     - alpha is spatially modulated: low activation stays subtly tinted,
%       high activation carries the colour -> retina anatomy stays visible
%     - overlay blended as double, then cast to uint8 (no grayscale path)
%
%   PRESENTATION-ONLY. Never alters Grad-CAM values - it only decides
%   colours, opacity, interpolation and layering.

    p = inputParser;
    addParameter(p, 'Theme', [], @isstruct);
    addParameter(p, 'Colormap', '', @ischar);
    addParameter(p, 'Alpha', [], @(x) isempty(x) || (numel(x) == 2 && x(1) < x(2)));
    addParameter(p, 'Interp', '', @ischar);
    parse(p, varargin{:});

    if isempty(gradCAMMap) || ~isnumeric(gradCAMMap) || isempty(baseImg)
        overlay = [];
        heatRGB = [];
        heatmap = [];
        return;
    end

    th = drishtiTheme();
    if ~isempty(p.Results.Theme), th = p.Results.Theme; end

    cmapName = th.gradcam.colormap;
    if ~isempty(p.Results.Colormap), cmapName = p.Results.Colormap; end
    alphaLo = th.gradcam.alphaLo;
    alphaHi = th.gradcam.alphaHi;
    if ~isempty(p.Results.Alpha), alphaLo = p.Results.Alpha(1); alphaHi = p.Results.Alpha(2); end
    interp = th.gradcam.interp;
    if ~isempty(p.Results.Interp), interp = p.Results.Interp; end

    map = drishtiColormap(cmapName);                 % 256 x 3, low -> high

    hm  = mat2gray(double(gradCAMMap));              % always [0 1]
    [hr, hc]  = size(hm);
    [br, bc, ~] = size(baseImg);
    if hr ~= br || hc ~= bc
        hm = imresize(hm, [br bc], interp);
    end

    heatRGB  = im2uint8(ind2rgb(im2uint8(hm), map)); % standalone heatmap
    base     = im2double(baseImg);
    hmRGB    = ind2rgb(im2uint8(hm), map);           % double [0 1]

    alpha = alphaLo + (alphaHi - alphaLo) * hm;      % activation-modulated
    alpha = repmat(alpha, 1, 1, 3);

    overlay = im2uint8(alpha .* hmRGB + (1 - alpha) .* base);

    heatmap = hm;
end