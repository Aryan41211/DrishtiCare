# DrishtiCare Day 3 — Quality Assessment Module

## 1. Overview

Day 3 implements the **Engineering Quality Gate** — an automated image quality assessment system for fundus images. This module evaluates images against prototype thresholds derived from the Day 3 full-dataset statistical analysis (3,662 images, per `config.derivedFrom` in `src/quality/defaultQualityConfig.m`) and provides PASS/WARNING/FAIL decisions with human-readable feedback.

**IMPORTANT: This is an ENGINEERING quality gate, NOT a clinical diagnostic system. Thresholds are prototype values only and require ophthalmologist validation before clinical use.**

## 2. Quality Status Definitions

### PASS
- **Definition:** Image is sufficiently usable for the prototype pipeline
- **Meaning:** All quality metrics are within acceptable ranges
- **Action:** Image proceeds to downstream processing (Day 4: Enhancement)
- **Note:** This is an engineering decision, NOT a clinical gradability label

### WARNING
- **Definition:** Image has a quality concern but is not automatically rejected
- **Meaning:** One or more metrics are marginal (between WARNING and FAIL bounds)
- **Action:** Image proceeds but with caution flags; may benefit from recapture
- **Note:** Warning images are still usable for analysis

### FAIL
- **Definition:** Image does not meet the prototype quality requirements and should be recaptured
- **Meaning:** One or more metrics are outside acceptable ranges
- **Action:** Image is flagged for recapture with human-readable feedback
- **Note:** Failed images may produce unreliable downstream results

**These are engineering decisions, NOT clinical gradability labels.** A FAIL does not mean the image is clinically ungradable — it means the image does not meet our prototype engineering thresholds.

## 3. Module Files

| File | Purpose |
|------|---------|
| `defaultQualityConfig.m` | Configuration struct with thresholds, severity levels, and feedback messages |
| `assessImageQuality.m` | Core function: image → metrics → threshold comparison → quality decision |
| `testQualityAssessment.m` | Test script verifying all functions work correctly |
| `runQualityAssessment.m` | Batch evaluation on full APTOS dataset with result export |

## 4. Quality Metrics Evaluated

| Metric | Method | Unit | What It Measures |
|--------|--------|------|------------------|
| **Brightness** | Mean foreground intensity | [0, 1] | Overall exposure level |
| **Contrast** | Std dev of foreground intensities | [0, 1] | Dynamic range |
| **Focus Score** | Variance of Laplacian (512×512) | scientific notation | Edge sharpness |
| **Foreground Fraction** | Retinal area / total area | [0, 1] | How much retina is visible |
| **Illumination** | Center brightness / Edge brightness | ratio | Lighting uniformity |
| **Mask Valid** | Foreground detection success | boolean | Whether metrics are reliable |

## 5. Prototype Thresholds

### Source of truth

Every value in this section is transcribed from the operative
`config.thresholds` struct in **`src/quality/defaultQualityConfig.m`**
(config version `2.0.0`, `config.derivedFrom = 'Day 3 full dataset analysis
(3,662 images)'`, `config.validationStatus = 'Prototype - NOT clinically
validated'`). These are the values the runtime gate actually reads — they are
passed straight into `evaluateRangeCheck()` by
`src/quality/assessImageQuality.m:216-256`, which is the only place a
PASS/WARNING/FAIL decision is made. If this table and the config ever
disagree, **the config is authoritative and this table is wrong.**

### Direction of every test (two-sided, not one-sided)

The gate is a **band-pass on all five range metrics** — a metric can fail by
being too *low* **or** too *high*. `evaluateRangeCheck()` implements:

```matlab
if value < lowerFail || value > upperFail   -> FAIL
elseif value < lowerWarn || value > upperWarn -> WARNING
else                                        -> PASS
```

So the four bounds are ordered `lowerFail < lowerWarn < upperWarn < upperFail`,
and the PASS band is the **interval** `[lowerWarn, upperWarn]` — not "above a
minimum". Severity is per-metric in `config.severity`: `FAIL` for brightness,
contrast, focus, foreground and `maskValid`; **`WARNING` (non-fatal) for
illumination**, so illumination alone can never fail an image. A NaN metric
(`isnan(value)`) is also forced to FAIL. The sixth enabled check,
`maskValid`, is a boolean, not a range: false → `FAIL`.

Units come from `config.thresholdDocumentation.*.unit`.

### Brightness Thresholds

Mean foreground intensity, unit **[0, 1] scale**, lower = darker / higher = brighter.

| Threshold | Value | Direction | Derivation |
|-----------|-------|-----------|------------|
| FAIL lower | 0.1901 | value < 0.1901 → FAIL (too dark) | Day 3 percentile analysis, 3,662 images |
| WARNING lower | 0.2145 | value < 0.2145 → WARNING (too dark) | Between FAIL bound and normal range |
| WARNING upper | 0.4586 | value > 0.4586 → WARNING (too bright) | Between normal range and FAIL bound |
| FAIL upper | 0.5154 | value > 0.5154 → FAIL (too bright) | Day 3 percentile analysis, 3,662 images |

**PASS band:** 0.2145 ≤ brightness ≤ 0.4586
**Day 3 observed distribution:** min=0.2165, P5=0.294, P25=0.361, P50=0.402, P75=0.428, P95=0.451, max=0.4644

### Contrast Thresholds

Std dev of foreground intensities, unit **[0, 1] scale**, lower = flatter / higher = more dynamic range.

| Threshold | Value | Direction | Derivation |
|-----------|-------|-----------|------------|
| FAIL lower | 0.0315 | value < 0.0315 → FAIL (washed-out) | FAIL lower bound set below P5 to catch severely degraded images |
| WARNING lower | 0.0387 | value < 0.0387 → WARNING (flat) | Between FAIL bound and normal range |
| WARNING upper | 0.1065 | value > 0.1065 → WARNING (high range) | Between normal range and FAIL bound |
| FAIL upper | 0.1375 | value > 0.1375 → FAIL (unusually high) | Upper bound for unusually high contrast |

**PASS band:** 0.0387 ≤ contrast ≤ 0.1065
**Day 3 observed distribution:** min=0.0342, P5=0.044, P25=0.055, P50=0.063, P75=0.078, P95=0.129, max=0.1556

### Focus Score Thresholds

Variance of the Laplacian on a 512×512 resized image, unit **scientific notation**, lower = blurrier / higher = sharper.

| Threshold | Value | Direction | Derivation |
|-----------|-------|-----------|------------|
| FAIL lower | 1.42e-04 | value < 1.42e-04 → FAIL (significant blur) | FAIL lower bound set below P5 to catch severely blurred images |
| WARNING lower | 2.37e-04 | value < 2.37e-04 → WARNING (blurry) | Between FAIL bound and normal range |
| WARNING upper | 1.34e-03 | value > 1.34e-03 → WARNING (unusually sharp) | Between normal range and FAIL bound |
| FAIL upper | 1.75e-03 | value > 1.75e-03 → FAIL (noise/artifacts) | Upper bound for unusually sharp images |

**PASS band:** 2.37e-04 ≤ focusScore ≤ 1.34e-03
**Day 3 observed distribution:** min=2.16e-4, P5=3.50e-4, P25=5.52e-4, P50=7.60e-4, P75=9.90e-4, P95=1.34e-3, max=2.64e-3

### Foreground Fraction Thresholds

Proportion of image that is retinal tissue, unit **[0, 1] scale**, lower = more black border / higher = more retina visible.

| Threshold | Value | Direction | Derivation |
|-----------|-------|-----------|------------|
| FAIL lower | 0.2651 | value < 0.2651 → FAIL (mostly black border) | FAIL lower bound set conservatively to catch images with insufficient retinal area |
| WARNING lower | 0.4736 | value < 0.4736 → WARNING (border heavy) | Between FAIL bound and normal range |
| WARNING upper | 0.8833 | value > 0.8833 → WARNING (unusually large) | Between normal range and FAIL bound |
| FAIL upper | 0.9758 | value > 0.9758 → FAIL (suspect mask) | Upper bound for unusual foreground detection |

**PASS band:** 0.4736 ≤ foregroundFrac ≤ 0.8833
**Day 3 observed distribution:** min=0.474, P5=0.474, P25=0.474, P50=0.742, P75=0.787, P95=0.839, max=0.840

### Illumination Thresholds

Ratio of center brightness to edge brightness, unit **ratio (1.0 = uniform)**, lower = edges brighter / higher = center brighter (vignetting).

| Threshold | Value | Direction | Derivation |
|-----------|-------|-----------|------------|
| FAIL lower | 0.8025 | value < 0.8025 (edges brighter) | Bound defined; severity is WARNING so this never rejects an image |
| WARNING lower | 0.9200 | value < 0.9200 → WARNING (uneven) | Between FAIL bound and normal range |
| WARNING upper | 1.2615 | value > 1.2615 → WARNING (vignetting) | Between normal range and FAIL bound |
| FAIL upper | 1.3541 | value > 1.3541 (extreme vignetting) | Bound defined; severity is WARNING so this never rejects an image |

**PASS band:** 0.9200 ≤ illumination ≤ 1.2615
**Day 3 observed distribution:** min=0.757, P5=0.95, P25=1.06, P50=1.14, P75=1.22, P95=1.28, max=1.293

**Note:** `config.severity.illumination = 'WARNING'`, so illumination is
non-fatal — its two FAIL bounds are recorded in the config but an out-of-range
illumination ratio can only downgrade an image to WARNING, never to FAIL
(rationale in config: illumination issues rarely make images unusable). This
matches the documented Day 2 observation that the APTOS image set contained no
unusable images on this metric.

## 6. Output Structure

### Per-Image Result
```matlab
result = struct(
    'overall',       'PASS',          % 'PASS', 'WARNING', or 'FAIL'
    'qualityScore',  0.85,            % 0.0 to 1.0 (1.0 = perfect)
    'numPass',       5,               % Count of metrics passing
    'numWarning',    0,               % Count of warnings
    'numFail',       0,               % Count of failures
    'failureReasons', {},             % Human-readable reasons
    'recaptureAdvice', '...'          % Guidance for photographer
);
```

### Batch Results (CSV)
- `id_code` — Image identifier
- `diagnosis` — DR grade (0-4)
- `quality_status` — PASS/WARNING/FAIL
- `quality_score` — 0.0 to 1.0
- `num_pass`, `num_warn`, `num_fail` — Per-metric counts
- `failure_reason` — Semicolon-separated failure messages
- `feedback` — Overall recapture advice
- `brightness`, `contrast`, `focus_score`, etc. — Raw metrics

## 7. Usage

### Quick Test
```matlab
cd('C:\projects\DrishtiCare')
addpath('src\quality');

% Test on a single image
img = imread('data\aptos2019\train_images\000c1434d8d7.png');
[result, metrics] = assessImageQuality(img);
fprintf('Overall: %s\n', result.overall);
fprintf('Score: %.2f\n', result.qualityScore);
```

### Run Full Test Suite
```matlab
cd('C:\projects\DrishtiCare')
addpath('src\quality');
testQualityAssessment();
```

### Batch Evaluation (Full Dataset)
```matlab
cd('C:\projects\DrishtiCare')
addpath('src\quality');
runQualityAssessment('full');   % All 3662 images (default)
runQualityAssessment('fast');   % 500 images (stratified sample)
```

## 8. Integration with Pipeline

```
Input Fundus Image
        ↓
   assessImageQuality()
        ↓
   Quality Gate
       / \
  PASS   FAIL → Recapture Advice
      ↓
  [Day 4: Enhancement]
```

The quality gate is designed to be called early in the pipeline. Images that FAIL are flagged with human-readable reasons suggesting recapture. WARNING images proceed but with caution flags.

## 9. Limitations

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| **Single dataset** | Thresholds may not generalize to other cameras/sites | Future: multi-site validation |
| **No clinical validation** | May reject clinically acceptable images | Future: ophthalmologist review |
| **Fixed thresholds** | Different cameras may need different thresholds | Future: per-camera calibration |
| **Simple metrics** | May miss subtle quality issues | Future: learned quality models |
| **No anomaly detection** | Cannot detect artifacts or unusual pathologies | Future: OOD detection module |

## 10. Comparison with Day 2

| Aspect | Day 2 | Day 3 |
|--------|-------|-------|
| **Purpose** | Explore distributions | Apply thresholds |
| **Thresholds** | None (exploratory) | Prototype engineering values |
| **Output** | Statistics, visualizations | PASS/WARNING/FAIL decisions |
| **Blur detection** | `blur < 100` (invalid, 99.6% fail) | Focus score with percentile-based thresholds |
| **Feedback** | None | Human-readable recapture advice |

## 11. Important Notes

### What This IS
- An engineering quality gate for filtering images before downstream processing
- A prototype system with thresholds derived from statistical analysis
- A tool for identifying images that may need recapture

### What This IS NOT
- A clinical diagnostic system
- A replacement for ophthalmologist review
- A validated medical device
- A system that claims to detect eye diseases

### Required Future Work
1. **Clinical validation** — Ophthalmologist review of threshold decisions
2. **Multi-site testing** — Validate on different camera models and populations
3. **Adaptive thresholds** — Per-camera or per-site calibration
4. **Learned quality models** — Train neural networks for quality prediction
5. **Integration testing** — Verify quality gate improves downstream classification

## References

- APTOS 2019 dataset: https://www.kaggle.com/c/aptos2019-blindness-detection
- Day 2 analysis: `docs/day2-quality-observations.md`
- SIH 26038 problem statement