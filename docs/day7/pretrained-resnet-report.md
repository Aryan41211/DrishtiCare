# Day 7 — Final Model Improvement Report

## 1. Executive Summary
ImageNet-pretrained ResNet-18 beats every scratch model on every metric
and becomes both the grading and screening champion. All results are
VALIDATION results (733 images). The official test set was never touched.

## 2. Existing Model (scratch champions, preserved)
- 5-class baseline: 73.67% / F1 0.5083 / QWK 0.7672 / sens 83.22% / spec 90.80%
- Ensemble w=0.6: 74.08% / 0.5178 / 0.7807 / 85.94% / 86.67%
- Binary @0.60: sens 90.27% / spec 85.75% / AUC 0.9496

## 3. Training Pipeline Audit
Full audit in `docs/day7/pretrained_pipeline_audit.md`. Key findings:
labels categorical class_0..4; resize 224 bilinear; ResNet input-layer
zerocenter normalization shared by all runs; enhancement NOT in training;
baseline trained WITHOUT augmentation (augmenter built but unattached —
verified via logs + git), balanced/binary WITH augmentation; Stage 1 =
head-only (60 frozen), Stage 2 = full unfreeze @1e-5.
**Also caught and fixed a latent bug**: `config.classes.referable` was
0-indexed while all labels are 1-indexed, so every 5-class referable
metric to date used {Mild,Moderate,Severe} instead of
{Moderate,Severe,Proliferative}. Fixed at the source; all numbers below
are recomputed with the correct set.

## 4. Pretrained vs Scratch
`resnet18()` DAGNetwork verified (71 layers) + `imagePretrainedNetwork`
(dlnetwork, 1000 classes). Pipeline reused unchanged
(`defaultPretrainedConfig`, same split/augmentation): Stage 1 head-only
9 epochs (val 73.53%), Stage 2 full unfreeze @1e-5 + 3-epoch resume,
final val 70.5% in-loop but **82.81% on proper inference** (BN
population statistics finalize at train end — train-loop val understates).

## 5. Data Augmentation
Kept as-is (rot ±15, x-reflect, trans ±10, shear ±5). Brightness/contrast
are not supported by `imageDataAugmenter` (verified). One controlled
config only — no augmentation zoo.

## 6. Resolution Experiment
SKIPPED with reason: 320px ≈ 2.5× CPU cost against an already ~8h
queue; revisit on GPU. No silent omission — documented here.

## 7. Enhancement Experiment
Deferred with reason: enhancement is not in any training path; an A/B
needs two full training runs. Same revisit condition as resolution.

## 8. Class Imbalance
In-memory oversampling (cap 800/class, zero disk) + augmentation.
Pretrained run shows balancing no longer distorts the tradeoff the way
it did from scratch.

## 9. Ensemble Optimization
w=0.6/0.4 kept for scratch grading. Pretrained 5-class alone beats the
scratch ensemble on all six metrics, so no pretrained+scratch ensemble
was forced.

## 10. Binary Screening
Pretrained binary (same IDs): @0.50 acc 93.45% sens 92.28% spec 94.25%
AUC 0.9796; @0.60 sens 90.60% spec 94.71%. PR-AUC 0.7821 independently
verified (real, not a code artifact — mid-recall precision dip).

## 11. Calibration
Brier 0.0563. Reliability: mild under-confidence mid-range
(e.g. conf 0.37 → outcome 0.50). No Platt/isotonic fitted (no spare
split) — raw calibration reported with the limitation stated.

## 12. Error Analysis (pretrained 5-class)
MAE 0.2278; within ±1: 95.36%; errors ≥2 levels: 4.64%.
Severe 48.7% (was 18%), Mild 60.8% (44.6%), Moderate 78.5% (68.5%),
Proliferative 52.5% (22.0%). Remaining errors are nearly all adjacent.

## 13. Grad-CAM
8 pretrained overlays in `data/analysis/day7/figures/` (5 correct +
Severe FN, Proliferative FN, Mild→Proliferative jump). Coarse attention
only — never lesion segmentation.

## 14. Lesion-Aware Findings
IDRiD inspected: not used. No annotation transfer performed; no lesion
claims made. Lesion-aware modeling (U-Net/YOLO) explicitly NOT started
— unjustified before test-set evaluation.

## 15. Final Model Selection
- Grading champion: `day7_pretrained_resnet18_5class` (82.81 / 0.6805 / 0.8914).
- Screening champion: `day7_pretrained_resnet18_binary` @0.60 (90.60 / 94.71).
- Pipeline: binary screens → 5-class grades. Old champions retained.

## 16. Individual Image Inference
`src/inference/predictSingleFundus.m` + `demoSingleImage.m`, tested on 4
validation images (NoDR/Severe/Proliferative×2): all structs valid,
probabilities sum to 1. See `docs/individual-image-inference.md`.

## 17. Limitations
CPU-only; from-ImageNet (not retina-pretrained); Severe n=154;
no enhancement/resolution A/B yet; calibration raw only; validation-only
evidence — test set locked.

## 18. Recommendation for Next Phase
Unlock the official test set for a SINGLE locked evaluation of the
frozen pipeline (binary @0.60 → 5-class), then SIH demo prep.
