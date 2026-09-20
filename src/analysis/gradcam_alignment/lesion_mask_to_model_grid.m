function mGrid = lesion_mask_to_model_grid(mask, outSize)
%LESION_MASK_TO_MODEL_GRID Binary lesion mask -> model input grid (nearest)
%   mGrid = lesion_mask_to_model_grid(mask, outSize)
%
%   mask    : HxW binary mask at the ORIGINAL image resolution
%             (IDRiD annotation tif; any nonzero value = lesion)
%   outSize : [H W] of the model input grid (must equal the size the
%             pipeline gives the image, e.g. net.Layers(1).InputSize(1:2))
%
%   The inference pipeline (predictSingleFundus.m) turns the image into the
%   model input with imresize(img, [224 224]). The mask MUST follow the
%   SAME output-size resize so that image and mask share one spatial
%   mapping (no aspect-ratio mismatch, no padding on one and stretch on the
%   other). Binary masks use 'nearest' interpolation: lesion boundaries are
%   not blurred and no averaged phantom pixels are created.
%
%   Returns a logical mask on the model grid.
    if ndims(mask) > 2
        mask = mask(:,:,1);
    end
    m = double(mask > 0);                       % binarize (any nonzero = lesion)
    mGrid = imresize(m, outSize, 'nearest') > 0.5;   % nearest-neighbour
    assert(size(mGrid,1) == outSize(1) && size(mGrid,2) == outSize(2), ...
        'lesion_mask_to_model_grid: resized mask grid size mismatch');
end
