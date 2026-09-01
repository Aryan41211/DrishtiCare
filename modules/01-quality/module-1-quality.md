# Module 1 — Image Quality Assessment & Enhancement

## Purpose

Evaluate fundus images for adequacy before analysis. Enhance borderline images. Reject ungradeable ones with actionable feedback.

## Quality Measures (Interpretable, Not Black-Box)

### 1. Field-of-View Mask
```matlab
% Threshold + circular fit
bw = imbinarize(gray, 'adaptive');
bw = imfill(bw, 'holes');
bw = bwareaopen(bw, 5000);
stats = regionprops(bw, 'Centroid', 'MajorAxisLength', 'MinorAxisLength');
% Detect circular FOV boundary
```

### 2. Focus Quality
```matlab
% Variance of Laplacian
lap = fspecial('laplacian', 0);
focusScore = std2(imfilter(gray, lap));

% Tenengrad gradient energy
[Gx, Gy] = imgradientxy(gray);
tenengrad = sum(Gx(:).^2 + Gy(:).^2);
```

### 3. Illumination
```matlab
meanIllum = mean(gray(:));
stdIllum = std(gray(:));
satFrac = sum(gray(:) > 250) / numel(gray);
darkFrac = sum(gray(:) < 5) / numel(gray);
```

### 4. Vessel Visibility
```matlab
% Fraction of image where small vessels remain detectable
% Use matched filter or vesselness response
vesselness = frangiFilter2D(double(green));
vesselVisible = sum(vesselness(:) > threshold) / numel(vesselness);
```

### 5. Anatomical Adequacy
```matlab
% Can OD and fovea be located?
odDetected = detect_optic_disc(image);
foveaDetected = detect_fovea(image, odPosition);
adequate = odDetected && foveaDetected;
```

## Three-Way Decision

| Grade | Criteria | Action |
|-------|----------|--------|
| Gradeable | All measures pass threshold | Proceed to analysis |
| Borderline | Some measures marginal | Enhance → re-score → admit if improved |
| Ungradeable | Any critical measure fails | Reject with reason code |

## Reason Codes

| Code | Meaning | Health Worker Guidance |
|------|---------|----------------------|
| FOCUS_LOW | Low focus score | Refocus the camera |
| ILLUM_LOW | Underexposed | Increase flash intensity |
| ILLUM_HIGH | Overexposed | Reduce flash intensity |
| FOV_PARTIAL | Incomplete field of view | Reposition camera |
| ANATOMY_FAIL | Cannot locate OD/fovea | Reposition for macula-centered field |
| HAZE | Central haze | Clean camera lens |

## Enhancement Pipeline

```matlab
function enhanced = enhance_image(image)
    % 1. Illumination normalization
    background = medfilt2(gray, [51 51]); % Large-kernel median
    normalized = double(image) ./ double(background);

    % 2. CLAHE on green channel
    green = image(:,:,2);
    enhanced_green = adapthisteq(green, 'ClipLimit', 0.02);

    % 3. Ben Graham preprocessing
    graham = double(image) - imclose(double(image), strel('disk', 15));

    % 4. Denoising
    denoised = imnlmfilt(enhanced_green);

    % 5. Combine
    enhanced = cat(3, denoised, denoised, denoised);
end
```

## Closed-Loop Design

```
Image → Score Quality → Borderline?
  → Yes: Enhance → Re-score → Improved? → Admit / Reject
  → No: Admit or Reject directly
```

**Critical:** Quality confidence feeds grading confidence, not just admission. A borderline image that was enhanced carries lower final confidence.

## Training Data

- **EyeQ dataset:** 28,792 images with Good/Usable/Reject labels
- **Handcrafted measures:** No training needed, physically motivated
- **Cross-check:** Handcrafted measures should agree with EyeQ labels

## Metrics

- Gradeable/Ungradeable accuracy against EyeQ ground truth
- Agreement with ophthalmologist gradeability assessment
- Enhancement impact: accuracy improvement on borderline subgroup
