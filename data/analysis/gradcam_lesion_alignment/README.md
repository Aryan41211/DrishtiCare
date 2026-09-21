# DrishtiCare Grad-CAM Lesion Alignment Evaluation

Generated: 21-Sep-2026 02:22:50

## Experiment Overview

Quantitative evaluation of Grad-CAM attention overlap with doctor-annotated IDRiD lesion masks (MA/HE/EX/SE) for the locked Day-7 5-class ResNet-18 model.

**This is an offline analysis experiment only.** No training, no model modification, no threshold tuning, and no production behavior changes.

## Configuration

- **Model**: Day-7 pretrained ResNet-18 5-class (LOCKED)
- **Model SHA-256**: DD152C917689146F6DEC4687B263EC5E5F237ECF60EC719A59F9FCEEFF737C1B
- **Grad-CAM layer**: res5b_relu
- **Input size**: 224x224x3
- **Attention threshold (primary)**: Top 20% of pixels by activation rank
- **Attention threshold (secondary, T6 comparability)**: Top 20% cumulative saliency mass
- **Class mapping**: class_0, class_1, class_2, class_3, class_4 -> grades [0 1 2 3 4]

## Dataset Audit

- **Total candidate images**: 81
- **Valid image+mask pairs**: 81
  - Training split: 54
  - Test split: 27
- **Skipped images**: 0 (every skip has a documented reason)

### Skip Reasons

- Missing/unreadable image: 0
- Missing mask file: 0 (MA 0, HE 0, EX 0, SE 0)
- Unreadable mask: 0
- Empty mask (0 lesion px): 0 (MA 0, HE 0, EX 0, SE 0)
- Mask/image dimension mismatch: 0
- No valid lesion pixels in any type: 0
- Other: 0

### Per-Lesion-Type Coverage

| Type | Files on Disk | Usable (Candidates) | Usable (Valid Pairs) | Median Mask Px (Full Res) |
|---|---|---|---|---|
| MA | 81 | 81 | 81 | 10367 |
| HE | 80 | 80 | 80 | 58861 |
| EX | 81 | 81 | 81 | 52629 |
| SE | 40 | 40 | 40 | 38471 |

## Aggregate Results

### Overall (Any Lesion)

- **Evaluated images**: 81
- **Saliency mass in lesion**: 0.031 (median 0.020, std 0.044)
- **Pointing-game accuracy**: 0.074
- **Mean IoU (top-20% pixels)**: 0.035 (median 0.016, std 0.051)
- **Mean IoU (top-20% mass, T6 comparability)**: 0.027
- **Mean Dice (top-20% mass)**: 0.051
- **Chance baseline (areal)**: 0.0220
- **×Chance (mass)**: 1.39×
- **×Chance (point)**: 3.36×

### Per-Lesion-Type Results

| Type | n | Mass Mean | Mass Med | Point Acc | IoU Mean | IoU Med | ×Chance Mass |
|---|---|---|---|---|---|---|---|
| MA | 81 | 0.0013 | 0.0010 | 0.0123 | 0.0015 | 0.0012 | 1.24× |
| HE | 80 | 0.0126 | 0.0046 | 0.0125 | 0.0132 | 0.0048 | 1.23× |
| EX | 81 | 0.0145 | 0.0051 | 0.0494 | 0.0186 | 0.0059 | 1.61× |
| SE | 40 | 0.0049 | 0.0023 | 0.0000 | 0.0059 | 0.0000 | 1.30× |

### By Dataset Split

#### train (n=54)

- Saliency mass in lesion: 0.030
- Pointing-game accuracy: 0.074
- Mean IoU: 0.035

#### test (n=27)

- Saliency mass in lesion: 0.031
- Pointing-game accuracy: 0.074
- Mean IoU: 0.034

## Proxy Correct-vs-Incorrect Analysis

IDRiD 5-class grades do NOT exist for the segmentation images (IDRiD_01..IDRiD_81). The grading CSVs cover IDRiD_001..IDRiD_413 (train) and IDRiD_001..IDRiD_103 (test) only. A proxy split is reported instead:

- **Proxy GT referable**: Any doctor-annotated lesion present (derived from real annotations)
- **Model referable**: Predicted grade >= Moderate (grade index >= 2)

### Proxy Confusion Matrix

- TP: 72
- FN: 9
- FP: 0
- TN: 0

### Proxy-Correct Predictions (n=72)

- Saliency mass in lesion: 0.034
- Pointing-game accuracy: 0.083
- Mean IoU: 0.039

### Proxy-Incorrect Predictions (n=9)

- Saliency mass in lesion: 0.003
- Pointing-game accuracy: 0.000
- Mean IoU: 0.002

### Exact 5-Class Correct/Incorrect

**NOT COMPUTABLE**: IDRiD segmentation images (IDRiD_01..IDRiD_81) are a distinct image set from the IDRiD Disease-Grading set (IDRiD_001..IDRiD_413 / 001..103). No 5-class DR grade labels exist for the segmentation images (verified in this run: the grading label CSVs contain zero two-digit image names), so an exact correct-vs-incorrect 5-class split is NOT computable. A clearly-labelled referable-DR PROXY split (GT = any lesion present, from real annotations) is reported instead. Consistent with the Day-8 T6 finding (docs/validation/2026-09-08-task6-gradcam.md).

## Champion Predicted-Class Distribution on IDRiD

| Class | Count |
|---|---|
| class_0, class_1, class_2, class_3, class_4 -> grades [0 1 2 3 4] | 0 |
| class_0, class_1, class_2, class_3, class_4 -> grades [0 1 2 3 4] | 9 |
| class_0, class_1, class_2, class_3, class_4 -> grades [0 1 2 3 4] | 54 |
| class_0, class_1, class_2, class_3, class_4 -> grades [0 1 2 3 4] | 5 |
| class_0, class_1, class_2, class_3, class_4 -> grades [0 1 2 3 4] | 13 |

## Visual Examples

Deterministically selected (seed=42):

### 1. best_alignment (IDRiD_17)

- IoU: 0.323
- Saliency mass in lesion: 0.314
- Pointing game: 1

### 2. worst_alignment (IDRiD_15)

- IoU: 0.000
- Saliency mass in lesion: 0.001
- Pointing game: 0

### 3. median_alignment (IDRiD_49)

- IoU: 0.016
- Saliency mass in lesion: 0.034
- Pointing game: 0

### 4. proxy_correct_random (IDRiD_10)

- IoU: 0.209
- Saliency mass in lesion: 0.166
- Pointing game: 0

### 5. proxy_incorrect_random (IDRiD_41)

- IoU: 0.002
- Saliency mass in lesion: 0.002
- Pointing game: 0

All visual examples are in `visual_examples/`.

## Transformation Sanity Checks

Images (n=1) verifying that lesion masks stay aligned after resizing to 224x224:

- IDRiD_73

Sanity check figures are in `sanity_checks/`.

## Quality & Sanity Assertions (All Passed)

1. Model SHA-256 unchanged during run
2. No duplicate image IDs in results
3. Attention region size fixed at 10036 px for all images
4. All evaluable rows have finite IoU
5. Non-evaluable rows carry NaN (not 0) for lesion metrics
6. Every error row has a documented reason
7. Visual examples match reported CSV metrics

## Limitations

1. **No IDRiD 5-class grades** for the segmentation images → exact correct/incorrect split not computable.
2. **Domain shift**: IDRiD (portrait frames, different cameras) vs APTOS (training data) may affect alignment.
3. **Resolution limit**: 224x224 model input means tiny lesions (MA median ~43 px) are barely resolved.
4. **No lesion supervision**: Champion trained on image-level grades only, no pixel-level lesion labels.
5. **Proxy correctness**: The proxy GT (any lesion = referable) is a screening-level approximation, not a grade.
6. **Engineering analysis only**: This does not constitute clinical validation.

## Files

- `dataset_audit.csv` / `.mat` / `.md` — Phase-2 dataset audit
- `per_image_results.csv` — Machine-readable per-image metrics
- `gradcam_lesion_alignment.mat` — Complete MATLAB workspace
- `results_checkpoint.mat` — Periodic checkpoints
- `visual_examples/` — Representative four-panel figures
- `sanity_checks/` — Transformation alignment verification
- `run_log.txt` — Full console log

---

*Engineering explainability analysis — NOT clinical validation.*
