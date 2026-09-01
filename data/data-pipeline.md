# Data Pipeline — Preprocessing and Augmentation

## Ingestion

```
Raw Images → Standardize Format → Resize/Crop → FOV Detection → Green Channel Extraction
```

## Preprocessing Pipeline

```matlab
function processed = preprocess_fundus(image)
    % 1. FOV crop
    fovMask = detect_fov(image);
    image = image .* uint8(fovMask);

    % 2. Illumination normalization
    green = image(:,:,2);
    background = medfilt2(double(green), [51 51]);
    normalized = double(green) ./ (background + eps);

    % 3. CLAHE
    enhanced = adapthisteq(uint8(normalized * 255), 'ClipLimit', 0.02);

    % 4. Ben Graham preprocessing
    blurred = imgaussfilt(double(enhanced), 15);
    graham = double(enhanced) - blurred + 128;

    % 5. Denoising
    denoised = imnlmfilt(uint8(graham));

    % 6. Normalize to [0, 1]
    processed = double(denoised) / 255;
end
```

## Patch Extraction

- Lesion detection: 32×32 or 48×48 patches
- Vessel segmentation: 48×48 or 64×64 patches
- Grading: Full image resized to 224×224

## Augmentation

- Geometric: rotation, flip, crop, elastic deformation
- Photometric: brightness, contrast, noise, color jitter, gamma
- Medical-specific: Ben Graham variations, CLAHE variations, illumination artifacts

## Resolution Matching

Critical: DRIVE (565×584) → IDRiD (4288×2848). Match on vessel calibre, not raw dimensions.
