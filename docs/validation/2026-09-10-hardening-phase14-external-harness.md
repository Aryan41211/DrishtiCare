# DrishtiCare Hardening — Phase 14: External Validation Harness

Date: 2026-09-10. **6/6 PASS.** External validation itself is **PENDING** (data-blocked).

## Purpose
Provide a ready-to-run, firewall-compliant external-validation harness so that
the moment a labelled external DR dataset arrives (Messidor-2 or Sin-NP DR
2019), the frozen evaluation protocol (Phase 10) can be applied without any
model change, tuning, or data leakage.

## Status of external data (verified locally)
- **Messidor-2** — not present; requires a human ADCIS download-form request
  (see `docs/validation/2026-09-08-task10-external-validation-status.md`).
- **Sin-NP DR 2019** — not present; download pending.
- **APTOS 2019 official test** — `data/aptos2019/test_images/` contains
  **1,928 PNGs**, but `test.csv` contains only `id_code` and **no labels**
  (leaderboard-blind by design). Since it cannot be scored it is correctly
  excluded; the harness check `P14 aptos_unlabeled_protected` enforces this.

## Harness bug found and fixed by the harness's own checks
Initial metric-mechanics check used an **incorrect referable label mapping**
(`YTrue>=2`) instead of the frozen Phase-7 definition (`YTrue>=3`, i.e. 1-based
label >= 3 = Moderate/severe/Proliferative). Result before fix:
sens 0.7876 / spec 1.0000 / AUC 0.9912 → **3 FAILs**. After correcting to the
frozen formulas and `perfcurve` definitions (identical to
`src/phase7_metric_freeze.m`), the same locked-val cache reproduces:

| metric | harness | frozen | status |
|---|---|---|---|
| sensitivity @0.60 | 0.9060 | 0.9060 | PASS |
| specificity @0.60 | 0.9471 | 0.9471 | PASS |
| ROC-AUC | 0.9796 | 0.9796 | PASS |
| PR-AUC (perfcurve) | 0.7821 | 0.7821 | PASS (informational) |

This proves the metric/scoring path is faithful to the committed evaluators, so
external results computed by the harness are directly comparable to the frozen
headlines.

## PASS checks
1. `P14 aptos_unlabeled_protected` — official APTOS test is label-blind and
   excluded (no fabricated metrics).
2. `P14 metrics_mechanics_sens` — frozen formulas reproduce sens 0.9060.
3. `P14 metrics_mechanics_spec` — frozen formulas reproduce spec 0.9471.
4. `P14 auc_sanity` — perfcurve reproduces AUC 0.9796.
5. `P14 frozen_protocol_bound` — decision at locked raw `pRef>=0.60`; harness
   has no threshold-tuning path.
6. `P14 external_status_honest` — status is declared PENDING, nothing invented.

## Artifacts
- `src/phase14_external_validation.m`
- `data/analysis/day10/phase14/phase14_external_validation.mat`
  (fields: `status`, `harnessReady`, `valDryRun`, `scoring`, `external`,
  `auditRes`)