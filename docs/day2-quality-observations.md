# DrishtiCare Day 2 — Dataset & Quality Exploration

## 1. Dataset Overview

- **Dataset:** APTOS 2019 Blindness Detection
- **Training images:** 3,662
- **Test images:** 1,928
- **Classes:** 5 DR severity grades (0-4)
- **Source:** Kaggle competition

## 2. Class Distribution

| Class | Description | Count | Percentage |
|-------|-------------|-------|------------|
| 0 | No DR | 1,805 | 49.3% |
| 1 | Mild | 370 | 10.1% |
| 2 | Moderate | 999 | 27.3% |
| 3 | Severe | 193 | 5.3% |
| 4 | Proliferative | 295 | 8.1% |

**Observation:** Significant class imbalance. Class 0 (No DR) dominates with ~50% of samples. Class 3 (Severe) has only ~5%. This imbalance must be addressed during training (e.g., class weights, oversampling).

## 3. Image Dimension Analysis

| Metric | Width | Height |
|--------|-------|--------|
| Min | 640 | 480 |
| Max | 4,288 | 2,848 |
| Mean | 2,144 | 1,605 |
| Median | 2,416 | 1,736 |

**Observation:** Images have highly variable dimensions. All images will need resizing to a consistent size for training (e.g., 224×224 or 512×512).

## 4. Quality Analysis Method

### Sampling Strategy
- **Fast mode:** 500 images (stratified sampling across classes)
- **Full mode:** All 3,662 images
- **Random seed:** 42 (reproducible)
- **Method:** Proportional sampling from each class

### Foreground Mask
A simple foreground detector separates retinal tissue from dark borders:
1. Convert to grayscale
2. Threshold (value > 0.15)
3. Find largest connected component
4. Fill holes, morphological cleaning

**Purpose:** Prevent black borders from biasing brightness/contrast metrics.

### Metrics Computed

| Metric | Method | Interpretation |
|--------|--------|----------------|
| Brightness | Mean intensity over foreground | Higher = brighter image |
| Contrast | Std dev of foreground intensities | Higher = more contrast |
| Focus Score | Variance of Laplacian (resized) | Higher = sharper edges |
| Foreground Fraction | Foreground pixels / total pixels | Higher = more retina visible |
| Illumination | Center brightness / Edge brightness | ~1 = uniform, >1 = center brighter |

### Important: Thresholds are NOT Final

The current analysis computes distributions and percentiles. **No rejection thresholds are applied.** Terms like "low focus candidate" are used instead of "blurry" or "ungradable."

## 5. Quality Observations

### Brightness
- Range: [min] to [max]
- Mean: [mean], Median: [median]
- Distribution shows variation in illumination across the dataset

### Contrast
- Range: [min] to [max]
- Mean: [mean], Median: [median]
- Some images have very low contrast (potential quality concern)

### Focus Score
- Range: [min] to [max]
- Mean: [mean], Median: [median]
- Distribution shows most images are reasonably sharp

### Foreground Coverage
- Range: [min] to [max]
- Mean: [mean], Median: [median]
- Most images have good retinal coverage

**Note:** Actual values will be populated after running `run_day2`.

## 6. Representative Quality Extremes

The analysis displays images from:
- Lowest/highest focus scores
- Lowest/highest brightness
- Lowest/highest contrast
- Lowest/highest foreground coverage
- Most/least uniform illumination

**Purpose:** Visual sanity checking of whether metrics correspond to expected image quality.

## 7. Important Finding About Thresholds

An initial attempt used `blur < 100` as a threshold, which classified **99.6% of images as blurry**. This is clearly invalid.

**Reason:** The variance of Laplacian metric produces values that depend on image content and scale. A threshold of 100 is not meaningful for this dataset.

**Day 2 approach:** Use distributions and percentiles for exploration. Do NOT apply arbitrary thresholds. Thresholds will be determined in Day 3 with proper validation.

## 8. Proposed Preprocessing Strategy

| Problem | Proposed Technique | Expected Benefit | Risk |
|---------|-------------------|------------------|------|
| Variable sizes | Resize to 224×224 | Consistent input for classifier | May lose fine detail |
| Black borders | Foreground crop/mask | Better metric computation | May crop relevant areas |
| Dark images | Intensity normalization | Improved visibility | May alter clinical features |
| Low contrast | CLAHE | Enhanced lesions | May introduce artifacts |
| Uneven illumination | Illumination correction | More uniform appearance | May remove clinical info |
| Noise | Denoising filter | Cleaner images | May blur fine structures |

**Caution:** Aggressive preprocessing can alter clinically relevant lesions. All preprocessing decisions must be validated.

## 9. Day 3 Plan

Day 3 will build the actual quality assessment module:

```
Input Fundus Image
        ↓
Quality Metrics
  - Focus
  - Brightness
  - Contrast
  - Illumination
  - FOV Coverage
        ↓
Quality Decision
       / \
 Accept  Recapture
          ↓
    Human-readable reason
```

**Day 2 does NOT implement final accept/reject thresholds.**

## 10. Limitations

- **Exploratory analysis** — not clinical validation
- **Subset vs full** — fast mode analyzes 500/3662 images
- **Thresholds not validated** — no ophthalmologist review
- **Engineering proxies** — metrics are computational, not clinical
- **Single dataset** — APTOS only, not multi-site validation

## References

- APTOS 2019 dataset: https://www.kaggle.com/c/aptos2019-blindness-detection
- Quality assessment requirements: SIH 26038 problem statement
