# Hardening Phase 7 — Metric Definition Freeze

Date: 10-Sep-2026 00:31
Auditor: `src/phase7_metric_freeze.m`
Result: **PASS — 12/12 checks.** The exact metric formulas from the committed
evaluation path are locked and reproduce every headline figure on the cached
locked-val arrays. A machine-readable registry (`phase7_metric_freeze.json`)
is the single source of truth for all downstream reports and audits.

## Frozen metric definitions (axis 1 = label encoding: 1-based 1..5)

| Metric | Frozen formula | Committed ref |
|--------|----------------|---------------|
| accuracy | `mean(YPred==YTrue)` (per-image) | 0.8281 |
| per-class recall(_c_) | `tp_c/(tp_c+fn_c+eps)` from 5×5 confusion | e.g. NoDR 0.9834, Prolif 0.5254 |
| per-class F1(_c_) | `2*tp_c/(2*tp_c+fp_c+fn_c+eps)` | — |
| macroF1 | `mean(per-class F1)` | 0.6805 |
| QWK | `W=(i-j)²/16`; `O`=confusion; `E=row·col/n`; `1 − Σ(W·O)/(Σ(W·E)+eps)` | 0.8914 |
| binary decision | `PRef ≥ 0.60` (`PRef` = binary screener channel 2, P(referable)) | locked |
| referable ground truth | 1-based label ≥ 3 ⇔ grade ≥ 2 (Moderate+) | — |
| bin sens | `TP/(TP+FN+eps)` | 0.9060 |
| bin spec | `TN/(TN+FP+eps)` | 0.9471 |
| ROC-AUC | `perfcurve(posclass=true)` | 0.9796 |
| PR-AUC | `perfcurve(XCrit='tpr', YCrit='prec')` | 0.7821 |

`eps` policy mirrors the committed evaluators (`re_verify_audit.m`,
`evaluateClassifier.m`, `evaluateBinaryClassifier.m`, `computeQWK`):
`eps()` is added to every denominator to avoid divide-by-zero for
unsupported classes.

## Rule

All reports and audits MUST recompute metrics via these frozen definitions.
No alternative macro-average (e.g., harmonic-mean form), QWK normalization
(e.g., unnormalized weights — mathematically equal but not the committed
form), or binary orientation may be substituted. Any future metric MUST be a
new named definition, not a silent reinterpretation.

## Checks (fresh recompute from `reverify_audit_T0.mat`, no re-inference)

- acc 0.8281, macroF1 0.6805, QWK 0.8914 ✔
- per-class recall [0.9834 0.6081 0.7850 0.4872 0.5254] ✔
- binary @0.60: sens 0.9060, spec 0.9471, ROC-AUC 0.9796, PR-AUC 0.7821 ✔

## Artifacts

- `src/phase7_metric_freeze.m`
- `data/analysis/day10/phase7/phase7_metric_freeze.mat` (+ recomputed vectors)
- `data/analysis/day10/phase7/phase7_metric_freeze.json` (machine-readable
  definition registry + mandate)

## Rollback

Read-only audit; no production code changed.
---
Engineering demo, NOT a clinical device: all cited metrics are engineering measurements on validation-set artifacts from the frozen protocol (Phase 10); no clinical validation is claimed.
