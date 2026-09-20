function m = saliency_lesion_metrics(sal, mask, topFracPx, topFracMass)
%SALIENCY_LESION_METRICS Grad-CAM vs lesion-mask overlap metrics (one map)
%   m = saliency_lesion_metrics(sal, mask, topFracPx, topFracMass)
%
%   sal         : HxW double saliency map in [0,1] (0 = low, 1 = high
%                 activation) on the model input grid (224x224)
%   mask        : HxW binary lesion mask (logical or 0/1), same grid
%   topFracPx   : PRIMARY attention region = top fraction of PIXELS by
%                 activation rank, fixed a priori (0.20 -> the top-20%
%                 most activated pixels, ceil(N*0.20) of them)
%   topFracMass : SECONDARY region = smallest set of highest-activation
%                 pixels holding topFracMass of total saliency mass
%                 (cumulative-mass rule of the Day-8 T6 study; kept only
%                 for cross-study comparability, never for tuning)
%
%   Returned metrics (NaN-with-reason when undefined; never silently 0):
%     massIn        sum(sal(mask)) / sum(sal)            saliency mass in lesion
%     point         1/0 - max-saliency pixel inside mask  pointing game
%     iou           IoU(top-<topFracPx>-pixel attention, mask)   PRIMARY
%     iouMass       IoU(top-<topFracMass>-mass attention, mask)  secondary
%     diceMass      Dice of the same secondary region
%     nMaskPx       lesion pixels on the model grid
%     nAttnPx       attention pixels (primary rule)
%     maskAreaFrac  mask area / frame area (areal chance baseline)
%     chancePoint   probability a uniformly random pixel is a lesion pixel
%     attn          logical attention region (primary rule)
%     valid / reason  'empty_mask' | 'degenerate_saliency' | ''
%
%   No visual processing is applied; the calling pipeline passes the map
%   exactly as produced by mat2gray normalization.

    m = struct('massIn', NaN, 'point', NaN, 'iou', NaN, 'iouMass', NaN, ...
        'diceMass', NaN, 'nMaskPx', 0, 'nAttnPx', 0, 'maskAreaFrac', NaN, ...
        'chancePoint', NaN, 'attn', [], 'valid', false, 'reason', '');

    sal = double(sal);
    nPix = numel(sal);
    m.chancePoint = nnz(mask(:) > 0) / nPix;

    salSum = sum(sal(:));
    if ~isfinite(salSum) || salSum <= 0
        m.reason = 'degenerate_saliency';
        m.attn = false(size(sal));
        return;
    end

    maskLogical = mask(:) > 0;
    m.nMaskPx = nnz(maskLogical);
    m.maskAreaFrac = m.nMaskPx / nPix;

    % Attention region is defined even when the mask is empty (it is used
    % for the per-image attention/retina statistics); the lesion metrics
    % themselves stay NaN with reason 'empty_mask'.
    m.attn = attentionRegionPx(sal, topFracPx);
    m.nAttnPx = nnz(m.attn(:));

    if m.nMaskPx == 0
        m.reason = 'empty_mask';
        return;
    end

    m.massIn = sum(sal(maskLogical)) / salSum;
    [~, maxIdx] = max(sal(:));
    m.point = double(maskLogical(maxIdx));

    % PRIMARY: IoU of the top-<topFracPx>-pixel attention region vs mask
    m.iou = iouOf(m.attn(:), maskLogical);

    % SECONDARY (T6 comparability): cumulative-mass rule
    sSort = sort(sal(:), 'descend');
    cumC = cumsum(sSort);
    cutIdx = find(cumC >= topFracMass * salSum, 1);
    if isempty(cutIdx), cutIdx = nPix; end
    attnMass = sal >= sSort(cutIdx);
    m.iouMass = iouOf(attnMass(:), maskLogical);
    m.diceMass = 2 * nnz(attnMass(:) & maskLogical) / ...
        (nnz(attnMass(:)) + nnz(maskLogical));

    m.valid = true;
end

function attn = attentionRegionPx(sal, topFracPx)
%ATTENTIONREGIONPX Top-<topFracPx> fraction of pixels by activation rank.
%   The threshold rule is FIXED before evaluation and identical for every
%   image and every lesion type: keep the ceil(N*topFracPx) highest-
%   activation pixels; boundary ties are included (documented behaviour).
    nPix = numel(sal);
    k = ceil(topFracPx * nPix);
    sSort = sort(sal(:), 'descend');
    thr = sSort(k);
    attn = sal >= thr;
end

function v = iouOf(a, b)
%IOUOF Intersection-over-union of two binary index vectors.
    inter = nnz(a & b);
    uni   = nnz(a | b);
    if uni == 0
        v = NaN;
    else
        v = inter / uni;
    end
end
