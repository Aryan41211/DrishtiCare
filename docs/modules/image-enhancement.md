# Module: Image Enhancement

## Purpose
Enhance fundus images for better classification accuracy.

## Function Signature

```matlab
function enhanced = enhanceImage(img)
    % Input: RGB fundus image (raw or quality-checked)
    % Output: Enhanced RGB image
```

## Enhancement Pipeline

### Step 1: CLAHE (Contrast Limited Adaptive Histogram Equalization)
- Applied to green channel (best for retinal features)
- ClipLimit: 0.02 (conservative to avoid noise amplification)

```matlab
green = img(:,:,2);
enhanced_green = adapthisteq(green, 'ClipLimit', 0.02);
```

### Step 2: Illumination Normalization
- Background subtraction using Gaussian blur
- Kernel size: 25 (large to capture illumination pattern)

```matlab
background = imgaussfilt(double(enhanced_green), 25);
normalized = double(enhanced_green) ./ (background + eps);
normalized = uint8(normalized * 255);
```

### Step 3: Denoising
- Median filtering (3x3 kernel)
- Preserves edges while removing noise

```matlab
denoised = medfilt2(normalized, [3 3]);
```

### Step 4: Reconstruct RGB
- Replace green channel with enhanced version
- Keep red and blue channels unchanged

```matlab
enhanced = img;
enhanced(:,:,2) = denoised;
```

## Visual Verification

Always verify enhancement visually:
```matlab
figure;
subplot(1,2,1); imshow(img); title('Original');
subplot(1,2,2); imshow(enhanced); title('Enhanced');
```

## References
- Section 6.1 of 10-day roadmap
- PS requirement: "CLAHE, illumination normalization, denoising"
