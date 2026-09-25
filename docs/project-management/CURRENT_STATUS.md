# DrishtiCare — Current Status

**Snapshot:** 2026-09-26  
**Git HEAD:** `ec0b2cf`  
**Branch:** `main`  
**Repository:** `https://github.com/Aryan41211/DrishtiCare.git`

**Evidence record:** [`docs/task-tracker.md`](../task-tracker.md) — per-task status,
artifact paths and the honest negative results (P0–P25 hardening table, S1–S8
post-hardening table). This file summarises; the tracker is what proves it.

**Governance set:** [ROADMAP](ROADMAP.md) · [FROZEN_CONTRACT](FROZEN_CONTRACT.md) ·
[DECISION_LOG](DECISION_LOG.md) · [EXECUTION_CHECKLIST](EXECUTION_CHECKLIST.md) ·
[DEMO_AND_SUBMISSION_PLAN](DEMO_AND_SUBMISSION_PLAN.md) · [file map](#file-map)

## Competition stage

- Internal/institute round: DONE
- National screening: NEXT GATE
- Grand Finale: December 2026

The current stage is primarily about a real, live, defensible demo and a strong submission package.

## Environment

- MATLAB R2026a Update 5
- Windows 64-bit
- MathWorks-only dependencies
- `resnet18` is the only pretrained network used

## Live entry points

- `launchRetinaAI.m`
- `src/inference/predictSingleFundus.m`
- `src/reporting/verify_drishti_report_extended.m`

## Live pipeline

1. Quality gate
2. OOD advisory
3. 5-class grading + binary referral
4. Raw `pRef >= 0.60`
5. Display-only temperature calibration
6. Branch B lesion evidence + fusion
7. CLEAR / REVIEW / ABSTAIN router
8. Lesion evidence
9. Grad-CAM + explanation

FAIL images can be withheld before model execution.

## Frozen results

Validation n = 733.

- Accuracy: 0.8281
- Macro F1: 0.6805
- QWK: 0.8914
- Binary sensitivity @0.60: 0.9060
- Binary specificity @0.60: 0.9471
- ROC-AUC: 0.9796
- PR-AUC: 0.7821
- Calibration T: 2.5382

## Operational measurements

- Quality PASS: 65.48%
- Quality WARNING: 26.68%
- Quality FAIL: 7.84%
- Router CLEAR: 648 / 733
- Router REVIEW: 75 / 733
- Router ABSTAIN: 10 / 733
- OOD p99: 34.22
- Model-only: 0.1028 s/image
- Full demo path median: 11.03 s/image

Do not conflate model-only throughput with full demo-path throughput.

## Simulink

Real model:

`src/simulink/DrishtiCare_DistrictScreening.slx`

Verified internal model.

Measured scenario:

- 96,081 screened
- 38,406 referrals
- 60.03% never reach a specialist
- 153.6 referrals/day
- 7.68 specialists implied
- breakpoint ≈180 reviews/day

This is an engineering simulation, not a staffing prescription.

## Main limitations

- External validation not performed
- Sealed APTOS test is unlabeled and untouched
- Explainability localization is weak
- Fovea localization failed
- MA detector has low recall
- OD generalization is limited
- Vessel segmentation excluded
- Enhancement excluded from production inference
- Severe/Proliferative recall remain weak

## Verification

- P0–P25: 230/230 PASS
- Dashboard: 35/35 PASS
- Report: PASS
- Documentation completeness: 10/10 PASS
- Champion hashes unchanged

## Immediate next work

1. Final dashboard/report polish
2. End-to-end demo hardening
3. Final Simulink presentation figure
4. Resolve the three metric provenance discrepancies
5. Source impact statistics
6. Create final PPT
7. Record demo video
8. Final audit

---

## File map

What lives where, and the gotchas worth knowing before you touch anything.
Consolidated 2026-09-26 from `docs/STATUS_HANDOFF_2026-09-26.md` (deleted — it
duplicated this file).

```
RetinaAIApp.m                  # USER-FACING APP CLASS — at the REPO ROOT, 1,430 lines
launchRetinaAI.m               # App launcher
src/ui/                        # drishtiTheme, drishtiColormap,
                               #   gradcamColorbarStrip, renderGradCAMViews
                               #   (shared by BOTH app and PDF report)
src/inference/                 # predictSingleFundus.m, cascade_router.m
src/quality/                   # assessImageQuality (the real gate), defaultQualityConfig
src/grading/                   # classifier + frozen eval
src/calibration/               # temperatureScale, calibrationStats (frozen defs)
src/ood_detection/             # ood_detector, buildOodStats
src/lesions/                   # MA/OD CNNs, Branch B, fuseEvidence
src/explainability/            # buildExplanationNarrative
src/reporting/                 # generateDrishtiReport (branded A4, 2-tier engine)
src/dashboard/                 # DRScreeningDashboard (5 tabs) + headless verifiers
src/demo/                      # failure-aware screening demo + tests
src/simulink/                  # DrishtiCare_DistrictScreening.slx + build/reference engine
src/phases/                    # phase1..phase25 audits
src/verify/                    # independent evaluators
data/models/                   # 15 .mat (2 locked champions, 13 experimental)
data/analysis/                 # committed evidence tree (day1..day10)
data/splits/                   # 2,929 train / 733 val, seed 42
results/                       # demo outputs + verdict txt files + visual_qa/
docs/validation/               # one report per audit phase (the evidence record)
docs/task-tracker.md           # status source of truth
audit/final_project_audit/     # judge-facing audit + 2026-09-25 correction notes
audit/improvement_baseline/    # baseline_manifest (integrity anchor) + post-baseline notes
pitch/                         # deck-structure.md, demo-script.md
modules/future-roadmap.md      # redirect to ROADMAP.md (was stale; fixed 2026-09-26)
```

**Datasets on disk:** APTOS 2019 (3,662 train + 1,928 unlabeled test) · IDRiD
(A Segmentation, B Grading, C Localization) · DRIVE · DRIMDB (downloaded,
licence-cleared, **not used in any result**) · **No Messidor-2, no Sin-NP, no
EyePACS/HRF/STARE/CHASE.**

### Gotchas

- **`RetinaAIApp.m` sits at the repo ROOT, not under `src/`.** It is the
  user-facing app class. `src/dashboard/DRScreeningDashboard.m` is a *different*,
  earlier 5-tab App Designer dashboard — do not confuse the two.
- **The two champion `.mat` files are not git-tracked.** The baseline-manifest
  SHA-256s are the integrity anchor, not git. A working backup lives at
  `C:\projects\DrishtiCare-model-backup\2026-09-26\`.
- `src/phases/` = the audit scripts; `src/verify/` = the independent evaluators.
- Committed verification verdicts are the `results/_verify_*.txt` files; read
  those before re-running anything.
- Root runners live in `src/runs/` — launch with `run src/runs/<name>` from the
  repo root.

