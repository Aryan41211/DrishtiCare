function out = calibrationStats(mode, varargin)
%CALIBRATIONSTATS Canonical calibration statistics (single source of truth).
%
%   out = calibrationStats('ece',  p, y)      -> ECE (10 equal-width bins)
%   out = calibrationStats('brier', p, y)     -> Brier score
%   out = calibrationStats('nll',   p, y)     -> NLL (log-loss, clipped)
%   out = calibrationStats('fitT',  z, y)     -> temp T minimizing NLL [0.1,8]
%   out = calibrationStats('flip',  pRaw, pCal, thr) -> flip fraction @ thr
%   out = calibrationStats('scale', pRaw, T)  -> temperature-scaled probs
%   out = calibrationStats('logitc',p)        -> clipped logit z = logit(p) in [-40,40]
%
%   The definitions here are the LOCKED contract for every reported
%   calibration number in the project. Rebuilding from the committed cache
%   with the committed seed MUST reproduce the committed artifacts exactly.
%
%   ECE definition (locked):
%     - 10 equal-width bins over [0,1] (edges = linspace(0,1,11))
%     - bin membership: edges(b) < p <= edges(b+1); bin 1 additionally
%       catches p == 0 (no lower bound)
%     - ECE = sum_b (n_b/N) |mean(p)_b - mean(y)_b|
%
%   NLL definition (locked):
%     NLL = -mean( y*log(pc) + (1-y)*log(1-pc) ), pc = clip(p, 1e-15, 1-1e-15)
%
%   Brier definition (locked):
%     Brier = mean((p - y).^2)
%
%   Flip (locked):
%     flip = mean( (pRaw >= thr) ~= (pCal >= thr) )
%
%   Temperature fit (locked):
%     T = argmin_{T in [0.1, 8.0]} NLL( sigmoid(zcal/T), ycal )
%     via fminbnd, z = clip(logit(p), -40, 40) with NO pre-clip of p
%     (p exactly 1 -> z = inf -> 40; p exactly 0 -> z = -inf -> -40).

    mode = lower(mode);
    switch mode
        case 'ece'
            [p, y, nBins] = deal(varargin{1}, varargin{2}, 10);
            if nargin >= 4, nBins = varargin{3}; end
            out = computeECE(p, y, nBins);
        case 'brier'
            out = mean((varargin{1} - varargin{2}).^2);
        case 'nll'
            out = computeNLL(varargin{1}, varargin{2});
        case 'fit'
            [z, y] = deal(varargin{1}, varargin{2});
            out = fminbnd(@(T) computeTempNLL(T, z, y), 0.1, 8.0);
        case 'flip'
            [pRaw, pCal, thr] = deal(varargin{1}, varargin{2}, varargin{3});
            out = mean((pRaw >= thr) ~= (pCal >= thr));
        case 'scale'
            [pRaw, T] = deal(varargin{1}, varargin{2});
            out = 1 ./ (1 + exp(-logitc(pRaw) ./ T));
        case 'logitc'
            out = logitc(varargin{1});
        case 'sig'
            out = 1 ./ (1 + exp(-varargin{1}));
        otherwise
            error('calibrationStats:unknownMode', 'Unknown mode ''%s''.', mode);
    end
end

function ece = computeECE(p, y, nBins)
    edges = linspace(0, 1, nBins+1);
    counts = zeros(1, nBins); avgP = zeros(1, nBins); avgY = zeros(1, nBins);
    for b = 1:nBins
        mask = p > edges(b) & p <= edges(b+1);
        if b == 1, mask = mask | p <= edges(1); end
        counts(b) = sum(mask);
        if counts(b) > 0
            avgP(b) = mean(p(mask));
            avgY(b) = mean(y(mask));
        end
    end
    ece = sum(counts .* abs(avgP - avgY)) / sum(counts);
end

function nll = computeNLL(p, y)
    pc = max(min(p, 1 - 1e-15), 1e-15);
    nll = mean(-y .* log(pc) - (1 - y) .* log(1 - pc));
end

function nllt = computeTempNLL(T, z, y)
    a = z ./ T;
    p = 1 ./ (1 + exp(-a));
    nllt = -mean(y .* log(p) + (1 - y) .* log(1 - p));
end

function z = logitc(p)
    % Matches the committed scripts EXACTLY: raw logit then clip to [-40,40].
    % No pre-clip of p (p==1 -> z=inf -> 40; p==0 -> z=-inf -> -40).
    z = log(p ./ (1 - p));
    z = max(min(z, 40), -40);
end