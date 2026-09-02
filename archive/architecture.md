# System Architecture — DrishtiCare DR Screening Pipeline

## Design Principle

**Dual-evidence path with closed-loop feedback.** Every clinical decision is backed by two independent evidence streams that must agree before the system commits to a grade. This is not a classifier with an explainability add-on — it is an evidence-agreement system where the classifier and the lesion model are peers.

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TRAINING PIPELINE (Offline)                             │
│                                                                             │
│  EyePACS + APTOS → Preprocessing → Augmentation → Patch Extraction        │
│       │                                                                       │
│       ▼                                                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐     │
│  │                    MODEL TRAINING HUB                               │     │
│  │                                                                     │     │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                │     │
│  │  │ Branch A    │  │ Branch B    │  │ Quality     │                │     │
│  │  │ Deep        │  │ Lesion      │  │ Gate        │                │     │
│  │  │ Classifier  │  │ Feature     │  │ Trainer     │                │     │
│  │  │ (EfficientNet│  │ Model       │  │ (EyeQ +    │                │     │
│  │  │  /ResNet)   │  │ (GradBoost/ │  │  handcraft) │                │     │
│  │  │             │  │  SVM)       │  │             │                │     │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘                │     │
│  │         │                │                │                        │     │
│  │         ▼                ▼                ▼                        │     │
│  │  ┌─────────────────────────────────────────────────────────────┐   │     │
│  │  │              CALIBRATION LAYER                              │   │     │
│  │  │  Constrained Temperature Scaling on validation split        │   │     │
│  │  │  Focus: referable/non-referable decision boundary           │   │     │
│  │  └─────────────────────────────────────────────────────────────┘   │     │
│  └─────────────────────────────────────────────────────────────────────┘     │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐     │
│  │              VALIDATION PIPELINE                                    │     │
│  │  IDRiD test → Messidor-2 external → Ablation table → FROC curves  │     │
│  └─────────────────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                       INFERENCE PIPELINE (Runtime)                         │
│                                                                             │
│  Fundus Image In                                                            │
│    │                                                                        │
│    ▼                                                                        │
│  ┌──────────────────┐                                                       │
│  │ QUALITY GATE     │── REJECT → Reason code → Recapture feedback          │
│  │ (interpretable)  │                                                       │
│  └────────┬─────────┘                                                       │
│           │ ADMIT                                                           │
│           ▼                                                                 │
│  ┌──────────────────┐                                                       │
│  │ ENHANCEMENT      │                                                       │
│  │ (CLAHE + illum   │                                                       │
│  │  norm + denoise  │                                                       │
│  │  + Graham)       │                                                       │
│  └────────┬─────────┘                                                       │
│           │                                                                 │
│           ▼                                                                 │
│  ┌──────────────────┐                                                       │
│  │ OOD DETECTOR     │── OOD → Human review ("unfamiliar type")            │
│  │ (Mahalanobis     │                                                       │
│  │  distance)       │                                                       │
│  └────────┬─────────┘                                                       │
│           │ IN-DISTRIBUTION                                                  │
│           ▼                                                                 │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ CASCADE ROUTER                                                       │   │
│  │                                                                      │   │
│  │ Run 3-backbone ensemble (EfficientNet-B4 + ResNet-50 + Inception)   │   │
│  │ Calibrated via constrained temperature scaling                       │   │
│  │                                                                      │   │
│  │ Average calibrated P(grade≥2) across ensemble                        │   │
│  │                                                                      │   │
│  │ ┌────────────────────────────────────────────────────────────────┐  │   │
│  │ │ CONFIDENCE BAND                                                 │  │   │
│  │ │                                                                 │  │   │
│  │ │ conf > 0.92 ──→ CLEAR (no Branch B needed)                    │  │   │
│  │ │ 0.35 < conf < 0.92 ──→ RUN BRANCH B → FUSE                   │  │   │
│  │ │ conf < 0.35 ──→ ABSTAIN → Human review                        │  │   │
│  │ └────────────────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────┬───────────────────────────────────────────┘   │
│                             │                                               │
│              ┌──────────────┼──────────────┐                                │
│              ▼              ▼              ▼                                │
│         CLEAR         NEED REVIEW      ABSTAIN                              │
│              │              │              │                                │
│              │              ▼              ▼                                │
│              │     ┌──────────────────────────┐                            │
│              │     │    BRANCH B              │                            │
│              │     │    Lesion Model          │                            │
│              │     │    (MA/HE/EX/SE counts   │                            │
│              │     │     + 4-2-1 rule eval)   │                            │
│              │     └──────────┬───────────────┘                            │
│              │                │                                             │
│              │                ▼                                             │
│              │     ┌──────────────────────────┐                            │
│              │     │  EVIDENCE AGREEMENT      │                            │
│              │     │  A grade == B grade?     │                            │
│              │     │  → Yes: commit           │                            │
│              │     │  → No: flag for review   │                            │
│              │     └──────────┬───────────────┘                            │
│              │                │                                             │
│              └────────────────┼─────────────────────────────────────────────┘
│                               ▼                                             │
│              ┌──────────────────────────────────────────┐                   │
│              │  REPORT GENERATION                       │                   │
│              │  • Grad-CAM (quantified IoU vs lesions)  │                   │
│              │  • Lesion evidence (4-2-1, quadrant maps)│                   │
│              │  • Calibrated confidence                 │                   │
│              │  • Recommended action + follow-up        │                   │
│              └──────────────────────────────────────────┘                   │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                    SIMULINK SYSTEM MODEL                                   │
│                                                                             │
│  Poisson Arrival → Quality Gate → AI Inference Queue → Decision Splitter   │
│       │                                                                       │
│       ▼                                                                       │
│  Threshold Sweep: Referral Volume vs Reviewer Load vs Turnaround            │
│  → Pareto frontier → Optimal operating point                                │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Three Feedback Loops

### 1. Quality Feedback Loop
```
Image → QA gate → reject/admit → enhance → re-score → admit only if quality improved
```
Reason codes flow back to the health worker with actionable guidance.

### 2. Evidence Agreement Loop
```
Branch A (deep) and Branch B (lesion) produce independent assessments
→ Agree: confident grade
→ Disagree: uncertain → abstain → human review
```
This is the clinical safety mechanism.

### 3. Threshold-Resource Loop (Simulink)
```
Sweep referable-DR threshold → changes referral volume → changes reviewer workload → changes staffing requirement
```
The clinical operating point and the resource budget are the same variable viewed from two ends.

## Branch Specifications

### Branch A — Deep Classifier (Accurate but Opaque)

- **Input:** Enhanced fundus image
- **Architecture:** EfficientNet-B4 (primary), ResNet-50, Inception-v3 (ensemble)
- **Pretraining:** ImageNet → EyePACS → APTOS (progressive)
- **Output head:** 4 sigmoid outputs — P(grade≥1), P(grade≥2), P(grade≥3), P(grade≥4)
- **P(grade≥2)** is the direct referable-DR probability
- **Also produces:** Grad-CAM attention map on final convolutional layer

### Branch B — Lesion-Feature Model (Interpretable by Construction)

- **Input:** Enhanced fundus image + vessel segmentation + OD/fovea locations
- **Processing:** Dedicated detection sub-modules per lesion type
  - MA: Two-stage candidate-then-classify → count per quadrant
  - HE: Candidate pipeline → count per quadrant → subtype classification
  - EX: Morphological reconstruction → area + distance to fovea
  - SE: Fuzzy-boundary detection → presence/absence
  - Vessels: Tortuosity, fractal dimension, density features
- **Output:** Structured feature vector → gradient-boosted trees → ICDR grade
- **Also produces:** Quadrant-level counts for 4-2-1 rule evaluation

### Evidence Agreement Layer

- Compare Branch A grade with Branch B grade
- If both agree and both confident → commit to grade
- If Branch A confident but Branch B disagrees → flag discrepancy → human review
- If both uncertain → abstain → human review
- The agreement rate itself is a quality metric for the system

## Cascade Efficiency

Instead of running both branches on every image:

1. **Run Branch A ensemble first** (fast, accurate)
2. **If confident (conf > 0.92):** Commit to grade, skip Branch B
3. **If uncertain (0.35 < conf < 0.92):** Run Branch B → fuse
4. **If very uncertain (conf < 0.35):** Abstain → human review

**Impact:** Branch B only runs on ~30-40% of images (borderline cases). Cuts average inference time by ~40% while maintaining accuracy on hard cases.

## Module Mapping

| Module | Documentation | Key Output |
|--------|--------------|------------|
| Quality Gate | [MODULE-1-QUALITY.md](docs/modules/MODULE-1-QUALITY.md) | Gradeable/Borderline/Ungradeable + reason code |
| Enhancement | [MODULE-1-QUALITY.md](docs/modules/MODULE-1-QUALITY.md) | CLAHE + illumination norm + denoising |
| OOD Detection | [MODULE-0-OOD-DETECTION.md](docs/modules/MODULE-0-OOD-DETECTION.md) | In-distribution / OOD flag |
| Cascade Router | [MODULE-0-CASCADE-ROUTER.md](docs/modules/MODULE-0-CASCADE-ROUTER.md) | Clear/Need Review/Abstain |
| Segmentation | [MODULE-2-SEGMENTATION.md](docs/modules/MODULE-2-SEGMENTATION.md) | OD/fovea/vessels/MA/HE/EX/SE |
| Grading | [MODULE-3-GRADING.md](docs/modules/MODULE-3-GRADING.md) | ICDR 0-4 + calibrated confidence |
| Explainability | [MODULE-4-EXPLAINABILITY.md](docs/modules/MODULE-4-EXPLAINABILITY.md) | Grad-CAM + lesion evidence + report |
| Simulink | [MODULE-5-SIMULINK.md](docs/modules/MODULE-5-SIMULINK.md) | Queueing model + Pareto analysis |
