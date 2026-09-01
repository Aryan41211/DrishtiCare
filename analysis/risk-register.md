# Risk Register — DrishtiCare

## High Severity

| Risk | Impact | Mitigation |
|------|--------|------------|
| Messidor-2 / IDRiD access delayed | Cannot do external validation | Submit requests DAY ONE. Fall back to APTOS-held-out + IDRiD-test if Messidor-2 doesn't arrive |
| Only ~54 lesion-annotated training images | Weak MA/HE/EX/SE segmentation | Patch-based training, heavy augmentation, add e-ophtha/DIARETDB1, pseudo-labeling on APTOS |
| Scope overrun across 5+ modules | Incomplete submission | Freeze scope early. Deprioritize NV (surrogate only), IRMA, venous beading. Depth > breadth |
| MATLAB DL training friction / no GPU | Cannot train models | Confirm license + GPU access week one. Train externally and import via ONNX if needed |

## Medium Severity

| Risk | Impact | Mitigation |
|------|--------|------------|
| Microaneurysm performance disappoints | Weak 5-class kappa | Expected — plan for it, report FROC honestly. Grade-1 (MA-only) is NOT referable |
| Class imbalance distorts results | Misleading accuracy numbers | Balanced sampling, per-class reporting, QWK over accuracy |
| Overclaiming clinical validation | Loses judge trust | Frame as retrospective + external validation. State what prospective study requires |
| Judges suspect Python project in MATLAB clothing | Penalty | Keep pipeline genuinely in MATLAB. Be able to run it live |
| Ungradeable rate higher than expected (20-40%) | Throughput impact | Model as parameter in Simulink, not fixed point. Show sweep |

## Low-Medium Severity

| Risk | Impact | Mitigation |
|------|--------|------------|
| Messidor-2 license terms restrict publication | Cannot show external results | Check terms before publishing |
| EyePACS download too large (35 GB) | Wastes time | Use resized version (3.65 GB) |
| SimEvents not in campus license | Simulink model limited | Plain Simulink + Stateflow can approximate queueing |
| Team member drops out | Seat vacancy | Cross-train on critical seats |

## Silver Lining

Grade 1 (MA-only) is NOT referable, so weak MA detection damages five-class kappa more than referable-DR sensitivity — the endpoint you are actually graded on.
