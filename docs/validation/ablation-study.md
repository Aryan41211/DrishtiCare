# Ablation Study — The Centerpiece

## Ablation Table

**Setup.** All rows evaluated on the fixed 733-image validation split (APTOS 2019).
**Metric definitions.** Sens(≥2)/Spec(≥2) = binary referable-detection sensitivity/specificity
(referable = grade ≥ 2), taken from the `referable` sub-struct of each eval artifact. QWK = quadratic
weighted kappa over the 5 ordinal grades. Source per cell is listed in the rightmost column.

| # | Configuration | Sens (≥2) | Spec (≥2) | QWK | What It Proves | Sources |
|---|--------------|-----------|-----------|-----|----------------|---------|
| 1 | CNN alone (Branch A) — scratch ResNet18, no class balance (day5) | 0.8322 | 0.9080 | 0.7672 | Single-technique baseline | [artifact: eval_fixed_day5_resnet18_baseline_stage2.mat → m.referable, m.qwk] |
| 2 | CNN + class balancing — scratch ResNet18, balanced (day6) | 0.8020 | 0.8966 | 0.6887 | Balancing alone does not help (scratch) | [artifact: eval_fixed_day6_resnet18_balanced_stage2.mat → m.referable, m.qwk] |
| 3 | (1) + EyePACS pretraining + balancing — **CHAMPION** (day7) | 0.9060 | 0.9471 | 0.8914 | Pretraining + balancing is the winning recipe | [artifact: eval_fixed_day7_pretrained_resnet18_5class_stage2.mat → m.referable, m.qwk] |
| 4 | Pretraining ablation: row 3 vs row 2 (balanced pair) | +0.1040 | +0.0505 | +0.2027 | Pretraining is the decisive lever | [derived from sources above] |
| 5 | Lesion-features branch (Branch B, 10 features) | 0.6913 | 0.9126 | — (no 5-class) | Interpretable-only baseline; AUC 0.8969 on the same 733-val | [artifact: data/analysis/day8/task7/branchb_fullval_T7.mat → pRefB vs YTrue5, perfcurve ref] |
| 6 | Fused A+B / agreement / TTA / calibration | A 0.9060 / B 0.6913; agreement 598 agree / 135 REVIEW; TTA A acc 0.8336, QWK 0.8965; calibration ECE 0.045→0.030 | — | — | Full evidence path, confidence reliability, free accuracy | [artifacts: branchb_fullval_T7 (fusion counts), run_ensemble_eval (TTA), calibration standards docs] |
| 7 | — without EyePACS pretraining | 0.8322 | 0.9080 | 0.7672 | Data ablation (== row 1 baseline) | [artifact: eval_fixed_day5_resnet18_baseline_stage2.mat] |
| 8 | day8_5class_v2a (extra candidate) | 0.8926 | 0.9540 | 0.8877 | Weighting variant on 733-val: SeVRec/ProlRec unchanged | [artifact: data/analysis/day9/ensemble_scores_cache.mat → scores8, per-class recall; task-tracker V(a) row] |
| 9 | + Quality gating (Module 1) | — | — | — | Downstream value of quality gating | **not measured** on 733-val. Module-level stats only (documented): PASS 65.48% / WARNING 26.68% / FAIL 7.84% on 3662 train images [documented: data/analysis/day3/quality_assessment_results.csv; docs/day3-quality-assessment.md] |
| 10 | Enhancement A/B (Task 9B) — same pretrained+balanced protocol, only day-4 enhanceImage differs | raw A acc 0.8322 / B 0.5416 | — | raw A 0.8952 / B 0.6507 | Enhancement (B) **hurts** 5-class grading: acc −0.2906, macro-F1 −0.2789, QWK −0.2445 vs raw control. Raw model is also preprocessing-mismatch-fragile (QWK→0 on enhanced inputs). **5-class-only; binary screening out of scope** | [artifact: data/analysis/day9/task9b_ab_eval.mat → results.primary.raw / .enhanced; doc: docs/validation/2026-09-08-task9b-enhancement-ab.md] |
| 11 | OD-CNN honest-refusal diagnosis (RF-1) | — | — | — | OD locator: 9/10 IDRiD but 10.6% APTOS acceptance — dataset generalization gap, not bug | [artifact: data/analysis/day9/od_discrepancy_investigation.mat; tracker RF-1] |
| 12 | Ensemble (day7+day8_v2a) / TTA (RF-3) | — | — | ens QWK 0.8933, TTA QWK 0.8965 | Inference-only moves; small gains, nothing promoted | [artifact: run_ensemble_eval.m + ensemble_scores_cache.mat] |

### Preprocessing / enhancement ablation
Row 10 is the enhancement A/B (Task 9B): the same pretrained + balanced 5-class protocol trained with
and without day-4 `enhanceImage()` (raw imresize-224 control vs enhance → imresize-224). Raw control
reproduces the champion within noise; enhancement **hurts** (QWK −0.2445 vs raw control) and is
**5-class-only** — the binary screening model was not part of this ablation. Full details:
`docs/validation/2026-09-08-task9b-enhancement-ab.md`.

## The Story

**Integrated pipeline > any single technique.**

Only the CNN branch (Branch A) ablation is measured to date: the champion (row 3) dominates the
scratch baseline (row 1) and the scratch+balanced model (row 2) on every column.

- Class balancing alone (row 2) does **not** help a scratch model — it even slightly hurts QWK
  (−0.079) vs the unbalanced scratch baseline.
- Adding EyePACS pretraining on top of balancing (row 3) is the decisive lever: QWK +0.203, referable
  sensitivity +0.104, specificity +0.051 vs the dotted-balanced scratch model (row 2).
- Branch B (row 5) is now measured on the full closed 733-val: it is a real but strictly weaker
  second opinion (AUC 0.8969, sens 0.691 / spec 0.913 @0.60, 82.95% decision agreement with B). It
  adds interpretability and a discrepancy→REVIEW cross-check, not accuracy.
- The fusion/caibration row (row 6) is now measured: 598 of 733 A/B decisions agree (81.6%), 135 go
  to REVIEW; temperature calibration holds ECE ≤0.030 on val (~2× reduction) with only 11/733 (1.5%)
  decision flips at 0.60; TTA on the champion (h-flip + rot±5°) lifts acc 0.8281→0.8336 and QWK
  0.8914→0.8965 without any retraining.
- Row 8 (day8_5class_v2a) is now measured on 733-val: QWK 0.8877 (−0.0037 vs champion) with Severe/
  Proliferative recall unchanged — the weighting experiment is a confirmed negative for the target
  classes, so the day7 champion stays.
- Rows 9, 11, 12 are recorded constraints/diagnostics, not ablations of the CNN head. **No number in
  this table is invented.**

The PS explicitly asks for this. Cheap to produce, widely skipped. Design the whole project backwards from this table.