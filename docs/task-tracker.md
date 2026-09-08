# Task Tracker (post-Day-7 corrective tasks)

Updated: 2026-09-09. Source of truth for the numbered
corrective tasks that started after the Day 7 champion
(`day7_pretrained_resnet18_5class`, val n=733: Acc 82.81%, Macro F1 0.6805,
QWK 0.8914; per-class recall Mild 60.81 / Moderate 78.50 / Severe 48.72 /
Proliferative 52.54, NoDR 98.34).

## Status

| Task | Description | Status | Notes |
|------|-------------|--------|-------|
| Task 3 | PR-AUC regression investigation (scratch vs pretrained binary) | ✅ Complete | `src/run_task3_prauc.m` + `data/analysis/day7/pr_auc_investigation.mat` |
| Task 4 | One-time official APTOS test-set evaluation | ✅ Complete — **test set now CLOSED** | `src/run_task4_test_eval.m` + `data/analysis/day8/test_evaluation.mat`. Local copy has NO test ground truth → only distribution/confidence/agreement metrics measured; accuracy/F1/QWK not computable. Binary threshold stays locked at 0.60. |
| Task 5(a) | `day8_5class_v2a` — corrected class weighting (uniform 800/class → targets 800/800/800/1000/1000) | ✅ **Complete (negative result on the target classes)** | Final model `data/models/day8_5class_v2a_stage2.mat`; metrics `data/analysis/day5/day8_5class_v2a_metrics.mat`; independently verified (`src/verify_taskB_metrics.m`, `day8_v2a_metrics_verification.mat`). One-line outcome: **Severe recall +0.00 pts, Proliferative recall +0.00 pts** (unchanged); Mild +2.70 pts, NoDR −0.56 pts, accuracy ±0.00, Macro F1 +0.0022, QWK −0.0037. Day7 champion retained. |
| Task 5(b) | Target-boosted weighting on Severe/Proliferative | ⛔ Skipped per operator decision | Recorded in `docs/day8/day8-task5-minority-recall.md`. Auto-chaining is disabled in code (`RUN_VARIANT_B = false`); launching it later still requires explicit user approval. |
| Task 5(c) | Targeted augmentation for Severe/Proliferative | ⛔ Skipped per operator decision | `RUN_VARIANT_C = false`. |
| Task 6 | Lesion-feature branch (IDRiD MA/HE/EX/SE masks) | ✅ Complete | Code: `src/lesions/extractLesionCandidates.m`, `src/run_task6_lesions.m`. Outputs: `data/analysis/day8/lesions/` (`lesion_features.mat` [gitignored, 116 MB], `lesion_summary.csv`, `lesion_montage.png`, `inspect_IDRiD_01..10.png` overlay figures for manual review). Report: `docs/day8/day8-task6-lesions.md`. Classical candidates (not deep segmentation); counts usable as relative features. |
| Inference + lesion evidence | Wire MA/HE/EX candidates + optic-disc into `predictSingleFundus` report | ✅ Complete | `src/lesions/estimateOpticDisc.m` (classical fallback), `src/lesions/locateOpticDiscCnn.m` (CNN primary), extended `src/inference/predictSingleFundus.m` (5-panel report). Verified on APTOS train images (grades 0–4). OD honesty: CNN 9/10 IDRiD within 300px (mask-centroid GT), classical 4/10; CNN + classical fallback wired in; "OD NOT located" flag retained for refused. |
| CNN microaneurysm detector | Replace broken classical MA (recall 0.002) with a trained CNN | ✅ Complete | `src/lesions/{buildMaDataset,trainMaCnn,hardNegMineMaCnn,evalMaCnn,detectMaCnn}.m` + integrated into `extractLesionCandidates.m` (threshold 0.9). 2,409 MA positives from the 54 IDRiD train images; 44/10 image-held-out. Held-out **patch AUC 0.976**, detection-level at thr 0.9: **recall 0.113, precision 0.595** (IDRiD 01–10, tol 12 px) — vs classical 0.002 recall / 0.003 precision. Trained nets in `data/analysis/day8/ma_cnn/ma_cnn_net.mat`; detection metrics `ma_cnn_detection.mat`. Counts are LOW-RECALL relative cues, not clinical-grade. |
| CNN optic-disc locator | Replace classical bright-blob OD heuristic with a trained CNN locator | ✅ Complete | `src/lesions/{buildOdDataset,trainOdCnn,hardNegMineOdCnn,locateOpticDiscCnn}.m`. OD/background CNN on 54 IDRiD OD masks (44/10 image-held-out), held-out **patch AUC 0.993**. Sliding-window locator (stride 48 @s4, ensemble of first-pass + hard-neg nets; fixed a coordinate-scrambling `reshape` bug): on IDRiD 01–10 vs mask centroids **9/10 within 300 px** (classical heuristic: 4/10). `predictSingleFundus` now uses the CNN with classical fallback. CSV center markups rejected as reference (disagree with masks by up to ~2000 px). Nets in `data/analysis/day8/od_cnn/od_cnn_net.mat`. |
| Explanation narrative + report layout | Generate a clinical-style, hedged explanation paragraph from model evidence; polish the report figure | ✅ Complete | `src/explainability/buildExplanationNarrative.m` (`.paragraph/.assessment/.evidence/.screening/.recommendation/.quality/.caveats`), wired into `predictSingleFundus` and shown in a 2-row figure (original \| enhanced \| Grad-CAM // lesion evidence \| decision metrics \| explanation). Verified across grades 0–4 on APTOS train. Explicit "engineering demo, not clinical advice" caveat; lesion counts flagged as automated candidates. |
| OOD detector | Mahalanobis-distance out-of-distribution gate on deep `pool5` features | ✅ Complete | `src/ood_detection/ood_detector.m` + `buildOodStats.m`, stats at `data/analysis/day8/ood/ood_stats.mat` (fit on 3,662 APTOS train images). Threshold = 99th percentile (34.2) → 1.01% false-OOD on training. Sanity: solid red / Gaussian-noise frames flagged OOD (Mah 74/160); blurred+darkened real image NOT flagged (deep features tolerant — by design). Wired into `predictSingleFundus` (guarded, degrades gracefully). |
| Fovea localization | Localize the fovea for exudate-to-fovea distance | ❌ Complete — **honest negative result** | Two attempts measured on IDRiD 01–10 vs fovea CSV of truth: patch CNN (`locateFoveaCnn`) 0/10 within 300 px (mean ~620 px); disc-relative anatomical estimate (K×disc-radius, K swept 2.0–3.5) mean error ~1400 px. Fovea is too subtle for these approaches. Pipeline does NOT emit a fovea-derived distance by default; `meanExudateDistToFovea` stays `NaN` unless a fovea center is supplied by the caller. Code retained in `src/lesions/` for future work. |
| Cascade router | Confidence router → CLEAR / REVIEW / ABSTAIN routing | ✅ Complete | `src/cascade_router/cascade_router.m` + `verify_cascade.m`. ABSTAIN if conf<0.50 or \|pRef−0.60\|<0.05; REVIEW if conf<0.75, margin<0.20, or screen/grade conflict; else CLEAR. All bands exercised synthetically; real APTOS train images → CLEAR. Wired into `predictSingleFundus`; feeds narrative governance sentence + forces manual-review recommendation when not CLEAR. |
| Temperature calibration | Constrained single-temperature calibration of the binary referable probability | ✅ Complete | `src/calibration/{buildCalibrationCache,analyse_calibration_standard,analyse_calibration_firewalled,temperatureScale,loadTemperatureParams}.m`; cache `data/analysis/day8/calibration/aptos_train_cache.mat` (3,662 APTOS train). Two evidence designs agree T≈2.5–2.7: standard split fit-on-train **T=2.6722** (val: ECE 0.0450→0.0280, NLL 0.290→0.177); firewalled fit-on-500 **T_cal=2.5382** (eval 2429: ECE 0.0319→0.0087, NLL 0.200→0.124, flip@0.60 0.74%). Promoted **T=2.5382** into `current_T.mat`. Calibrated P(referable) is display-only; screening decision stays locked on raw pRef at 0.60. Honest caveat: no truly firewalled set exists (model saw all APTOS train), so these are within-train reliability estimates, not generalization. |
| Branch B dual-evidence (pilot) | Independent lesion-feature referable classifier + evidence agreement with Branch A | ✅ Complete (pilot, honest) | `src/lesions/{build_aptos_feature_cache,trainBranchB,branch_b_predict,fuseEvidence}.m`; artifacts `data/analysis/day8/branch_b/`. Firewalled eval (50 imgs): logistic **eval AUC 0.858**, match vs Branch A @0.60 = **0.760**. `fuseEvidence` rules: both referable → agree; both non-referable + confident → agree; any A/B conflict → discrepancy → REVIEW flag (never downgrades a referable). Wired into `predictSingleFundus` (`result.fusion`), panel line, narrative governance, and review forcing. Per-grade eval mean P(ref): g0 0.24, g1 0.49, g2 0.66, g3 0.78, g4 0.78. Caveat: OD CNN accepts only ~13% of APTOS train (sparse OD/exudate-disc features); signal mostly MA/HE/EX counts + quadrants. Branch B is a cross-check second opinion, not a diagnostic. |
| Task 9A | Quality-gate enforcement in the inference pipe (FAIL never auto-answered) | ✅ Complete | `predictSingleFundus.m`: `'EnforceQualityGate'` (default **true**) — a FAIL assessment forces `route→REVIEW` + surfaces `qualityFailureReasons`/`qualityRecaptureAdvice` and a `qualityGate.enforced` flag; narrative forces recapture/manual-review wording. Verified on a PASS image (route CLEAR, gate inert), a FAIL image (route REVIEW when enforced). |
| Task 11 fold | Honest fovea hook: distance computed only when caller supplies a center | ✅ Complete | `predictSingleFundus.m` `'FoveaCenter'` param → `loos.fovea` → `meanExudateDistToFovea` computed; `result.lesions.fovea`/`foveaSupplied` disclosure. No fovea → builds `NaN` distance + explicit "not available" narrative line (no claim). Verified: supplied `[100 200]` → dist 389.7 px, panel shows fovea line. |
| Task 9B | Enhancement (CLAHE+denoise) ablation — is enhanced input better for grading? | ✅ Complete — **5-class ONLY** (binary not retrained) | `data/models/day9_5class_{raw,enh}_stage{1,2}.mat` + `data/analysis/day9/task9b_ab_eval.mat`; report `docs/validation/2026-09-08-task9b-enhancement-ab.md`. **Enhancement HURTS**: acc 0.8322→0.5416, macroF1 0.6828→0.4039, QWK 0.8952→0.6507 (raw control within noise of champion 0.8281/0.6805/0.8914). Cross-condition nets preconditioned on training input (raw-on-enhanced QWK 0.0000). Deployed path keeps raw input (enhancement is display-only). |

## Red-flag investigation + targeted improvement (2026-09-09)

| Task | Description | Status | Notes |
|------|-------------|--------|-------|
| RF-1 | OD localization discrepancy: "9/10 IDRiD" vs "~10.6%" | ✅ Complete — **not a bug, documented gap** | `src/verify_od_discrepancy.m` + `data/analysis/day9/od_discrepancy_investigation.mat`. On IDRiD 01–10 the CNN locates 10/10 (9/10 within 300 px, matches claim). On APTOS val it refuses (P<0.90) on 655/733 → **located 78/733 = 10.6%**, reproducing the report number exactly. Root cause: OD-CNN trained on 44 IDRiD images does not generalize to APTOS (different cameras/resolution); hardware-threshold honest refusal works as designed. Classical fallback locates ~44% (sample), combined ~50%. Branch B feature 8 (`odLocated`) correctly 0 when refused. No code change needed; limitation documented. |
| RF-2 | Quality-gate threshold reconciliation (§7.3 vs config) | ✅ Complete | `src/quality/defaultQualityConfig.m` operative thresholds (Day 3, 3,662 imgs: brightness 0.2145/0.1901/0.4586/0.5154 etc.) are what the runtime gate reads (`assessImageQuality.m`) and were always correct. The stale values lived only in `config.thresholdDocumentation` and the report §7.3 table. Updated the documentation struct + header comments to match the operative values (all 5 metrics now MATCH, verified in MATLAB). **No change to the live gate** — docs fixed to match reality. |
| RF-3 | Ensemble + TTA for 5-class grader (inference-only) | ✅ Complete — small gains, mentor-only | `src/run_ensemble_eval.m` + `data/analysis/day9/ensemble_scores_cache.mat`. Inference-only; no retraining. **Ensemble (day7+day8_v2a weighted)**: best QWK 0.8933 (w=0.3/0.7) vs champion 0.8914; Severe recall +2.56 pts (48.72→51.28) at w=0.7/0.3, Prolif unchanged. **TTA on day7** (h-flip + rot±5): acc 82.81→83.36%, QWK 0.8914→0.8965, Mild recall +4.05 pts, Prolif +5.08 pts, but Severe −2.56 pts. Both are small; consistent with the ±1-grade confusion bottleneck (n=39/59 weak classes). Awaiting operator decision — nothing promoted; champion file untouched. |
| RF-4 | Calibration flip-case audit (11 flips) | ✅ Complete — net-negative on flips but tiny; keep calibration | `src/verify_calibration_flips.m`. 11/733 (1.50%) decision flips at 0.60, ALL ref→non-ref. 3/11 correct (Mild over-called as referable pushed below 0.60), 8/11 errors (truly referable Moderate/Severe/Prolif dropped below 0.60). Net-negative on this hand (3 vs 8) but the overall calibration effect (ECE 0.045→0.030, Brier 0.056→0.053) remains positive and flip rate is below clinical significance. **No calibration change** — T=2.5382 retained. |
| RF-5 | Branch B light tuning (logistic regularization) | ✅ Complete — small AUC gain, not promoted | `src/run_branchb_light_tuning.m`. Tuned `fitclinear` lambda on the same 10 features (no new extraction). Current model (T7): AUC 0.8969, match@0.60 0.8295. Best lambda 3e-2: AUC 0.9054 (+0.0085) but match 0.8172 (−0.012). Gains sit within the ceiling the current 10 features allow. **Nothing overwritten** — `branchB_model.mat` unchanged. |
| RF-6 | Vessel segmentation negative-result documentation | ✅ Complete | Report `docs/validation/2026-09-08-task8-vessel-segmentation.md` includes the full honest negative (Dice 0.2576 vs human 0.7881; Branch B +vessel AUC 0.8969→0.8810, Δ −0.0159, CI −0.0312..−0.0004, P(vessel wins)=0.022) + new **"Production exclusion (confirmed in code)"** section citing `predictSingleFundus.m:230` (`featRow = zeros(1,10)`, no vessel features) and `branch_b_predict.m:9` (10-feature length guard). No segmenter retraining. |
| RF-7 | `predictSingleFundus` OD capture bug (latent) | ✅ Complete — bugfix | `locateOpticDiscCnn` returns `[cx cy r P]` (4 outputs), but `predictSingleFundus` captured only the first (`odCnn = locateOpticDiscCnn(raw)` → scalar `cx`). For any image the CNN *accepts* (Pmax ≥ 0.90) `od(1:2)` threw, so lesions silently fell into the catch branch (empty od/exudate/MA-HE-EX counts + `lesions.error`). Build-time feature cache (`build_aptos_feature_cache.m:60`) already used the correct 4-output call — that is why Branch B full-val (T7) was unaffected. Fixed: capture all 4 outputs, pack `[cx cy r]`. Now CNN-accepted images yield full lesions (`MA=0 HE=6 EX=53`, `od=[772 772 160]`) with route still REVIEW / gate enforced. Also hardened `projectRoot` resolution from `pwd` → `mfilename('fullpath')` in `predictSingleFundus.m` so it works from any cwd. |
| T12 | Interactive App Designer screening dashboard | ✅ Complete | `src/dashboard/DRScreeningDashboard.m` (`matlab.apps.AppBase`, 5 tabs: Overview / Performance / Quality Gate / Workload-Staffing / Inspector) fed by `src/dashboard/load_dashboard_data.m` (verified 2026-09-09: PASS 65.48%, WARNING 26.68%, FAIL 7.84% of n=3662; champion acc 0.8281 / macroF1 0.6805 / QWK 0.8914; binary sens 0.9060 / spec 0.9471; infer 0.1028 s/img ≈ 9.7 img/s; referable val 40.65%; Branch B AUC 0.858 match 0.760; ablation day5/day6/day7). Inspector tab runs `predictSingleFundus` on a val image (validated headlessly: WARNING → route CLEAR). Workload tab is labeled **what-if only** — threshold 0.60 locked. `.mlapp` packaging: `build_dashboard_mlapp.m` opens the class in App Designer for File→Save As (both paths identical). Verification: `src/dashboard/verify_dashboard.m` — ALL T12 CHECKS PASS. |

## Task 5(a) vs day7 baseline — measured, validation n=733 (verified)

| Metric | day7_pretrained_resnet18_5class | day8_5class_v2a | Δ (pts) |
|--------|--------------------------------|-----------------|---------|
| NoDR recall | 98.34% | 97.78% | −0.56 |
| Mild recall | 60.81% | 63.51% | **+2.70** |
| Moderate recall | 78.50% | 78.50% | 0.00 |
| **Severe recall** | **48.72%** | **48.72%** | **0.00** |
| **Proliferative recall** | **52.54%** | **52.54%** | **0.00** |
| Accuracy | 82.81% | 82.81% | 0.00 |
| Macro F1 | 0.6805 | 0.6827 | +0.0022 |
| QWK | 0.8914 | 0.8877 | −0.0037 |

## Decision rule for Task 5 — applied outcome

- Rule branch that applies: **"recall barely moved or got worse on either
  class"** — Severe and Proliferative recall did not move at all (±0.00 pts).
  Strictly, the rule points to variant (b) as the next single isolated
  experiment **subject to explicit user approval**.
- However, the operator has already recorded the decision to **skip (b) and
  (c)** as separate training runs, with the interpretation that the
  Severe/Proliferative bottleneck is feature discriminability (errors are
  ±1-severity confusions), not training-data representation.
- **Net recommendation: accept Task 5 as PARTIAL (negative result kept on
  record) and move to Task 6 (lesion-feature branch)**, which is already
  underway. No variant (b)/(c) training will be launched without explicit
  user approval. Variant (c) remains off the table unless both (a) and (b)
  were tried and underperformed.

## Baseline to beat (measured, day7_pretrained_resnet18_5class)

| Metric | Value |
|--------|-------|
| Accuracy | 82.81% |
| Macro F1 | 0.6805 |
| QWK | 0.8914 |
| Mild recall | 60.81% |
| Moderate recall | 78.50% |
| Severe recall | 48.72% |
| Proliferative recall | 52.54% |

