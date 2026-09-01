# External Validation — Messidor-2 Protocol

## Protocol

1. **Lock the model** — final weights, calibration, threshold chosen on APTOS validation split
2. **Run inference on Messidor-2** — 1,744 usable images
3. **Evaluate** — referable DR sensitivity/specificity against Krause et al. adjudicated grades
4. **Report honestly** — compare to published figures, explain any gaps

## Contamination Prevention

- Download Messidor-2 day one, set aside and forget
- Never tune hyperparameters on Messidor-2
- Only use for final evaluation

## Cross-Dataset Generalization

- Train on APTOS only → test on IDRiD test set
- Train on IDRiD only → test on APTOS
- Tests whether model learns general features or dataset artifacts
