# DrishtiCare Hardening — Phase 12: Runtime & Robustness Hygiene

Date: 2026-09-10. Runs: 3 (1×1-CLAHE crash fixed; audit workspace isolation);
final **11/11 PASS**.

## Defects found and fixed

1. **1×1 (degenerate) input crashed the pipeline** — `adapthisteq` (CLAHE) in
   `enhanceImage` requires image dimensions ≥ 2, so a 1×1 fundus input aborted
   `predictSingleFundus` with a raw error instead of routing to review. Fixed
   with a pass-through guard in `enhanceImage.m`: any input with a collapsed
   axis (< 2 px) is returned unchanged with a NaN improvement struct and a
   clear note. Regressed: 1×1 image now completes end-to-end (quality gate
   reviewed route, no crash).

2. **verify_* scripts leak variables into the caller's workspace** — re-running
   `verify_cascade.m` from the audit overwrote the audit's own `results`/`files`
   locals (conversion error). The verifier scripts are standalone scripts, not
   functions, so they are not caller-safe. The audit now executes them inside an
   isolated sub-function workspace; the hazard is recorded as hygiene debt
   (Phase 13 documentation sprint should note "runner scripts are not
   function-isolated; never `run()` them from a function that shares variable
   names").

## Behavior verification (all PASS)

- **Corrupt input file**: clean explicit error (`File format "png" is not
  supported`), never a silent NaN/grade output.
- **Missing model file**: clean explicit error; no silent prediction.
- **Grayscale single-channel input**: replicated to RGB, full result returned.
- **Random-noise image**: completes; OOD sanity recorded.
- **Deterministic rerun**: same input → bit-identical `classProbabilities`,
  identical `binaryDecision`, `|ΔpRef| ≤ 1e-12`.
- **WITHHELD path** (quality FAIL + SkipModelOnFail): complete structured
  output (quality, cascade=REVIEW, ood, fusion, lesions, explanation).
- **verify_cascade.m** reruns cleanly on locked artifacts (9 synthetic router
  cases all route as expected: 4 CLEAR, 2 REVIEW, 3 ABSTAIN).
- **verify_dashboard.m** reruns cleanly — data layer matches committed
  artifacts, app lifecycle, workload math (@1000 img/day ≈ 552 reviews), and
  the full `predictSingleFundus` inspector path (val image
  `005b95c28852.png`, quality WARNING, route CLEAR).

## Runtime profile (10 val images, mixed classes, full pipeline)

median = **11.03 s/image** (mean 15.16 s). This is the full engineering demo
path (quality gate 0.8s + enhancement + both CNNs + Grad-CAM + lesion
candidates + OOD + fusion + narrative), far above the 0.1028 s/img pure-model
dashboard measure; both figures are recorded honestly — the pipeline measure
is not a throughput claim.

## Artifacts
- `src/phase12_runtime_robustness.m`
- `data/analysis/day10/phase12/phase12_runtime_robustness.mat`
- Source fixes: `src/enhancement/enhanceImage.m` (degenerate-input guard)