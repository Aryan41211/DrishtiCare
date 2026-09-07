# Task 0 — Full Re-Verification Report

Date: 08-Sep-2026 03:15
Auditor: re_verify_audit.m (fresh re-run, committed)
Result: **PASS — 21/21 checks, all documented headline numbers reproduce exactly.**

## Method

Fresh end-to-end re-run, not a doc check:
- Loaded both champion DAG networks (`day7_pretrained_resnet18_5class_stage2.mat`,
  `day7_pretrained_resnet18_binary_stage2.mat`) from `data/models`.
- Re-ran inference on all **733** validation images (identical preprocessing:
  `imresize` to 224x224, raw pRef).
- Recomputed 5-class and binary metrics from scratch.
- Re-checked train/val/test overlap at image-ID level (names only; test set was
  never opened, only listed).
- Re-verified `split_info`, oversampling placement, and threshold lock in code.

Inference runtime: 56 s for 733 images (~0.076 s/img).

## Results

### Overlap (fresh, image-ID level)
| Pair             | Intersection | Expected | Status |
|------------------|--------------|----------|--------|
| train ∩ val      | 0            | 0        | PASS   |
| train ∩ test     | 0            | 0        | PASS   |
| val ∩ test       | 0            | 0        | PASS   |
| train count      | 2929         | 2929     | PASS   |
| val count        | 733          | 733      | PASS   |
| test count       | 1928         | n/a      |       |

### 5-class metrics (fresh)
| Metric             | Fresh | Documented | Status |
|--------------------|-------|------------|--------|
| accuracy           | 0.8281 | 0.8281    | PASS   |
| macro F1           | 0.6805 | 0.6805    | PASS   |
| quadratic Kappa    | 0.8914 | 0.8914    | PASS   |
| recall NoDR        | 0.9834 | 0.9834    | PASS   |
| recall Mild        | 0.6081 | 0.6081    | PASS   |
| recall Moderate    | 0.7850 | 0.7850    | PASS   |
| recall Severe      | 0.4872 | 0.4872    | PASS   |
| recall Proliferativ| 0.5254 | 0.5254    | PASS   |

### Binary metrics @ 0.60 (fresh)
| Metric        | Fresh | Documented | Status |
|---------------|-------|------------|--------|
| sensitivity   | 0.9060 | 0.9060    | PASS   |
| specificity   | 0.9471 | 0.9471    | PASS   |
| ROC-AUC       | 0.9796 | 0.9796    | PASS   |
| PR-AUC        | 0.7821 | 0.7821    | PASS   |

Confusion @0.60: tp=270, fp=23, fn=28, tn=412.

### Split + threshold
- split seed 42, ratio 0.80, train 2929 / val 733, date 06-Sep-2026 16:56:13 — PASS
- train dir counts per class [1444 296 799 154 236] == split_info.trainCounts — PASS
- Threshold 0.60 hard-coded in `predictSingleFundus.m` (default) and
  `cascade_router.m` (`def.pRefLocked`) and was NOT changed — PASS

## Test-set policy
Only the image-ID list of the closed test set was read for the overlap check.
No labels loaded, no inference run. The lock remains in force.

## Stale-plan reconciliation (from Task 0 metadata audit)
The staged plan was written against an earlier repo state (HEAD 1749ef3, 2
unpushed commits, ~19 uncommitted files). Actual state at audit start:
- HEAD c4d30ec == origin/main, working tree clean.
- Prior modules (calibration T=2.5382, Branch B + fusion, OD-CNN locator,
  explanation narrative) are all committed and pushed.
- Fovea detection (plan Task 11) was already run and is an honest negative —
  reported, not re-run.
- Confidence calibration (plan Task 5, binary) is already implemented and
  re-verified at `current_T.mat`; a 5-class calibration reliability check
  remains as the genuine open piece of that task.

## Artifacts
- `src/re_verify_audit.m` — audit script (re-runnable)
- `data/analysis/day8/reverify_audit_T0.mat` — raw metrics + predictions