# Week 4 — Validation, Simulink & Demo (Days 22-42)

## Status: NOT STARTED

## Tasks

| Task | Owner | Status | Notes |
|------|-------|--------|-------|
| Ablation study (9 configurations) | Seat 4 | Pending | THE centerpiece — design backwards from this |
| External validation (Messidor-2) | Seat 4 | Pending | Lock model first, then evaluate |
| Cross-dataset test (IDRiD↔APTOS) | Seat 4 | Pending | Tests generalization |
| Subgroup analysis (camera type, severity) | Seat 4 | Pending | |
| Simulink queueing model | Seat 6 | Pending | M/M/c, utilization, abandonment |
| Threshold-staffing Pareto analysis | Seat 6 | Pending | Cost vs accuracy tradeoff |
| MATLAB App Designer GUI | Seat 5 | Pending | Live demo interface |
| Live demo script + practice | All | Pending | 5-7 minute demo |
| Documentation finalization | Seat 6 | Pending | All modules documented |

## Milestones

- [ ] Ablation table complete — integrated > any single technique
- [ ] External validation: AUC > 0.90 on Messidor-2
- [ ] Simulink model: 95% utilization at 2,400 images/year
- [ ] Working demo with live inputs
- [ ] 30-second clinician validation

## Risks

- External validation shows poor transfer → honest reporting + explain why
- Simulink model too simple → add stochastic variability
- Demo crashes → have pre-recorded backup

## Notes

- **DO NOT skip the ablation study** — judges explicitly said it matters
- Practice the demo 3+ times before the final presentation
- Prepare for "what if you don't have GPU?" question
