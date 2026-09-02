# Module: Image Quality Assessment

## Purpose
Assess whether a fundus image is usable for DR grading.

## Function Signature

```matlab
function result = assessImageQuality(img)
    % Input: RGB fundus image
    % Output: struct with fields:
    %   .pass - logical (true/false)
    %   .reason - string (e.g., 'reject: low illumination')
    %   .blurScore - numeric
    %   .brightness - numeric
    %   .fovCoverage - numeric
```

## Checks

### 1. Blur Detection
- Method: Variance of Laplacian
- Low variance = blurry image
- Threshold: >100 (tune on your data)

```matlab
gray = rgb2gray(img);
laplacian = fspecial('laplacian');
filtered = imfilter(double(gray), laplacian);
blurScore = var(filtered(:));
```

### 2. Illumination Check
- Method: Histogram-based brightness
- Too dark (<40) or too bright (>220) = reject

```matlab
brightness = mean(gray(:));
pass = brightness > 40 && brightness < 220;
```

### 3. Field-of-View Check
- Method: Circular mask coverage
- Retina should fill >30% of frame

```matlab
mask = gray > 20; % Simple threshold
coverage = sum(mask(:)) / numel(mask);
pass = coverage > 0.3;
```

## Decision Logic

```
if blurScore < 100:
    reject: low contrast/blurry
elif brightness < 40 or > 220:
    reject: poor illumination
elif fovCoverage < 0.3:
    reject: small field of view
else:
    pass
```

## References
- Section 6.1 of 10-day roadmap
- PS requirement: "quality assessment with reason codes"
