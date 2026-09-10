# DrishtiCare Improvement Phase — Baseline Manifest

Snapshot timestamp: 2026-09-09T18:40
Git HEAD: 9c553adff6320074d8376845b44f09e5261dc2d1
Branch: main (up to date with origin/main)
MATLAB: 26.1.0.3346908 (R2026a) Update 5, arch win64
Machine: win32, PowerShell 5.1

NOTE: pre-existing untracked content present at snapshot time (NOT part of this
baseline; left untouched until Phase 25 decides disposition):
  - audit/final_project_audit/ (19 CSV + 2 MD audit from an earlier ad-hoc audit)
  - _audit_quality.ps1

---

## LOCKED MODELS (never overwrite)

| Role | Path | SHA-256 | Size (bytes) |
|------|------|---------|--------------|
| 5-class champion (stage2) | data/models/day7_pretrained_resnet18_5class_stage2.mat | DD152C917689146F6DEC4687B263EC5E5F237ECF60EC719A59F9FCEEFF737C1B | 41,724,762 |
| Binary champion (stage2)  | data/models/day7_pretrained_resnet18_binary_stage2.mat | 43E8DF33B429231EE5BD60A775FDB3629AD81F287617AFAA9308EA87D311F9A0 | 41,723,622 |

Read-only policy: hash must be identical at end of the hardening phase.

Other committed experimental models (do NOT delete; not promoted):
  data/models/day7_pretrained_resnet18_5class_stage1.mat
  data/models/day7_pretrained_resnet18_binary_stage1.mat
  data/models/day8_5class_v2a_stage2.mat   (Task 5(a), not promoted; stage1 checkpoint was NOT committed - manifest corrected at P25)
  data/models/day9_5class_raw_stage1.mat / _stage2.mat   (T9B variant A control)
  data/models/day9_5class_enh_stage1.mat / _stage2.mat   (T9B variant B, hurt)
  data/models/day6_resnet18_balanced_stage1/2, day6_binary_referable_v1_stage1/2 (day6)
  data/models/day5_resnet18_baseline_stage1/2, day5_setup.mat (day5)

---

## COMPONENT → FILE MAP (baseline)

| Component | Files |
|-----------|-------|
| Quality gate | src/quality/quality_gate.m, assessImageQuality.m, computeQualityMetrics.m, buildMetricsTable.m, computeDay3Thresholds.m, createRetinalMask.m, defaultQualityConfig.m, runQualityAssessment.m, createDay2Results.m* createDay3Visualizations.m, reviewExtremeExamples.m |
| Enhancement | src/enhancement/enhanceImage.m, testEnhancement.m, viewEnhancedImage.m |
| 5-class grading | src/grading/grading.m, setupClassifier.m, trainClassifier.m, trainClassifierDay8.m, prepareData.m, prepareBinaryData.m, evaluateClassifier.m, evaluateBinaryClassifier.m, plotTrainingResults.m, defaultPretrainedConfig.m, defaultTrainingConfig.m, tuneReferableThreshold.m, gradcamExplain.m |
| Binary referable | src/grading/prepareBinaryData.m, evaluateBinaryClassifier.m; decision threshold 0.60 in predictSingleFundus + cascade_router |
| Calibration | src/calibration/buildCalibrationCache.m, analyse_calibration_standard.m, analyse_calibration_firewalled.m, temperatureScale.m, loadTemperatureParams.m |
| Cascade / confidence router | src/cascade_router/cascade_router.m |
| Branch B second opinion | src/lesions/branch_b_predict.m, fuseEvidence.m, trainBranchB.m, verify_fuseEvidence.m, build_aptos_feature_cache.m |
| Lesion evidence (MA/HE/EX, OD) | src/lesions/extractLesionCandidates.m, detectRedLesions.m, estimateOpticDisc.m, locateOpticDiscCnn.m, trainOdCnn.m, hardNegMineOdCnn.m, buildOdDataset.m, detectMaCnn.m, trainMaCnn.m, hardNegMineMaCnn.m, buildMaDataset.m, evalMaCnn.m, locateFoveaCnn.m, trainFoveaCnn.m, buildFoveaDataset.m, segmentVesselsCnn.m, trainVesselCnn.m, buildDriveVesselDataset.m |
| OOD detector | src/ood_detection/ood_detector.m, buildOodStats.m |
| Explanation narrative | src/explainability/buildExplanationNarrative.m, explainability.m |
| Grad-CAM | src/grading/gradcamExplain.m |
| Inference entry point | src/inference/predictSingleFundus.m, demoSingleImage.m |
| Dashboard | src/dashboard/DRScreeningDashboard.m, load_dashboard_data.m, verify_dashboard.m, build_dashboard_mlapp.m |
| Vessel segmentation | src/vessel/extractVessels.m, extractVessels3.m, vesselParams.m, vesselParams3.m, evaluateVessels.m, evaluatePhase3.m, runVesselExperiments.m, viewVessels.m |
| Simulink | src/simulink/simulink_model.slx (56-byte placeholder; SimEvents NOT installed) |
| T9B enhancement experiments | src/task9b/buildTask9bEnhancedSplits.m, run_task9b_variantA.m, run_task9b_variantB.m, evaluate_task9b_ab.m |

---

## HEADLINE METRIC VALUES AT BASELINE (all verified by re_audit_T13, 63/63 PASS)

### 5-class (locked, 733 val, fresh inference)
Accuracy 0.8281 | Macro F1 0.6805 | QWK 0.8914
Recall: NoDR 0.9834 | Mild 0.6081 | Moderate 0.7850 | Severe 0.4872 | Proliferative 0.5254

### Binary @ 0.60 (locked, 733 val)
Sens 0.9060 | Spec 0.9471 | ROC-AUC 0.9796 | PR-AUC 0.7821
Confusion: TP 270 | FP 23 | FN 28 | TN 412

### Calibration
Promoted T = 2.5382 (current_T.mat)
Firewalled eval: ECE 0.031915 -> 0.0087196; NLL 0.1998 -> 0.12425; flip@0.60 0.0074105 (18/2429)
Standard split: T_fitTrain 2.6722; val ECE 0.045013 -> 0.029653; flipFraction 0.016371

### Quality (train, n=3662)
PASS 65.483% | WARNING 26.679% | FAIL 7.837%

### Branch B second opinion (full val)
AUC 0.8969 | A/B match 0.8295 | agree 598 | discrepancy 135 | OD located 0.1064

### Lesion/anatomy (IDRiD)
OD CNN: patch AUC 0.993; 9/10 check images within 300 px; APTOS acceptance 78/733 = 10.6%
MA CNN: patch AUC 0.976; det recall 0.113, precision 0.595 (vs classical 0.002/0.003)
Fovea: 0/10 within 300 px (HONEST NEGATIVE - do not claim)

### Vessel
Champion: Dice 0.7549 | Prec 0.8220 | AUC 0.9029 (testChamp)
Phase3 candidate: Dice 0.7438 | Prec 0.8498 | AUC 0.8923 (testLocked) — NOT promoted
vessel feature in Branch B: AUC 0.8969 -> 0.8810 (hurt, excluded from production)

### T9B enhancement A/B
RAW: acc 0.8322 | QWK 0.8952 | macroF1 0.6828
ENH:  acc 0.5416 | QWK 0.6507 | macroF1 0.4039 (HURTS; NOT promoted; RAW is classifier input)

### Inference speed (dashboard measure)
0.1028 s/img ~ 9.73 img/s

### OOD detector
Thr = 99th pct (34.2) on 3662 train | false-OOD on train 1.01%

### Referable fraction (val)
40.65% (298/733)

---

## RESULT ARTIFACT PATHS (committed, used by audits)

- data/analysis/day8/reverify_audit_T0.mat       (T0 fresh metrics + preds)
- data/analysis/day8/calibration/current_T.mat   (T=2.5382)
- data/analysis/day8/calibration/firewalled/firewalled_calibration.mat
- data/analysis/day8/calibration/standard/standard_calibration.mat
- data/analysis/day8/calibration/aptos_train_cache.mat
- data/analysis/day8/task7/branchb_fullval_T7.mat
- data/analysis/day8/branch_b/ (pilot + models)
- data/analysis/day8/lesions/ (summary/montage/overlays)
- data/analysis/day8/od_cnn/od_cnn_net.mat, day8/ma_cnn/ma_cnn_net.mat
- data/analysis/day8/ood/ood_stats.mat
- data/analysis/day8/vessel/vessel_cnn_net.mat, vessel_cnn_metrics.mat
- data/analysis/day9/task9b_ab_eval.mat
- data/analysis/day9/ensemble_scores_cache.mat
- data/analysis/day9/od_discrepancy_investigation.mat
- data/analysis/day9/reaudit_T13.mat
- data/analysis/day3/quality_assessment_summary.mat
- data/analysis/day5/day8_5class_v2a_metrics.mat

## END-TO-END PIPELINE STATUS AT BASELINE
predictSingleFundus implements: enhancement(display) -> OOD(guarded) -> quality gate
(Fail=>REVIEW, EnforceQualityGate default on) -> 5-class + binary -> calibration
(display-only) -> Branch B fusion -> cascade router -> narrative. Structured result
fields: .cascade, .quality*, .grade, .lesions, .calibration*, .fusion, .explanation,
.runtime. Documented in src/inference/predictSingleFundus.m.

## Simulink status at baseline
src/simulink/simulink_model.slx = 56-byte placeholder. SimEvents/Stateflow NOT
installed. Phase 15 will implement a MATLAB-script system-level discrete-event
simulation as a documented substitute (file-based), clearly labeled as
system-level simulation, not clinical operations.