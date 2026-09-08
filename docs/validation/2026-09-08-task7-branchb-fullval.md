# Task 7 — Branch B Lesion-Feature Classifier: Full 733-Image Validation Evaluation

Date: 08-Sep-2026
Reproducer: `src/eval_branchb_fullval_T7.m` (MATLAB R2026a, CPU, `-batch`)
Saved results: `data/analysis/day8/task7/branchb_fullval_T7.mat`
Extraction cache: `data/analysis/day8/task7/branchb_cache_partial.mat`

## What was measured

- **Full feature extraction** on **all 733 validation images** (split dirs
  `data/splits/val/class_{0..4}`, sorted listing — same order as
  `reverify_audit_T0.mat`, verified: **0 alignment mismatches** between the
  folder grade and YTrue5−1). Extraction used the exact
  `build_aptos_feature_cache.m` recipe: `locateOpticDiscCnn(imread(imgPath))`
  OD callback (P<0.90 → odLocated=0), then
  `extractLesionCandidates(imgPath, odCenter/odRadius)`. Feature failures: **0**.
- **Branch B predictions** reused the existing 250-image-subsample logistic
  model (`data/analysis/day8/branch_b/branchB_model.mat`, `ClassificationLinear`,
  T=0.7139) via `branch_b_predict`. **No retraining, no threshold change.**
- **Branch A** reused the fresh audit predictions (`PRef`, `YTrue5`, `YPred5`,
  `s5All`). Referable ground truth = gold grade ≥ 2 (YTrue5 ≥ 3). **No
  re-inference.**
- Test set untouched. No existing source files modified (only the new eval
  script).

## Measured results (full 733)

| Metric | Value |
|---|---|
| **Branch B ROC-AUC (full 733)** | **0.8969** |
| Branch A ROC-AUC (recheck) | 0.9796 (= audit/reproduced exactly) |
| Match rate @0.60 (A decision vs B decision) | 0.8295 |
| A referable (PRef ≥ 0.60) | n = 293 |
| — of which B agrees (pRefB ≥ 0.60) | 206 (70.3%) |
| A non-referable | n = 440 |
| — of which B agrees (pRefB < 0.60) | 402 (91.4%) |
| Fusion: agree | 598 / 733 (81.6%) |
| Fusion: discrepancy → REVIEW | 135 / 733 (18.4%) |
| OD located (odLocated mean) | 0.1064 (~10.6%) |

### Per-grade Branch B mean `pRefB` (n / mean / range)

| Grade | n | mean | min | max |
|---|---|---|---|---|
| g0 | 361 | 0.2288 | 0.1374 | 0.8498 |
| g1 | 74 | 0.5249 | 0.1406 | 1.0000 |
| g2 | 200 | 0.6995 | 0.1399 | 1.0000 |
| g3 | 39 | 0.7887 | 0.1509 | 0.9999 |
| g4 | 59 | 0.7717 | 0.1683 | 1.0000 |

Monotone with grade up to g3, then flat/down at g4 (g4 mean 0.772 < g3 0.789;
corr(pRefB, grade) = 0.707, corr(pRefB, PRef) = 0.741).

### Fusion breakdown (via `fuseEvidence`, exactly as `predictSingleFundus.m`:
A referable = predicted grade ≥ 2 OR calibrated PRef ≥ 0.60; B referable =
pRefB ≥ 0.60; A confident = max 5-class softmax ≥ 0.80)

| Case | Count | Fusion result |
|---|---|---|
| Both referable | 206 | agree |
| A referable, B non-referable | 87 | discrepancy → REVIEW (never downgrades A) |
| A non-referable, B referable | 38 | discrepancy → REVIEW |
| Both non-referable, A confident | 392 | agree |
| Both non-referable, A **not** confident | 10 | discrepancy → REVIEW |

Agree 598 = 206 + 392. REVIEW 135 = 87 + 38 + 10. Sum 733.

### Runtime

- Full extraction: **5623 s (~1.56 h)** wall time for 733 images, **avg
  7.7 s/image** (within the expected 3.4–13.3 s/im range; slower pages appear
  later in the sorted order). 0 extraction failures; 1 cache resume was not
  needed (single uninterrupted run).

## Interpretation (measured vs expected vs uncertain)

- **Measured:** on the full 733-val set Branch B is a **real but weak
  independent cue**: AUC 0.8969 vs Branch A's 0.9796; decision match @0.60 is
  82.95%. Branch B mostly adds value only as an internal consistency check: it
  agrees with A on 81.6% of images and flags **18.4% as needs-review**.
- **Of the 135 REVIEW flags, 87 (64%) never downgrade a referable A**; they
  surface for manual review while A's referable decision stands — consistent
  with the design intent (A referable ⇒ stays referable). 10 are both-non-
  referable with low A confidence (the genuinely uncertain tail), and 38 are
  A non-referable / B referable (B pulls up — can trigger review of a
  presumably-clear image).
- **Expected:** Branch B was trained on only 250 images and its lesion counts
  are heuristic; an AUC well below Branch A and high (70.3%) but imperfect B
  agreement on referable images is consistent with a weak auxiliary signal.
  The monotone-then-flat per-grade profile (saturates at g3+) mirrors the
  limited lesion-headroom of the classical extractor.
- **Uncertain:** (1) OD localization succeeded on only **~10.6%** of images
  (locateOpticDiscCnn P<0.90 threshold; consistent with the previously
  documented ~13% OD-accept caveat), so features 8–10 (odLocated / exNearDisc /
  meanExDistToDisc) are mostly 0/noise — a likely floor on achievable B AUC,
  not a ceiling test of the lesion features themselves. (2) The full-test-set
  fusion rate is unknowable from this data; the test set was not touched.

## Caveats

- The 250-image-trained model was reused as-is per approved scope (no
  retraining). Branch B AUC 0.8969 is therefore an honesty estimate of the
  *deployed* model, not of a retrained one.
- Branch A numbers reproduce the day7 audit exactly (AUC 0.9796), and the
  sorted-listing alignment check passed with 0 mismatches.
- Decision threshold locked at 0.60 for both branches; none changed.

## Files

- `src/eval_branchb_fullval_T7.m` — reproducer (resumable via partial cache).
- `data/analysis/day8/task7/branchb_cache_partial.mat` — X (733×10), ids,
  done, grade, failed, extractionTimeSec.
- `data/analysis/day8/task7/branchb_fullval_T7.mat` — X, pRefB, PRef, YTrue5,
  goldGrade, aucB, aucA, matchRate, perGrade, perGradeN, nARef/nARefBAg/
  nANonRef/nANonRefBAg, odLocatedMean, nAgree, nDiscrepancy, extractionTimeSec,
  alignMiss, failed.