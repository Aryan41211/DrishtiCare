function [cx, cy, r, P] = locateOpticDiscCnn(I)
%LOCATEOPTICDISCCNN Locate optic disc via sliding-window CNN classification
%   [cx, cy, r, P] = locateOpticDiscCnn(I)
%
%   Loads the trained OD-vs-background CNN ensemble (data/analysis/day8/
%   od_cnn/od_cnn_net.mat: net = first-pass model, net2 = retrained with
%   hard negatives) and runs it in a sliding-window grid on a green-channel
%   copy of I downscaled by S=4. Each window is classified and P(class=OD)
%   is averaged across the two nets; the disc centre is the grid cell with
%   the maximum ensemble probability (verified: 9/10 IDRiD holdout within
%   300 px after fixing a coordinate-scrambling reshape bug; see docs).
%
%   Honest refusal: if the max P(OD) is below acceptThr (default 0.90),
%   returns cx=[] (caller treats as "OD NOT located").

    PH = 192;              % CNN patch size @s4
    STRIDE = 48;           % grid stride @s4 (a quarter patch, smooth overlap)
    S = 4;                 % working scale (matches classical detector)
    acceptThr = 0.90;

    netFile = 'C:\projects\DrishtiCare\data\analysis\day8\od_cnn\od_cnn_net.mat';
    persistent nets
    if isempty(nets)
        T = load(netFile);
        nets = {T.net, T.net2};
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
    s = zeros(nx*ny, 1);
    for k = 1:numel(nets)
        [~,sc] = classify(nets{k}, ds);
        s = s + sc(:,1);
    end
    s = s / numel(nets);

    % explicit row/col layout (row-major crop index, as built above)
    P = zeros(ny, nx);
    for j = 1:ny
        P(j,:) = s((j-1)*nx+1 : j*nx)';
    end

    % ---- disc centre = grid cell with max ensemble P(OD) ----
    [Pmax, ii] = max(P(:));
    [py, px] = ind2sub([ny nx], ii);
    cx = xs(px) * S;
    cy = ys(py) * S;
    r = 0.062 * size(I,2);                   % measured disc-radius fraction
    P = Pmax;

    if Pmax < acceptThr
        cx = []; cy = []; r = [];
    end
end