# Day 7 — Training Pipeline Audit (pretrained_pipeline_audit.md)

Date: 2026-09-06. Auditor: code inspection + git history + verification runs.
No training code modified during audit. No test set touched.

## 1–3. Loading, labels, split
- `prepareData`: `imageDatastore(data/splits/{train,val}/class_X)`,
  `LabelSource foldernames` → categorical `class_0..class_4`, mapped to
  indices 1..5 (NoDR, Mild, Moderate, Severe, Proliferative).
- Stratified 80/20, `rng(42)` → train 2929 / val 733. Test-set overlap
  asserted empty. No leakage detected.
- `prepareBinaryData` reuses the SAME split IDs via folder copy
  (class_0,1 → nonreferable; class_2,3,4 → referable). No re-split.

## 4–5. Resize, pixels, normalization
- `imresize` to 224×224×3 (bilinear default), uint8 0–255 in.
- Normalization comes from ResNet-18's own `imageInputLayer`
  (zerocenter, ImageNet mean) — identical layer spec in the untrained
  architecture and the pretrained net, so the input path is consistent.
- Eval scripts (`evaluateClassifier`, binary, ensemble) use the same
  `imresize` to 224×224. Training and validation preprocessing match
  (modulo augmentation, below).

## 6–8. Enhancement, CLAHE, illumination — NOT in training path
- `prepareData` copies RAW PNGs. `trainClassifier` never calls
  `enhanceImage`/CLAHE. Day 4 enhancement is currently dashboard-only.
- Any enhancement comparison must be a NEW controlled experiment.

## 9–10. Augmentation — material finding
- Config: rotation ±15°, x-reflection, translation ±10px, shear ±5°.
  Brightness/contrast NOT supported by `imageDataAugmenter` (verified
  against R2026a docs); absent everywhere.
- **Baseline champion (73.67%) trained with NO augmentation**: the code
  path used then ("Using original training datastore") built the
  `augmenter` object but never attached it; `prepareData` datastores
  only resize. Verified via run log + git history (7a64ef1).
- Balanced/binary runs DO augment (attached inside
  `createBalancedDatastore`). So baseline-vs-balanced comparisons
  conflate balancing AND augmentation. Recorded here for fairness.

## 11–17. Hyperparameters, stages, freezing
- Input 224×224×3. Adam. Stage 1: batch 32, LR 1e-3 (new head ×10 via
  learn-rate factors), backbone first 60 layers frozen (only head trains).
- Stage 2: full unfreeze, LR 1e-5, batch 16 (5-class) — same schedule
  reused for binary (batch 32/16, 15 epochs each).
- Epochs: 5-class 10–15 (S1) / 7–20 (S2, early stop patience 8);
  binary 15/15. Piecewise decay ×0.5 every 5 epochs.
- Validation every epoch (`floor(N/batch)` iters), deterministic.
- All models start randomly initialized (scratch). No pretrained weights
  used anywhere to date.

## 18–22. Validation methodology
- `trainNetwork` validation accuracy + final `evaluateClassifier` on raw
  val folders agree after the label-mapping fix (70.40 vs 70.12; 73.40
  vs 73.67). Probabilities via `predict` (DAGNetwork scores sum to 1,
  asserted in ensemble script). Class order class_0..class_4 verified
  identical across all saved models.

## Implications for pretrained experiments
1. Reuse the pipeline UNCHANGED except `usePretrained=true` + new
   experiment IDs — this isolates initialization as the variable
   (plus the documented augmentation difference vs the old baseline).
2. Stage 1 (head-only, effective head LR 1e-2) and Stage 2 (full
   unfreeze, LR 1e-5) are already correct transfer-learning structure.
3. `resnet18()` DAGNetwork verified working with `layerGraph`
   (71 layers) — no pipeline rewrite needed.
4. Resolution (320px) SKIPPED: ~2.5× CPU cost per run for an
   already 5–6h queue; revisit on GPU.
5. Enhancement A/B deferred: same reason; documented, not silent.

Saved: data/analysis/day7/training_pipeline_audit.mat (this doc's metrics table).
