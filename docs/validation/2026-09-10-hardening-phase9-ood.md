# Hardening Phase 9 — OOD Detector Audit

Date: 10-Sep-2026 00:40
Auditor: `src/phase9_ood_audit.m`
Result: **PASS — 14/14 checks.** The Mahalanobis OOD detector's exact
parameters, threshold provenance, and behavior matrix are all verified
against the committed artifact. OOD output is **advisory-only** and never
alters a decision.

## Locked protocol (from `buildOodStats.m`)

- **Features:** pool5 (512-d) activations of the locked 5-class champion
  (`day7_pretrained_resnet18_5class_stage2.mat`).
- **Fit set:** all 3662 APTOS training images (`nImagesFit = 3662`).
- **Means:** per-class `mu` (5×512).
- **Covariance:** pooled = average of per-class scatter/(n_c−1) over classes
  with count>1; diagonal regularization `+1e-4·I`.
- **Distance:** `sqrt(min_c (x−mu_c)' Σ⁻¹ (x−mu_c))`.
- **Threshold:** **p99 of in-distribution nearest-class distances = 34.22**
  (recomputed from the committed `mDistAll`; `distStats.p99` consistent).
- **Flag:** `mDist > threshold`.

## Behavior matrix (deterministic canaries)

| Input | Mahalanobis | OOD flag | Expected |
|-------|-------------|----------|----------|
| Real val image (APTOS) | 22.63 | 0 | 0 ✔ |
| Random noise | 103.42 | 1 | 1 ✔ |
| Pure black | 54.03 | 1 | 1 ✔ |
| Uniform gray | 60.89 | 1 | 1 ✔ |

The detector's flag equals `mDist > threshold` (code-path verified) and the
in-sample false-OOD rate is 1.01% — exactly what p99 construction implies.

## Honest caveat (recorded in registry)

The fit set includes the 733 val images along with train (all in-distribution
APTOS), so the ~1% in-sample false-OOD figure is **not** a generalization
estimate for unseen populations. OOD is a post-hoc flag: it does not touch
model weights and never changes the grade or referral decision — it only
surfaces an advisory governance sentence via
`buildExplanationNarrative.m` (`ood.flag` branch).

## Checks

- dims/layer/imgSize/model path/regEps/fit-count all match ✔
- threshold = p99 = 34.22 (recompute exact) ✔
- false-OOD in-sample 1.01% ✔
- behavior canaries behave as expected; flag definition correct ✔
- real image in-distribution; nearest class sane ✔
- OOD is advisory-only (narrative text), no decision impact ✔

## Artifacts

- `src/phase9_ood_audit.m`
- `data/analysis/day10/phase9/phase9_ood_audit.mat` / `.json`

## Rollback

Read-only audit; no production code changed.
---
Engineering demo, NOT a clinical device: all cited metrics are engineering measurements on validation-set artifacts from the frozen protocol (Phase 10); no clinical validation is claimed.
