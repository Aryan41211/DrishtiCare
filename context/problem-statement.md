# Problem Statement — SIH 26038

## Title
Explainable AI for Diabetic Retinopathy Screening in Rural India

## Sponsor
MathWorks

## Theme
MedTech/BioTech/HealthTech

## The Problem

India has **77 million diabetic adults** with **18% DR prevalence**. Rural areas have **1 ophthalmologist per 100,000 population**. Most diabetic retinopathy cases go undetected until permanent vision loss.

## What the PS Expects

A MATLAB/Simulink-based pipeline with:

1. **Image Quality Assessment & Enhancement** — Quality gate with reason codes, closed-loop enhance→re-score, reject/recapture feedback
2. **Retinal Structure Segmentation** — OD/fovea, vessels, MA, HE, EX, SE detection
3. **DR Severity Grading** — ICDR 0-4, >90% sensitivity, >85% specificity for referable DR (≥2)
4. **Explainability Module** — Grad-CAM, lesion evidence, calibrated confidence, <30 sec review
5. **Simulink Workflow Simulation** — Queueing model, bandwidth, throughput for 100k+ patients/year

## The Hidden Grading Criterion

> "...validation against published benchmarks showing the integrated pipeline outperforms any single technique approach."

This asks for an **ablation study** — proof that the assembled pipeline beats each of its parts alone.

## ICDR Severity Scale

| Level | Name | Key Findings | Referable? |
|-------|------|--------------|------------|
| 0 | No DR | No abnormalities | No |
| 1 | Mild NPDR | Microaneurysms only | No |
| 2 | Moderate NPDR | More than MA, less than severe | **Yes** |
| 3 | Severe NPDR | 4-2-1 rule | **Yes** |
| 4 | PDR | Neovascularization | **Yes** |

**Referable DR = Level ≥ 2** — this is the binary endpoint for >90%/>85% targets.

## Performance Bar

| Metric | Target | Literature |
|--------|--------|-----------|
| Sensitivity (≥2) | >90% | Gulshan 2016: 96.1%, IDx-DR: 87.2% |
| Specificity (≥2) | >85% | Gulshan 2016: 93.9%, IDx-DR: 90.7% |

The bar is below published literature. You are not advancing SOTA — you are integrating, explaining, and validating.
