# Task 5 — Minority-Class Recall (Severe, Proliferative)

## Scope
Per operator decision, only variant **(a)** was run (corrected class-weighting
wiring). Variants (b) boost-beyond-inverse-frequency and (c) targeted
augmentation were approved to be **skipped** as separate training runs.

## (a) Class-weighting verification — CONFIRMED + FIXED

**Before this task, the weighting mechanism was:**
- `config.imbalance.useClassWeights = true` but `config.imbalance.classWeights = []`
  (empty — never computed/used).
- The actual mechanism is **in-memory oversampling** in
  `trainClassifierDay8.m`/`trainClassifier.m` — all classes repeated to a
  uniform target (800/class in day7). That is *balanced* sampling (equal
  effective class weight), **not** inverse-frequency weighting.

**Ordering (Hard Constraint 5 verification):** oversampling happens strictly
**after** the train/val split. `trainClassifierDay8` builds the balanced
datastore from `data/splits/train` (training split only); the validation
datastore (`data/splits/val`) is separate and never oversampled. **No leakage —
verified by construction and by config paths.**

**Fix applied (variant a):** per-class targets changed from uniform `[800×5]`
to `[800, 800, 800, 1000, 1000]` — a higher effective weight specifically on
Severe and Proliferative (the two classes furthest from target).

## Variant (a) result — measured on validation (n=733)

| Class | Baseline (day7) | V(a) | Delta |
|---|---|---|---|
| NoDR | 98.34% | 97.78% | −0.56 |
| Mild | 60.81% | 63.51% | +2.70 |
| Moderate | 78.50% | 78.50% | 0.00 |
| Severe | 48.72% | 48.72% | 0.00 |
| Proliferative | 52.54% | 52.54% | 0.00 |
| Accuracy | 82.81% | 82.81% | 0.00 |
| Macro F1 | 0.6805 | 0.6827 | +0.0022 |
| QWK | 0.8914 | 0.8877 | −0.0037 |

## Interpretation

Boosting Severe/Proliferative oversampling did **not** change their recall
(bit-identical predictions to baseline for those classes). Mild improved.
The bottleneck for Severe/Proliferative is not training-data representation;
it is feature discrimainability — these images are confused with adjacent
severity levels (consistent with error analysis: MAE 0.2278, 95.4% of errors
within ±1 severity). More weight on the same ResNet-18 224px features does
not create new discriminative signal.

## Artifacts
- Model: `data/models/day8_5class_v2a_stage2.mat` (does NOT overwrite champion)
- Metrics: `data/analysis/day5/day8_5class_v2a_metrics.mat`
- Comparison table stored in `metricsA` structure.

## Independent verification (Task B cross-check, 2026-09-07 00:55)

All numbers above were re-derived from the stored artifacts
(`day8_5class_v2a_metrics.mat` + model file) via
`src/verify_taskB_metrics.m` — every value matched (tolerance 5e-4):

- `metricsA.totalSamples` = 733 (same validation split as the day7 baseline;
  true-class counts: NoDR 361, Mild 74, Moderate 200, Severe 39, Proliferative 59)
- Accuracy 0.828104 → 82.81% ✔ · Macro F1 0.682676 → 0.6827 ✔
- Recalls [0.977839, 0.635135, 0.785000, 0.487179, 0.525424] ✔
- QWK **recomputed from stored YTrue/YPred** = 0.887696 → 0.8877 ✔
- Stored confusion matrix matches the recomputed one exactly (max abs diff 0)
- `balA` confirms the one changed variable: targets `[800 800 800 1000 1000]`
  (day7 used uniform 800×5)
- Verification artifact: `data/analysis/day5/day8_v2a_metrics_verification.mat`

## Status
**Task 5: PARTIAL** — variant (a) complete and reported. Variants (b) and (c)
were approved to be skipped by the operator. The day7 champion remains the
grading champion (82.81%); day8_5class_v2a is a non-overwriting checkpoint.