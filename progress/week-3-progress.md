# Week 3 — Grading, Fusion & Explainability (Days 15-21)

## Status: NOT STARTED

## Tasks

| Task | Owner | Status | Notes |
|------|-------|--------|-------|
| Branch B training (lesion features → DR grade) | Seat 4 | Pending | Interpretable model |
| SE detection + NV surrogate features | Seat 3 | Pending | Fractal dimension + vessel tortuosity |
| Fusion model (A + B → final grade) | Seat 4 | Pending | Evidence agreement layer |
| Grad-CAM + lesion quantification | Seat 5 | Pending | Spatial grounding of decisions |
| Calibration (constrained temperature) | Seat 4 | Pending | ECE < 0.05 target |
| Report generation + evidence template | Seat 5 | Pending | One-page radiologist-style report |
| Cascade router (3 confidence bands) | Seat 4 | Pending | 90% easy images → fast path |
| OOD detector (Mahalanobis distance) | Seat 6 | Pending | Reject unfamiliar inputs |

## Milestones

- [ ] Full pipeline connected: image → quality → segmentation → grading → report
- [ ] Fusion accuracy > Branch A alone
- [ ] Explainability: saliency-in-lesion fraction > 60%
- [ ] Calibration: ECE < 0.05

## Risks

- Fusion doesn't improve over Branch A → adjust weight balancing
- Grad-CAM doesn't ground on lesions → check activation map alignment
- OOD detector too aggressive → tune threshold on validation set

## Notes

- This is the integration week — everything must connect
- Start writing the report template early
- The fusion model is the key differentiator — spend extra time here
