# Week 2 — Segmentation & Lesion Detection (Days 8-14)

## Status: NOT STARTED

## Tasks

| Task | Owner | Status | Notes |
|------|-------|--------|-------|
| Vessel segmentation (U-Net, DRIVE) | Seat 2 | Pending | Fine-tune on IDRiD vessel annotations |
| MA detection (candidate + classifier) | Seat 3 | Pending | Challenge: only ~54 images with pixel masks |
| HE detection + quadrant counting | Seat 3 | Pending | Quadrant counts for grading rule |
| EX detection + DME grading | Seat 3 | Pending | Distance-to-fovea classification |
| Branch A training (EyePACS → APTOS) | Seat 4 | Pending | Transfer learning pipeline |
| Preprocessing pipeline (Ben Graham + CLAHE) | Seat 1 | Pending | Standardize across all modules |
| Resolution matching (DRIVE ↔ IDRiD) | Seat 2 | Pending | Critical: vessel calibre matching |

## Milestones

- [ ] Vessel segmentation: IoU > 0.7 on DRIVE test set
- [ ] MA detection: FROC > 1.5 at 4 FP/image
- [ ] Branch A baseline: QWK > 0.7 on APTOS validation

## Risks

- MA detection accuracy low due to tiny lesion masks → use patch-based approach + heavy augmentation
- Vessel segmentation doesn't transfer to IDRiD → fine-tune on IDRiD vessel annotations
- Branch A overfits to APTOS → use EyePACS pretraining + dropout + augmentation

## Notes

- This is the hardest week for lesion detection — MA is the bottleneck
- Start Branch A training early so it can run while working on segmentation
