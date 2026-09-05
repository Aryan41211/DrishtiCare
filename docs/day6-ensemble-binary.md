# DrishtiCare Day 6 — Advanced Optimization Report
(Ensemble + Threshold + Binary Referable Model)

## Comparison Table (all measured on 733-image validation set)

| Experiment | Accuracy | Macro F1 | QWK | Ref Sensitivity | Ref Specificity | Ref F1 |
|------------|----------|----------|-----|-----------------|-----------------|--------|
| 5-class baseline (champion) | 73.67% | 0.5083 | 0.7672 | 0.8307 | 0.8667 | 0.8267 |
| 5-class balanced | 68.21% | 0.5050 | 0.6887 | 0.8147 | 0.8286 | 0.7969 |
| Ensemble w=0.6 (best) | 74.08% | 0.5178 | 0.7807 | 0.8594 | 0.8667 | 0.8433 |
| Ensemble @thr 0.10 | — | — | — | 0.9265 | 0.7810 | 0.8345 |
| Binary referable @0.50 | 86.90% | n/a | n/a | 0.9262 | 0.8299 | 0.8519 |
| Binary referable @0.60 | — | — | — | **0.9027** | **0.8575** | — |

Binary ROC-AUC = 0.9496, PR-AUC = 0.9070.

## Answers

**A. Did the ensemble improve anything?**
Yes, modestly and on every metric: accuracy 73.67→74.08, macro F1
0.5083→0.5178, QWK 0.7672→0.7807, sensitivity 83.1%→85.9% at equal
specificity. Best weight w_baseline=0.6 selected by combined
(sens+spec+macroF1+QWK) score on validation.

**B. Did threshold tuning improve the tradeoff?**
Yes. Ensemble @thr 0.10 reaches 92.7% sensitivity (spec 78.1%).
Binary @thr 0.60 reaches **90.3% sensitivity with 85.8% specificity**,
meeting the SIH >90%/>85% target on validation. No threshold reaches
both targets for the 5-class models — reported honestly.

**C. Did the dedicated binary model improve screening?**
Yes, substantially. Sensitivity 83.1%→92.6% (argmax), AUC 0.95.
Binary screening + 5-class grading is now the recommended pipeline:
binary gates referable cases, 5-class model grades severity.

**D. Hierarchical grading?**
Not trained. With binary screening at 90.3%/85.8%, the remaining gap
is 5-class severity (Severe recall 18–38%). A 3-class severity model on
only ~1,271 referable images (Severe n=154) is unlikely to beat the
existing 5-class head from scratch. Recommended only after pretrained
weights are available.

**E/F. Champion and screening pipeline.**
- Grading champion: ensemble w=0.6 (74.08%, QWK 0.78).
- Screening champion: binary @thr 0.60 (90.3%/85.8%).
- Pipeline: binary screens → 5-class ensemble grades.

**G. What blocks >90%/>85% simultaneously?**
From-scratch features (no pretrained weights) + Severe n=154.
Severe recall is 18–38% across all runs.

**H. Next.**
Install ResNet-18 support package (pretrained) or move training to
GPU/Colab; then re-run the identical pipeline. Consider enhancement
on/off comparison and 320px input only after that.

## Guarantees
- Champion `day5_resnet18_baseline_stage2.mat`: never overwritten.
- Official 1,928 test images: NEVER used (training NO, threshold NO,
  selection NO, ensemble NO).
- No leakage: train/val disjoint, test excluded (asserted in code).
- No fabricated metrics: every number above is measured.

**Day 6 advanced performance optimization completed. Best validation
model identified. Official test set remains untouched and is ready
only for final locked evaluation.**
