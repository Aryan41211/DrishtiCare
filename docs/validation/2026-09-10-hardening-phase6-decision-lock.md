# Hardening Phase 6 — Decision Threshold Lock

Date: 10-Sep-2026 00:29
Auditor: `src/phase6_decision_lock.m`
Result: **PASS — 9/9 checks.** Every decision threshold on the screening path
is verified against its committed hard-coded value, its provenance is
recorded, and a machine-readable registry documents the no-retuning rule.

## Locked decision thresholds

| Threshold | Value | Provenance | Lock |
|-----------|-------|------------|------|
| Binary referral `pRefLocked` | **0.60** | Day 6 binary threshold sweep on the validation split; committed rule `find(thrSens>=0.90, 1, 'last')` reproduces 0.60 exactly from `day6_binary_referable_v1_metrics.mat` (`chosenThreshold=0.6`); hard-coded in `predictSingleFundus.m` (`BinaryThreshold` default) and `cascade_router.m` (`def.pRefLocked`) **before** the Day 7 champion existed | LOCKED |
| Router `abstainConf` | 0.50 | `cascade_router.m` default | LOCKED |
| Router `reviewConf` | 0.75 | `cascade_router.m` default | LOCKED |
| Router `marginThr` | 0.20 | `cascade_router.m` default | LOCKED |
| Router `pRefBand` | 0.05 | `cascade_router.m` default (ABSTAIN zone ≈0.60) | LOCKED |
| Router `agreePRef` | 0.50 | `cascade_router.m` default (screen/grade agree pivot) | LOCKED |
| Quality gates | 6 metric bounds | `defaultQualityConfig v2.0.0` = Day 3 percentiles of 3,662 APTOS images; **prototype, NOT clinically validated** | LOCKED |

## Honest framing (recorded in the registry)

- 0.60 was **tuned on the validation split** at Day 6. The val binary sens/spec
  at 0.60 (0.9060 / 0.9471) are therefore **operating-point estimates, not
  fully held-out numbers** — reproduced here exactly (fresh recompute).
- The threshold was **not re-swept for the Day 7 champion**: it was hard-coded
  before the champion was created, and the champion was never used to tune it.
- The **sealed APTOS test set is the baseline held-out evidence** (not
  download-presence locally) and is **never used** for threshold selection;
  external datasets (Messidor-2 / Sin-NP DR 2019, Phases 14/16) are the
  additional held-out checks.
- Rule: **no decision threshold may be retuned on the validation split, and
  the sealed test set is never used for threshold selection.**

## Checks

- `predictSingleFundus.m` default `BinaryThreshold` == 0.60 ✔
- `cascade_router` defaults == `[0.50 0.75 0.20 0.05 0.60 0.50]` ✔
- `defaultQualityConfig` version `2.0.0`, derived from 3,662 images ✔
- Day 6 sweep rule `find(thrSens>=0.90,1,'last')` reproduces chosenThreshold 0.60 ✔
- val operating point at 0.60 (fresh): sens 0.9060 / spec 0.9471 ✔
- no-retune invariant (threshold fixed pre-Day-7, champion never re-swept) ✔
- no test-split directory present in `data/splits` ✔

(Note: sweeps built as `0.05:0.05:0.95` accumulate ~1e-12 float error at
index 12; checks use 1e-9 tolerance — the values are semantically 0.60.)

## Artifacts

- `src/phase6_decision_lock.m`
- `data/analysis/day10/phase6/phase6_decision_lock.mat`
- `data/analysis/day10/phase6/phase6_decision_lock.json` (machine-readable
  registry: all thresholds, provenance, tuned-on windows, lock status)

## Rollback

Read-only audit; no production code changed.