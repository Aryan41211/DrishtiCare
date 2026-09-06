# Task Tracker (post-Day-7 corrective tasks)

Updated: 2026-09-07 ~00:15 (local). Source of truth for the numbered
corrective tasks that started after the Day 7 champion
(`day7_pretrained_resnet18_5class`, val n=733: Acc 82.81%, Macro F1 0.6805,
QWK 0.8914; per-class recall Mild 60.81 / Moderate 78.50 / Severe 48.72 /
Proliferative 52.54, NoDR 98.34).

## Status

| Task | Description | Status | Notes |
|------|-------------|--------|-------|
| Task 3 | PR-AUC regression investigation (scratch vs pretrained binary) | ✅ Complete | `src/run_task3_prauc.m` + `data/analysis/day7/pr_auc_investigation.mat` |
| Task 4 | One-time official APTOS test-set evaluation | ✅ Complete — **test set now CLOSED** | `src/run_task4_test_eval.m` + `data/analysis/day8/test_evaluation.mat`. Local copy has NO test ground truth → only distribution/confidence/agreement metrics measured; accuracy/F1/QWK not computable. Binary threshold stays locked at 0.60. |
| Task 5(a) | `day8_5class_v2a` — corrected class weighting (was uniform 800/class, now per-class targets 800/800/800/1000/1000 for classes 0–4) | 🔶 **IN PROGRESS — training running** | Stage-2 run started 23:45:57 on 2026-09-06. Last observed checkpoint: iteration 274 @ 00:03:23 (`data/models/checkpoints/day8_5class_v2a_stage2/`). Final `data/models/day8_5class_v2a_stage2.mat` **not yet saved**. Evaluation vs day7 baseline (Task B) pending until training completes. |
| Task 5(b) | Target-boosted weighting on Severe/Proliferative | ⛔ Blocked — needs explicit user approval | Auto-chaining disabled in `src/run_task5_minority_recall.m` (`RUN_VARIANT_B = false`). Decision only AFTER Task 5(a) numbers exist. |
| Task 5(c) | Targeted augmentation for Severe/Proliferative | ⛔ Not started — only if both (a) and (b) underperform | `RUN_VARIANT_C = false`. |
| Task 6 | Lesion-feature branch (IDRiD MA/HE/EX/SE masks) | 🔹 Prep done | Annotation-format reference: `docs/idrid-lesion-annotations.md`. Implementation not started. |

## Decision rule for Task 5 (apply after Task B evaluation)

- If Severe AND Proliferative recall both improved by a meaningful margin
  (beyond run-to-run noise) → mark Task 5 sufficient, move directly to
  Task 6 (lesion-feature branch). Do NOT queue variant (b)/(c).
- If recall barely moved or got worse on either class → the next single
  isolated experiment is variant (b), **launching only with explicit user
  approval**. Variant (c) is not queued.

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

(Task 5(a) result columns will be appended here after the Task B evaluation
on the same 733-image validation split.)
