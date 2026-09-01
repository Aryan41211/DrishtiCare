# Validation Metrics — Per Component

## Referable DR (Level ≥2) — Headline Metrics

| Metric | Target | Notes |
|--------|--------|-------|
| Sensitivity | >90% | Bootstrap 95% CI |
| Specificity | >85% | Bootstrap 95% CI |
| PPV | Report | Bootstrap 95% CI |
| NPV | Report | Bootstrap 95% CI |
| AUC-ROC | >0.95 | Bootstrap 95% CI |
| AUC-PR | Report | Bootstrap 95% CI |

## 5-Class Grading

| Metric | Notes |
|--------|-------|
| QWK | Primary metric for ordinal classification |
| Per-class recall | Especially for rare grades (1, 3) |
| Confusion matrix | Full 5×5 |

## Lesion Detection (IDRiD test set)

| Lesion | Metric |
|--------|--------|
| MA | FROC curve at 1, 2, 4, 8 FP/image |
| HE | FROC + quadrant counts |
| EX | AUC-PR + distance-to-fovea accuracy |
| SE | Binary accuracy + AUC |

## Calibration

| Metric | Target |
|--------|--------|
| ECE | <0.05 |
| Brier score | <0.15 |
| Reliability diagram | Near-diagonal |

## Explainability

| Metric | Target |
|--------|--------|
| Saliency-in-lesion fraction | >60% |
| Pointing game | >70% |
| IoU vs lesion masks | >0.3 |
| MACE | <10 px |
