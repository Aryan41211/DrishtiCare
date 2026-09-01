# Winning Factors — Ranked by ROI

## Tier 1: Highest Impact, Lowest Competition

### 1. Quantified Explainability
- **What:** Measure Grad-CAM saliency against IDRiD pixel lesion masks
- **Metrics:** IoU, pointing-game score, fraction of saliency mass inside lesions
- **Why:** Converts "heatmap looks plausible" into a measured claim. Almost no student teams do this.
- **Effort:** Low — IDRiD masks exist, Grad-CAM is built into MATLAB

### 2. The Ablation Study
- **What:** CNN alone vs. Lesion model alone vs. Fused vs. Full pipeline
- **Why:** Explicitly requested in the PS. Cheap to produce. Widely skipped.
- **Effort:** Low — same experiment run 4-5 times with pieces switched off

### 3. External Validation on Messidor-2
- **What:** Test on Messidor-2 with zero training contamination. Place beside published figures.
- **Why:** Credibility anchor. Only meaningful if you never touch Messidor-2 during development.
- **Effort:** Low — just don't look at it until the end

## Tier 2: High Impact, Moderate Effort

### 4. Simulink Threshold-Staffing Pareto
- **What:** Sweep referable-DR threshold → plot referral volume, reviewer utilization, turnaround time, cost per patient
- **Why:** Shows you understood the system, not just the algorithm. "Clinical operating point = resource budget" is the insight judges remember.
- **Effort:** Medium — needs real inference-time numbers from pipeline

### 5. Closed-Loop Quality Gating with Reason Codes
- **What:** Reject/recapture feedback with actionable reasons ("out of focus" → refocus, "underexposed" → increase flash)
- **Why:** Makes the system deployable by a health worker, not just a researcher
- **Effort:** Medium — interpretable measures + mapping table

### 6. Calibration + Abstention as Clinical Safety
- **What:** Constrained temperature scaling + accuracy-coverage curve
- **Why:** Genuine clinical safety feature. Feeds Simulink reviewer-workload model.
- **Effort:** Medium — temperature scaling is straightforward, reporting requires care

## Tier 3: Good Differentiators

### 7. Real Clinician Feedback
- **What:** 2-3 ophthalmologists, 20 reports, stopwatch, Likert rating
- **Why:** Converts "30-second review" assertion into measured evidence
- **Effort:** Finding the clinician is the bottleneck

### 8. Honest Limitations Slide
- **What:** Specific acknowledgment of MA sensitivity, absent NV annotations, retrospective-only validation
- **Why:** Clinician judges weight intellectual honesty heavily
- **Effort:** Zero — just do it

### 9. 4-2-1 Rule Implementation
- **What:** Quadrant-level hemorrhage counting for ICDR Level 3
- **Why:** Falls out of Branch B naturally. Directly checkable against ICDR criteria.
- **Effort:** Low — already counting per quadrant

## What Separates This From Other DR Projects

| Common Approach | Our Approach |
|----------------|--------------|
| Single CNN classifier | Dual-evidence path with agreement check |
| Raw softmax as confidence | Constrained temperature scaling |
| Grad-CAM heatmap (visual) | Grad-CAM quantified (IoU vs masks) |
| "90% accuracy" | Sensitivity/specificity with bootstrap CIs |
| Python + MATLAB README | Genuinely in MATLAB |
| No validation beyond test split | External validation + ablation study |
| Classifier is the product | System (quality + classifier + explainability + resource model) is the product |
