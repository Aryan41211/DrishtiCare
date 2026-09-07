# Task 11 — Fovea Detection: Closure Report (Honest Negative)

Date: 2026-09-08
Verdict: **CLOSED as a measured honest negative — no further work planned without new data.**

## Background
The roadmap item was to localize the fovea so the lesion branch could emit a
clinically meaningful "exudate distance to fovea" (DME proxy). Two approaches
were built and measured against the IDRiD fovea-center CSV ground truths on the
IDRiD 01–10 holdout. Source: `docs/task-tracker.md` Task "Fovea localization".

## Measured results (both attempts)

| Approach | Metric | Result |
|----------|--------|--------|
| Patch CNN (`locateFoveaCnn`, mirrors OD-CNN) | located within 300 px of GT | **0/10** |
| Patch CNN | mean accepted error | ~620 px |
| Patch CNN | held-out patch AUC (`fovea_cnn_metrics.mat`) | 0.7487 |
| Patch CNN | held-out patch accuracy | 0.6479 |
| Disc-relative anatomical estimate (K × disc-radius temporal offset) | mean error | ~1400 px |
| Disc-relative (K swept 2.0–3.5) | within 300 px | 0/10 (disc–fovea offset not a consistent multiple) |

The patch CNN accepts almost everything at its 0.85 gate (AUC barely above the
0.75 mark, accuracy ≈ 0.65 ≈ high-frequency "on-retina" guessing), i.e. it does
not learn a discriminating fovea signal at 192 px crops.

## Decision
- The pipeline does **NOT** emit a fovea-derived distance by default.
- `meanExudateDistToFovea` stays `NaN` unless a fovea center is supplied by the
  caller (e.g. API-supplied markup). Behavior documented in
  `docs/individual-image-inference.md`.
- Code is retained in `src/lesions/` (`trainFoveaCnn.m`, `locateFoveaCnn.m`,
  `buildFoveaDataset.m`) for future work if fovea-labeled training data becomes
  available.

## Metacondition (honest-reporting check)
This closure was confirmed against the saved artifact
(`data/analysis/day8/fovea_cnn/fovea_cnn_metrics.mat`: AUC 0.7487, acc 0.6479)
and the CSV-of-truth comparison, not from memory. Decision to retain the
"negative" verdict: the measured performance is below any usable acceptance
threshold and cannot be improved with the currently available labels.
Re-opening this module requires one of:
- new fovea-labeled training data at scale, or
- a superset of the `C. Localization` IDRiD markups covering the 733 APTOS-val set.