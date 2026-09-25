# DrishtiCare — Master Roadmap

**Snapshot:** 2026-09-26  
**Branch:** `main`  
**Competition stage:** National screening submission → Grand Finale  
**Primary rule:** The ML is frozen. The remaining work is packaging, defensibility, demo reliability, and selected evidence gaps.

---

## 1. Project North Star

DrishtiCare is a MATLAB/Simulink, quality-aware and explainable diabetic-retinopathy screening prototype for rural healthcare workflows.

The target workflow is:

```text
Retinal Image
    ↓
Quality Gate
    ↓
FAIL ───────────────→ WITHHOLD → Recapture / Manual Review
    │
    └─ PASS
        ↓
OOD Advisory
        ↓
5-Class DR Grading + Binary Referral
        ↓
Calibration (display only)
        ↓
Lesion Evidence / Branch B
        ↓
CLEAR / REVIEW / ABSTAIN
        ↓
Grad-CAM + Explanation
        ↓
Screening Report
        ↓
Human / Ophthalmologist Review
```

The product differentiator is not "one more CNN." It is the complete workflow, refusal behavior, auditability, uncertainty handling, explainability analysis, and district-scale simulation.

---

# 2. Current State

## 2.1 Frozen ML contract

Do not retrain or modify the champion models.

### 5-class model

`data/models/day7_pretrained_resnet18_5class_stage2.mat`

- Validation n = 733
- Accuracy = 0.8281
- Macro F1 = 0.6805
- QWK = 0.8914
- Recall:
  - No DR = 0.9834
  - Mild = 0.6081
  - Moderate = 0.7850
  - Severe = 0.4872
  - Proliferative = 0.5254

### Binary referable model

`data/models/day7_pretrained_resnet18_binary_stage2.mat`

- Sensitivity @ 0.60 = 0.9060
- Specificity @ 0.60 = 0.9471
- ROC-AUC = 0.9796
- PR-AUC = 0.7821
- Referral threshold = 0.60 — LOCKED

### Calibration

- Temperature = 2.5382
- ECE: 0.0319 → 0.0087
- Calibration is display-only and is not a claim of external generalization.

---

# 3. What Is Already Built

The following are considered shipped unless a verification artifact says otherwise:

- APTOS dataset pipeline
- Stratified train/validation split
- 5-class DR grading
- Binary referable screening
- Quality gate
- OOD advisory detector
- Temperature calibration
- Branch B lesion-feature second opinion
- CLEAR / REVIEW / ABSTAIN router
- Lesion evidence pipeline
- Grad-CAM
- Quantified Grad-CAM vs IDRiD lesion-mask analysis
- Failure-aware screening behavior
- Branded dashboard
- Branded A4 report
- Real Simulink district-screening model
- Hardening/audit program P0–P25
- Documentation and metric freeze
- Determinism checks
- Model integrity hashes
- Headless dashboard verification
- Report verification

Latest verification:

- P0–P25: 230/230 PASS
- Dashboard: 35/35 PASS
- Report: PASS
- Phase 13 documentation completeness: 10/10 PASS
- Champion model hashes unchanged

---

# 4. Honest Limitations — Keep These Visible

These are not tasks to hide. They are part of the project's evidence.

### External validation
Not performed. Messidor-2 and Sin-NP DR 2019 are blocked by access/licensing.

### Explainability localization
- Saliency-in-lesion: 3.1%
- Pointing game: 7.4%
- IoU: 0.035
- MACE: not measured

Do not describe Grad-CAM as lesion localization.

### Fovea localization
0/10 within 300 px in the tested set.

### MA detection
Patch AUC 0.976, but detection recall is only 0.113 at the evaluated threshold.

### Optic-disc generalization
9/10 within 300 px on IDRiD, but only 10.6% acceptance on APTOS validation.

### Vessel segmentation
Excluded from production because adding vessel features reduced Branch B AUC.

### Enhancement
Excluded from production inference because the A/B experiment showed substantial performance degradation.

### Minority recall
Severe and Proliferative recall remain the main 5-class weakness.

---

# 5. Roadmap Priorities

## P1 — National Submission Package

**Priority: CRITICAL**

### Deliverables

- Actual presentation deck
- Final pitch script
- Demo video
- Final visual assets
- Sourced impact statistics
- Final architecture/workflow figure
- Final limitations slide
- Final references/links

### Acceptance criteria

- No unsupported numbers
- No clinical overclaims
- All screenshots are from the real system
- Demo video shows real inference
- Demo includes at least one FAIL/refusal case
- Deck clearly separates BUILT vs PLANNED
- Every important metric has a source

---

# P2 — Dashboard + Report Final Polish

**Priority: CRITICAL**

The dashboard must feel like a polished medical-AI prototype, not a raw MATLAB GUI.

### Work

- Improve layout hierarchy
- Improve typography
- Improve spacing
- Improve result cards
- Improve quality cards
- Improve referral-status visualization
- Improve confidence presentation
- Improve image display
- Improve Original / Enhanced / Grad-CAM / Overlay tabs
- Improve Grad-CAM rendering
- Improve colorbar
- Improve report design
- Keep dashboard and PDF styling consistent

### Important

Do not change:

- model outputs
- thresholds
- quality thresholds
- Grad-CAM values
- referral logic

Only improve presentation/rendering.

### Acceptance criteria

- PASS case looks polished
- WARNING case is understandable
- FAIL case clearly shows AI withheld
- Grad-CAM is visually clear without implying lesion localization
- Report is presentation-ready
- Dashboard passes existing 35/35 verification

---

# P3 — End-to-End Demo Hardening

**Priority: CRITICAL**

The live workflow must work from a clean launch.

### Required flow

```text
Upload
→ Quality
→ AI
→ Referral
→ Router
→ Evidence
→ Grad-CAM
→ Report
```

### Required refusal flow

```text
Bad image
→ FAIL
→ AI NOT EXECUTED
→ Reason shown
→ Recapture / manual review
```

### Acceptance criteria

- At least 3 PASS examples
- At least 2 WARNING examples
- At least 2 FAIL examples
- One surprise/unseen image test
- No hardcoded prediction
- No manual patching during demo

---

# P4 — Simulink / District-Scale Story

**Priority: HIGH**

The Simulink model already exists and has passed internal checks.

Current measured scenario:

- 96,081 screened
- 38,406 referrals
- 39.97% referred
- 60.03% never reach a specialist
- 153.6 referrals per working day
- 7.68 specialists implied
- break point ≈ 180 reviews/day

These are engineering simulation results, not staffing prescriptions.

### Work remaining

- Create one clean presentation figure
- Explain assumptions
- Connect quality gate → referral queue → specialist capacity
- Demonstrate one scenario live if practical
- Clearly label assumptions versus measurements

Do not turn simulation output into a real staffing recommendation.

---

# P5 — External Validation

**Priority: HIGH, BLOCKED BY DATA ACCESS**

Obtain:

- Messidor-2
- Sin-NP DR 2019

Then run the already-prepared harness without changing the locked models.

### Rules

- Never tune on the external test set
- Report all failures
- Preserve the locked APTOS results
- Report dataset composition
- Report preprocessing compatibility
- Do not cherry-pick images

If data cannot be obtained before submission, leave this as a documented limitation.

---

# P6 — Resolve Metric Provenance Discrepancies

**Priority: MEDIUM**

Investigate only these three items:

1. DRIVE task8 Dice:
   - document: 0.2576
   - artifact: 0.2541

2. Human inter-observer Dice:
   - document: 0.7881
   - artifact: 0.7902

3. Day-7 scratch baseline:
   - competing derivations:
     - 0.8307 / 0.8667
     - 0.8322 / 0.9080

### Rule

Read the authoritative `.mat` artifacts and source code.

Do not choose a number because it looks better.

If unresolved, document the discrepancy.

---

# P7 — Documentation Cleanup

**Priority: MEDIUM**

Replace the stale:

`modules/future-roadmap.md`

with this roadmap or redirect it to this roadmap.

The old roadmap incorrectly describes already-shipped components as future work.

Update terminology so documentation matches the actual system:

- lesion evidence
- Branch B
- cascade router
- OOD
- calibration
- quality gate
- Simulink
- dashboard
- report

---

# P8 — Repository Housekeeping

**Priority: LOW**

After making a backup:

- inspect/remove stale `.kilo/worktrees/periodic-sheep`
- remove or ignore stale `results/_*` debug leftovers
- review `tuneReferableThreshold.m` because its output can be misread as an alternative to the locked 0.60 threshold

Do not delete anything until confirming it is not referenced by a verification script.

---

# P9 — Grand Finale Preparation

**Priority: HIGH, after national submission**

Prepare for surprise-input judging.

### Required live-demo cases

1. Good No-DR
2. Mild
3. Moderate
4. Severe/Proliferative
5. Referable
6. Poor-quality image
7. Out-of-distribution/unusual image
8. Unknown/unseen image

### Team preparation

Every team member should understand:

- quality gate
- 5-class model
- binary referral
- threshold 0.60
- QWK
- sensitivity/specificity
- OOD
- router
- Branch B
- Grad-CAM limitations
- Simulink assumptions
- external validation limitation

---

# 6. Explicitly Do NOT Do

Do not:

- retrain the champion models casually
- retune 0.60
- retune T=2.5382
- use the sealed APTOS test set for tuning
- force vessel segmentation into production
- force fovea localization into production
- claim Grad-CAM localizes lesions
- claim clinical validation
- claim doctor-level performance
- claim replacement of ophthalmologists
- invent impact statistics
- silently rewrite historical audit results
- overwrite locked model files
- optimize the dashboard by changing scientific outputs

---

# 7. Definition of Done

DrishtiCare is submission-ready when:

- [ ] Dashboard polished and verified
- [ ] Report polished and verified
- [ ] End-to-end demo works from clean launch
- [ ] FAIL/refusal behavior demonstrated
- [ ] Grad-CAM rendering is consistent
- [ ] Simulink story has one clean figure
- [ ] Deck exists as an actual file
- [ ] Demo video exists
- [ ] Impact statistics are sourced
- [ ] Built vs Planned is accurate
- [ ] Limitations are explicit
- [ ] External validation is either completed or clearly documented as blocked
- [ ] All final metrics trace to source artifacts
- [ ] Model hashes unchanged
- [ ] Sealed test remains untouched
- [ ] Git working tree clean
- [ ] Final team rehearsal completed

---

# 8. Recommended Execution Order

```text
NOW
 ↓
1. Dashboard + report polish
 ↓
2. End-to-end demo hardening
 ↓
3. Final Simulink visualization/story
 ↓
4. Resolve metric provenance discrepancies
 ↓
5. Source impact statistics
 ↓
6. Build final PPT
 ↓
7. Record real demo video
 ↓
8. Final audit
 ↓
9. National submission
 ↓
10. External validation if data becomes available
 ↓
11. Grand Finale rehearsal
```

This roadmap deliberately prioritizes packaging and defensibility over adding another model.
