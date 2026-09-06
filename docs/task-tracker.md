# Task Tracker (post-Day-7 corrective tasks)

Updated: 2026-09-07. Source of truth for the numbered
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

