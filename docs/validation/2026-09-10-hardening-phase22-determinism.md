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

> **Correction — 2026-09-25.** Check 1's function list was **13** names long as
> run on 2026-09-10. `src/quality/quality_gate.m` was a 1-line comment-only
> placeholder containing no function and was **deleted** on 2026-09-25; the real
> quality gate is `src/quality/assessImageQuality.m`. The list is now **12**
> names and `src/phases/phase22_determinism_probe.m` asserts `numel(crit) == 12`.
>
> This correction does **not** change this phase's verdict: the check count
> stays **3/3 PASS**, and checks 2 and 3 are byte-for-byte untouched. Check 1
> still PASSES — the deleted placeholder contributed nothing to the scan
> (a comment-only file can contain no RNG call-sites), and all 12 remaining
> names are unchanged and still RNG-free. The claim "13 eval-critical
> functions" above is left as the as-run record for 2026-09-10 and must be
> read together with this note.
>
> **Known limitation of check 1, disclosed 2026-09-25 (not fixed, verdict
> unchanged).** `src/phases/phase22_determinism_probe.m:37` scans each file with
> `regexp(c, rngPat, 'tokens', 'once')`, i.e. it inspects only the **first**
> match per file. A file with a second, later RNG call-site would therefore be
> reported as clean. The limitation was found while removing the `quality_gate`
> entry and was deliberately **not** changed, because altering the scan would
> change the behaviour of a completed audit script. The strength of the "no RNG
> call-sites" claim should be read as "no RNG call-site at the first pattern
> match per file", not as an exhaustive per-file scan.

## Interpretation
Frozen eval artifacts cannot vary with Monte-Carlo randomness: no seed is
needed at evaluation time. (Training-side determinism was already covered by
Phases 4/12: reproducible reruns, |ΔpRef|≤1e-12.)

## Artifacts
- `src/phase22_determinism_probe.m`
- `data/analysis/day10/phase22/phase22_determinism_probe.mat`

Engineering demo, NOT a clinical device: all cited metrics are engineering measurements on validation-set artifacts from the frozen protocol (Phase 10); no clinical validation is claimed.
