# Validation Metrics — Per Component

> **Read this first.** This file originally listed *targets only*, with no
> measured values, and was reachable from `README.md` as the place to find
> "reported metrics" — so a target could be mistaken for an achievement. Every
> table below now separates **TARGET** (a pre-registered goal, never a result)
> from **MEASURED** (a value actually computed from a committed artifact), with
> the source path and sample size for each measured number. Where a target was
> never measured, the row says **not measured** rather than showing a bare
> target. Targets are *not* claims.

**Metric definitions are frozen.** Every measured classification number below
uses the formulas locked in `docs/validation/2026-09-10-hardening-phase7-metric-freeze.md`
(Phase 7, 12/12 PASS), which is the single source of truth. No alternative
macro-average, QWK normalization, or binary orientation may be substituted.

**Scope.** All numbers are engineering measurements on **validation-set
artifacts** from the frozen protocol. The official APTOS 2019 test set (1,928
images) was sealed and never scored. Nothing here is a clinical claim.

## Headline: what is actually frozen and measured

| Metric | Measured | n | Source |
|---|---|---|---|
| 5-class accuracy | **0.8281** | 733 val | `2026-09-10-hardening-phase7-metric-freeze.md` (recompute from `data/analysis/day8/reverify_audit_T0.mat`) |
| 5-class macro F1 | **0.6805** | 733 val | same |
| 5-class QWK | **0.8914** | 733 val | same |
| Per-class recall | **[0.9834 0.6081 0.7850 0.4872 0.5254]** (NoDR→Proliferative) | 733 val | same |
| Referable (binary) sens @0.60 | **0.9060** | 733 val (298 positive) | same |
| Referable (binary) spec @0.60 | **0.9471** | 733 val (435 negative) | same |
| Binary ROC-AUC | **0.9796** | 733 val | same |
| Binary PR-AUC | **0.7821** | 733 val | same |
| Binary decision threshold | **0.60 (locked)** | — | Phase 6 / Phase 7; CV-optimal, not knife-edge (P21) |
| Calibration temperature | **T = 2.5382 (promoted)** | — | `data/analysis/day8/calibration/current_T.mat`; frozen list in `audit/improvement_baseline/baseline_manifest.md` |

Confusion at the locked 0.60 threshold: TP 270 / FP 23 / FN 28 / TN 412
(`audit/final_project_audit/06_referable_metrics.csv`). Referable fraction on
val = 40.65% (298/733).

## Referable DR (Level ≥2) — TARGET vs MEASURED

| Metric | TARGET (goal only) | MEASURED | Verdict | n / source |
|---|---|---|---|---|
| Sensitivity | >90% | **0.9060** (90.60%) | TARGET MET | 733 val, @0.60, `phase7-metric-freeze.md` |
| Specificity | >85% | **0.9471** (94.71%) | TARGET MET | 733 val, @0.60, `phase7-metric-freeze.md` |
| PPV | Report | **0.9215** (270/293) | reported | 733 val, derived from the @0.60 confusion; `audit/final_project_audit/06_referable_metrics.csv` |
| NPV | Report | **0.9364** (412/440) | reported | 733 val, same source |
| AUC-ROC | >0.95 | **0.9796** | TARGET MET | 733 val, `perfcurve` posclass=true, `phase7-metric-freeze.md` |
| AUC-PR | Report | **0.7821** | reported (not a pass/fail target) | 733 val, `perfcurve` tpr/prec, `phase7-metric-freeze.md` |

Confidence intervals are recorded in the Phase 7 / T13 audit artifacts; this
table quotes the point estimates that the frozen formulas reproduce.

## 5-Class Grading — TARGET vs MEASURED

No numeric target was pre-registered for the 5-class head; QWK is the primary
metric by design.

| Metric | TARGET | MEASURED | n / source |
|---|---|---|---|
| QWK | primary metric (no numeric target set) | **0.8914** | 733 val, `phase7-metric-freeze.md` |
| Accuracy | — | **0.8281** | 733 val, `phase7-metric-freeze.md` |
| Macro F1 | — | **0.6805** | 733 val, `phase7-metric-freeze.md` |
| Per-class recall | especially rare grades (1, 3) | **[0.9834 0.6081 0.7850 0.4872 0.5254]** | 733 val, `phase7-metric-freeze.md` |
| Confusion matrix | full 5×5 | stored in `data/analysis/day8/reverify_audit_T0.mat` (YTrue5/YPred5) | 733 val |

**Honest reading of the per-class recall:** the model is strong on NoDR
(0.9834) and Moderate (0.7850) and weak on exactly the grades that matter for
referral — Severe (0.4872) and Proliferative (0.5254). A high aggregate
accuracy therefore overstates screening performance; this is stated in
`VERIFIED_RESULTS_SIMPLE.md` §4 as well.

## Lesion Detection (IDRiD) — TARGET vs MEASURED

The targets below were specified as FROC / AUC-PR / fovea-accuracy studies.
**None of them was measured in the form specified.** What was actually
measured is patch-level lesion/anatomy detection, and the fovea target is an
explicit honest negative. Do not read the target column as a result.

| Lesion / structure | TARGET (goal only) | MEASURED | Verdict | n / source |
|---|---|---|---|---|
| MA | FROC curve at 1, 2, 4, 8 FP/image | **FROC not measured.** Patch ROC-AUC **0.976**; detection recall **0.113**, precision **0.595** | target not measured | IDRiD, `data/analysis/day8/ma_cnn/ma_cnn_metrics.mat`; `docs/task-tracker.md`; `baseline_manifest.md` |
| HE | FROC + quadrant counts | quadrant counts produced; **no FROC curve measured** | target not measured | `src/lesions/`, `docs/day8/day8-task6-lesions.md` |
| EX | AUC-PR + distance-to-fovea accuracy | **neither measured.** `meanExudateDistToFovea` stays `NaN` unless a caller supplies a fovea center | target not measured — fovea localization failed | `docs/validation/2026-09-08-task11-fovea-closure.md` |
| SE | Binary accuracy + AUC | **not measured** (no SE detector evaluation committed) | — | — |
| Optic disc (supporting) | — | patch AUC **0.993**; 9/10 IDRiD check images within 300 px; APTOS acceptance 78/733 = **10.6%** | measured; generalization gap disclosed | `data/analysis/day9/od_discrepancy_investigation.mat`; `docs/task-tracker.md` RF-1 |
| Fovea (supporting) | — | patch AUC 0.7487, acc 0.6479; localization **0/10 within 300 px** (mean error ~620 px) | **honest negative — do not claim** | `data/analysis/day8/fovea_cnn/fovea_cnn_metrics.mat`; `2026-09-08-task11-fovea-closure.md` |

## Calibration — TARGET vs MEASURED

| Metric | TARGET (goal only) | MEASURED | Verdict | n / source |
|---|---|---|---|---|
| ECE | <0.05 | **0.0297** after temperature scaling (val, standard split) | TARGET MET | 733 val, `data/analysis/day8/calibration/standard/standard_calibration.mat` |
| Brier score | <0.15 | **0.0563** | TARGET MET | `day7_binary_calibration.mat`; `audit/final_project_audit/07_calibration_metrics.csv` |
| Reliability diagram | near-diagonal | improved mid-range; `data/analysis/day8/calibration/reliability_curve.png` | qualitatively improved | same |
| ECE (firewalled split) | — | **0.0319 → 0.0087**; NLL 0.1998 → 0.1243; decision flips @0.60 = 0.0074 (18/2429) | — | `data/analysis/day8/calibration/firewalled/firewalled_calibration.mat` |
| Promoted temperature | — | **T = 2.5382** | — | `data/analysis/day8/calibration/current_T.mat` |

Calibration is auxiliary/display-only in the deployed pipeline and is applied
for reliability reporting; it is not a screening decision input.

## Explainability — TARGET vs MEASURED

**The four explainability targets are missed by one to two orders of magnitude.**
They are recorded here as targets that were **not** achieved. Measured values
are Grad-CAM saliency of the 5-class champion
(`day7_pretrained_resnet18_5class_stage2.mat`, feature layer `res5b_relu`,
attention = top 20% of pixels by activation) scored against IDRiD lesion
masks.

| Metric | TARGET (goal only) | MEASURED | Verdict | n / source |
|---|---|---|---|---|
| Saliency-in-lesion fraction | >60% | **3.1%** (0.0307) | **TARGET MISSED — ~19× short** | 81 IDRiD images, `data/analysis/gradcam_lesion_alignment/run_log.txt` (final summary) + `per_image_results.csv` |
| Pointing game | >70% | **7.4%** | **TARGET MISSED — ~9× short** | same, n=81 |
| IoU vs lesion masks | >0.3 | **0.035** | **TARGET MISSED — ~8.6× short** | same, n=81 |
| MACE | <10 px | **not measured** — no MACE computation exists anywhere in the repo | target not measured | — |

Per-lesion-type measured values (same run, `run_log.txt`):

| Type | n | Saliency mass in lesion | Pointing game | Mean IoU |
|---|---|---|---|---|
| MA | 81 | 0.1% | 1.2% | 0.002 |
| HE | 80 | 1.3% | 1.2% | 0.013 |
| EX | 81 | 1.4% | 4.9% | 0.019 |
| SE | 40 | 0.5% | 0.0% | 0.006 |
| Any lesion | 81 | 3.1% | 7.4% | 0.035 |

Confound check: ~78% of saliency mass falls on the retinal disk, so the low
lesion overlap is **not** a black-background artifact
(`docs/validation/2026-09-08-task6-gradcam.md`).

An earlier, independent Grad-CAM evaluation (Task 6, 08-Sep-2026) measured the
same order of magnitude: any-lesion mass 0.0307, pointing 0.074, Dice 0.051,
Jaccard 0.027, all 1.2–1.6× uniform chance
(`docs/validation/2026-09-08-task6-gradcam.md`).

### Why the explainability targets are missed (measured vs expected)

- **Measured:** the champion's Grad-CAM does **not** localize IDRiD lesions at
  224 px input. Best single image captures ~31% of saliency mass on lesion.
- **Expected / by design:** the champion was trained on APTOS image-level
  grades with **no lesion supervision**, so strong lesion localization was
  never a training objective. Coarse 7×7 Grad-CAM maps resampled to 224 px
  further cap attainable overlap for MA (median 43 mask px at 224 px).
- **Uncertain:** how much of the residual gap is model behavior vs. IDRiD↔APTOS
  domain shift vs. interpolation loss on tiny lesions is **not separable** from
  this data.

**An exact correct-vs-incorrect Grad-CAM split is NOT COMPUTABLE**: the IDRiD
*segmentation* images (`IDRiD_01..IDRiD_81`) are a different image set from
IDRiD *Disease Grading* and carry no 5-class DR labels, and the 733 APTOS val
split has no lesion masks. A clearly-labelled referable-DR **proxy** split
(GT = any lesion present) is reported instead: proxy-correct n=72 → mass 3.4%,
pointing 8.3%, IoU 0.039; proxy-incorrect n=9 → mass 0.3%, pointing 0.0%,
IoU 0.002 (`data/analysis/gradcam_lesion_alignment/run_log.txt`). This is
reported rather than fabricated.

## Quality gate (supporting module) — measured

Not a pre-registered target; measured on the full APTOS train set.

| Metric | MEASURED | n / source |
|---|---|---|
| PASS / WARNING / FAIL split | **65.483% / 26.679% / 7.837%** | 3,662 images, `data/analysis/day3/quality_assessment_results.csv`; `baseline_manifest.md` |
| Operative thresholds | band-pass on 5 metrics, per `src/quality/defaultQualityConfig.m` | `docs/day3-quality-assessment.md` §5 |

These are **engineering** decisions from a prototype, non-clinically-validated
gate — a FAIL is not a clinical gradability label.

## Vessel segmentation (supporting, excluded from production)

Measured, honest negative. The DRIVE-trained CNN segmenter reaches mean Dice
**0.2576** (vs 1st manual, n=20) — well below DRIVE deep-learning SOTA (~0.80).
Adding its 8 density features to Branch B **hurt** AUC (0.8969 → 0.8810,
Δ −0.0159, bootstrap CI −0.0312..−0.0004, P(vessel wins) = 0.022), so vessel
features are **excluded from the production path**. Full report:
`docs/validation/2026-09-08-task8-vessel-segmentation.md`. (The separate
*classical* vessel pipeline reaches Dice ~0.75; the two are different systems
and are not interchangeable.)

## References

- `docs/validation/2026-09-10-hardening-phase7-metric-freeze.md` — frozen
  metric definitions (source of truth for all classification metrics)
- `docs/validation/2026-09-08-task6-gradcam.md` — Grad-CAM vs IDRiD masks
- `docs/validation/2026-09-08-task8-vessel-segmentation.md` — vessel negative
- `docs/validation/2026-09-08-task11-fovea-closure.md` — fovea honest negative
- `docs/validation/ablation-study.md` — component ablation
- `audit/improvement_baseline/baseline_manifest.md` — frozen headline values
- `docs/task-tracker.md` — per-task status incl. honest negatives
- `VERIFIED_RESULTS_SIMPLE.md` — judge-facing summary

---
Engineering demo, NOT a clinical device: all cited metrics are engineering
measurements on validation-set artifacts from the frozen protocol; no clinical
validation is claimed.
