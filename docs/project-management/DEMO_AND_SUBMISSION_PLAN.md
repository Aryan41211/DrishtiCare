# DrishtiCare — Demo and Submission Plan

## 1. Core demo story

Do not start with metrics.

Start with the workflow:

```text
IMAGE
  ↓
QUALITY
  ↓
AI
  ↓
REFERRAL
  ↓
EVIDENCE
  ↓
HUMAN REVIEW
```

The strongest product behavior is refusal:

> If the image is not suitable, DrishtiCare does not blindly produce a grade.

## 2. Recommended live demo sequence

### Beat 1 — Good image

Show:

- fundus
- PASS
- DR grade
- referral status
- confidence
- Grad-CAM

### Beat 2 — Poor-quality image

Show:

- quality failure
- exact reason
- AI withheld
- recapture/manual review

### Beat 3 — Explainability

Show:

- original
- Grad-CAM
- overlay

Say that Grad-CAM is model attention, not lesion localization.

### Beat 4 — Scale

Show Simulink:

- patient volume
- referrals
- specialist review capacity
- breakpoint

Call it an engineering simulation.

### Beat 5 — Honest limitation

State:

- external validation remains pending
- explainability alignment is limited
- Severe/Proliferative recall is weaker

This should be deliberate, not defensive.

## 3. Video requirements

The video should:

- use the real application
- show real inference
- show the failure/refusal case
- show report generation
- show Grad-CAM
- show Simulink
- avoid hardcoded results
- avoid unsupported claims

## 4. Slide structure

### Slide 1
Title + Team ID

### Slide 2
Problem → solution → real retinal evidence

### Slide 3
Six-box workflow

### Slide 4
Feasibility:
BUILT vs PLANNED + risks

### Slide 5
Impact:
2–3 sourced statistics + measured project outputs

### Slide 6
Resources:
GitHub, dataset links, references

## 5. Claims policy

Use:

- "AI-assisted screening"
- "held-out validation"
- "engineering prototype"
- "model attention"
- "specialist review"
- "engineering simulation"

Avoid:

- "clinically validated"
- "doctor-level"
- "replaces doctors"
- "diagnoses with certainty"
- "lesion localization" for Grad-CAM
