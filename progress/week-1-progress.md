# Week 1 — Foundation (Days 1-7)

## Status: NOT STARTED

## Tasks

| Task | Owner | Status | Notes |
|------|-------|--------|-------|
| Request Messidor-2 access (ADCIS form) | Seat 1 | Pending | Takes 3-7 days — submit Day 1 |
| Request e-ophtha access (ADCIS form) | Seat 1 | Pending | Same form, both datasets |
| Download all datasets | Seat 1 | Pending | kaggle CLI + Zenodo |
| Confirm MATLAB licenses + GPU | Seat 2 | Pending | Check university lab access |
| IDRiD ingestion + FOV detection | Seat 1 | Pending | |
| Baseline grader (simple CNN, APTOS) | Seat 4 | Pending | Quick baseline for comparison |
| Quality gate (handcrafted measures) | Seat 1 | Pending | CLAHE, blur, brightness, FOV |
| OD/fovea detection | Seat 2 | Pending | CNN with regression heads |

## Milestones

- [ ] All datasets downloaded and organized
- [ ] MATLAB environment verified
- [ ] End-to-end skeleton: image → grade (any grade)

## Risks

- GPU unavailability → use CPU fallback
- Dataset downloads timing out → resume with `--continue` flag
- ADCIS license delay → start with APTOS/IDRiD only

## Notes

- Submit ADCIS form IMMEDIATELY on Day 1
- Download EyePACS in background (35 GB, takes time)
