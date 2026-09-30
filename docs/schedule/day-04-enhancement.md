# Day 4 — Image Enhancement (Sep 5)

## Focus
Image enhancement module

## Deliverables
- CLAHE contrast enhancement
- Illumination normalization
- Denoising applied and visually verified

## Checklist

### Morning
- [ ] Write `enhanceImage(img)` function
- [ ] Implement CLAHE via `adapthisteq`
- [ ] Implement illumination normalization

### Afternoon
- [ ] Implement denoising (median or non-local means)
- [ ] Test on 10-15 sample images
- [ ] Visually verify improvements

### Evening
- [ ] Chain quality → enhancement pipeline
- [ ] Document function signature
- [ ] Save before/after comparisons

## MATLAB Implementation

```matlab
function enhanced = enhanceImage(img)
    % Step 1: CLAHE on green channel
    green = img(:,:,2);
    enhanced_green = adapthisteq(green, 'ClipLimit', 0.02);
    
    % Step 2: Illumination normalization
    background = imgaussfilt(double(enhanced_green), 25);
    normalized = double(enhanced_green) ./ (background + eps);
    normalized = uint8(normalized * 255);
    
    % Step 3: Denoising
    denoised = medfilt2(normalized, [3 3]);
    
    % Step 4: Reconstruct RGB
    enhanced = img;
    enhanced(:,:,2) = denoised;
end
```

## Before/After Comparison

```matlab
% Show comparison
figure;
subplot(1,2,1); imshow(original); title('Original');
subplot(1,2,2); imshow(enhanced); title('Enhanced');
```

## End of Day Check
- [ ] `enhanceImage()` working
- [ ] CLAHE, illumination norm, denoising all applied
- [ ] Visual improvements verified
- [ ] Quality → enhancement chain working
- [ ] Ready for Day 5 (classifier)
