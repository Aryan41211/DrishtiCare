# DrishtiCare Hardening — Phase 21: Threshold-Robustness Disclosure

Date: 2026-09-10. **4/4 PASS.**

Swept the binary decision threshold ±0.05 around the **locked 0.60** on the
733-val locked predictions (frozen definitions, referable = 1-based label ≥ 3).
This is a **disclosure**, not a tuning exercise: threshold stays locked at 0.60.

## Operating-point table (val, n=733)
| t | sens | spec | PPV | F1 | referrals |
|---|---|---|---|---|---|
| 0.55 | 0.9128 | 0.9448 | 0.9189 | 0.9158 | 296 |
| 0.56 | 0.9128 | 0.9448 | 0.9189 | 0.9158 | 296 |
| 0.57 | 0.9094 | 0.9448 | 0.9186 | 0.9140 | 295 |
| 0.58 | 0.9094 | 0.9448 | 0.9186 | 0.9140 | 295 |
| 0.59 | 0.9094 | 0.9471 | 0.9218 | 0.9155 | 294 |
| **0.60** | **0.9060** | **0.9471** | 0.9215 | 0.9137 | **293** |
| 0.61 | 0.9060 | 0.9471 | 0.9215 | 0.9137 | 293 |
| 0.62 | 0.9060 | 0.9471 | 0.9215 | 0.9137 | 293 |
| 0.63 | 0.8993 | 0.9471 | 0.9210 | 0.9100 | 291 |
| 0.64 | 0.8993 | 0.9494 | 0.9241 | 0.9116 | 290 |
| 0.65 | 0.8960 | 0.9494 | 0.9239 | 0.9097 | 289 |

## Findings
- At t=0.60 the frozen metrics reproduce exactly (sens 0.9060 / spec 0.9471).
- **Not knife-edge:** over the ±0.05 window, sens spans 0.8960–0.9128
  (≤1.7 pt), spec spans 0.9448–0.9494 (≤0.9 pt), F1 0.9097–0.9158.
- **Referral-load gradient** ≈ 0.7 images per 0.01 threshold step (289→296
  referrals across the full 0.55–0.65 band).

## Artifacts
- `src/phase21_threshold_robustness.m`
- `data/analysis/day10/phase21/phase21_threshold_robustness.mat`
  (fields: `thresholds`, `sweep` table, `frozenT60`, `report`, `auditRes`)