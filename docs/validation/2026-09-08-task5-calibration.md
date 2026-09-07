# Task 5 — Confidence Calibration Verification Report

Date: 08-Sep-2026
Script: `src/verify_calibration_T5.m` (artifact-only; NO new inference)
Artifacts:
- `data/analysis/day8/calibration/calibration_verify_T5.mat`
- `data/analysis/day8/calibration/reliability_curve.png`

## Scope

Two deliverables:
1. **Binary re-verification** of the already-implemented temperature
   calibration (T=2.5382, promoted in `current_T.mat`), as an independent
   holdout-style check on the 733-image validation set.
2. **5-class reliability assessment** — the genuinely new piece of Task 5.
   Assessment only; no calibration fit was made.

## 1. Binary — raw vs calibrated (val n=733)

Reliability computed from fresh val predictions in `reverify_audit_T0.mat`
(`PRef`, `YTrue5`), referable = grade ≥ 2 (classes 3–5). Calibrated
probabilities via the exact promoted code path
`sigmoid(logit(p)/T)` with `T=2.5382` (`temperatureScale` +
`loadTemperatureParams`). 10 equal-width bins over [0,1].

| Metric | Raw | Calibrated (T=2.5382) | Δ |
|--------|-----|------------------------|---|
| ECE    | 0.0450 | 0.0298 | −0.0152 |
| Brier  | 0.0563 | 0.0529 | −0.0034 |
| NLL    | 0.2899 | 0.1801 | −0.1098 |

Flip rate @ 0.60 threshold on val: **1.50% (11 / 733)** — decision change
after calibration is small; screening decision stays locked on raw pRef.

### Documented firewalled-eval numbers (for contrast, NOT matched)

The originally documented calibration numbers were computed on the
**firewalled 2429-image eval subset** of APTOS *train* (fit on a disjoint 500,
rng 42): ECE 0.0319 → 0.0087, Brier 0.0371 → 0.0336, NLL 0.1998 → 0.1243,
flip@0.60 = 0.741% (18/2429).

**Val-vs-firewalled caveat:** the 733 val numbers above are a *different,
disjoint, label-safe holdout* — they are naturally not identical and are NOT
forced to match. Key observations:
- On the val set, raw ECE is **0.0450 — exactly reproducing the raw ECE of
  the earlier standard train/val design** (documented 0.0450 on the same val
  split). The val-set raw Brier/NLL also reproduce that standard design's
  numbers exactly (0.0563 / 0.2899) — confirming the promoted T checkpoint
  and the audit predictions are consistent with the original day-7 eval.
- The re-verification *numerically reproduces* the archived standard-design
  analysis on the same val set: raw ECE 0.0450, raw Brier 0.0563 and raw NLL
  0.2899 are **exact** matches to `standard_calibration.mat` (`eceRawVal`,
  `brierRawVal`, `nllRawVal`), confirming the verification pipeline (same
  bins, same predictions, same T checkpoint) is faithful.
- Applying the *promoted* T=2.5382 to the *same val set* yields ECE
  0.0450 → 0.0298 and NLL 0.2899 → 0.1801 — very close to the standard
  design's fit-on-train T=2.6722 → ECE 0.0280 / NLL 0.1767 (the tiny
  difference is the T value: 2.5382 vs 2.6722). Calibrated Brier lands at
  0.0529 for both T values (Brier is flatter in T in this range).
- The firewalled 500/2429 design gave lower ECE (0.0319 → 0.0087) because it
  evaluates and fits within the larger, lower-variance train population.
- Direction is consistent everywhere: temperature scaling always reduces
  ECE/Brier/NLL, the calibration is real and reproducible, and the promoted
  T=2.5382 behaves sensibly on the independent val holdout.

Use **firewalled** numbers for the headline lower-variance estimate and the
**val** numbers as the independent holdout-style confirmation. Both agree in
direction and magnitude.

## 2. 5-class reliability (assessment only)

Per-class reliability: bin the predicted class probability `s5All(:,c)` vs
`indicator(yTrue==c)` (10 equal-width bins). Top-1: bin the max predicted
probability vs whether argmax matched truth (`yPred==argmax(s5All)`).

| Class | n (val) | prevalence | ECE |
|-------|---------|------------|-----|
| NoDR | 361 | 49.2% | 0.0168 |
| Mild | 74 | 10.1% | 0.0708 |
| Moderate | 200 | 27.3% | 0.0925 |
| Severe | 39 | 5.3% | 0.0463 |
| Proliferative | 59 | 8.0% | 0.0580 |

Top-1: accuracy 0.8281, **top-1 ECE = 0.1255**.

Interpretation:
- Per-class ECE is small for NoDR (0.017) and worst for Moderate (0.093) and
  Mild (0.071) — the two classes on the referable boundary where the net is
  least calibrated. Severe/Proliferative ECEs (0.046/0.058) are moderated by
  huge mass at high predicted probability in their very small cells (n=39/59).
- Top-1 ECE (0.126) is much larger than any per-class ECE — the classic
  signature of **overconfidence in the argmax**: the max class probability is
  systematically higher than the true match rate (typical for a
  softmax-trained net, no temperature/ODE calibration applied to the 5-class
  output).

**5-class temperature: NOT FITTED.** A search of `src/calibration/` and
`data/analysis/day8/calibration/` found only the *binary* temperature
(`current_T.mat`, T=2.5382); no 5-class temperature has ever been fitted.
This deliverable is therefore **assessment only** — per the plan, no 5-class
temperature was fitted here and the 5-class scores remain uncalibrated.
Fitting one (and re-checking top-1 ECE) is the natural follow-up.

## 3. Saved artifacts

- `data/analysis/day8/calibration/calibration_verify_T5.mat`
  (fields: `eceRaw`, `eceCal`, `brierRaw`, `brierCal`, `nllRaw`, `nllCal`,
  `flipRate`, `nFlip`, `binEdges`, `binRaw`, `binCal`, `perClassECE`,
  `top1ECE`, `n`, `T`, `top1Acc`, `perClassCnt`, `classNames`, `out`)
  with `docFirewalled` reference numbers in `out`.
- `data/analysis/day8/calibration/reliability_curve.png` — binary raw vs
  calibrated reliability diagram + per-class ECE bar chart.

## Constraints honored

No retraining, no promotion change, no re-inference, test set untouched,
`src/calibration/` and `current_T.mat` unmodified.