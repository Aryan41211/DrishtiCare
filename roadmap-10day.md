# 10-Day Implementation Roadmap

**Explainable AI for Diabetic Retinopathy Screening in Rural India**
**SIH Problem Statement ID:** 26038 | **Internal round target date:** 12 September 2026

## Quick Navigation

| Section | File |
|---------|------|
| Project Context | [context/problem-statement.md](context/problem-statement.md) |
| Goals | [context/goals-internal-round.md](context/goals-internal-round.md) |
| Tools & Access | [context/tools-access.md](context/tools-access.md) |
| Team Roles | [team/roles.md](team/roles.md) |
| Risk Checklist | [team/risk-checklist.md](team/risk-checklist.md) |
| Day 1 | [schedule/day-01-setup.md](schedule/day-01-setup.md) |
| Day 2 | [schedule/day-02-exploration.md](schedule/day-02-exploration.md) |
| Day 3 | [schedule/day-03-quality-assessment.md](schedule/day-03-quality-assessment.md) |
| Day 4 | [schedule/day-04-enhancement.md](schedule/day-04-enhancement.md) |
| Day 5 | [schedule/day-05-classifier-setup.md](schedule/day-05-classifier-setup.md) |
| Day 6 | [schedule/day-06-classifier-training.md](schedule/day-06-classifier-training.md) |
| Day 7 | [schedule/day-07-gradcam.md](schedule/day-07-gradcam.md) |
| Day 8 | [schedule/day-08-simulink.md](schedule/day-08-simulink.md) |
| Day 9 | [schedule/day-09-integration.md](schedule/day-09-integration.md) |
| Day 10 | [schedule/day-10-pitch.md](schedule/day-10-pitch.md) |
| Quality Assessment | [modules/quality-assessment.md](modules/quality-assessment.md) |
| Image Enhancement | [modules/image-enhancement.md](modules/image-enhancement.md) |
| Grading Classifier | [modules/grading-classifier.md](modules/grading-classifier.md) |
| Grad-CAM Explainability | [modules/gradcam-explainability.md](modules/gradcam-explainability.md) |
| Simulink Workflow | [modules/simulink-workflow.md](modules/simulink-workflow.md) |
| Segmentation (Simplified) | [modules/segmentation-od-vessels.md](modules/segmentation-od-vessels.md) |
| Future Roadmap | [modules/future-roadmap.md](modules/future-roadmap.md) |
| Pitch Deck Structure | [pitch/deck-structure.md](pitch/deck-structure.md) |
| Demo Script | [pitch/demo-script.md](pitch/demo-script.md) |

## Timeline Summary

```
Sep 2  ── Day 1:  MATLAB access + dataset download
Sep 3  ── Day 2:  Data exploration + repo structure
Sep 4  ── Day 3:  Image quality assessment module
Sep 5  ── Day 4:  Image enhancement module
Sep 6  ── Day 5:  Classifier setup (transfer learning)
Sep 7  ── Day 6:  Classifier training + first results
Sep 8  ── Day 7:  Grad-CAM explainability
Sep 9  ── Day 8:  Simulink workflow model
Sep 10 ── Day 9:  Integration + auto-report
Sep 11 ── Day 10: Pitch deck + rehearsal
Sep 12 ── INTERNAL ROUND
```

## Key Milestones

| Day | Milestone | Success Criteria |
|-----|-----------|-----------------|
| 1 | Environment ready | MATLAB running, APTOS downloaded |
| 4 | Preprocessing done | Quality gate + enhancement working |
| 6 | First results | Accuracy/sensitivity/specificity numbers |
| 7 | Explainability | Grad-CAM overlays on 10+ images |
| 8 | Simulink model | Throughput bottleneck graph |
| 9 | End-to-end demo | Raw image → report |
| 10 | Pitch ready | Deck + rehearsed demo |
