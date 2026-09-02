# Future Roadmap (Beyond Internal Round)

## What We Are NOT Attempting in 10 Days

| Item | Why Not | When |
|------|---------|------|
| Full segmentation (MA, HE, EX, SE, NV) | Too complex, needs specialized models | Phase 2 (Weeks 3-4) |
| >90% sensitivity / >85% specificity | Needs more data + tuning | Phase 3 (Weeks 5-6) |
| Real-world deployment | Needs regulatory approval | Phase 5+ |
| Multi-dataset validation | Needs Messidor-2 license | Phase 4 (Weeks 7-8) |
| Clinical trials | Needs IRB approval | Post-hackathon |

## Evolution Path

### Phase 1: Internal Round (Current)
- Basic pipeline: quality → classification → Grad-CAM → report
- Simple Simulink model
- Honest numbers on APTOS

### Phase 2: Grand Finale
- Add lesion-level segmentation
- Dual-evidence path (Branch A + Branch B)
- Cascade router
- OOD detection

### Phase 3: Post-Hackathon
- Train on larger dataset (EyePACS)
- External validation (Messidor-2)
- Clinical validation with ophthalmologists

### Phase 4: Deployment
- CDSCO regulatory approval
- Edge deployment (Jetson)
- Integration with fundus cameras

## Key Differences (Internal Round vs Full System)

| Feature | Internal Round | Full System |
|---------|---------------|-------------|
| Segmentation | OD only | Full lesion detection |
| Grading | Single CNN | Dual-branch fusion |
| Explainability | Grad-CAM only | Grad-CAM + lesion evidence |
| Calibration | None | Constrained temperature |
| OOD Detection | None | Mahalanobis distance |
| Cascade | None | 3 confidence bands |

## References
- Section 7 of 10-day roadmap
- Full architecture in architecture.md
