# DrishtiCare - Explainable AI for Diabetic Retinopathy Screening

**Problem Statement:** SIH 26038 | **Sponsor:** MathWorks | **Stage:** National screening round, 2026

## Start here

The repo grew past the 10-day internal build, so there is no single right
file. Read in this order for what you need:

| If you want | Read |
|---|---|
| How the code is organised | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| What is true right now, and what is deliberately not done | [docs/project-management/FINAL_RELEASE_STATUS.md](docs/project-management/FINAL_RELEASE_STATUS.md) |
| What must never change, and why | [docs/project-management/FROZEN_CONTRACT.md](docs/project-management/FROZEN_CONTRACT.md) |
| Whether this is finished | [docs/project-management/EXECUTION_CHECKLIST.md](docs/project-management/EXECUTION_CHECKLIST.md) — 67/69 |
| The evidence behind any number | [docs/validation/](docs/validation/) · [docs/task-tracker.md](docs/task-tracker.md) |
| How to run the app | [launchRetinaAI.m](launchRetinaAI.m), then the [GUI demo checklist](FINAL_GUI_DEMO_CHECKLIST.md) |
| How to present it | [pitch/](pitch/) · [FINAL_REHEARSAL_CHECKLIST.md](FINAL_REHEARSAL_CHECKLIST.md) |

`roadmap-10day.md` and [docs/schedule/](docs/schedule/) are the original
10-day plan, kept as history. [docs/modules/](docs/modules/) holds the module
specs as written at the time. Neither is current status.

## Overview

MATLAB/Simulink DR screening pipeline for rural India. A quality gate runs
**before** the classifier; an image that fails it is withheld for recapture
and the model is never called. Over-refusal is the intended failure direction.

> **Status / disclaimer:** Engineering research project. NO clinical validation
> has been performed. Automated grade labels, confidence-routed
> recommendations, Grad-CAM overlays, OOD flags and lesion candidate counts
> are engineering demonstrations. They must NOT be used for diagnosis,
> treatment, triage, or any patient-facing decision. Reported metrics are
> engineering measurements on an internal validation split — see
> [docs/validation/metrics.md](docs/validation/metrics.md) and
> [docs/task-tracker.md](docs/task-tracker.md).

### What is measured, and what is not

Stated plainly because it is the point of the submission. Full detail in
[FINAL_RELEASE_STATUS.md](docs/project-management/FINAL_RELEASE_STATUS.md).

- **Measured, internally:** QWK 0.8914, sensitivity 0.9060, specificity 0.9471
  on the locked 733-image APTOS split, seed 42, threshold 0.60.
- **Measured, and weak:** Grad-CAM localisation (3.1% saliency-in-lesion,
  IoU 0.035), MA lesion recall 0.113, fovea localisation 0/10.
- **Not performed:** external validation. Messidor-2 needs ADCIS
  registration and Sin-NP DR 2019 needs a data request. The harness passes
  6/6 but has never seen their data.
- **Excluded on evidence:** image enhancement and vessel features, both of
  which made results worse.

## Project Structure


```
DrishtiCare/
+-- RetinaAIApp.m             # USER-FACING APP CLASS — at the REPO ROOT, not
+-- │                          #   under src/ (matlab.apps.AppBase, 1430 lines).
+-- │                          #   Launch via launchRetinaAI.m; it is a thin
+-- │                          #   caller of predictSingleFundus.
+-- launchRetinaAI.m          # App launcher: run this in MATLAB
+-- roadmap-10day.md          # Master roadmap
+-- src/
+-- ├── runs/                 # Runnable eval + smoke-test scripts
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
+-- ├── ui/                   # Shared presentation layer: drishtiTheme,
+-- │                          #   drishtiColormap, gradcamColorbarStrip,
+-- │                          #   renderGradCAMViews (used by BOTH the app
+-- │                          #   and the PDF report)
+-- ├── demo/                 # Failure-aware end-to-end screening demo
+-- │                          #   (quality FAIL never reaches the AI stage)
+-- │                          #   + tests/ contract suite
+-- ├── analysis/             # Grad-CAM alignment analysis helpers
+-- │                          #   (gradcam_alignment/)
+-- ├── dashboard/            # App Designer 5-tab dashboard (DRScreeningDashboard)
+-- │                          #   + headless verifiers / visual-QA harness.
+-- │                          #   NOTE: the user-facing app class is
+-- │                          #   RetinaAIApp.m at the ROOT, not here.
+-- ├── reporting/            # PDF screening reports (branded A4, 2-tier engine)
+-- ├── data_loaders/         # Dataset loading + splits
+-- ├── setup/                # Day-1 setup utilities
+-- └── simulink/             # District screening & resource-allocation model
+--                              #   DrishtiCare_DistrictScreening.slx + build
+--                              #   script + reference engine
+-- data/
+-- ├── aptos2019/ idrid/ drive/ drimdb/   # Datasets (git-ignored, local only)
+-- ├── models/               # Locked champion weights (convention: kept here)
+-- ├── splits/               # 2929 train / 733 val (seed 42)
+-- └── analysis/             # Metrics + audit evidence (committed)
+--                              #   e.g. simulink_resource_simulation/,
+--                              #        failure_aware_demo/
+-- results/                  # Demo outputs (PDFs, visualizations)
+-- audit/ docs/ pitch/ team/ context/
+-- archive/                  # Legacy scripts + old probes (reference only)
```

> Models live under `data/models/` by convention (locked champions + registry).
> Root runners moved to `src/runs/` — launch them with `run src/runs/<name>`
> after `cd`-ing to the repo root; each script sets its own paths.
>
> **Launch the app:** run `launchRetinaAI.m` from the repo root (it adds the root
> plus `src/` recursively to the path and instantiates `RetinaAIApp`).
>
> **Governance and evidence:** [docs/project-management/](docs/project-management/)
> holds the roadmap, frozen contract, decision log, execution checklist, demo and
> submission plan, plus the annotated [file map](docs/project-management/CURRENT_STATUS.md).
> [`docs/task-tracker.md`](docs/task-tracker.md) is the evidence record behind
> every status claim made in those documents.

## Key Files

| File | Purpose |
|------|---------|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | **How the code is organised** — the 20 modules, the pipeline order, the four gates |
| [launchRetinaAI.m](launchRetinaAI.m) | **Start the screening app** — launcher wrapper (adds paths, instantiates the class) |
| [RetinaAIApp.m](RetinaAIApp.m) | The user-facing screening app class (repo root, `matlab.apps.AppBase`) — DRISHTI dashboard |
| [src/inference/predictSingleFundus.m](src/inference/predictSingleFundus.m) | Single-image pipeline: quality → grade → referable → route. **The frozen contract boundary** |
| [src/reporting/generateDrishtiReport.m](src/reporting/generateDrishtiReport.m) | Branded A4 PDF screening report (`mlreportgen` → headless Edge) |
| [src/quality/](src/quality/) | The quality gate that runs before the model |
| [src/verify/](src/verify/) | The headless test suite — 27 scripts, including the gates below |
| [src/runs/](src/runs/) | Runnable evaluation + smoke-test scripts |
| [src/simulink/DrishtiCare_DistrictScreening.slx](src/simulink/DrishtiCare_DistrictScreening.slx) | District screening & resource-allocation model (`.slx` + build script) |
| [data/analysis/simulink_resource_simulation/README.md](data/analysis/simulink_resource_simulation/README.md) | Simulation method, measured inputs, labelled assumptions, limitations |
| [src/demo/run_failure_aware_demo.m](src/demo/run_failure_aware_demo.m) | Failure-aware end-to-end demo (quality FAIL never reaches the AI stage) |
| [src/ui/drishtiTheme.m](src/ui/drishtiTheme.m) | Shared theme: one source of truth for app + report colours and Grad-CAM rendering |
| [docs/task-tracker.md](docs/task-tracker.md) | Per-task status, evidence paths and honest negative results |
| [docs/validation/metrics.md](docs/validation/metrics.md) | Frozen metric definitions and headline numbers |
| [docs/project-management/FROZEN_CONTRACT.md](docs/project-management/FROZEN_CONTRACT.md) | What must never change, and the model hashes |
| [FINAL_GUI_DEMO_CHECKLIST.md](FINAL_GUI_DEMO_CHECKLIST.md) | Pre-flight and run steps for the live demo |
| [FINAL_REHEARSAL_CHECKLIST.md](FINAL_REHEARSAL_CHECKLIST.md) | Content, demo and adversarial rehearsal passes |
| [pitch/deck.pptx](pitch/deck.pptx) | The editable 11-slide deck (fill in the SIH Team ID here) |
| [pitch/demo-script.md](pitch/demo-script.md) | How to present |
| [team/roles.md](team/roles.md) | Who does what |

## Verification

Four headless gates, all of which must pass. Run from the repo root:

```matlab
addpath('src/verify'); addpath('src/dashboard'); addpath('src/reporting');
addpath('src/inference');
verify_app_layout
verify_gradcam_rendering
verify_drishti_report_extended
```

```powershell
powershell -ExecutionPolicy Bypass -File pitch\audit_deck_pptx.ps1
```

Chromium `fallback_task_provider` lines in the MATLAB log are Edge engine
startup noise, not failures.

## Datasets

Local only — all of these are gitignored and none is committed. Sizes are
what was downloaded, not what ships.

| Dataset | Status | Size | Used for |
|---------|--------|------|----------|
| APTOS 2019 | Downloaded | 9.7 GB | Primary training + the locked 733-image validation split |
| IDRiD | Downloaded | 962 MB | Lesion GT, B-test unseen rehearsal |
| DRIVE | Downloaded | 29 MB | Unseen foreign-camera rehearsal |
| DRIMDB | Downloaded | 17 MB | Real-world web fundus, unseen rehearsal |
| Messidor-2 | **Not available** | — | Needs ADCIS registration — blocks external validation |
| Sin-NP DR 2019 | **Not available** | — | Needs a data request — blocks external validation |

Datasets are never committed. Regenerate them under `data/`; nothing in
`src/` depends on a checked-in image.

## Team

- 6 members + mentors
- See [team/roles.md](team/roles.md) for assignments

## License

Academic use only. Dataset licenses apply individually. Not a medical
device; not for clinical use.

