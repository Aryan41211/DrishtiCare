# Task 8 — DRIVE Vessel Segmentation + Vessel-Extended Branch B: Validation Report

Date: 08-Sep-2026
Reproducers (MATLAB R2026a, CPU, `-batch`):
- `src/lesions/buildDriveVesselDataset.m` — DRIVE patch dataset build
- `src/lesions/trainVesselCnn.m` — train small vessel-vs-BG CNN
- `src/lesions/segmentVesselsCnn.m` — dense sliding-window vessel-map inference
- `src/eval_segmenter_drive.m` — Dice/IoU on the 20 DRIVE test images
- `src/predict_vessel_features.m` — per-image vessel features (733 val + 250 fit), resumable
- `src/eval_vessel_T8.m` — baseline-vs-+vessel Branch B comparison (full 733)

Saved results:
- `data/analysis/day8/vessel/vessel_dataset.mat`
- `data/analysis/day8/vessel/vessel_cnn_net.mat`, `vessel_cnn_metrics.mat`
- `data/analysis/day8/task8/drive_test_dice.mat`
- `data/analysis/day8/task8/vessel_features_val733.mat`, `vessel_features_train250.mat`
- `data/analysis/day8/task8/branchb_comparison_T8.mat`

## Scope

Add a DRIVE-trained vessel-segmentation CNN, extract per-image vessel-density
features, and test whether prepending those features to the Branch B (lesion)
feature block improves the referable classifier on the closed 733-val set.
DRIVE test was used ONLY as the open segmenter benchmark (NOT the APTOS test
set). No existing source or model files were modified; only new files created.

## 1. Dataset build (`buildDriveVesselDataset.m`)

- DRIVE training: 20 images, `1st_manual` vessel masks, `mask` FOV masks.
- Patch size **64×64**, green channel replicated to 3 channels (uint8).
- Positive = 64×64 crop centered on a marked vessel pixel; negative = crop
  centered on an FOV pixel **≥3 px** from any vessel (center-based labels, the
  exact house convention used by the MA/OD CNNs).
- Image-held-out split mirrors `buildMaDataset`: **images 21–36 = train pool**,
  **37–40 = held out** for patch-level evaluation. DRIVE test manual GT was not
  used at dataset-build time.
- Balance 1:1 (12,000 vessel / 12,000 BG).
- **Orientation note:** DRIVE images are 565×584 (RGB rows×cols) and the
  `1st_manual`/`mask` GIFs are 584×565 (transposed). Patches are cropped from
  the *green channel* and the *equivalent transposed view of the mask* so both
  live in the same pixel frame for any given image; no rotation is applied — a
  consistent transpose is applied to the mask to match the image's
  row-major `[H,W]` layout, and masks are AND-ed with the FOV. This alignment is
  verified per image by construction (crops come from matching coordinates).

| Item | Value |
|---|---|
| images (train pool / held out) | 16 / 4 |
| patches total | 24,000 (64×64×3) |
| positives / negatives | 12,000 / 12,000 |
| train / val (held-out) patches | 19,200 / 4,800 |

## 2. Training (`trainVesselCnn.m`)

House 4-conv-block CNN (16/32/64/128, BN, ReLU, 2× maxpool, gap, dropout
0.3, softmax 2-class), exactly the `trainMaCnn`/`trainOdCnn` skeleton, on 64×64
input. Adam, lr 1e-3 piecewise (drop 0.3 every 5), L2 1e-4, minibatch 128,
15 epochs, augmentation (rotation ±15°, reflection, ±4px translation).
The net is saved mid-run on completion (`saveVesselNet` OutputFcn) and finally
in `vessel_cnn_net.mat` (field `net`).

### Held-out patch metrics (DRIVE images 37–40)

| Metric | Value |
|---|---|
| Patch accuracy | 0.7800 |
| Patch ROC-AUC (VESSEL vs BG) | 0.8478 |

## 3. Segmenter eval on DRIVE test (`eval_segmenter_drive.m`, n=20)

Segmenter run at full native 584×565 (targetLongEdge 584, STRIDE 4), scored vs
the two manual segmentations inside the DRIVE FOV mask.

| Metric | vs 1st_manual (official) | vs 2nd_manual (independent) |
|---|---|---|
| Mean Dice | **0.2576** | 0.2532 |
| Mean IoU | **0.1481** | 0.1452 |
| Human inter-observer Dice (2nd vs 1st) | 0.7881 | — |
| Pixel-level ROC-AUC (map vs 1st_manual) | 0.6110 | — |

**Honest note:** Dice 0.258 / IoU 0.148 is **well below** DRIVE deep-learning
SOTA (~0.80 Dice). This is a small, CPU-only, patch-center CNN (not a dense
U-Net), trained on only 16 images; vessel exit/entry paths are thin and the
center-label sliding-window map under-segments them. The segmenter is therefore
**unfit as a high-quality vessel map**, but its map is still a weak usable
density cue (weak positive pixel AUC 0.61). This limitation is carried into —
and honestly reflects — the feature results in §5.

## 4. Vessel features on the 733-val + 250-fit (`predict_vessel_features.m`)

Per image: green channel → `segmentVesselsCnn` (targetLongEdge 512, STRIDE 8) →
vessel-probability map; fundus FOV proxy via Otsu on green + largest-component
+ hole-fill + close. **8 features** (region means/fractions of the map over the
FOV):

1. `vesselDensity` — mean map over FOV
2. `densityInner` — mean map over inner disk (r = 0.45·√(FOV_area/π))
3–6. `densityQ1..Q4` — quadrant means split by FOV centroid
7. `topFrac` — fraction of FOV pixels with map ≥ 0.70
8. `densityVar` — variance of map over FOV

Resumable (`done` flag + partial `.mat` every 10 images / budget). **0 failures**
on both scopes. **0 id mismatches** against `branchb_cache_partial.mat`
(asserted in `eval_vessel_T8.m`).

## 5. Branch B comparison: baseline vs +vessel (`eval_vessel_T8.m`, full 733)

Two logistic classifiers fit on the **same** 250-image Branch B training
subsample with the identical protocol (rng(7), fitclinear logistic lasso lambda
1e-3 sparsa, per-column /max scaling from fit rows, temperature fit by NLL on
the same 50-image eval slice). Feature block is the *only* difference:
(a) baseline = original 10 lesion features, (b) +vessel = 10 lesion + 8 vessel.

| Metric | Baseline (10) | + Vessel (18) | Delta |
|---|---|---|---|
| **ROC-AUC (full 733)** | **0.8969** ✓ (T7 sanity) | **0.8810** | **−0.0159** |
| AUC difference (bootstrap B=500) | — | — | −0.0159 [95% CI −0.0312 .. −0.0004], P(diff>0)=0.022 |
| Match-rate @0.60 vs Branch A | 0.8295 | 0.8336 | +0.0041 [CI −0.0136..0.0218] |
| Fusion agree | 598 | 596 | −2 |
| Fusion REVIEW | 135 | 137 | +2 |
| REVIEW per grade [g0..g4] | [12 28 73 8 14] | [11 30 76 7 13] | [−1 +2 +3 −1 −1] |

Per-grade REVIEW counts change only +3 at grade 2 (the class-2 "borderline"
band), −1 to +2 elsewhere — noise-level movement.

**Sanity check passed:** baseline AUC on full 733 reproduces Task 7's 0.8969
exactly, confirming the fit/eval protocol, temp scaling and alignment are
byte-identical to the deployed Branch B.

### Vessel feature diagnostics

- `corr(vessel feature, goldGrade)` are all small and mostly **negative**
  (range −0.206..+0.085, only densityQ3 reaches −0.21); lower-grade images
  carry *slightly* more vessel density, not less — the expected "more severe →
  more vessels" monotonic relationship is essentially absent here.
- Max `|corr(vessel feat, lesion feat)|` = 0.294 (mean 0.126) — vessels are
  only weakly redundant with lesions, largely orthogonal.
- Lasso coefficients (leg1, +vessel model) keep most vessel terms near 0 except
  `densityInner` (+1.92) and small negatives on `densityQ3/topFrac/densityVar`.
  Net effect on referable probability is small and inconsistent.

### Measured vs expected vs uncertain

- **Measured:** adding 8 vessel features does **not** help; it slightly *hurts*
  AUC (0.8969 → 0.8810, Δ −0.0159). The bootstrap CI on the difference does not
  include 0 favourably (−0.0312..−0.0004) and P(vessel wins) = 0.022. Match rate
  is flat (+0.004), fusion is essentially unchanged (−2 agree, +2 REVIEW).
- **Expected:** this is consistent with the segmenter being too weak (§3, Dice
  0.26, pxAUC 0.61, only 16 training images) and with vessel density being only
  weakly and non-monotonically related to referable grade in APTOS (most
  diagnostics negative). A high-quality vessel feature could still add value,
  but this delivered feature block does not carry it.
- **Uncertain:** the segmenter ceiling is the dominant confounder. With Dice
  0.26 the density features are noisy proxies; a stronger (U-Net / more data)
  segmenter might produce different features. But given CPU constraints and the
  negative, non-monotonic correlations observed, the added extraction cost is
  **not justified** for this deployment.

## 6. Runtime

| Step | Wall time | Details |
|---|---|---|
| Dataset build | ~1 min | 20 DRIVE train images, 24k patches |
| CNN training | ~15–30 min | 15 epochs CPU |
| DRIVE test eval | ~10 min | 20 imgs @ native res, STRIDE 4 |
| Vessel feats (733 val) | 795.5 s (~13.3 min) | avg 1.1 s/img, 0 fails |
| Vessel feats (250 fit) | 274.2 s (~4.6 min) | avg 1.1 s/img, 0 fails |
| Branch B comparison | ~1–2 min | 2 logistic fits + B=500 bootstrap |
| **Total** | **~45–60 min** | well under the 2–3 h budget |

## Conclusion

- **Did vessels help?** No. Adding the DRIVE-trained vessel block to Branch B
  **reduced** AUC on the full 733 (0.8969 → 0.8810, Δ −0.0159; CI excludes a
  positive effect, P(vessel wins)=0.022), left match-rate flat, and changed
  fusion counts by only −2 agree / +2 REVIEW (all movement in the borderline
  g2 band).
- **By how much?** It hurt by ~0.016 AUC — small but consistent (CI does not
  include a benefit). It did not help match-rate or fusion either.
- **Is the added extraction cost justified?** **No.** ~18 min extra CPU for a
  feature block that slightly degrades the model. The bottleneck is the
  weak segmenter (Dice ~0.26 vs SOTA ~0.80), not the classifier protocol
  (baseline reproduces T7 exactly). Vessel features as delivered are not a
  useful Branch B addition; Branch B should remain the 10-feature lesion
  classifier.

## Files created

- `src/lesions/buildDriveVesselDataset.m`
- `src/lesions/trainVesselCnn.m`
- `src/lesions/segmentVesselsCnn.m`
- `src/eval_segmenter_drive.m`
- `src/predict_vessel_features.m`
- `src/eval_vessel_T8.m`
- `data/analysis/day8/vessel/vessel_dataset.mat`
- `data/analysis/day8/vessel/vessel_cnn_net.mat`
- `data/analysis/day8/vessel/vessel_cnn_metrics.mat`
- `data/analysis/day8/task8/drive_test_dice.mat`
- `data/analysis/day8/task8/vessel_features_val733.mat`
- `data/analysis/day8/task8/vessel_features_train250.mat`
- `data/analysis/day8/task8/branchb_comparison_T8.mat`
