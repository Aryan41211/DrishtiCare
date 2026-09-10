# DrishtiCare Hardening — Phase 22: Eval-Path Determinism Probe

Date: 2026-09-10. **3/3 PASS.**

## Checks
1. **Static call-syntax scan** — the 13 eval-critical functions
   (`predictSingleFundus`, `quality_gate`, `cascade_router`, `fuseEvidence`,
   `gradcamExplain`, `ood_detector`, `buildExplanationNarrative`,
   `calibrationStats`, `temperatureScale`, `loadTemperatureParams`,
   `evaluateClassifier`, `evaluateBinaryClassifier`, `re_verify_audit`)
   contain **no** RNG-consuming call-sites
   (`rand/randn/randi/datasample/cvpartition/shuffle/rng/RandStream`).
2. **Runtime probe** — one full `predictSingleFundus` on a real val image
   (`data/splits/val/class_1/06b71823f9cd.png`) leaves the global RNG state
   **bit-identical** (type/seed/state) before vs after → the entire *reached*
   call graph (including helpers outside the static list) consumes no
   randomness.
3. **Metric reproducibility** — the frozen binary metric computation
   (sens/spec @0.60, referable=label≥3) is deterministic across repeated calls.

## Interpretation
Frozen eval artifacts cannot vary with Monte-Carlo randomness: no seed is
needed at evaluation time. (Training-side determinism was already covered by
Phases 4/12: reproducible reruns, |ΔpRef|≤1e-12.)

## Artifacts
- `src/phase22_determinism_probe.m`
- `data/analysis/day10/phase22/phase22_determinism_probe.mat`