# Task Tracker (post-Day-7 corrective tasks)

Updated: 2026-09-08. Source of truth for the numbered
corrective tasks that started after the Day 7 champion
(`day7_pretrained_resnet18_5class`, val n=733: Acc 82.81%, Macro F1 0.6805,
QWK 0.8914; per-class recall Mild 60.81 / Moderate 78.50 / Severe 48.72 /
Proliferative 52.54, NoDR 98.34).

## Status

| Task | Description | Status | Notes |
|------|-------------|--------|-------|
| Task 3 | PR-AUC regression investigation (scratch vs pretrained binary) | ✅ Complete | `src/run_task3_prauc.m` + `data/analysis/day7/pr_auc_investigation.mat` |
| Task 4 | One-time official APTOS test-set evaluation | ✅ Complete — **test set now CLOSED** | `src/run_task4_test_eval.m` + `data/analysis/day8/test_evaluation.mat`. Local copy has NO test ground truth → only distribution/confidence/agreement metrics measured; accuracy/F1/QWK not computable. Binary threshold stays locked at 0.60. |
| Task 5(a) | `day8_5class_v2a` — corrected class weighting (uniform 800/class → targets 800/800/800/1000/1000) | ✅ **Complete (negative result on the target classes)** | Final model `data/models/day8_5class_v2a_stage2.mat`; metrics `data/analysis/day5/day8_5class_v2a_metrics.mat`; independently verified (`src/verify_taskB_metrics.m`, `day8_v2a_metrics_verification.mat`). One-line outcome: **Severe recall +0.00 pts, Proliferative recall +0.00 pts** (unchanged); Mild +2.70 pts, NoDR −0.56 pts, accuracy ±0.00, Macro F1 +0.0022, QWK −0.0037. Day7 champion retained. |
| Task 5(b) | Target-boosted weighting on Severe/Proliferative | ⛔ Skipped per operator decision | Recorded in `docs/day8/day8-task5-minority-recall.md`. Auto-chaining is disabled in code (`RUN_VARIANT_B = false`); launching it later still requires explicit user approval. |
| Task 5(c) | Targeted augmentation for Severe/Proliferative | ⛔ Skipped per operator decision | `RUN_VARIANT_C = false`. |
| Task 6 | Lesion-feature branch (IDRiD MA/HE/EX/SE masks) | ✅ Complete | Code: `src/lesions/extractLesionCandidates.m`, `src/run_task6_lesions.m`. Outputs: `data/analysis/day8/lesions/` (`lesion_features.mat` [gitignored, 116 MB], `lesion_summary.csv`, `lesion_montage.png`, `inspect_IDRiD_01..10.png` overlay figures for manual review). Report: `docs/day8/day8-task6-lesions.md`. Classical candidates (not deep segmentation); counts usable as relative features. |
| Inference + lesion evidence | Wire MA/HE/EX candidates + optic-disc into `predictSingleFundus` report | ✅ Complete | `src/lesions/estimateOpticDisc.m` (classical fallback), `src/lesions/locateOpticDiscCnn.m` (CNN primary), extended `src/inference/predictSingleFundus.m` (5-panel report). Verified on APTOS train images (grades 0–4). OD honesty: CNN 9/10 IDRiD within 300px (mask-centroid GT), classical 4/10; CNN + classical fallback wired in; "OD NOT located" flag retained for refused. |
| CNN microaneurysm detector | Replace broken classical MA (recall 0.002) with a trained CNN | ✅ Complete | `src/lesions/{buildMaDataset,trainMaCnn,hardNegMineMaCnn,evalMaCnn,detectMaCnn}.m` + integrated into `extractLesionCandidates.m` (threshold 0.9). 2,409 MA positives from the 54 IDRiD train images; 44/10 image-held-out. Held-out **patch AUC 0.976**, detection-level at thr 0.9: **recall 0.113, precision 0.595** (IDRiD 01–10, tol 12 px) — vs classical 0.002 recall / 0.003 precision. Trained nets in `data/analysis/day8/ma_cnn/ma_cnn_net.mat`; detection metrics `ma_cnn_detection.mat`. Counts are LOW-RECALL relative cues, not clinical-grade. |
| CNN optic-disc locator | Replace classical bright-blob OD heuristic with a trained CNN locator | ✅ Complete | `src/lesions/{buildOdDataset,trainOdCnn,hardNegMineOdCnn,locateOpticDiscCnn}.m`. OD/background CNN on 54 IDRiD OD masks (44/10 image-held-out), held-out **patch AUC 0.993**. Sliding-window locator (stride 48 @s4, ensemble of first-pass + hard-neg nets; fixed a coordinate-scrambling `reshape` bug): on IDRiD 01–10 vs mask centroids **9/10 within 300 px** (classical heuristic: 4/10). `predictSingleFundus` now uses the CNN with classical fallback. CSV center markups rejected as reference (disagree with masks by up to ~2000 px). Nets in `data/analysis/day8/od_cnn/od_cnn_net.mat`. |
| Explanation narrative + report layout | Generate a clinical-style, hedged explanation paragraph from model evidence; polish the report figure | ✅ Complete | `src/explainability/buildExplanationNarrative.m` (`.paragraph/.assessment/.evidence/.screening/.recommendation/.quality/.caveats`), wired into `predictSingleFundus` and shown in a 2-row figure (original \| enhanced \| Grad-CAM // lesion evidence \| decision metrics \| explanation). Verified across grades 0–4 on APTOS train. Explicit "engineering demo, not clinical advice" caveat; lesion counts flagged as automated candidates. |
| OOD detector | Mahalanobis-distance out-of-distribution gate on deep `pool5` features | ✅ Complete | `src/ood_detection/ood_detector.m` + `buildOodStats.m`, stats at `data/analysis/day8/ood/ood_stats.mat` (fit on 3,662 APTOS train images). Threshold = 99th percentile (34.2) → 1.01% false-OOD on training. Sanity: solid red / Gaussian-noise frames flagged OOD (Mah 74/160); blurred+darkened real image NOT flagged (deep features tolerant — by design). Wired into `predictSingleFundus` (guarded, degrades gracefully). |
| Fovea localization | Localize the fovea for exudate-to-fovea distance | ❌ Complete — **honest negative result** | Two attempts measured on IDRiD 01–10 vs fovea CSV of truth: patch CNN (`locateFoveaCnn`) 0/10 within 300 px (mean ~620 px); disc-relative anatomical estimate (K×disc-radius, K swept 2.0–3.5) mean error ~1400 px. Fovea is too subtle for these approaches. Pipeline does NOT emit a fovea-derived distance by default; `meanExudateDistToFovea` stays `NaN` unless a fovea center is supplied by the caller. Code retained in `src/lesions/` for future work. |
| Cascade router | Confidence router → CLEAR / REVIEW / ABSTAIN routing | ✅ Complete | `src/cascade_router/cascade_router.m` + `verify_cascade.m`. ABSTAIN if conf<0.50 or \|pRef−0.60\|<0.05; REVIEW if conf<0.75, margin<0.20, or screen/grade conflict; else CLEAR. All bands exercised synthetically; real APTOS train images → CLEAR. Wired into `predictSingleFundus`; feeds narrative governance sentence + forces manual-review recommendation when not CLEAR. |

## Task 5(a) vs day7 baseline — measured, validation n=733 (verified)

| Metric | day7_pretrained_resnet18_5class | day8_5class_v2a | Δ (pts) |
|--------|--------------------------------|-----------------|---------|
| NoDR recall | 98.34% | 97.78% | −0.56 |
| Mild recall | 60.81% | 63.51% | **+2.70** |
| Moderate recall | 78.50% | 78.50% | 0.00 |
| **Severe recall** | **48.72%** | **48.72%** | **0.00** |
| **Proliferative recall** | **52.54%** | **52.54%** | **0.00** |
| Accuracy | 82.81% | 82.81% | 0.00 |
| Macro F1 | 0.6805 | 0.6827 | +0.0022 |
| QWK | 0.8914 | 0.8877 | −0.0037 |

## Decision rule for Task 5 — applied outcome

- Rule branch that applies: **"recall barely moved or got worse on either
  class"** — Severe and Proliferative recall did not move at all (±0.00 pts).
  Strictly, the rule points to variant (b) as the next single isolated
  experiment **subject to explicit user approval**.
- However, the operator has already recorded the decision to **skip (b) and
  (c)** as separate training runs, with the interpretation that the
  Severe/Proliferative bottleneck is feature discriminability (errors are
  ±1-severity confusions), not training-data representation.
- **Net recommendation: accept Task 5 as PARTIAL (negative result kept on
  record) and move to Task 6 (lesion-feature branch)**, which is already
  underway. No variant (b)/(c) training will be launched without explicit
  user approval. Variant (c) remains off the table unless both (a) and (b)
  were tried and underperformed.

## Baseline to beat (measured, day7_pretrained_resnet18_5class)

| Metric | Value |
|--------|-------|
| Accuracy | 82.81% |
| Macro F1 | 0.6805 |
| QWK | 0.8914 |
| Mild recall | 60.81% |
| Moderate recall | 78.50% |
| Severe recall | 48.72% |
| Proliferative recall | 52.54% |

