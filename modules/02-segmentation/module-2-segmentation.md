# Module 2 — Retinal Structure Segmentation

## Purpose

Extract clinically relevant structures: optic disc, fovea, vessels, and lesions (MA, HE, EX, SE).

## 2.1 Optic Disc Detection

**Method:** Brightest large region + vessel convergence point (no training data needed)

```matlab
% 1. Find bright regions
bw = imbinarize(green, 'global');
bw = bwareaopen(bw, 1000);

% 2. Filter by circularity
stats = regionprops(bw, 'Centroid', 'Area', 'Eccentricity', 'BoundingBox');
circular = stats([stats.Eccentricity] < 0.8);

% 3. Vessel convergence
[~, vesselMask] = segment_vessels(green);
distanceTransform = bwdist(~vesselMask);
% OD is where vessels converge

% 4. Hough circle fit
[centers, radii] = imfindcircles(green, [100 300], 'ObjectPolarity', 'bright');
```

**Validation:** IDRiD provides OD centers on all 516 images. Report error in disc-diameter units.

## 2.2 Fovea Localization

**Method:** ~2-2.5 disc diameters temporal to OD, darkest avascular region

```matlab
% Search region constrained by OD position
searchRadius = 2.5 * odRadius;
searchCenter = odCenter + [searchRadius, 0]; % Temporal direction

% Find darkest region in search window
window = gray(searchCenter(2)-R:searchCenter(2)+R, searchCenter(1)-R:searchCenter(1)+R);
[~, minIdx] = min(window(:));
[foveaY, foveaX] = ind2sub(size(window), minIdx);
```

**Validation:** IDRiD provides fovea coordinates. Report error in disc-diameter units.

## 2.3 Vessel Segmentation

**Architecture:** Patch-based U-Net on CLAHE-enhanced green channel

```matlab
% Training data
% DRIVE: 20 training images (565×584)
% + STARE: 20 images (700×605)
% + CHASE_DB1: 28 images (999×960)
% + HRF: 45 images (3504×2336)

% Patch extraction: 48×48 or 64×64
% → 20 images become tens of thousands of patches

% CRITICAL: Match vessel calibre across datasets
% DRIVE is 565×584, IDRiD is 4288×2848
% Resample so pixel width matches, not raw dimensions
```

**Report:** Standard DRIVE test metrics (accuracy, AUC, sensitivity, specificity)

**Downstream purposes:**
1. Suppress MA false positives (vessel crossings = dominant confounder)
2. Provide morphology features for IRMA/venous-beading proxies
3. Support neovascularisation surrogate

## 2.4 Microaneurysm Detection

**Architecture:** Two-stage candidate-then-classify

### Stage 1: Candidate Extraction (High Recall)
```matlab
% Morphological top-hat with multi-orientation structuring elements
% Removes elongated vessels, preserves small round blobs
for theta = 0:30:150
    se = strel('line', 15, theta);
    tophat(:,:,k) = imtophat(inverted_green, se);
    k = k + 1;
end
candidates = max(tophat, [], 3);

% Or: matched Gaussian filtering
sigma_range = 1:0.5:3;
for s = sigma_range
    h = fspecial('gaussian', [20 20], s);
    filtered(:,:,k) = imfilter(inverted_green, h);
end
```

### Stage 2: Candidate Classification (Restore Precision)
```matlab
% Extract features per candidate
features = [intensityContrast, shapeCompactness, area, ...
            distanceToNearestVessel, localBackgroundStd];

% Classify: gradient-boosted trees or small CNN on 32×32 patches
mdl = fitcensemble(X_train, y_train, 'Method', 'Bag');
```

### Reporting: FROC Curve
- Sensitivity vs. false positives per image (FPI)
- Clinically relevant operating point: 1-2 FPI
- Report FROC score (harmonic mean at 1, 2, 4, 8 FPI)

**Set expectations:** MA sensitivity substantially below EX sensitivity is a robust literature finding.

## 2.5 Hemorrhage Detection

**Same candidate pipeline as MA**, discriminated by:
- Size/area (larger than MA)
- Elongation (flame-shaped = elongated)
- Subclassification: dot / blot / flame

**Critical:** Count per retinal quadrant for 4-2-1 rule evaluation

```matlab
% Divide image into quadrants using OD and fovea as reference
quadrantCounts = zeros(1, 4);
for i = 1:numHemorrhages
    q = getQuadrant(lesionCenters(i,:), odCenter, foveaCenter);
    quadrantCounts(q) = quadrantCounts(q) + 1;
end

% Evaluate 4-2-1 rule
rule_4 = all(quadrantCounts > 20); % >20 hemorrhages in each of 4 quadrants
```

## 2.6 Exudate Detection

**Method:** Bright-lesion candidates via morphological reconstruction

```matlab
% 1. Bright candidate extraction
reconstructed = imreconstruct(imopen(luminance, strel('disk', 15)), luminance);
candidates = luminance - reconstructed;

% 2. EXCLUDE OPTIC DISC (classic false-positive source)
odMask = create_od_mask(odCenter, odRadius);
candidates(odMask) = 0;

% 3. Separate hard vs soft by boundary gradient
boundaryGradient = imgradient(boundaryMask);
hardEX = boundaryGradient > threshold; % Sharp margins
softEX = boundaryGradient <= threshold; % Fuzzy margins (cotton-wool spots)

% 4. Distance to fovea for DME grading
distToFovea = min(sqrt(sum((exudateCentroids - foveaCenter).^2, 2)));
dmeGrade = assign_dme_grade(distToFovea, odRadius);
```

## 2.7 Neovascularisation — The Honest Workaround

**No dataset provides NV annotations.** Do not fake it.

**Surrogate features:**
- Vessel tortuosity
- Fractal dimension of vessel network
- Vessel density in peripapillary region
- Presence of large preretinal/vitreous hemorrhage

**State plainly:** *"No public pixel-level NV annotations exist. System routes suspected proliferative cases to urgent human review based on surrogate vascular features."*

This is a safety-first framing that directly answers the PS's "human-in-the-loop" requirement.

## Output Feature Vector

```
[
  ma_count_total, ma_count_per_quadrant(4),
  he_count_total, he_count_per_quadrant(4), he_subtypes(3),
  ex_total_area, ex_distance_to_fovea, ex_dme_grade,
  se_present,
  vessel_tortuosity, vessel_fractal_dim, vessel_density,
  nv_surrogate_score
]
```
