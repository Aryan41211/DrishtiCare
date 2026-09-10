# DrishtiCare Hardening — Phase 18: Environment & Toolbox Pinning

Date: 2026-09-10. **6/6 PASS.**

## Pinned environment (measured)
- MATLAB `26.1.0.3346908 (R2026a) Update 5`, arch `win64`
  (`version('-release')` reports `2026a`; the baseline manifest wrote `R2026a`
  — equivalent, documented).
- Required toolboxes resolvable via representative functions: **Deep Learning
  Toolbox** (`resnet18`), **Image Processing Toolbox** (`adapthisteq`),
  **Statistics and Machine Learning Toolbox** (`perfcurve`). Full `ver()` list
  dumped to `data/analysis/day10/phase18/phase18_environment_pin.mat/json`.
- Default global RNG: **Mersenne-Twister, type `mt19937ar`, seed 0** (R2026a's
  new name for the classic twister) — the deterministic baseline all frozen
  eval artifacts rely on.

## No-shadowing proof
All 13 eval-critical project functions (`quality_gate`, `cascade_router`,
`predictSingleFundus`, `fuseEvidence`, `gradcamExplain`, `ood_detector`,
`buildExplanationNarrative`, `calibrationStats`, `temperatureScale`,
`loadTemperatureParams`, `evaluateClassifier`, `evaluateBinaryClassifier`,
`re_verify_audit`) resolve from **this** repository (no toolbox/other-path
duplicate).

## Check corrections during development (found by the checks themselves)
- `computeQWK` is **not** a standalone file — it is a local helper inside the
  committed evaluators (e.g. `re_verify_audit.m`). Replaced in the probe list
  by `re_verify_audit` (which resolves to `src/re_verify_audit.m`); QWK formula
  itself is already frozen under Phase 7.
- `version('-update')` is not a valid option in R2026a → update number parsed
  from the full version string ("Update 5").
- `RandStream` type for the default stream is now `mt19937ar` (was `twister`).
- The temp diagnostic script hit MATLAB's "Invalid text character" when invoked
  via `run()`/inline; resolved by inlining diagnostics into the phase script.

## Artifacts
- `src/phase18_environment_pin.m`
- `data/analysis/day10/phase18/phase18_environment_pin.mat` (incl. full `ver`)
- `data/analysis/day10/phase18/phase18_environment_pin.json` (portable subset)