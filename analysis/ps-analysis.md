# Problem Statement Analysis — SIH 26038

## The Statement

Design a MATLAB-based retinal image analysis pipeline for automated DR screening addressing real-world deployment challenges in rural India.

## What It Actually Asks For (5 Required Deliverables)

| # | Deliverable | What Judges Grade |
|---|-------------|-------------------|
| 1 | Image Quality Assessment & Enhancement | Reason codes, closed-loop enhance→re-score, reject/recapture feedback |
| 2 | Retinal Structure Segmentation | OD/fovea, vessels, MA, HE, EX, SE detection |
| 3 | DR Severity Grading | ICDR 0-4, >90% sensitivity, >85% specificity for referable DR (≥2) |
| 4 | Explainability Module | Grad-CAM, lesion evidence, calibrated confidence, <30 sec review |
| 5 | Simulink Workflow Simulation | Queueing model, bandwidth, throughput for 100k+ patients/year |

## The Hidden Grading Criterion

The expected-solution paragraph ends with:

> "...validation against published benchmarks showing the integrated pipeline outperforms any single technique approach."

This asks for an **ablation study** — proof that the assembled pipeline beats each of its parts alone. Cheap to produce, widely skipped.

**Design the whole project backwards from this one table.**

## Required Toolchain

Image Processing, Computer Vision, Deep Learning, Medical Imaging, Statistics & ML Toolboxes, plus Simulink. This is a MathWorks-owned PS — evaluators check genuine toolbox usage.

## Performance Bar

| Metric | Target | Literature |
|--------|--------|-----------|
| Sensitivity (≥2) | >90% | Gulshan 2016: 96.1%, IDx-DR: 87.2% |
| Specificity (≥2) | >85% | Gulshan 2016: 93.9%, IDx-DR: 90.7% |

The bar is below published literature. You are not advancing SOTA — you are integrating, explaining, and validating.

## Why This Is Winnable

1. **The MATLAB filter** — Most student teams are Python-native. Commit to MATLAB and competition thins.
2. **The ablation study is cheap** — Same experiment run 4-5 times with pieces switched off.
3. **Explainability quantification is free** — IDRiD gives pixel masks. Measure Grad-CAM IoU against them.
4. **The Simulink model is load-bearing** — Not a bonus slide. Required deliverable.
5. **The framing is deployment, not algorithm** — "We're not proposing a better classifier; we're proposing the system that lets an existing classifier be trusted and deployed."

## Risk: The Last Line

> "This problem demands clinical validation rigor, sub-pixel microaneurysm detection, and clinically meaningful explainability"

- "Clinical validation rigor" = ablation study + external validation + calibration
- "Sub-pixel MA detection" = FROC curve at fixed FP/image, not literal sub-pixel spec
- "Clinically meaningful explainability" = lesion evidence in ICDR criteria language
