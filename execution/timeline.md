# Timeline — 4-Week Build Order

## Phase 0: Setup (Days 1-2)
- Request Messidor-2 + e-ophtha access (ADCIS)
- Download all datasets
- Confirm MATLAB licenses + GPU access
- Confirm SIH internal hackathon date

## Phase 1: Foundation (Days 3-7)
- IDRiD ingestion + FOV detection + preprocessing
- Baseline grader (simple CNN on APTOS)
- Quality gate (handcrafted measures)
- OD/fovea detection
- **Checkpoint:** End-to-end skeleton working

## Phase 2: Segmentation (Days 8-14)
- Vessel segmentation (U-Net on DRIVE)
- MA detection (candidate + classifier)
- HE detection + quadrant counting
- EX detection + DME grading
- Branch A training (EyePACS → APTOS)

## Phase 3: Grading & Fusion (Days 15-21)
- Branch B training (lesion features)
- SE detection + NV surrogate
- Fusion model
- Grad-CAM + quantification
- Calibration + threshold selection
- **Checkpoint:** Full pipeline working

## Phase 4: Explainability & Simulink (Days 22-28)
- Report generation + evidence template
- Simulink queueing model
- MATLAB App Designer GUI
- Threshold-staffing Pareto analysis
- Cascade router + OOD detector

## Phase 5: Validation & Polish (Days 29-35)
- Ablation study execution
- External validation (Messidor-2)
- Cross-dataset generalization test
- Subgroup analysis
- Report polish + limitations

## Phase 6: Demo Prep (Days 36-42)
- Live demo script
- Surprise-input handling
- Presentation slides
- Clinician validation (30-second review)
- Final polish + practice

## Key Milestones

| Milestone | Date | Success Criteria |
|-----------|------|-----------------|
| Data access | Day 1 | All 4 PS datasets downloaded |
| Environment | Day 2 | MATLAB + toolboxes verified |
| Skeleton | Day 7 | Image → grade (any grade) |
| Full pipeline | Day 21 | All modules connected |
| Validation | Day 35 | Ablation table complete |
| Demo ready | Day 42 | Working demo with live inputs |
