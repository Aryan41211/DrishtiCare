# DrishtiCare — Frozen Contract

This file defines what must not be changed during presentation/demo hardening.

## Champion models

### 5-class

`data/models/day7_pretrained_resnet18_5class_stage2.mat`

SHA-256:

`DD152C917689146F6DEC4687B263EC5E5F237ECF60EC719A59F9FCEEFF737C1B`

### Binary

`data/models/day7_pretrained_resnet18_binary_stage2.mat`

SHA-256:

`43E8DF33B429231EE5BD60A775FDB3629AD81F287617AFAA9308EA87D311F9A0`

## Locked validation protocol

- Validation n = 733
- Train = 2,929
- Seed = 42
- Official APTOS test = 1,928 images
- Official test labels are unavailable
- Official test must remain firewalled

## Locked metrics

| Metric | Frozen value |
|---|---:|
| Accuracy | 0.8281 |
| Macro F1 | 0.6805 |
| QWK | 0.8914 |
| Binary sensitivity | 0.9060 |
| Binary specificity | 0.9471 |
| ROC-AUC | 0.9796 |
| PR-AUC | 0.7821 |
| Referral threshold | 0.60 |
| Calibration temperature | 2.5382 |

## Locked rules

1. Never retune 0.60.
2. Never retune T=2.5382.
3. Never tune using the sealed test set.
4. Never replace champion weights for cosmetic reasons.
5. Never alter historical audit findings silently.
6. Every number must have a traceable source.
7. Every report must carry the non-clinical disclaimer.
8. Back up `.mat` files before risky operations.
9. UI work must not alter inference behavior.
10. Explainability visualization must not imply lesion localization.

## Allowed work

- UI redesign
- Report redesign
- Visualization rendering improvements
- Demo orchestration
- Documentation
- Presentation
- Video
- Simulink visualization
- External validation without tuning
- Provenance investigation
- Repository housekeeping

## Model-change policy

Any proposed model change requires an explicit new experiment and must not overwrite the frozen champions.
