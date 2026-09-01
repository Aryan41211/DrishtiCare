# DrishtiCare — Explainable AI for Diabetic Retinopathy Screening

**Problem Statement:** SIH 26038 | **Sponsor:** MathWorks | **Theme:** MedTech/BioTech/HealthTech

## Overview

A MATLAB-based retinal image analysis pipeline for automated Diabetic Retinopathy (DR) screening targeting rural India, where 77 million diabetic adults face a 18% DR prevalence with only 1 ophthalmologist per 100,000 rural population.

**Key Statistics:**
- Diabetes-related blindness costs India **INR 400 billion annually** (ORNATE 2023)
- Google ARDA at Aravind Eye Hospital: **0% miss rate** for referable DR
- Remidio: First CDSCO-approved ophthalmic AI software in India (2024)
- India launched first national AI DR screening programme (Dec 2025)

## Architecture

```
Image In → Quality Gate → Enhancement → Cascade Router → Dual Evidence Path → Calibrated Grade + Report
                                    ↓                                                        ↓
                              Reject + Reason Code                              Grad-CAM + Lesion Evidence + 4-2-1 Rule
```

See [architecture.md](architecture.md) for full system design.

## Key Differentiators

1. **Dual-evidence path** — Deep classifier + interpretable lesion model must agree
2. **Constrained temperature scaling** — Calibration focused on referable/non-referable boundary
3. **Grad-CAM quantification** — IoU measured against IDRiD lesion masks, not just visual
4. **4-2-1 rule implementation** — Quadrant-level hemorrhage counting for ICDR Level 3
5. **Cascade efficiency** — Branch B only runs on ~30-40% borderline cases (40% compute savings)
6. **Simulink threshold-staffing Pareto** — Clinical operating point = resource budget

## Performance Targets

| Metric | Target | Published Comparison |
|--------|--------|---------------------|
| Referable DR Sensitivity | >90% | MONA.health: 88.9%, EyeArt: 95%, IDx-DR: 87.2% |
| Referable DR Specificity | >85% | MONA.health: 98.7%, EyeArt: 81%, IDx-DR: 90.7% |
| AUC-ROC | >0.95 | MONA.health: 0.965, AADR-AI: 0.967 |
| Ophthalmologist Review | <30 seconds | Report designed for cognitive speed |

## Project Structure

```
DrishtiCare/
├── readme.md                          # This file
├── architecture.md                    # Full system design
├── contributing.md                    # Contribution guidelines
├── data/                              # Dataset storage
│   ├── aptos2019/                     # APTOS 2019 (3,662 images)
│   ├── idrid/                         # IDRiD (516 images + lesions)
│   ├── drive/                         # DRIVE (40 images, vessel masks)
│   ├── drimdb/                        # DRIMDB (216 images, quality labels)
│   ├── hrf/                           # HRF (45 images, high-res)
│   ├── stare/                         # STARE (20 images)
│   ├── chase_db1/                     # CHASE_DB1 (28 images)
│   ├── eyepacs2015/                   # EyePACS 2015 (88,702 images)
│   └── dr_testing_set/                # DR Testing Set
├── docs/
│   ├── analysis/                      # Problem analysis & strategy
│   │   ├── ps-analysis.md
│   │   ├── framing.md
│   │   ├── risk-register.md
│   │   └── winning-factors.md
│   ├── background/                    # Clinical & technical background
│   │   ├── clinical-background.md
│   │   ├── literature-verification.md
│   │   ├── matlab-toolbox-guide.md
│   │   └── sih-logistics.md
│   ├── data/                          # Dataset documentation
│   │   ├── datasets.md
│   │   ├── data-pipeline.md
│   │   └── data-gaps.md
│   ├── modules/                       # Technical module specs
│   │   ├── 00-ood-detection/
│   │   ├── 00-cascade-router/
│   │   ├── 01-quality/
│   │   ├── 02-segmentation/
│   │   ├── 03-grading/
│   │   ├── 04-explainability/
│   │   └── 05-simulink/
│   ├── validation/                    # Validation strategy
│   │   ├── metrics.md
│   │   ├── ablation-study.md
│   │   └── external-validation.md
│   ├── execution/                     # Team & timeline
│   │   ├── team-split.md
│   │   ├── timeline.md
│   │   ├── matlab-setup.md
│   │   └── demo-prep.md
│   ├── deployment/                    # Deployment & future
│   │   ├── deployment-plan.md
│   │   └── future-roadmap.md
│   ├── references/                    # Papers & sources
│   │   ├── key-papers.md
│   │   └── dataset-sources.md
│   └── progress/                      # Weekly progress tracking
│       ├── week-1-progress.md
│       ├── week-2-progress.md
│       ├── week-3-progress.md
│       └── week-4-progress.md
└── src/                               # MATLAB source (future)
```

## Quick Start

1. Download datasets (see [docs/data/datasets.md](docs/data/datasets.md))
2. Set up MATLAB (see [docs/execution/matlab-setup.md](docs/execution/matlab-setup.md))
3. Follow the module build order (see [docs/execution/timeline.md](docs/execution/timeline.md))

## Team

- 6 members + 1-2 mentors
- At least one female member mandatory (SIH rule)
- See [docs/execution/team-split.md](docs/execution/team-split.md) for seat assignments

## Timeline

- Internal hackathon: September 2026
- Grand Finale: December 2026 (36-hour non-stop hackathon)

See [docs/background/sih-logistics.md](docs/background/sih-logistics.md) for full timeline.

## License

Academic use only. Dataset licenses apply individually.
