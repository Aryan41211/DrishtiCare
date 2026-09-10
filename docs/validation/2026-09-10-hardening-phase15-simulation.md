# DrishtiCare Hardening — Phase 15: System-Level Discrete-Event Simulation

Date: 2026-09-10. **4/4 PASS.**

**Engineering discrete-event simulation, NOT a clinical operations claim.** Two
defects were found and fixed during the run: (a) a placeholder/duplicate first
router loop in the draft, and (b) an order-of-magnitude arrival-rate bug
(`60/minPerDay * arrivalsPerDay` → 75/min, ~36,000 arrivals/day instead of
600/day). Both corrected; final run below.

## What was modeled
Day-level event simulation of a rural screening workflow (documented substitute
for the Simulink/SimEvents module — SimEvents not installed):

```
Poisson arrivals (8h day, minute bins)
  -> quality gate (FAIL 7.84% | WARN 26.68% -> 25% review | PASS)
  -> auto-screening (CLEAR -> auto-answer)
     or REVIEW/ABSTAIN + gate flags -> specialist review queue (daily capacity)
  -> end-of-day referral list
```

Anchors are **measured**, not assumed: router behaviour computed by rerunning
`cascade_router` on all **733 locked val predictions** (not a hard-coded split);
AI screening 0.1028 s/img (dashboard); inspector full path 11.03 s/img (Phase 12
median); gate distribution from the Day-3 train assessment (n=3662).

## Results (engineering numbers)
- **Measured val router fractions:** CLEAR 0.884, REVIEW 0.102, ABSTAIN 0.014
  (sum = 1). Engineered flagged fraction ≈ 0.248 (gate FAIL + 25% WARN + router
  REVIEW/ABSTAIN on the passing remainder).
- **Nominal 600 img/day, specialist capacity 350/day:** 453 auto-clear/day,
  149 flagged/day, 149 reviewed/day, EOD backlog 0 → **stable** (10-day slope
  0.0 img/day). Reviewer headcount for stationarity: **3** (assumed
  60 exams/reviewer/day).
- **Bottleneck sensitivity: 4× volume (2,400 img/day), same capacity:**
  queue grows ~234 img/day → system is **unstable**, specialist review is the
  bottleneck. This is the expected "key insight" of the module.

## PASS checks
1. `P15 route_fractions_measured` — fractions sum to 1, computed from locked
   preds (no assumed route split).
2. `P15 sim_stable_nominal` — 600 img/day stable with 350/day review capacity.
3. `P15 reviewers_reported` — headcount estimate emitted (3).
4. `P15 bottleneck_sensitivity` — 4× workload with same capacity is clearly
   unstable (slope 234 img/day @ EOD backlog 7,000+).

## Caveats (stated honestly)
- Arrival model is Poisson/day-uniform; real clinics have arrival peaks.
- 60 exams/reviewer/day and 350/day capacity are **assumptions** (not measured
  operational data); the sim demonstrates *sensitivity*, not a staffing
  prescription.
- Quality-gate fractions were measured on the training set, not on a clinical
  deployment population.

## Artifacts
- `src/phase15_system_simulation.m`
- `data/analysis/day10/phase15/phase15_system_simulation.mat`
  (fields: `routeFractions`, `qualityFractions`, `params`, `daily`,
  `slopeNominal`, `slope4x`, `reviewersNeeded`, `auditRes`)