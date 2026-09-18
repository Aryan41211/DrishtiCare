# DrishtiCare - Explainable AI for Diabetic Retinopathy Screening

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
+-- RetinaAIApp.m             # Screening app (user-facing entry point)
+-- launchRetinaAI.m          # App launcher: run this in MATLAB
+-- roadmap-10day.md          # Master roadmap
+-- src/
+-- ├── runs/                 # Runnable scripts: pipeline, eval, smoke tests
+-- │                          (`run src/runs/runSmokeTest` from repo root)
+-- ├── phases/               # Day-10 system audits (phase1..phase25)
+-- ├── verify/               # Independent evaluators + re-verification
+-- ├── quality/              # Image quality assessment
+-- ├── enhancement/          # Image enhancement/preprocessing
+-- ├── grading/              # DR grading + classifier evaluation
+-- ├── explainability/       # Grad-CAM and model explanation
+-- ├── vessel/               # Vessel processing (legacy_* = superseded)
+-- ├── lesions/              # Lesion analysis
+-- ├── inference/            # Single-image inference + cascade router
+-- ├── calibration/          # Temperature scaling (T=2.5382)
+-- ├── ood_detection/        # Mahalanobis OOD detector
+-- ├── dashboard/            # Dashboard app code
+-- ├── reporting/            # PDF screening reports
+-- ├── data_loaders/         # Dataset loading + splits
+-- ├── setup/                # Day-1 setup utilities
+-- └── simulink/             # Simulink workflow model (.slx)
+-- data/
+-- ├── aptos2019/ idrid/ drive/ drimdb/   # Datasets (git-ignored, local only)
+-- ├── models/               # Locked champion weights (convention: kept here)
+-- ├── splits/               # 2929 train / 733 val (seed 42)
+-- └── analysis/             # Metrics + audit evidence (committed)
+-- results/                  # Demo outputs (PDFs, visualizations)
+-- audit/ docs/ pitch/ team/ context/ schedule/ modules/
+-- archive/                  # Legacy scripts + old probes (reference only)
```

> Models live under `data/models/` by convention (locked champions + registry).
> Root runners moved to `src/runs/` — launch them with `run src/runs/<name>`
> after `cd`-ing to the repo root; each script sets its own paths.

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
