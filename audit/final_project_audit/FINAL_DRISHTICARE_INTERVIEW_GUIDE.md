# FINAL DRISHTICARE — INTERVIEW GUIDE

*Q&A for defending the project. Every number is verified from committed artifacts (re-audited 09-Sep-2026; 63/63 checks PASS). Do NOT invent better numbers than these — the interview is won by honesty + exact recall, not by inflating.*

## 0. THE ONE QUESTION YOU MUST ANSWER PERFECTLY

**Q: What exactly did you build?**
A: A MATLAB pipeline that (1) checks image quality (5 metrics → PASS/WARNING/FAIL), (2) grades diabetic retinopathy into 5 classes with a ResNet-18 CNN, (3) runs a second 10-feature statistical model (Branch B) that must agree — disagreements go to REVIEW, (4) temperature-calibrates the probabilities, (5) attaches a Grad-CAM heatmap and a written explanation, and (6) fully separates train (2,929) / validation (733) / blind test (1,928). The test set (no labels) was never used for tuning.

**Q: What is NOT done?** (volunteer this — it pre-empts the trap)
A: The Simulink workflow-simulation module — the `.slx` is a text placeholder, so the "100k patients/yr queueing analysis" does not exist computationally yet. External validation on Messidor-2 was blocked by licensing. Those are the two gaps; everything else is measured and reproducible.

---

## 1. DATA & SPLITS (10 Q&A)

1. Q: Data used? A: APTOS-2019 (train 3,662; test 1,928), IDRiD segmentation (54+27) for lesion/Grad-CAM GT, DRIVE (20+20) for vessel, DRIMDB downloaded but unused.
2. Q: Class distribution? A: [1805, 370, 999, 193, 295] = 49.3/10.1/27.3/5.3/8.1%.
3. Q: Train/val split? A: Stratified 80/20, random seed 42 → 2,929 train [1444,296,799,154,236], 733 val [361,74,200,39,59].
4. Q: Leakage? A: Verified zero overlap train/val/test (integrity_check.mat).
5. Q: Preprocessing? A: 224×224 bilinear imresize + ResNet zerocenter normalization; no enhancement in the training path.
6. Q: Augmentation? A: Rotation ±15°, reflection, translation ±10px, shear ±5° (imageDataAugmenter does NOT support brightness/contrast).
7. Q: Test set labels? A: APTOS test.csv has only id_code — no labels, so we never claim a test accuracy.
8. Q: Why IDRiD? A: It provides pixel-level lesion masks for explainability/lesion GT that APTOS lacks.
9. Q: Imbalance handling? A: Class weights via Total/(5×count) attempted; balancing alone (day6) hurt overall to QWK 0.689, so the champion uses raw distribution + pretraining.
10. Q: Checkpoint/aborted training honesty? A: day9 raw/enh models exist but were NOT promoted (val 70%/68%).

## 2. MODEL & METRICS (15 Q&A)

11. Q: Champion model? A: `day7_pretrained_resnet18_5class_stage2` — ResNet-18 (71 layers), ImageNet-pretrained, fine-tuned in 2 stages (frozen then unfrozen, lr 1e-3/1e-5, miniBatch 32).
12. Q: 5-class results? A: accuracy 82.81%, QWK 0.8914, macroF1 0.6805 on 733 val.
13. Q: Per-class recall? A: NoDR 0.9834, Mild 0.6081, Moderate 0.7850, Severe 0.4872, Proliferative 0.5254.
14. Q: Per-class precision? A: 0.9807 / 0.5769 / 0.7772 / 0.5000 / 0.5849.
15. Q: Confusion matrix? A: rows [355 6 0 0 0; 6 45 19 1 3; 1 23 157 8 11; 0 0 12 19 8; 0 4 14 10 31].
16. Q: What is the weakness? A: Severe & Proliferative recall ≈0.49/0.53; bootstrap 95% CI [0.34,0.64] / [0.39,0.66] — the honest bottleneck.
17. Q: Binary referable? A: Classes 3,4,5 = referable (n=298 of 733).
18. Q: Binary metrics @0.60? A: sensitivity 90.60%, specificity 94.71%, PPV 92.15%, NPV 93.64%; tp 270 / fp 23 / fn 28 / tn 412.
19. Q: Binary AUC? A: ROC 0.9796; PR-AUC 0.7821 (drops vs day6 0.907 — explained: class-0 dominates high-recall tradeoff, DIAGNOSTIC_ONLY).
20. Q: Why threshold 0.60? A: Locked invariant; chosen on val, never tuned on test.
21. Q: Bootstrapping? A: B=1000, seed 2026: sens [0.870,0.939], spec [0.925,0.967], acc [0.800,0.854], mF1 [0.635,0.723], QWK [0.866,0.915].
22. Q: How do you prove the numbers aren't cherry-picked? A: Every number re-runs from saved artifacts (T0 re-verification + T13 re-audit 63/63 PASS).
23. Q: What is BN-finalization and why does it matter? A: BatchNorm needs the training-pass statistics at inference; in-loop val acc 70.5% vs proper-inference 82.81% — we documented and fixed the discrepancy, determinism run1==run2.
24. Q: day8 v2a? A: Retrain candidate — acc 0.8281, QWK 0.8877, macroF1 0.6827; cross-check PASSED but NOT promoted (no gain).
25. Q: Why not a vision transformer / ensembles in production? A: Ensembles/TTA measured: best QWK 0.8933, TTA QWK 0.8965 — small gains, extra complexity, so nothing promoted.

## 3. QUALITY (10 Q&A)

26. Q: What is measured? A: Brightness (mean gray FG), contrast (std FG), focus (variance of Laplacian @512px), foreground fraction, illumination (center/edge ratio).
27. Q: Thresholds? A: brightness 0.2145/0.1901/0.4586/0.5154; contrast 0.0387/0.0315/0.1065/0.1375; focus 2.37e-4/1.42e-4/1.34e-3/1.75e-3; foreground 0.4736/0.2651/0.8833/0.9758; illumination 0.92/0.8025/1.2615/1.3541 (lowerWarn/lowerFail/upperWarn/upperFail).
28. Q: How is the verdict combined? A: FAIL if any metric fails, WARNING if any warns (illumination is warning-only), else PASS.
29. Q: Distribution? A: PASS 65.48%, WARNING 26.68%, FAIL 7.84% (n=3662).
30. Q: Is the gate enforced? A: Yes — FAIL → route REVIEW enforced; WARNING → not enforced (CLEAR); verified end-to-end.
31. Q: What happens to a FAIL image? A: It is flagged for recapture / routed to REVIEW — never silently graded.
32. Q: How were thresholds set? A: From Day-3 stat distributions (5th/95th percentiles style) on 3,662 train images; kept as config `defaultQualityConfig` v2.0.0.
33. Q: Known doc issue? A: `docs/day3-quality-assessment.md` tables still show older round numbers — the live config differs; we flagged it (audit P0 fix).
34. Q: Retinal mask method? A: gray > 0.15, largest connected component, fill holes, morphological open.
35. Q: Enhancement + quality? A: Enhancement (CLAHE etc.) is display-only; evaluated A/B and it hurts the champion (acc 0.83 → 0.54), so not used.

## 4. CALIBRATION (10 Q&A)

36. Q: Why calibrate? A: The binary "referable" confidence was miscalibrated (ECE 0.045 raw).
37. Q: Method? A: Temperature scaling T=2.5382 (fitted on train split, applied to full).
38. Q: Both splits? A: Firewalled fit/firewalled-eval gave ECE 0.0319 → 0.0087 and NLL 0.1998 → 0.1243; standard split T=2.6722 gave 0.0450 → 0.0297.
39. Q: Flips @0.60 after calibration? A: 11/733 (1.5%), all ref→nonref: 3 correct (Mild), 8 errors (Moderate×5, Severe×1, Prolif×2) — net-negative on flips but net-positive overall; T retained as a product decision, documented (RF-4).
40. Q: Brier? A: 0.0563 (binary calibration artifact).
41. Q: Is T used in production? A: Yes — loadTemperatureParams reads current_T.mat; predictSingleFundus applies temperatureScale; calibrated prob feeds Branch B fusion.
42. Q: Could you have used Platt/isotonic? A: Yes, but temperature is 1-parameter (lowest variance with our small val) — we state this design choice.
43. Q: Did calibration change the decision threshold? A: No — threshold stayed 0.60 by design.
44. Q: Reproducible? A: Verify script `verify_calibration_flips.m`; artifacts in data/analysis/day8/calibration/*.

## 5. Branch B / CASCADE / FUSION (10 Q&A)

45. Q: What is Branch B? A: A second, independent 10-feature model (ClassificationLinear, T=0.7139): texture, vessel density, colour, lesion/OD hints — a statistical cross-check, not a deep net.
46. Q: Why a second model? A: Two independent models agreeing is more defensible than one black-box; disagreements surface as REVIEW.
47. Q: Branch B quality? A: Full-val AUC 0.89691 vs Branch A 0.97962; agreement 0.8295 (598 agree, 135 discrepancy).
48. Q: What happens on disagreement? A: REVIEW flag (fuseEvidence) — 135 of 733.
49. Q: Routes? A: CLEAR (both agree non-referable) / REVIEW (conflict or quality FAIL) / ABSTAIN (<0.50 confidence).
50. Q: Was vessel density added to Branch B? A: Tested — it made it WORSE (AUC 0.897→0.881, p=0.022 base better), so vessel features are excluded in production (featRow=zeros(1,10)).
51. Q: Feature count guard? A: branch_b_predict.m enforces 10 features — a 10-dim zero row is passed, not the raw vspace.
52. Q: Pilot eval? A: dashboard Branch B pilot AUC 0.858 on val-like data.
53. Q: Did fusion change the champion? A: No — champions are read-only; fusion only routes.

## 6. ENSEMBLE / TTA (5 Q&A)

54. Q: Ensembles? A: Post-hoc soft-voting champion + day8 → best QWK 0.8933 (vs 0.8914).
55. Q: Test-time augmentation? A: TTA acc 83.36% (vs 82.81%), QWK 0.8965; classes shift Mild +4pt, Prolif +5pt, Severe −3pt.
56. Q: Promoted? A: No — small gain, more complexity/inference cost; champion untouched (RF-3).
57. Q: Bootstrap trust bound? A: CIs above; margins ~0.03–0.07.

## 7. OOD (5 Q&A)

58. Q: OOD detection? A: Mahalanobis distance on 512-d penultimate features of the champion; threshold = p99 of train dist = 34.2155.
59. Q: Stats? A: mean 23.74, p90 28.66, p95 30.39, p99 34.22; false-OOD on train 1.01%.
60. Q: Integrated? A: Yes — ood_detector called in predictSingleFundus; result.ood returned to caller.
61. Q: Limitation? A: Calibrated to train self-distribution; no external-Corrupt/TF distribution test — noted as future work.
62. Q: Why Mahalanobis? A: Simple, interpretable (a distance), no training.

## 8. EXPLAINABILITY (10 Q&A)

63. Q: Method? A: Grad-CAM (built-in, target layer res5b_relu, predicted class, top-20% saliency threshold for IoU).
64. Q: Validated against what? A: 81 IDRiD segmentation images (54 train + 27 test) with MA/HE/EX/SE masks.
65. Q: Results? A: Saliency mass in any lesion 0.031 (≈1.4× areal chance 0.022); pointing game 0.074 (= 0.37× uniform chance); Dice 0.051; Jaccard 0.027.
66. Q: Honest interpretation? A: Heatmaps are real but do NOT localize small lesions; 78% of saliency mass is on the disc; we state Grad-CAM as a transparency tool, not a diagnostic — measured weakness.
67. Q: Confound? A: Retina-mask check — 78% mass on disc; only 3.8% of on-retina saliency hits lesions; i.e., not a black-background artefact.
68. Q: Best case? A: IDRiD_17 mass-in-lesion 0.314, pointing=1 (pred Proliferative, p=1.0).
69. Q: Correct-vs-error split of IDRiD? A: Honestly BLOCKED — IDRiD segmentation images ≠ IDRiD grading images ≠ APTOS val; we refused to fabricate (documented).
70. Q: metrics.md targets? A: STALE — saliency>60%, pointing>70%, IoU>0.3 not met; we flagged the targets for refresh (P1).
71. Q: Also explainability beyond saliency? A: 14 curated case overlays + class-average saliency maps (day7); manifest + average-maps artifacts exist.
72. Q: Does the report include text? A: Yes — buildExplanationNarrative writes a hedged paragraph (self-labeled "engineering demo, not clinical").

## 9. LESIONS / OD / FOVEA / VESSEL (12 Q&A)

73. Q: Lesion types? A: MA (CNN ensemble), HE (classical), EX (morphological reconstruction w/ OD exclusion), plus quadrant HE counts.
74. Q: Detection quality (GT, 10 IDRiD)? A: MA recall 0.23%/prec 0.29%; HE recall 33%/prec 11%; EX recall 7.4%/prec 16% → genuinely weak; engineering candidates only.
75. Q: MA patch model? A: AUROC 0.9755/acc 0.9135 (patch-level); detection recall ~0.113 (task-tracker) — honest negative.
76. Q: OD localization? A: CNN locator; IDRiD 10/10 located, 9/10 within 300 px; APTOS-val only 78/733 (10.6%) located — the CNN honestly refuses low-confidence cases.
77. Q: Is 10.6% a bug (RF-1)? A: No — verified: OD-CNN trained on 44 IDRiD images doesn't generalize to APTOS; fallback locates ~44% (sample); combined ~50%; documented, not fabricated.
78. Q: Fovea? A: CNN AUROC 0.7487 → unreliable; production uses clinician-supplied FoveaCenter with a disclosure flag (foveaSupplied); honest negative (T11).
79. Q: Vessel segmentation? A: Classical multi-scale bottom-hat + Frangi; champion Dice 0.7535 / Sens 0.6947 / Prec 0.8272 on DRIVE test.
80. Q: Legacy vessel code? A: src/extractVessels.m is a broken single-scale Otsu (Dice 0.312); production prototype lives in src/vessel/extractVessels.m; NOT called by inference (excluded by design RF-6).
81. Q: Phase-3 candidate? A: p3_od_off: Dice 0.7438 (below champ 0.7549) but precision 0.8498 (above 0.8220) — not promoted.
82. Q: Vessel CNN? A: AUC 0.8478/acc 0.78 — negative, unused.
83. Q: 2nd-manual agreement? A: champ 0.7573 vs human inter-observer 0.7902 — within human variability.
84. Q: Is any segmentation used in grading? A: No — deliberately excluded after measured negatives.

## 10. TEST SET, DASHBOARD, DEPLOYMENT (8 Q&A)

85. Q: Test set accuracy? A: None computed — 1,928 test images, no labels by Kaggle design; we only report prediction distributions (pred-referable 60.1% binary / 69.1% five-class, agreement 83.4%).
86. Q: Distribution shift? A: Val referable 40.65% → test predicted 60.06% (+0.19) — flagged as an observation.
87. Q: Batch processing capability? A: Offline scripts; single-image production path is predictSingleFundus (0.10 s/img CPU).
88. Q: Dashboard? A: 5-tab MATLAB App (Overview / Quality / Champion / Workload / Inspector), all numbers loaded from committed artifacts; Inspector runs live inference.
89. Q: Dashboard numbers? A: acc 0.8281, mF1 0.6805, QWK 0.8914, sens 0.9060, spec 0.9471, 9.73 img/s, quality 65.48/26.68/7.84.
90. Q: Deployment story? A: A prototype; modelling-code separable from app via load_dashboard_data; designed to be ONNX-transferable (documented).
91. Q: Cost/roll-out numbers? A: None computed — see Simulink gap.
92. Q: What would you change for production? A: Retrain with more (and external) data, add hard-example augmentation, strengthen Severe/Prolif, swap Grad-CAM for a model with better localization, integrate a real queueing model.

## 11. SIMULINK — THE LIKELY TRAP (6 Q&A)

93. Q: Where is the Simulink model? A: src/simulink/simulink_model.slx is a 56-byte text placeholder — a real model was NOT built.
94. Q: Did the demo claim Simulink insight? A: Yes — pitch demo Act 5 claims a bottleneck at 100k patients/yr and "automate 80%" — that is currently NOT backed by a simulation; we flagged it in the audit as the #1 gap.
95. Q: Correct response when asked "show the Simulink model"? A: State plainly it's the outstanding PS requirement; show the measured inputs (0.10 s/img, 60 reviews/h reviewer, 40/60 referable split) that a queueing model would use; offer the roadmapped scripted-throughput alternative.
96. Q: Did the schedule plan it? A: Yes — but the day-08 checkboxes are all unchecked, i.e., the plan was honest.
97. Q: Is throughput measured at all? A: Inference 0.1028 s/img (9.73 img/s, single-stream CPU) — the number a workflow model would consume.
98. Q: What is the honest pitch fix? A: Either deliver the Simulink/scripted throughput model, or remove Simulink from PS/deck and present the measured throughput + reviewer-capacity math as back-of-envelope (labeled as such).

## 12. ETHICS, LIMITS, PROCESS (10 Q&A)

99. Q: Is this a medical device? A: No — explicit disclaimer in code/docs; self-labeled engineering demo.
100. Q: Bias/data limits? A: APTOS is a graded challenge set; not demographically representative; class imbalance; no Indian-field-capture images except subset; external validation pending.
101. Q: Clinical safety? A: The FAIL→REVIEW and A/B-disagreement→REVIEW triage is the safety mechanism; calibration prevents overconfident "everything clear."
102. Q: Reproducibility? A: Seed 42, artifacts committed, 63/63 re-audit, re-verification scripts for every task.
103. Q: Biggest technical risk in the pipeline? A: Minority-class recall and domain shift (val 40.7% → test 60.1% referable) — both documented.
104. Q: How is honesty enforced in this repo? A: Every task has status VERIFIED/UNVERIFIED/BLOCKED/negative-result records; fabricated metrics are absent (audit confirmed); "no evidence found" is used when needed.
105. Q: What was the single best decision? A: The invariance discipline (locked threshold, read-only champions, closed test set) — it makes every later number trustworthy.
106. Q: Second best? A: The independent Branch B cross-check — it turns a single black-box into an auditable two-opinion system and forces REVIEW on conflict.
107. Q: What would you do with 2 more weeks? A: External validation (Messidor-2/EYE-PACS), minority-class data engine, a real Simulink capacity model, and lesion localization retraining.
108. Q: What did you learn hardest? A: Mean-vs-mode of small deltas (0.001–0.003) in metrics are noise; we measured CIs before ever "improving" anything; and that negative results (enhancement, vessel, fovea) are the ones that protected the pipeline from degrading.

## 13. NUMBER RECALL CHEAT-SHEET (fast-fire)

109. acc 0.8281 · QWK 0.8914 · macroF1 0.6805 · 5-class recall [0.9834,0.6081,0.7850,0.4872,0.5254]
110. binary @0.60: sens 0.9060 · spec 0.9471 · ROC 0.9796 · PR 0.7821 · tp/fp/fn/tn 270/23/28/412
111. val 733 · train 2929 · test 1928 · seed 42 · threshold 0.60 · T=2.5382
112. ECE 0.0450→0.0297 (standard) · 0.0319→0.0087 (firewalled) · Brier 0.0563
113. Branch B AUC 0.8969 · match 0.8295 · 598 agree / 135 review · vessel B: 0.881 (p=0.022 worse)
114. ensemble QWK 0.8933 · TTA 0.8965/83.36% · nothing promoted
115. quality 65.48/26.68/7.84 % · n 3662 · gate FAIL→REVIEW
116. vessel champion Dice 0.7535 · legacy 0.3124 · phase3 0.7438 · CNN AUC 0.8478
117. Grad-CAM: mass 0.031 (1.4× areal) · pointing 0.074 (0.37× uniform) · Dice 0.051
118. OD: 78/733 CNN-located (10.6%) · IDRiD 10/10, 9 within 300 px
119. fovea AUROC 0.7487 · MA patch 0.9755 · OD patch 0.9955 · OOD p99 34.2155
120. Simulink: NOT BUILT (placeholder) — say it first, own it, show the plan.

---
*Prepared 09-Sep-2026 · all figures cross-referenced in `FINAL_DRISHTICARE_TECHNICAL_AUDIT.md` and the 20 audit CSVs.*