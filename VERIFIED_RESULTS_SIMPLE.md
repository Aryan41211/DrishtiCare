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
4. Open: manifest hashes need updating before judging.
