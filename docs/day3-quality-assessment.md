# DrishtiCare Day 3 — Quality Assessment Module

## 1. Overview

Day 3 implements the **Engineering Quality Gate** — an automated image quality assessment system for fundus images. This module evaluates images against prototype thresholds derived from Day 2 statistical analysis and provides PASS/WARNING/FAIL decisions with human-readable feedback.

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

### Threshold Documentation

Every threshold is documented with:
- Metric name and description
- Threshold value
- Whether lower or higher is considered poor
- How the threshold was derived from Day 2 statistics

### Brightness Thresholds

| Threshold | Value | Direction | Derivation |
|-----------|-------|-----------|------------|
| FAIL lower | 0.15 | Lower is darker (poor) | Set 10-15% below Day 2 P5 (0.294) to catch extreme dark images |
| WARNING lower | 0.20 | Lower is darker (marginal) | Set between FAIL and normal range |
| WARNING upper | 0.50 | Higher is brighter (marginal) | Set above Day 2 P95 (0.451) |
| FAIL upper | 0.55 | Higher is brighter (poor) | Set 10-15% above Day 2 P95 to catch extreme bright images |

**Day 2 Statistics:** min=0.2165, P5=0.294, P50=0.402, P95=0.451, max=0.4644

### Contrast Thresholds

| Threshold | Value | Direction | Derivation |
|-----------|-------|-----------|------------|
| FAIL lower | 0.02 | Lower is flatter (poor) | Set below Day 2 P5 (0.044) to catch severely degraded images |
| WARNING lower | 0.03 | Lower is flatter (marginal) | Set between FAIL and normal range |
| WARNING upper | 0.20 | Higher has more range (marginal) | Set above Day 2 P95 (0.129) |
| FAIL upper | 0.25 | Higher has more range (poor) | Set to catch unusually high contrast |

**Day 2 Statistics:** min=0.0342, P5=0.044, P50=0.063, P95=0.129, max=0.1556

### Focus Score Thresholds

| Threshold | Value | Direction | Derivation |
|-----------|-------|-----------|------------|
| FAIL lower | 1.5e-4 | Lower is blurrier (poor) | Set below Day 2 P5 (3.5e-4) to catch severely blurred images |
| WARNING lower | 2.0e-4 | Lower is blurrier (marginal) | Set between FAIL and normal range |
| WARNING upper | 2.0e-3 | Higher is sharper (marginal) | Set above Day 2 P95 (1.34e-3) |
| FAIL upper | 2.5e-3 | Higher is sharper (poor) | Set to catch unusually sharp images (may be noise) |

**Day 2 Statistics:** min=2.16e-4, P5=3.5e-4, P50=7.6e-4, P95=1.34e-3, max=2.64e-3

### Foreground Fraction Thresholds

| Threshold | Value | Direction | Derivation |
|-----------|-------|-----------|------------|
| FAIL lower | 0.25 | Lower means more border (poor) | Set conservatively to catch images with insufficient retinal area |
| WARNING lower | 0.35 | Lower means more border (marginal) | Set between FAIL and normal range |
| WARNING upper | 0.90 | Higher means more retina (marginal) | Set above typical range |
| FAIL upper | 0.95 | Higher means more retina (poor) | Set to catch unusual foreground detection |

**Day 2 Statistics:** min=0.474, P5=0.474, P50=0.742, P95=0.839, max=0.840

### Illumination Thresholds

| Threshold | Value | Direction | Derivation |
|-----------|-------|-----------|------------|
| FAIL lower | 0.75 | Lower means edges brighter (poor) | Set below Day 2 min (0.757) to catch extreme cases |
| WARNING lower | 0.85 | Lower means edges brighter (marginal) | Set between FAIL and normal range |
| WARNING upper | 1.40 | Higher means center brighter (marginal) | Set above Day 2 P95 (1.28) |
| FAIL upper | 1.50 | Higher means center brighter (poor) | Set to catch extreme vignetting |

**Day 2 Statistics:** min=0.757, P5=0.95, P50=1.14, P95=1.28, max=1.293

**Note:** Illumination uses WARNING severity (non-fatal) since illumination issues rarely make images unusable.

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