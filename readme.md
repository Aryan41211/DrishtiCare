# DrishtiCare — Explainable AI for Diabetic Retinopathy Screening

**Problem Statement:** SIH 26038 | **Sponsor:** MathWorks | **Theme:** MedTech/BioTech/HealthTech

## Overview

A MATLAB-based retinal image analysis pipeline for automated Diabetic Retinopathy (DR) screening targeting rural India, where 77 million diabetic adults face a 18% DR prevalence with only 1 ophthalmologist per 100,000 rural population.

## Architecture

`
Image In → Quality Gate → Enhancement → Cascade Router → Dual Evidence Path → Calibrated Grade + Report
`

See [architecture.md](architecture.md) for full system design.

## Quick Start

1. Download datasets (see data/ folder)
2. Set up MATLAB (see execution/matlab-setup.md)
3. Follow the module build order (see execution/timeline.md)

## License

Academic use only. Dataset licenses apply individually.
