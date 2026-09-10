# DrishtiCare Hardening — Phase 10: Evaluation Protocol Freeze

Date: 2026-09-10. Runs: 4 (iterative fix of self-referential grep defects; final 5/5 PASS).

## Purpose

Freeze the *evaluation contract*: every downstream performance claim in this
hardening program must be produced through a fixed protocol against read-only
artifacts. This closes the last "who guards the experimenter" loophole —
phases 4–9 proved each measurement, this phase proves the measurement system
itself cannot be silently changed by the audit path.

## Findings

### P10 no train in eval — PASS
The verbatim audits in `src/evalScripts` (evaluators, verifiers, re-auditors,
bootstrap/ablation/ensemble scripts) contain **zero call-sites** (`trainNetwork(`,
`trainClassifier(`, `fitcnet(`, `fitcsvm(`, `fitcecoc(`, `fitcknn(`). A
`contains()`-style grep produced false positives from mere *mentions* (e.g.
`exist('trainNetwork','file')`, comments), so the detector was tightened to
require an actual `identifier(` call-site.

### P10 train isolated — PASS
Call-sites exist in **15 files**, all matched to explicit training entry points
(`run_*`, `train*`, `hardNegMine*`), except the phase-10 audit script itself
(which carries the search identifiers as string literals). No call-site appears
in any `verify*` / `eval_*` / `re_*` / dashboard loader.

### P10 hashes — PASS
Locked checkpoints byte-identical to baseline manifest:
- 5-class: `DD152C91…737C1B`
- binary: `43E8DF33…11F9A0`

### P10 T0 cache — PASS
`data/analysis/day8/reverify_audit_T0.mat` present (read-only eval input).

## Freeze Declaration (also in phase10_protocol_freeze.json)

1. Eval-critical checkpoints are READ-ONLY: the two locked champion nets and the
   T0 prediction cache. No committed eval path retrains or mutates them.
2. NO performance improvement may be recorded that relies on re-opening an
   eval-critical checkpoint.
3. Any future result must be reported under the frozen protocol: fresh inference
   of the LOCKED nets over the LOCKED 733-val split, metric defs from Phase 7,
   thresholds from Phase 6.
4. Training changes are permitted for future work but must NOT be claimed against
   baseline metrics on the same val split unless evaluated by the frozen protocol
   against locked artifacts.
5. The sealed official APTOS test set is never used for tuning; external
   validation (Phases 14/16) stays held-out.

## Artifacts
- `src/phase10_protocol_freeze.m`
- `data/analysis/day10/phase10/phase10_protocol_freeze.mat`
- `data/analysis/day10/phase10/phase10_protocol_freeze.json`
---
Engineering demo, NOT a clinical device: all cited metrics are engineering measurements on validation-set artifacts from the frozen protocol (Phase 10); no clinical validation is claimed.
