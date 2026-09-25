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

> **Correction — 2026-09-25.** The 13th entry, `quality_gate`, has been
> removed from the probe list. `src/quality/quality_gate.m` was a 1-line
> comment-only placeholder (`% Quality Gate Module - Image quality assessment
> and enhancement`) containing no function, and was **deleted** on 2026-09-25.
> The real quality gate is `src/quality/assessImageQuality.m`, which is the
> module actually integrated into the inference path; the deleted file existed
> only so the bare name would resolve, and `quality_gate(...)` was never called
> as a function anywhere in the repository. The eval-critical list is therefore
> now **12** functions and `src/phases/phase18_environment_pin.m` asserts
> `numel(crit) == 12`.
>
> This correction does **not** change this phase's verdict: the check count
> stays **6/6 PASS**, the `P18 eval_path_unshadowed` check still PASSES (all 12
> remaining names still resolve from this repository — verified statically), and
> the other five checks are untouched. Only the enumeration above is
> superseded; the "13" on this line is left in place as the as-run record for
> 2026-09-10 and must be read together with this note.

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

Engineering demo, NOT a clinical device: all cited metrics are engineering measurements on validation-set artifacts from the frozen protocol (Phase 10); no clinical validation is claimed.
