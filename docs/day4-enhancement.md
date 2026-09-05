# DrishtiCare Day 4 — Image Enhancement (Advanced)

## 1. Overview

Day 4 implements the **Image Enhancement Module** — a preprocessing pipeline that improves fundus image quality for downstream analysis. The module now includes adaptive parameter selection, multi-channel enhancement, histogram matching, vessel enhancement, optic disc normalization, and noise-aware processing.

**IMPORTANT: This is an ENGINEERING enhancement module, NOT a clinical image processing system. Enhancements are designed to improve visibility of retinal structures for downstream analysis.**

## 2. Module Files

| File | Purpose |
|------|---------|
| `enhanceImage.m` | Core enhancement function with adaptive parameters |
| `testEnhancement.m` | Test script verifying all functions work correctly |
| `run_day4.m` | Master script for batch enhancement |

## 3. Enhancement Techniques

### 3.1 CLAHE (Contrast Limited Adaptive Histogram Equalization)

**Purpose:** Improve local contrast without over-amplifying noise

**Method:**
- Applied to selected channels (green only or all RGB)
- Uses `adapthisteq` with adaptive clip limit
- Adaptive: Lower clip limit for low contrast images

**When to use:**
- Images with low contrast
- Images where lesions are hard to see

### 3.2 Illumination Normalization

**Purpose:** Remove uneven illumination (vignetting, center hotspot)

**Method:**
- Estimate background illumination via Gaussian filtering
- Divide original by background to normalize
- Scale to [0, 255] range
- Adaptive: Larger sigma for noisy images

**When to use:**
- Images with strong vignetting
- Images with uneven lighting

### 3.3 Histogram Matching

**Purpose:** Match image histogram to ideal fundus distribution

**Method:**
- Create ideal fundus histogram (Gaussian centered at 0.39)
- Compute CDFs of current and target distributions
- Map pixel values to match target distribution
- Improves consistency across images

**When to use:**
- Images with unusual intensity distributions
- Need to normalize across different camera settings

### 3.4 Gamma Correction

**Purpose:** Adjust brightness non-linearly

**Method:**
- Apply power-law transformation
- Adaptive: Lower gamma for dark images, higher for bright images

**When to use:**
- Very dark or very bright images
- Images needing brightness adjustment

### 3.5 Vessel Enhancement

**Purpose:** Enhance retinal blood vessels for better visibility

**Method:**
- Apply top-hat transformation (bright structures)
- Apply bottom-hat transformation (dark structures)
- Combine transformations for vessel enhancement
- Blend with original image (alpha = 0.3)

**When to use:**
- Images where vessels are hard to see
- Need to highlight vascular structures

### 3.6 Optic Disc Normalization

**Purpose:** Normalize optic disc region brightness

**Method:**
- Detect bright regions (likely optic disc) using 95th percentile threshold
- Create smooth mask with dilation and hole filling
- Compute mean intensity of bright region
- Scale bright region to match overall mean intensity

**When to use:**
- Images with overexposed optic disc
- Need to reduce optic disc brightness

### 3.7 Noise-Aware Processing

**Purpose:** Apply different denoising methods based on noise type

**Method:**
- Analyze noise characteristics (Gaussian vs salt & pepper)
- Use Laplacian variance for noise level estimation
- Use gradient statistics for noise type detection
- Apply appropriate denoising:
  - Gaussian noise: Wiener filter
  - Salt & pepper noise: Median filter

**When to use:**
- Images with different noise characteristics
- Need to optimize denoising for specific noise types

### 3.8 Denoising

**Purpose:** Remove noise while preserving edges

**Method:**
- Apply median filter to selected channels
- Adaptive: Larger kernel for noisy images

**When to use:**
- Images with visible noise
- Images with grainy appearance

### 3.9 Sharpening

**Purpose:** Enhance edge details

**Method:**
- Apply unsharp masking
- Adaptive: Gentler sharpening for noisy images

**When to use:**
- Images with soft edges
- Images needing detail enhancement

## 4. Adaptive Parameter Selection

The module analyzes image characteristics and selects parameters automatically:

| Characteristic | Analysis | Parameter Adjustment |
|----------------|----------|---------------------|
| **Brightness** | Mean intensity | Low brightness → lower gamma (brighten) |
| **Contrast** | Std dev / Mean | Low contrast → lower CLAHE clip limit |
| **Noise Level** | Laplacian variance | High noise → larger denoise kernel, gentler sharpening |
| **Noise Type** | Gradient statistics | Gaussian → Wiener filter; Salt & pepper → median filter |

### Adaptive Rules

| Image Type | CLAHE Clip | Gaussian Sigma | Denoise Kernel | Gamma | Sharpen |
|------------|------------|----------------|----------------|-------|---------|
| Dark, clean | 0.02 | 20 | 3 | 0.7 | 0.5 |
| Dark, noisy | 0.01 | 30 | 5 | 0.7 | 0.3 |
| Normal | 0.02 | 25 | 3 | 1.0 | 0.5 |
| Bright, clean | 0.03 | 20 | 3 | 1.3 | 0.5 |
| Bright, noisy | 0.02 | 30 | 5 | 1.3 | 0.3 |

## 5. Usage

### Quick Test
```matlab
cd('C:\projects\DrishtiCare')
addpath('src\enhancement');

% Test on a single image
img = imread('data\aptos2019\train_images\000c1434d8d7.png');
[enhanced, qualityImprovement] = enhanceImage(img);

% Show comparison
figure;
subplot(1,2,1); imshow(img); title('Original');
subplot(1,2,2); imshow(enhanced); title('Enhanced');

% Show quality improvement
fprintf('Quality improvement score: %.4f\n', qualityImprovement.overallScore);
```

### Run Full Test Suite
```matlab
cd('C:\projects\DrishtiCare')
addpath('src\enhancement');
testEnhancement();
```

### Batch Enhancement
```matlab
cd('C:\projects\DrishtiCare')
run_day4('fast');   % 100 images
run_day4('full');   % All 3662 images
```

## 6. Configuration Options

| Parameter | Default | Description |
|-----------|---------|-------------|
| `Adaptive` | true | Use adaptive parameter selection |
| `AllChannels` | true | Enhance all RGB channels |
| `CLAHE` | true | Apply CLAHE contrast enhancement |
| `IlluminationNorm` | true | Apply illumination normalization |
| `Denoise` | true | Apply denoising |
| `GammaCorrection` | true | Apply gamma correction |
| `Sharpen` | true | Apply sharpening |
| `HistogramMatch` | true | Apply histogram matching |
| `VesselEnhance` | true | Apply vessel enhancement |
| `OpticDiscNorm` | true | Apply optic disc normalization |
| `NoiseAware` | true | Use noise-aware processing |
| `ClipLimit` | auto | CLAHE clip limit |
| `GaussianSigma` | auto | Sigma for illumination estimation |
| `DenoiseKernel` | auto | Median filter kernel size |
| `GammaValue` | auto | Gamma correction value |

## 7. Output Structure

### Enhanced Image
```matlab
[enhanced, qualityImprovement] = enhanceImage(img);
```

### Quality Improvement
```matlab
qualityImprovement = struct(
    'brightnessDelta', 0.05,    % Change in brightness
    'contrastDelta',   0.02,    % Change in contrast
    'focusDelta',      0.001,   % Change in focus score
    'foregroundDelta', 0.01,    % Change in foreground fraction
    'overallScore',    0.85,    % Overall improvement score
    'original',        struct,  % Original quality metrics
    'enhanced',        struct   % Enhanced quality metrics
);
```

## 8. Enhancement Pipeline

```
Input Fundus Image
        ↓
   Noise Analysis
   - Detect noise type (Gaussian/salt & pepper)
   - Estimate noise level
        ↓
   Noise-Aware Preprocessing
   - Apply Wiener filter for Gaussian noise
   - Skip for low noise images
        ↓
   CLAHE (all channels)
   - Adaptive clip limit based on contrast
        ↓
   Illumination Normalization
   - Remove uneven illumination
        ↓
   Histogram Matching
   - Match to ideal fundus distribution
        ↓
   Gamma Correction
   - Adjust brightness non-linearly
        ↓
   Vessel Enhancement
   - Top-hat + bottom-hat transformation
   - Blend with original
        ↓
   Optic Disc Normalization
   - Detect and normalize bright regions
        ↓
   Noise-Aware Denoising
   - Wiener filter for Gaussian noise
   - Median filter for salt & pepper noise
        ↓
   Sharpening
   - Unsharp masking
        ↓
   Quality Improvement Score
        ↓
   [Day 5: Classifier]
```

## 9. Test Results (10 images)

| Metric | Improved | Percentage |
|--------|----------|------------|
| **Brightness** | 10/10 | 100.0% |
| **Contrast** | 10/10 | 100.0% |
| **Focus** | 10/10 | 100.0% |
| **Overall** | 10/10 | 100.0% |

### Example Enhancement

```
Original:  Brightness=0.2687, Contrast=0.0509, Focus=7.96e-04
Enhanced:  Brightness=0.6387, Contrast=0.1040, Focus=3.14e-02
Quality improvement score: 1.0604
```

## 10. Limitations

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| **May alter clinical features** | Enhancements could mask or create artifacts | Clinical validation required |
| **Adaptive heuristics** | May not work for all image types | Future: learned parameter selection |
| **Computational cost** | Multi-channel processing is slower | Future: GPU acceleration |
| **No artifact detection** | Cannot detect enhancement artifacts | Future: artifact detection module |
| **Histogram matching** | May not be optimal for all images | Future: learned histogram targets |

## 11. Important Notes

### What This IS
- An engineering enhancement module for preprocessing fundus images
- An adaptive image processing pipeline
- A tool for improving image quality before downstream analysis
- A noise-aware processing system

### What This IS NOT
- A clinical image processing system
- A replacement for professional image enhancement
- A validated medical device
- A system that claims to improve diagnostic accuracy

### Required Future Work
1. **Clinical validation** — Ophthalmologist review of enhancement effects
2. **Learned parameters** — Train model to predict optimal parameters
3. **Artifact detection** — Identify and flag enhancement artifacts
4. **GPU acceleration** — Faster processing for large datasets
5. **Multi-scale enhancement** — Enhance at multiple scales
6. **Adaptive histogram targets** — Learn optimal histogram from data

## References

- CLAHE: Contrast Limited Adaptive Histogram Equalization
- Gamma correction: Power-law transformation
- Illumination normalization: Standard fundus image preprocessing
- Histogram matching: Histogram specification
- Vessel enhancement: Top-hat/bottom-hat transformation
- Optic disc normalization: Bright region detection and normalization
- Noise-aware processing: Wiener filter, median filter
- Denoising: Median filter for noise reduction
- Sharpening: Unsharp masking
- SIH 26038 problem statement