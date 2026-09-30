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

The shipped deck is `pitch/deck.pdf` — **11 slides**, generated from
`pitch/deck.html`. Per-slide content, sources and timing are documented in
[`../../pitch/deck-structure.md`](../../pitch/deck-structure.md).

| # | Slide | Covers |
|---|-------|--------|
| 1 | Title | SIH 26038, MathWorks, team, standing "not a clinical device" disclaimer |
| 2 | Problem | Capacity is the constraint; measured demand side; reframed question |
| 3 | Workflow | Six-box flow, quality gate **before** the AI, WITHHELD on FAIL |
| 4 | Feasibility | **BUILT** vs PLANNED, 230/230 hardening checks, measured gate/router figures |
| 5 | Performance | Frozen metrics on the 733-image split, per-class recall, threshold/temperature |
| 6 | Refusal + rehearsal | 19/19 unseen images, 4/4 contract checks, 8 FAILs withheld before any model call |
| 7 | Explainability | Four views; Grad-CAM is attention, **not** lesion localisation (3.1% / 7.4% / 0.035) |
| 8 | District simulation | `.slx` resource model, break-point analysis, figures |
| 9 | Impact | Three national statistics, each with organisation, year and DOI |
| 10 | Limitations | What the system cannot do yet — **on the slide, not the appendix** |
| 11 | Resources | Repository, launch command, governance, datasets stated plainly |

Slide 10 is not optional. If the slot is short, compress slide 9 into slide 2
rather than cutting the limitations.

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
