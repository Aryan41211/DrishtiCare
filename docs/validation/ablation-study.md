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
| 5 | Lesion-features branch (Branch B) | — | — | — | Interpretable-only baseline | **not measured** — no artifact |
| 6 | Fused A+B / agreement / TTA / calibration | — | — | — | Full evidence path, confidence reliability, free accuracy | **not measured** — no artifact (see 2026-09-08-dual-evidence-path.md as plan only) |
| 7 | — without EyePACS pretraining | 0.8322 | 0.9080 | 0.7672 | Data ablation (== row 1 baseline) | [artifact: eval_fixed_day5_resnet18_baseline_stage2.mat] |
| 8 | day8_5class_v2a (extra candidate) | — | — | — | v2a variant on 733-val | **not measured** — no 733-val artifact; day8/test_evaluation.mat evals day7 models on 1928 test images with **no ground-truth labels** (hasLabels=0), so no Sens/Spec/QWK can be computed ([artifact: test_evaluation.mat → groundTruthAvailability]) |
| 9 | + Quality gating (Module 1) | — | — | — | Downstream value of quality gating | **not measured** on 733-val. Module-level stats only (documented): PASS 65.48% / WARNING 26.68% / FAIL 7.84% on 3662 train images [documented: data/analysis/day3/quality_assessment_results.csv; docs/day3-quality-assessment.md] |

### Preprocessing / enhancement ablation
No separate "with vs without preprocessing" run exists as a saved artifact. The only preprocessing
option exercised across runs is input resize (all models use imresize to 224×224). Any row for
"without preprocessing" is **not measured**.

## The Story

**Integrated pipeline > any single technique.**

Only the CNN branch (Branch A) ablation is measured to date: the champion (row 3) dominates the
scratch baseline (row 1) and the scratch+balanced model (row 2) on every column.

- Class balancing alone (row 2) does **not** help a scratch model — it even slightly hurts QWK
  (−0.079) vs the unbalanced scratch baseline.
- Adding EyePACS pretraining on top of balancing (row 3) is the decisive lever: QWK +0.203, referable
  sensitivity +0.104, specificity +0.051 vs the dotted-balanced scratch model (row 2).
- Rows 5–9 were not built as standalone ablations with eval artifacts; they are constraints documented
  to be filled when such artifacts exist. **No number in this table is invented.**

The PS explicitly asks for this. Cheap to produce, widely skipped. Design the whole project backwards from this table.