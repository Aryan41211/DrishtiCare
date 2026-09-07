function [fx, fy, r, P] = locateFoveaCnn(I)
%LOCATEFOVEACNN Locate fovea via sliding-window CNN classification
%   [fx, fy, r, P] = locateFoveaCnn(I)
%
%   Loads the trained FOV-vs-background CNN (data/analysis/day8/fovea_cnn/
%   fovea_cnn_net.mat: net) and runs it in a sliding-window grid on a
%   green-channel copy of I downscaled by S=4. Each window is classified
%   and P(class=FOV) is used; the fovea centre is the grid cell with the
%   maximum P(FOV). Crops are built in ROW-MAJOR order ((j-1)*nx+i) and the
%   score map is assembled with an explicit row/col loop (NOT reshape, which
%   scrambles non-square grids) — exactly mirroring locateOpticDiscCnn.
%
%   Honest refusal: if max P(FOV) is below acceptThr (default 0.60), returns
%   fx=[] (caller treats as "FOV NOT located"). The gate is lower than the
%   OD net's because the fovea is a subtle, featureless pit (see trainFoveaCnn
%   held-out metrics).

    PH = 192;              % CNN patch size @s4
    STRIDE = 48;           % grid stride @s4 (a quarter patch, smooth overlap)
    S = 4;                 % working scale (matches classical detector)
    acceptThr = 0.60;

    netFile = 'C:\projects\DrishtiCare\data\analysis\day8\fovea_cnn\fovea_cnn_net.mat';
    persistent net
    if isempty(net)
        T = load(netFile);
        net = T.net;
    end

    if numel(size(I))==3 && size(I,3)==3
        green = im2uint8(I(:,:,2));
    else
        green = im2uint8(I);
    end
    G = imresize(green, 1/S);
    [H,W] = size(G);

    % ---- build sliding grid inside the image (keep full patch inside) ----
    half = PH/2;
    xs = half+1 : STRIDE : W-half+1;
    ys = half+1 : STRIDE : H-half+1;
    if isempty(xs), xs = max(1, round(W/2)); end
    if isempty(ys), ys = max(1, round(H/2)); end
    nx = numel(xs); ny = numel(ys);
    crops = zeros(PH,PH,3,nx*ny,'uint8');
    for j = 1:ny
        y0 = ys(j)-half;
        for i = 1:nx
            x0 = xs(i)-half;
            crops(:,:,:,(j-1)*nx+i) = repmat(G(y0:y0+PH-1, x0:x0+PH-1), [1 1 3]);
        end
    end

    ds = augmentedImageDatastore([PH PH 3], crops, 'OutputSizeMode','resize');
    [~,sc] = classify(net, ds);
    s = sc(:,1);

    % explicit row/col layout (row-major crop index, as built above)
    P = zeros(ny, nx);
    for j = 1:ny
        P(j,:) = s((j-1)*nx+1 : j*nx)';
    end

    % ---- fovea centre = grid cell with max P(FOV) ----
    [Pmax, ii] = max(P(:));
    [py, px] = ind2sub([ny nx], ii);
    fx = xs(px) * S;
    fy = ys(py) * S;
    r = 0.015 * size(I,2);                   % modest fovea-radius fraction
    P = Pmax;

    if Pmax < acceptThr
        fx = []; fy = []; r = [];
    end
end
