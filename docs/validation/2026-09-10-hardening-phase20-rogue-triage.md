# DrishtiCare Hardening — Phase 20: Rogue / Unknown-File Triage

Date: 2026-09-10. **5/5 PASS** (one check self-match fixed by excluding the
audit script from its own scan — same class of bug as P19).

## Files triaged (untracked, pre-dating hardening)
- `runAPTOS.m`, `runFinalAPTOS.m`, `runFinalAPTOSBinary.m`, `runSmokeTest.m`
- `data/analysis/final/` (1 mat) and `data/analysis/smoke_test/` (1 mat
  + 2 PNGs)

## Findings
1. **Unreferenced by `src`** — no src file mentions the rogue scripts or their
   output dirs (verified by repo-wide scan).
2. **Eval-only runners** — zero `trainNetwork(/trainClassifier(/fit*(` call-
   sites; they load locked day-7 models and run inference/evaluation.
3. **No model-weight leak** — `final_aptos_evaluation.mat` and
   `smoke_test_100_results.mat` contain metric/label/path summary fields only
   (no `trainedNet`/`net`/`layers`).
4. **Contents** — `final/`: `final_aptos_evaluation.mat` (62.5 KB);
   `smoke_test/`: `smoke_test_100_results.mat` (2.2 KB),
   `smoke_test_100_confusion_matrix.png`, `smoke_test_10_images.png`.
5. **No accidental deletion** — all four scripts intact.

## Disposition (recorded for Phase 25)
**Keep, do not commit.** They document the pre-hardening final-APTOS eval and
10-image smoke-test provenance and cross-check the locked metrics. No training,
no weights, no image redistribution. Phase 25 will note them as untracked
provenance, superseded by hardening artifacts.

## Artifacts
- `src/phase20_rogue_triage.m`
- `data/analysis/day10/phase20/phase20_rogue_triage.mat`