# DrishtiCare — Verified Results

> Fresh-tested 17-Sep-2026 · n=733 val · Official 1,928 test set sealed/untouched

## 1. Headline scores

| # | Metric | Value |
|---|---|---|
| 1 | 5-class accuracy | 82.81% (607/733) |
| 2 | 5-class macro F1 | 0.6805 |
| 3 | 5-class QWK | 0.8914 |
| 4 | Screening sensitivity @0.60 | 90.60% (270/298) |
| 5 | Screening specificity @0.60 | 94.71% (412/435) |
| 6 | Screening accuracy @0.60 | 93.04% (682/733) |
| 7 | ROC-AUC | 0.9796 |
| 8 | PR-AUC | 0.7821 |

## 2. Per-class recall

| # | Class | Support | Recall | Correct |
|---|---|---|---|---|
| 1 | No DR | 361 | 98.34% | 355 |
| 2 | Mild | 74 | 60.81% | 45 |
| 3 | Moderate | 200 | 78.50% | 157 |
| 4 | Severe | 39 | 48.72% | 19 |
| 5 | Proliferative | 59 | 52.54% | 31 |

## 3. Supporting modules

| # | Module | Result |
|---|---|---|
| 1 | Quality gate (3,662 imgs) | PASS 65.5% / WARNING 26.7% / FAIL 7.8% |
| 2 | Branch-B evidence model | AUC 0.8969, agrees 82.95% |
| 3 | Vessel segmentation (DRIVE) | Dice ~0.75 (human 0.79) |
| 4 | Smoke test (100 imgs) | 68% |
| 5 | Enhancement A/B | Hurts grading — not used |

## 4. Caveats

1. No 98–99% overall accuracy exists (98% = healthy-only recall; 0.97 = ranking score).
2. Weak spots: Severe (48.7%), Proliferative (52.5%).
3. Validation-only — not hospital-tested.
4. ~~Open: manifest hashes need updating before judging.~~ **RESOLVED (closed
   2026-09-25).** The manifest hash drift was corrected at Phase 25 — see
   `audit/improvement_baseline/baseline_manifest.md:28`, which now records that
   the `day8_5class_v2a` stage1 checkpoint was never committed, and
   `docs/validation/2026-09-10-hardening-phase25-capstone.md` (disposition 2).
   The two locked champion SHA-256s were re-verified intact in Phase 17
   (`docs/validation/2026-09-10-hardening-phase17-immutability.md`, 8/8 PASS).
   **Nothing is outstanding on the manifest before judging.** This item is kept
   struck-through rather than deleted so the closure stays auditable.

## 5. Where the full metric table lives

`docs/validation/metrics.md` is the complete **target-vs-measured** source of
truth, including the explainability metrics this summary does not cover — the
champion's Grad-CAM saliency lands inside an IDRiD lesion only ~3.1% of the
time (pointing game 7.4%, IoU 0.035, n=81), far short of the original >60% /
>70% / >0.3 targets. Those targets were missed, not met.
