# Hardening Phase 8 — Firewalled Calibration Leakage Audit

Date: 10-Sep-2026 00:36
Auditor: `src/phase8_firewall_proof.m`
Result: **PASS — 18/18 checks.** No calibration leakage is possible in the
deployed path: `T_cal` is fit on a val-free training subset only, fit/eval
sets are disjoint, and the production **decision** consumes the RAW `pRef`
— temperature scaling is auxiliary display information only.

## Split and firewall facts (reproduced, seed 42)

- `rng(42)`; deterministic permutation of the 2929 train indices.
- **CALIBRATION** = first 500 of the shuffled train (`T_cal` fit here).
- **EVAL** = remaining 2429 train images (disjoint, *not* for fitting).
- Val (733) appears in **neither** set — verified by `isVal` masks.
- Reproduction of `calIdx`/`evalIdx` is byte-identical to the committed
  `firewalled_calibration.mat`.

## T provenance

| Quantity | Value | Role |
|----------|-------|------|
| `T_cal` | 2.53818939 | **fit ONLY on the 500 cal images** (fminbnd [0.1,8], logit NLL); the value promoted into `current_T.mat` ✔ |
| `T_eval` | 2.6979… | optimistic upper-bound sanity check (fit on the 2429) — **never promoted** ✔ |

## No-leakage proof at the decision layer

The deployed decision path is:
- `predictSingleFundus.m:150` — `binaryDecision = 'REFERABLE'` iff **raw** `pRef ≥ 0.60`
- `predictSingleFundus.m:256` — `cascade_router(result.grade, s5, pRef)` with **raw** `pRef`
- `temperatureScale(pRef, T_cal)` output goes only into the auxiliary field
  `binaryProbabilityCalibrated`.

Consequently the headline val binary metrics (sens 0.9060 / spec 0.9471)
recompute from **raw** decisions — calibration `T` has zero influence on the
reported operating point. Verified fresh in Phase 7 (P7 bin_sens/spec).

## Honest, quantified side-note

If the calibrated `pRef` were ever substituted into the decision, **11 of 733
val decisions would flip** (1.5%). This is recorded as a deterministic,
display-only figure; the code path never uses it for decisions, so it does
not change the operating point. The committed EVAL flip fraction (0.74%,
n=18/2429) is the in-distribution calibration-eval statistic — analogous,
also auxiliary.

## Honesty caveat (restated in the registry)

The binary screener was trained on every in-distribution image, so the
500/2429 equipartition is the **least-leaky estimate within the training
population** — not a true held-out generalization figure. The true held-out
evidence is the sealed official APTOS test set (never used here) and the
external datasets (Messidor-2 / Sin-NP DR 2019, Phases 14/16).

## Checks summary

- split reproduces identically (cal + eval indices) ✔
- cal ∩ eval = ∅; cal ∪ eval = 2929 train; val never in either ✔
- `T_cal` refit == 2.53818939; `T_eval` ≠ `T_cal` and not promoted ✔
- ECE/Brier/NLL/flip on EVAL reproduce committed artifact to 1e-9 ✔
- headline metrics are raw-decision based; cal-flips (11/733) are auxiliary-only ✔

## Artifacts

- `src/phase8_firewall_proof.m`
- `data/analysis/day10/phase8/phase8_firewall_proof.mat` / `.json`

## Rollback

Read-only audit; no production code changed.
---
Engineering demo, NOT a clinical device: all cited metrics are engineering measurements on validation-set artifacts from the frozen protocol (Phase 10); no clinical validation is claimed.
