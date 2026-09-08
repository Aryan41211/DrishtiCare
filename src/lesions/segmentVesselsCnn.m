function out = segmentVesselsCnn(I, opts)
%SEGMENTVESSELSCNN Dense vessel-probability map via sliding-window CNN.
%   out = segmentVesselsCnn(I, opts)
%   I: image path string, or HxWx3 RGB array, or HxW uint8 green channel.
%   Loads the trained vessel CNN (data/analysis/day8/vessel/vessel_cnn_net.mat,
%   field 'net') and runs it on the GREEN channel in a sliding 64x64 grid
%   (stride 16) at a working scale that makes the long edge ~targetLongEdge.
%   Returns out.map (HxW double, P(vessel), bilinear-upscaled to input res),
%   out.mask (logical, map>=0.5), out.green (HxW uint8), out.workingScale.
%
%   This mirrors the house sliding-window pattern (locateFoveaCnn /
%   locateOpticDiscCnn) but for a dense labeling task.

    if nargin < 2, opts = struct(); end
    if ~isfield(opts,'targetLongEdge'), opts.targetLongEdge = 512; end
    if ~isfield(opts,'PH'), opts.PH = 64; end
    if ~isfield(opts,'STRIDE'), opts.STRIDE = 8; end

    persistent net
    if isempty(net)
        T = load('C:\projects\DrishtiCare\data\analysis\day8\vessel\vessel_cnn_net.mat');
        net = T.net;
    end

    if ischar(I) || isstring(I)
        I = imread(char(I));
    end
    if numel(size(I)) == 3 && size(I,3) == 3
        green = im2uint8(I(:,:,2));
    else
        green = im2uint8(I);
    end
    [H,W] = size(green);
    s = opts.targetLongEdge / max(H,W);
    if s > 1, s = 1; end
    G = imresize(green, s);
    [h,w] = size(G);
    if h < opts.PH + 1 || w < opts.PH + 1
        G = imresize(G, [max(opts.PH+1,h), max(opts.PH+1,w)]);
        [h,w] = size(G);
    end

    half = opts.PH/2;
    xs = half+1 : opts.STRIDE : w-half+1;
    ys = half+1 : opts.STRIDE : h-half+1;
    if isempty(xs), xs = max(1, round(w/2)); end
    if isempty(ys), ys = max(1, round(h/2)); end
    nx = numel(xs); ny = numel(ys);

    crops = zeros(opts.PH, opts.PH, 3, nx*ny, 'uint8');
    for j = 1:ny
        y0 = ys(j)-half;
        for i = 1:nx
            x0 = xs(i)-half;
            crops(:,:,:,(j-1)*nx+i) = repmat(G(y0:y0+opts.PH-1, x0:x0+opts.PH-1), [1 1 3]);
        end
    end

    ds = augmentedImageDatastore([opts.PH opts.PH 3], crops, 'OutputSizeMode','resize');
    [~,sc] = classify(net, ds);
    sv = sc(:,1);                             % P(VESSEL)  Classes=['VESSEL','BG']

    % Center-pixel assignment: each window votes only at its CENTRE pixel
    % (center-based labels are how the CNN was trained), then the sparse grid
    % is nearest-centre assigned + smoothed to the working image. This
    % preserves thin vessel lines far better than stamping the whole block.
    SvGrid = reshape(sv, [nx, ny])';          % (j,i) grid; crops were row-major
    iRow = round((1:h - (half+1)) / opts.STRIDE) + 1;
    iCol = round((1:w - (half+1)) / opts.STRIDE) + 1;
    iRow = max(1, min(ny, iRow)); iCol = max(1, min(nx, iCol));
    Pw = SvGrid(iRow, iCol);
    Pw = imfilter(Pw, fspecial('gaussian', 3, 0.8), 'replicate');
    Pfull = imresize(Pw, [H W], 'bilinear');
    Pfull = min(max(Pfull, 0), 1);

    out.map = Pfull;
    out.mask = Pfull >= 0.5;
    out.green = green;
    out.workingScale = s;
    out.grid = [ny nx];
end