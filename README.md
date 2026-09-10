# DrishtiCare � Explainable AI for Diabetic Retinopathy Screening

**Problem Statement:** SIH 26038 | **Sponsor:** MathWorks | **Internal Round:** 12 September 2026

## Overview

MATLAB/Simulink-based DR screening pipeline for rural India. 10-day build for internal hackathon round.

> **Status / disclaimer:** Engineering research project for the 12 Sep 2026 internal
> hackathon round. NO clinical validation has been performed. Automated grade
> labels, confidence-routed recommendations, Grad-CAM overlays, OOD flags and
> lesion candidate counts are engineering demonstrations. They must NOT be used
> for diagnosis, treatment, triage, or any patient-facing decision. Reported
> metrics are engineering measurements on a validation split (see
> `docs/validation/metrics.md` and `docs/task-tracker.md`).

## Quick Start

1. **Read the roadmap:** [roadmap-10day.md](roadmap-10day.md)
2. **Check today's tasks:** [schedule/](schedule/)
3. **Review module specs:** [modules/](modules/)

## Timeline

```
Sep 2  -- Day 1:  MATLAB access + dataset download
Sep 3  -- Day 2:  Data exploration + repo structure
Sep 4  -- Day 3:  Image quality assessment module
Sep 5  -- Day 4:  Image enhancement module
Sep 6  -- Day 5:  Classifier setup (transfer learning)
Sep 7  -- Day 6:  Classifier training + first results
Sep 8  -- Day 7:  Grad-CAM explainability
Sep 9  -- Day 8:  Simulink workflow model
Sep 10 -- Day 9:  Integration + auto-report
Sep 11 -- Day 10: Pitch deck + rehearsal
Sep 12 -- INTERNAL ROUND
```

## Project Structure

```
DrishtiCare/
+-- roadmap-10day.md          # Master roadmap
+-- context/                  # Problem statement, goals, tools
+-- team/                     # Roles, risk checklist
+-- schedule/                 # Day 1-10 tasks
+-- modules/                  # Module specifications
+-- pitch/                    # Deck structure, demo script
+-- src/                      # MATLAB source code
+-- data/                     # Datasets (APTOS, IDRiD, DRIVE)
+-- docs/                     # Reference documentation
```

## Key Files

| File | Purpose |
|------|---------|
| [roadmap-10day.md](roadmap-10day.md) | Master roadmap with navigation |
| [context/goals-internal-round.md](context/goals-internal-round.md) | What we're delivering Sep 12 |
| [team/roles.md](team/roles.md) | Who does what |
| [schedule/day-01-setup.md](schedule/day-01-setup.md) | Start here on Day 1 |
| [pitch/demo-script.md](pitch/demo-script.md) | How to present |

## Datasets

| Dataset | Status | Size |
|---------|--------|------|
| APTOS 2019 | Downloaded | 9.7 GB |
| IDRiD | Downloaded | 962 MB |
| DRIVE | Downloaded | 29 MB |
| DRIMDB | Downloaded | 17 MB |

## Team

- 6 members + mentors
- See [team/roles.md](team/roles.md) for assignments

## License

Academic use only. Dataset licenses apply individually.
