# DrishtiCare - District Screening & Resource-Allocation Simulation

> **ENGINEERING / RESOURCE-PLANNING SIMULATION - NOT clinical validation.**

This simulation connects the project's *verified* screening performance to
district-scale patient flow and specialist review workload. It is a planning
tool, not evidence of clinical effectiveness or real staffing requirements.

## 1. Purpose

Answer: how many patients can be screened, how many are referred, how many
referable cases are caught, how many false referrals are created, how workload
scales with volume and threshold, and whether specialist review capacity is
sufficient - using the model's validated sensitivity/specificity as inputs.

## 2. Architecture

Daily aggregate (mean-field) flow model, 1-day step, 250 days = 1 year:

```
[Patient Arrival & Image Capture]
        -> [Quality Gate]            (PASS/WARNING usable, FAIL -> recapture/manual)
        -> [AI Screening & Referral] (sensitivity/specificity -> TP/FP/FN/TN)
        -> [Specialist Queue & Review] (queue, daily review capacity)
        -> [System Metrics]
```

Simulink model: `src/simulink/DrishtiCare_DistrictScreening.slx`
(built by `src/simulink/build_DrishtiCare_DistrictScreening.m`).
Reference engine + driver: `src/simulink/run_district_screening.m`.
Configuration: `src/simulink/create_simulation_config.m` -> `simulation_config.mat`.

## 3. Measured Inputs

| Input | Value | Source |
|---|---|---|
| Sensitivity @0.60 | 90.60% | `reverify_audit_T0.mat` (locked 733-val) |
| Specificity @0.60 | 94.71% | `reverify_audit_T0.mat` (locked 733-val) |
| Referral threshold | 0.60 (locked) | project config |
| Validation population | 733 | held-out APTOS validation |
| ROC-AUC / PR-AUC | 0.9796 / 0.7821 | `reverify_audit_T0.mat` |
| Quality gate PASS/WARN/FAIL | 65.48% / 26.68% / 7.84% | `quality_assessment_summary.mat` (n=3662) |
| Threshold-specific sens/spec | computed from locked PRef | `reverify_audit_T0.mat` |

### Threshold-specific operating points (measured from locked PRef)

| t | sens | spec | PPV | val referrals |
|---|---|---|---|---|
| 0.40 | 0.9295 | 0.9402 | 0.9142 | 303 |
| 0.50 | 0.9228 | 0.9425 | 0.9167 | 300 |
| 0.60 | 0.9060 | 0.9471 | 0.9215 | 293 |
| 0.70 | 0.8859 | 0.9517 | 0.9263 | 285 |
| 0.80 | 0.8624 | 0.9586 | 0.9345 | 275 |

## 4. Simulation Assumptions

All values below are **assumptions**, clearly labeled, not measurements.

| Assumption | Value | Note |
|---|---|---|
| Annual patient volume | 100000 patients/yr | planning assumption |
| Screening days | 250 /yr | working-days assumption |
| Patients / day | 400.0 | derived |
| Prevalence | 40.65% | **simulation assumption** - from validation composition, not clinical prevalence |
| Specialist capacity | 60 cases/day | 3 specialists x 20/day (assumption) |
| AI processing capacity | 480 images/day | 60 img/hr x 8 hr (assumption) |
| Recapture rate | 0.50 | assumption |
| Simulation length | 250 days @ 1-day step | daily aggregate |

## 5. Patient Flow

For each day: arrivals -> quality gate (usable vs FAIL) -> AI screening ->
referable/non-referable -> probabilistic TP/FP/FN/TN (expected flows) ->
specialist referral queue -> review capacity -> outcome/backlog.

## 6. Specialist Queue Model

Per day: `total_waiting = backlog_prev + referrals`;
`reviewed = min(total_waiting, capacity)`; `backlog = max(total_waiting - capacity, 0)`.
Utilization = `reviewed / capacity`. If demand > capacity, the backlog accumulates.

## 7. Scenario Definitions

- **A** baseline: 100k/yr, t=0.60, measured sens/spec, 60/day capacity.
- **B** lower threshold t=0.50 (measured), same volume/capacity.
- **C** higher threshold t=0.70 (measured), same volume/capacity.
- **D** volume scaling: 50k / 100k / 150k / 200k per year at t=0.60.
- **E** capacity sensitivity: 60 / 120 / 180 reviews/day at baseline.

## 8. Results (baseline)

| Quantity | Value |
|---|---|
| Patients arrived / year | 100000 |
| AI-screened / year | 96081 |
| True referable | 39062 |
| True positives (referred) | 35392 |
| False negatives | 3670 |
| False positives | 3015 |
| True negatives | 54005 |
| Specialist referrals | 38406 / year (153.6 / day) |
| Referral rate | 39.97% of AI-screened |
| Reviewed / year | 15000 |
| Year-end backlog | 23406 |
| Peak queue | 23406 |
| Specialist utilization | 100.0% |
| Specialists required | 7.68 |
| Status | **Specialist capacity exceeded** |

## 9. Scenario Results

| id | scenario | vol/yr | t | sens | spec | referrals/yr | ref/day | cap/day | util% | specialists | backlog | status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| A | Baseline (t=0.60, 100k/yr) | 100000 | 0.60 | 0.9060 | 0.9471 | 38406 | 153.6 | 60 | 100.0 | 7.68 | 23406 | Specialist capacity exceeded |
| B | Lower threshold (t=0.50) | 100000 | 0.50 | 0.9228 | 0.9425 | 39324 | 157.3 | 60 | 100.0 | 7.86 | 24324 | Specialist capacity exceeded |
| C | Higher threshold (t=0.70) | 100000 | 0.70 | 0.8859 | 0.9517 | 37358 | 149.4 | 60 | 100.0 | 7.47 | 22358 | Specialist capacity exceeded |
| D50 | Volume scaling 50k/yr | 50000 | 0.60 | 0.9060 | 0.9471 | 19203 | 76.8 | 60 | 100.0 | 3.84 | 4203 | Specialist capacity exceeded |
| D100 | Volume scaling 100k/yr | 100000 | 0.60 | 0.9060 | 0.9471 | 38406 | 153.6 | 60 | 100.0 | 7.68 | 23406 | Specialist capacity exceeded |
| D150 | Volume scaling 150k/yr | 150000 | 0.60 | 0.9060 | 0.9471 | 57610 | 230.4 | 60 | 100.0 | 11.52 | 42610 | Specialist capacity exceeded |
| D200 | Volume scaling 200k/yr | 200000 | 0.60 | 0.9060 | 0.9471 | 76813 | 307.2 | 60 | 100.0 | 15.36 | 61813 | Specialist capacity exceeded |
| E60 | Capacity 60/day | 100000 | 0.60 | 0.9060 | 0.9471 | 38406 | 153.6 | 60 | 100.0 | 7.68 | 23406 | Specialist capacity exceeded |
| E120 | Capacity 120/day | 100000 | 0.60 | 0.9060 | 0.9471 | 38406 | 153.6 | 120 | 100.0 | 7.68 | 8406 | Specialist capacity exceeded |
| E180 | Capacity 180/day | 100000 | 0.60 | 0.9060 | 0.9471 | 38406 | 153.6 | 180 | 85.3 | 7.68 | 0 | Review capacity sufficient |

## 10. Scaling Behaviour

Referral demand scales linearly with screening volume. At 100k/yr the AI
generates ~38406 referrals/year (~153.6/day); at 200k/yr roughly double. Under
the assumed 60/day review capacity, demand exceeds capacity at all volumes
(the 180/day capacity scenario is the first that clears the queue).

## 11. Limitations

- This is an **engineering simulation**, not a clinical trial or deployment.
- Specialist capacity values are **assumptions** unless externally sourced.
- Disease prevalence is an **assumption** unless directly measured.
- The simulation does **not** establish clinical effectiveness.
- It does **not** establish actual staffing requirements.
- Real deployment requires prospective clinical and operational validation.
- Queue behaviour depends on the assumptions used.
- Threshold scenarios are evidence-based only where threshold-specific
  validation data exists (here, computed from the locked 733-val PRef scores).

## 12. Interpretation

Sensitivity/specificity are not only ML metrics: they drive patient flow,
referral volume, specialist workload, and review capacity. False positives
(not just missed cases) consume specialist time; at 100k/yr, false positives
add ~3015 referrals/year on top of the ~35392 true positives.

## 13. Presentation (20-30 s)

> "DRISHTI doesn't stop at model accuracy. Using our validated sensitivity
> (90.60%) and specificity (94.71%) at the locked 0.60 threshold, we simulated
> the screening workflow at district scale. For 100,000 patients per year,
> about 96081 images reach AI screening and roughly 38406 referrals per year
> (~153.6 per working day) enter the specialist review queue - versus an
> assumed 60/day review capacity. This connects model performance to real
> resource planning. It is an engineering simulation, not proof of real-world
> staffing needs."

## 14. Sanity Checks

| check | result | detail |
|---|---|---|
| TP+FN = referable | PASS | max err 0.00e+00 |
| TN+FP = non-referable | PASS | max err 0.00e+00 |
| TP+TN+FP+FN = AI-screened | PASS | max err 0.00e+00 |
| referrals = TP+FP | PASS | max err 0.00e+00 |
| no negative counts | PASS | all TP/TN/FP/FN >= 0 |
| utilization >= 0 | PASS | min 1.0000 |
| queue never negative | PASS | min 93.6253 |
| zero volume -> all zero | PASS | all outputs zero at volume=0 |
| infinite capacity -> no backlog | PASS | max queue 0.0000 |
| annual TP+FN = annual referable | PASS | TP+FN=39061.7 ref=39061.7 |
| annual referrals = TP+FP | PASS | ref=38406.3 TP+FP=38406.3 |

Simulink verification: `matchesReference = 1` (max abs diff 0.00e+00).

---
*Generated by `src/simulink/run_district_screening.m`.*
