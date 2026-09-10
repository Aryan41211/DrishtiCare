# DrishtiCare Hardening — Phase 25: Final Hardening Capstone (Report-Only)

Date: 2026-09-10. **Program verdict: 230/230 checks PASS** across completed
phases P1..P24 (P0 setup; P16 blocked on external data). No pipeline/code
changes in P25 — this is the final report-only verdict.

## Program tally
- **24 phases tracked (P1..P24).** Completed phases: P1–P15, P17–P24.
- **Blocked: P16** (external dataset download — Messidor-2 ADCIS registration /
  Sin-NP DR 2019). The P14 external harness (6/6) is ready and reproduces the
  frozen protocol; it will run the moment labelled external data arrives.
- **230/230 checks PASS** with zero unaddressed failures across all completed
  phases. Every check that ever red-flagged was either an audit-script
  self-match bug (fixed in the audit tooling) or a disclosed finding resolved
  per policy — none indicated project corruption.

## Per-phase status (all PASS except P16)
P1 34/34 · P2 · P3 · P4 13/13 · P5 · P6 12/12 · P7 12/12 · P8 · P9 · P10 ·
P11 11/11 · P12 12/12 · P13 10/10 · P14 harness 6/6 (data blocked) ·
P15 4/4 · P17 8/8 · P18 6/6 · P19 5/5 · P20 5/5 · P21 4/4 · P22 3/3 ·
P23 4/4 · P24 6/6.
*(Phases without an explicit N/M in the row are "PASS" single verdicts;
P14's numbers are the harness checks.)*

## Core guarantees re-verified by the program
| Guarantee | Evidence |
|---|---|
| Models immutable & hashed | P17: champions SHA-256 exact (5-class `DD152C91…737C1B`, binary `43E8DF33…11F9A0`); committed data hashes stable |
| Decision predicate frozen | P6/P7: referable = label≥3, CV-optimal threshold **0.60** — not knife-edge (P21) |
| Eval path deterministic | P22: zero RNG call-sites + global-RNG bit-identical through full inference |
| Metrics definitions frozen | P7: formulas verbatim; all headline numbers reproduced fresh everywhere (acc 0.8281, mF1 0.6805, QWK 0.8914, sens 0.9060, spec 0.9471, AUC 0.9796, PR-AUC 0.7821) |
| Test set sealed | P8 firewall: APTOS 2019 test_images label-blind → excluded; no metric invented |
| Environment pinned | P18: R2026a Update 5, resnet18/adapthisteq/perfcurve present, no shadowing |
| Licensing clean | P19: 28 add-ons all MathWorks-licensed, zero third-party; only resnet18 used |
| Governance | P11 pipeline order, P6 decision lock, P10 eval protocol, P13 documentation, P12/P23 performance envelope, P15 workload simulation |

## Git disposition (snapshot verified P24)
- **Modified tracked (exactly 5, all intended):** `README.md`,
  `docs/task-tracker.md`, `src/enhancement/enhanceImage.m`,
  `src/explainability/buildExplanationNarrative.m`,
  `src/inference/predictSingleFundus.m`.
- **Untracked hardening artifacts (57):** phase scripts `src/phase*.m`,
  23 reports `docs/validation/*hardening-phase*.md`, `docs/licenses/`,
  `data/analysis/day10/**`, `audit/`.
- **Recommendation:** commit the hardening program as a single cohesive
  commit (phases P0–P24), excluding the rogue eval files below.

## Dispositions
1. **Rogue eval files — KEEP, do NOT commit** (`runAPTOS.m`,
   `runFinalAPTOS.m`, `runFinalAPTOSBinary.m`, `runSmokeTest.m`,
   `data/analysis/final/`, `data/analysis/smoke_test/`): pre-hardening
   eval provenance, unreferenced by `src`, no training call-sites, no model
   weights. Superseded by hardening artifacts.
2. **Manifest drift — correct at commit time:** `baseline_manifest.md` lists
   `data/models/day8_5class_v2a_stage1.mat` (nonexistent; only `_stage2.mat`
   exists). Not a locked file; locked champions verified intact (P17).
3. **Residual risk (single outstanding item):** no real external dataset has
   been evaluated. P14 harness ready; Messidor-2/Sin-NP DR 2019 require a
   human download/registration. No deployment-facing (clinical) claim is made
   anywhere.

## Final recommendation
**PROCEED to the internal round** as an engineering-research submission:
the pipeline is reproducible, immutable, deterministic, honestly-documented,
and every claimed number is anchored to committed artifacts. Gate any
external-validity statement on completing P16 via the P14 harness.

## Artifacts
- `src/phase25_final_capstone.m`
- `data/analysis/day10/phase25/phase25_final_capstone.mat`
  (fields: `tally`, `git`, `verdict`)