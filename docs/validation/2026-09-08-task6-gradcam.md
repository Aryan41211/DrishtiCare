# Task 6 — Grad-CAM Saliency vs IDRiD Ground-Truth Lesion Masks

Date: 08-Sep-2026
Reproducer: `src/run_task6_gradcam.m` (MATLAB R2026a, CPU, `-batch`)
Saved metrics: `data/analysis/day8/gradcam_T6.mat`

## What was measured

Predicted-class Grad-CAM saliency of the 5-class champion
(`day7_pretrained_resnet18_5class_stage2.mat`, input 224×224×3, feature
layer `res5b_relu`) scored against IDRiD microaneurysm / haemorrhage /
hard exudate / soft exudate segmentations.

- Saliency: **built-in `gradCAM`** (Deep Learning Toolbox 26.1 verified via
  full `ver()` list; gradCAM confirmed present — no fallback path used).
- 81 images scored: **54 train + 27 test** IDRiD segmentation images on
  disk. (Task brief said "28/12"; disk reality is 54/27 — the standard IDRiD
  split. Used all, satisfying "≥28".) Test-set masks used for annotation only.
- Alignment: image and masks are **already both 2848×4288** (rows×cols,
  portrait); verified `size` equality per image in-script; no transpose was
  needed. Image → 224×224 with `imresize` (same as training); masks → same
  grid with `imresize(...,'nearest')`, then thresholded.
- Threshold choice for IoU-like metric: **top-20% cumulated saliency mass**;
  Dice and Jaccard vs lesion-mask union. Stated per spec's "state which".

## Measured results (pooled across images containing ≥1 lesion of each type)

| Type | n | Saliency mass in lesion | Chance (areal) | ×chance | Pointing game | Chance point | Dice | Jaccard |
|------|---|------------------------|----------------|---------|---------------|--------------|------|---------|
| MA   | 81 | 0.0013 | 0.0010 | 1.24 | 0.012 | 0.001 | 0.003 | 0.002 |
| HE   | 80 | 0.0126 | 0.0103 | 1.23 | 0.013 | 0.010 | 0.016 | 0.008 |
| EX   | 81 | 0.0145 | 0.0090 | 1.61 | 0.049 | 0.009 | 0.034 | 0.018 |
| SE   | 40 | 0.0049 | 0.0038 | 1.30 | 0.000 | 0.004 | 0.012 | 0.006 |
| Any  | 81 | 0.0307 | 0.0220 | 1.39 | 0.074 | 0.022 | 0.051 | 0.027 |

Confound check (`createRetinalMask`): **78% of saliency mass falls on the
retina disk** (mean |median 0.779|0.776), so the low lesion overlap is NOT a
black-background artefact; 3.8% of on-retina saliency lands on any lesion.

By champion predicted class (any-lesion pool): Mild n=9 mass=0.003;
Moderate n=54 mass=0.024 point=0.093; Severe n=5 mass=0.088; Proliferative
n=13 mass=0.058 point=0.077. Champion class distribution on IDRiD: NoDR 0,
Mild 9, Moderate 54, Severe 5, Proliferative 13.

Best/worst cases: `IDRiD_17.jpg` massInAll=0.314 point=1 (pred
Proliferative, p=1.000); `IDRiD_15.jpg` massInAll=0.001 (pred Mild).

## Interpretation (measured vs expected vs uncertain)

- **Measured:** all lesion-overlap metrics are 1.2–1.6× uniform-chance —
  the champion's Grad-CAM does **not** strongly localize IDRiD lesions at
  224 px; best single image captures ~31% of saliency mass on lesion.
- **Expected/consistent with model design:** the champion was trained on
  APTOS image-level grades with **no lesion supervision**, so strong lesion
  localization would not be predicted; the coarse 7×7 Grad-CAM resampled
  maps and the pixel scale of MA at 224 px (median 43 mask px) further cap
  attainable overlap. No contradicting claim is made.
- **Uncertain:** how much of the gap reflects model behavior vs. IDRiD↔APTOS
  domain shift (portrait frames, different cameras) vs. interpolation loss on
  tiny lesions is not separable from this data.

## Correct-vs-error comparison — BLOCKED (exact reason)

The task asked to split IDRiD images into champion correct/error using the
733-val predictions. This is **not computable**: the IDRiD *segmentation*
images (`IDRiD_01..IDRiD_81`) are a distinct image set from IDRiD *Disease
Grading* (`IDRiD_001..`, different files), and neither maps to the champion's
APTOS class space. The 733-APTOS-val split (YTrue5/YPred5 in
`reverify_audit_T0.mat`) carries correct/incorrect labels but **no lesion
masks**, so saliency-mass-in-lesion cannot be evaluated on it. No
class-consistent correct/incorrect partition of IDRiD exists → reported as
blocked rather than fabricated. Quantification possible: champion predicted
class distribution on IDRiD above.

## Caveats

- MA/HE/EX/SE coverage at 224 px is small (median mask px: 43/247/221/0);
  resized-tenfold tiny lesions partly drive low Dice.
- No threshold/models modified; APTOS test set untouched; IDRiD test masks
  used for annotation only.

## Files

- `data/analysis/day8/gradcam_T6.mat` — per-image records (`perImage`:
  massIn/pt/dice/jacc per type, massInAll, retina confound, predClass/
  predScore), aggregates (`agg`), blocked-item record (`blocked`), settings.
- `src/run_task6_gradcam.m` — reproducer.