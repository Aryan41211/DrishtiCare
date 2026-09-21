# Baseline Report - District Screening Simulation

**ENGINEERING / RESOURCE-PLANNING SIMULATION - NOT clinical validation.**

## Measured Inputs

| Input | Value |
|---|---|
| Sensitivity | 90.60% |
| Specificity | 94.71% |
| Referral threshold | 0.60 |
| Validation population | 733 |
| Quality gate PASS/WARN/FAIL | 65.48% / 26.68% / 7.84% |

## Simulation Assumptions

| Assumption | Value |
|---|---|
| Annual volume | 100000 |
| Working days | 250 |
| Patients/day | 400.0 |
| Prevalence (assumption) | 40.65% |
| Specialist capacity | 60/day |
| Recapture rate | 0.50 |

## Baseline Results (1 year)

- Patients arrived: **100000**
- AI-screened: **96081**
- Referable (true): **39062**
- TP / FN: **35392 / 3670**
- FP / TN: **3015 / 54005**
- Specialist referrals: **38406 / year (153.6 / day)**
- Reviewed: **15000**; year-end backlog: **23406**; peak queue: **23406**
- Specialist utilization: **100.0%**; specialists required: **7.68**
- Status: **Specialist capacity exceeded**

## Queue Behaviour

Daily demand (153.6 referrals/day) exceeds the assumed review capacity
(60/day), so the backlog grows roughly linearly across the year to ~23406.
This is the expected bottleneck: specialist review, not AI processing.

## Sanity Checks

- [PASS] TP+FN = referable (max err 0.00e+00)
- [PASS] TN+FP = non-referable (max err 0.00e+00)
- [PASS] TP+TN+FP+FN = AI-screened (max err 0.00e+00)
- [PASS] referrals = TP+FP (max err 0.00e+00)
- [PASS] no negative counts (all TP/TN/FP/FN >= 0)
- [PASS] utilization >= 0 (min 1.0000)
- [PASS] queue never negative (min 93.6253)
- [PASS] zero volume -> all zero (all outputs zero at volume=0)
- [PASS] infinite capacity -> no backlog (max queue 0.0000)
- [PASS] annual TP+FN = annual referable (TP+FN=39061.7 ref=39061.7)
- [PASS] annual referrals = TP+FP (ref=38406.3 TP+FP=38406.3)

## Simulink Verification

- Model: `src/simulink/DrishtiCare_DistrictScreening.slx`
- Ran: 1; daily samples: 250
- Max abs difference vs reference engine: 0.000e+00 (tolerance 1e-6)
- Matches reference: 1
