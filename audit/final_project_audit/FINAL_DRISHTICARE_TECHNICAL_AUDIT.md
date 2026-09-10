# FINAL DRISHTICARE TECHNICAL AUDIT

- **Project:** DrishtiCare — MATLAB/Simulink DR screening pipeline (5-class + referable binary)
- **Audit date:** 09 Sep 2026 (evidence re-verified 18:00–20:00 IST)
- **Audit mode:** READ-ONLY. No source modified, no model retrained, no parameter changed, **no commits/pushes made**. All numbers below were re-verified live from committed artifacts on disk.
- **Method:** (1) Git/file inventory; (2) parallel artifact-existence checks; (3) live MATLAB/Simulink artifact loads (`whos`/`load`, `load_system`); (4) independent re-audit harness `src/re_audit_T13.m` re-run → **63/63 PASS**; (5) doc-vs-evidence tracing across all 74 markdown docs.
- **Verdict vocabulary:** VERIFIED / CONTRADICTED / UNVERIFIED / OVERCLAIMED / DOCUMENTED-BUT-NOT-IMPLEMENTED / INTEGRATION-GAP / BLOCKED (honest).

---

## EXECUTIVE SUMMARY

The DrishtiCare repo (132 commits, single `main`, HEAD `9c553ad`, clean, fully pushed) is an unusually rigorous student build: **every headline number reproduces exactly** from committed artifacts (T13 = 63/63 PASS), leakage is provably zero, champions are never overwritten, and negative results (lesion detection, fovea, Grad-CAM, enhancement, vessel-in-branch-B) are measured and documented honestly.

### Scorecard

| Domain | Verdict | Confidence |
|---|---|---|
| Repository hygiene & provenance | PASS | High |
| Dataset & split integrity | PASS | High |
| Champion 5-class / binary metrics | PASS (all exact) | High |
| Calibration | PASS | High |
| Quality assessment | PASS (config-live, gate enforced) | High |
| Enhancement | IMPLEMENTED-NOT-INTEGRATED (display-only; A/B shows it hurts) | High |
| Branch B / fusion / cascade | PASS | High |
| Vessel segmentation | PROTO ONLY + negative CNN; excluded from production (by design) | High |
| OD / IDRiD | PASS (10/10, 9 within 300 px; discrepancy explained) | High |
| Fovea / MA / HE / EX lesions | MEASURED WEAK (honest negatives) | High |
| Grad-CAM explainability | IMPLEMENTED; strong-confound, weak-localization (honest) | High |
| OOD | PASS (Mahalanobis p99, integrated) | High |
| Dashboard | PASS (all numbers verified) | High |
| Test-set evaluation | Prediction-only (no labels) — correctly reported as such | High |
| External validation (Messidor-2) | NOT PERFORMED (BLOCKED, license) | High |
| **Simulink workflow module** | **NOT IMPLEMENTED — `.slx` is a 56-byte text placeholder** | High |
| Doc-vs-impl consistency | Mostly PASS; 6 stale/contradicted doc tables + 2 minor numeric deltas found | High |
| Problem-statement compliance | **4/5 capabilities delivered; Simulink (PS #5) missing** | High |

---

## PART-BY-PART AUDIT (47 parts)

### 1. Repository inventory
132 commits, 1 branch (`main` from git), remote `origin=https://github.com/Aryan41211/DrishtiCare.git`, working tree clean, 0 unpushed. 19,381 files; 134 `.m`, 153 `.mat`, 18 `.csv`, 74 `.md`, 1 `.slx` (placeholder), 16,674 PNG images. `data/analysis/` (evidence tree) is tracked; raw datasets and all raw images gitignored with `!data/analysis/**` allow-list. **PASS.**

### 2. Git history & commit map
Headlines verified per commit: RF-1..RF-7 (5c574f3, 6b50c62, b7298a4, 87f746d, 20ff5b6, c6a2d74, 7f9bb71), stage5 quality-gate+fovea (473be21), T9B models, T12 dashboard (2c62dbb/9f705f0), vessel Phase-3 (b8776b4), T13 re-audit (b8f751a, 9c553ad). Every tracked claim has an artifact commit. **PASS.**

### 3. Dataset inventory
APTOS-2019 train 3,662 PNG (distro 1805/370/999/193/295) + test 1,928 PNG; IDRiD segmentation 54 train/27 test (2848×4288, masks aligned); IDRiD grading set; DRIVE 20/20 + 1st/2nd manual masks; DRIMDB downloaded (~216 imgs) but **zero code references** → documented-only. HRF/STARE/CHASE/EyePACS not present. **PASS (DRIMDB flagged).**

### 4. Split integrity & leakage
Stratified 80/20, seed 42 → train 2,929 (1444/296/799/154/236), val 733 (361/74/200/39/59); `splits_binary` (val nonref 435/ref 298); `splits_enhanced` identical counts (1 corrupted file fixed). `integrity_check.mat`: overlap train/val/test = 0. **PASS.**

### 5. Model inventory & training configs
16 model files; day5/day6 scratch (`usePretrained=0`), day7/day8/day9 pretrained (`1`); miniBatch 32, lr 1e-3 (stage1 1e-5 head, stage2 unfreeze), image 224³ bilinear + zerocenter; checkpoints present. day9 raw/enh train summaries: raw stage1 val 73.53% / stage2 70.12%; enh 66.71% / 67.67%. **PASS.**

### 6. Champion reconstruction (T0)
`reverify_audit_T0.mat` + `src/re_verify_audit.m` reproduced: acc 0.828104, QWK 0.891401, macroF1 0.680459, binary @0.60 sens 0.906040/spec 0.947126, ROC-AUC 0.979619, PR-AUC 0.782054. **PASS (exact).**

### 7. Classifier metric verification (5-class)
Full per-class arrays and confusion matrix verified (see CSV 05/20; support [361 74 200 39 59]). **PASS.**

### 8. Referable threshold & binary metrics
@0.60 tp/fp/fn/tn = 270/23/28/412 (sens=270/298, spec=412/435 — internally consistent). The day7 binary metrics file additionally stores the default-threshold confusion (275/25/23/410, sens 0.9228/spec 0.9425) — **two thresholds, not a contradiction**. Referable classes = [3,4,5] (1-indexed), n=298 positives (the "313" figure does **not exist anywhere**; verified absent). **PASS.**

### 9. Minority-class recall
Severe recall 0.4872 / Proliferative 0.5254 (champion). day8 v2a retrain changed nothing on Severe/Prolif (task 5a negative, honest). Bootstrap CI (1000): rec-c4 [0.337,0.640], rec-c5 [0.391,0.661]. **PASS (weak minority recall honestly bounded).**

### 10. Calibration verification (T5)
Standard OTS T=2.6722; val ECE 0.045013→0.029653; flip 0.016371. Firewalled eval ECE 0.031915→0.0087196, NLL 0.1998→0.12425, flip 0.0074105. Brier 0.0562956. **PASS.**

### 11. Calibration flips (RF-4)
11/733 flips, all ref→nonref; 3 correct (Mild) / 8 errors; net-negative on flips, net-positive overall; T=2.5382 retained (product decision vs staircase: no threshold change). **PASS.**

### 12. Quality assessment implementation
`computeQualityMetrics` (brightness=mean gray FG, contrast=std FG, focus=var(Laplacian)@512, illumination=center/edge, foreground fraction) exactly as documented; `assessImageQuality` FAIL-if-any-fail/WARNING-if-any-warn/else-PASS; `runQualityAssessment` → 3662-row CSV. **PASS.**

### 13. Quality threshold config (RF-2)
Live config v2.0.0 (all 20 values verified in CSV 08) is what `assessImageQuality` actually uses. `thresholdDocumentation`/header comments were fixed to match (RF-2). **However the standalone module doc `docs/day3-quality-assessment.md` threshold tables are STALE** (round-number 0.15/0.20/0.50/0.55-style values) → **CONTRADICTED-doc, needs fix.** Gate in inference: FAIL→REVIEW enforced, WARNING→CLEAR (T13 verified). **PASS-live / one stale doc.**

### 14. Quality metric ranges & distributions
Ranges verified (CSV 08); PASS/WARNING/FAIL = 65.483/26.679/7.837 %, n=3662. **PASS.**

### 15. Enhancement implementation
`enhanceImage` (CLAHE, illum-norm, hist-match, gamma, vessel-hat, OD-norm, noise-aware wiener+median, denoise, sharpen) real code. **Integration: NO — `predictSingleFundus.m:84` calls it for display only; model input = raw imresize (line 68). The day4/day5 "Enhance→Classify" pipeline diagrams are NOT wired.** Day-4 "10/10 improved" claim has no stored numeric artifact → UNVERIFIED. **IMPLEMENTED-NOT-INTEGRATED.**

### 16. Enhancement A/B (T9B)
Model-agnostic champion applied to raw vs enhanced 733-val: raw acc 0.8322/qwk 0.8952/mF1 0.6828 vs enhanced 0.5416/0.6507/0.4039 → **enhancement hurts the champion by ≈29 acc pts**; day9 own training confirms (67.67 vs 70.12 best). Decision: not used. **PASS (negative, verified).**

### 17. Vessel segmentation (classical)
Champion classical (DRIVE test, 1st manual GT, FOV eroded 5 px): Dice 0.7535, Sens 0.6947, Spec 0.9784, Prec 0.8272, AUC(FOV) 0.9029; dev Dice 0.7276. Legacy original: Dice 0.3124 (matches "broken" narrative). 2nd-manual: champ 0.7573; human inter-observer 0.7902. **PASS.**

### 18. Vessel CNN + Branch-B feature (T8)
CNN vessel AUC 0.8478/acc 0.78 (negative). Branch-B with vessel feature: aucBase 0.896914 vs aucVes 0.880984, CI [-0.03125, -0.00039] (excludes 0, base better), pVesWin=0.022 → **vessel feature significantly hurts**; match 0.8336 vs 0.8295. **PASS (negative, verified).**

### 19. Vessel production-integration (RF-6)
Production exclusion confirmed in code: `predictSingleFundus.m:231 featRow=zeros(1,10)`; `branch_b_predict.m:9` feature-count guard. No vessel call anywhere in inference/dashboard. **PASS-by-design.** Flag: `src/viewVessels.m:11` still calls the legacy broken `src/extractVessels.m` (latent trap).

### 20. OD localization + discrepancy (RF-1)
78/733 aptos-val CNN-located (10.6%), 655 refused (CNN honestly refuses P<0.90); IDRiD 10/10 located, 9/10 within 300 px (IDRiD_010 err 1375 px @P=1.0). Classical fallback ~44% (n=50) → combined ~50%. **NOT a bug**; documented. **PASS.**

### 21. OD CNN classifier
Patch AUROC 0.995538 / acc 0.995833; RF-7 fixed 4-output capture (scalar-capture bug that dropped lesions for CNN-accepted images). **PASS.**

### 22. Fovea estimation (+T11 closure)
Fovea CNN AUROC 0.7487/acc 0.6479 → **unreliable; honest negative.** Production: `FoveaCenter` supplier hook + `foveaSupplied` disclosure; returns NaN/guarded otherwise. **PASS (honest negative).**

### 23. Lesion detection (MA/HE/EX)
MA = CNN ensemble (`detectMaCnn`), HE/EX = classical; quadrant counts; OD-excluded EX. Detection GT (10 IDRiD, tol 20 px): MA recall 0.00233/prec 0.00294 (nGT 370); HE recall 0.3329/prec 0.1118 (nGT 227); EX recall 0.0737/prec 0.1600 (nGT 1742). Matched filter: MA prec 0.00264, HE prec 0.00207 → **very high false-positive explosion.** Patch AUROC MA 0.9755. Counts are engineering candidates, not clinical. **PASS (weak, honestly measured).**

### 24. Lesion GT validation
Pixel-wise GT: MA recall ~0.00013, HE 0.0023, EX 0.286 dice. Instance-level above. Cross-validated with task-tracker MA det-recall ~0.113. **PASS (weak, honestly measured).**

### 25. Lesion report integration
`lesion_report_test.mat`: 5 APTOS images end-to-end (quality, grade, calibrated binaryProb, cascade/fusion, lesions, OOD, Grad-CAM, explanation narrative). `buildExplanationNarrative` hedges and self-labels "engineering demo, not clinical". **PASS.**

### 26. Grad-CAM implementation
Built-in `gradCAM()` (Deep Learning Toolbox 26.1), default target `res5b_relu`, predicted-class; `gradFallback` raw gradient for dlnetwork (used only if needed); top-20% cumulated saliency as the IoU threshold. **PASS.**

### 27. Grad-CAM quantitative validation (T6)
81 IDRiD images. Saliency mass in lesion (any) 0.0307 (MA 0.0013/HE 0.0126/EX 0.0145/SE 0.0049) vs areal chance 0.0220 → 1.24–1.61× areal. **Pointing game (any) 0.074 — this is 0.37× the annotator uniform chance level (0.20), i.e. BELOW chance-representative.** Dice(any) 0.0513/Jaccard 0.0274. Retina confound: 78% of saliency mass is on the optic-disc region; only 3.8% of on-retina saliency touches lesions. Best image IDRiD_17: mass 0.314, point=1. Correct-vs-error split honestly BLOCKED (IDRiD seg ≠ IDRiD grade ≠ APTOS val). **Doc table is faithful to artifact.** **PASS (weak, honest).**

### 28. Explainability claims vs targets
`docs/validation/metrics.md` still lists targets **saliency-in-lesion >60%, pointing >70%, IoU >0.3, MACE <10 px**. Measured: 3.07%, 7.4%, 0.027, never-measured → **targets fail by 1–2 orders of magnitude and are stale.** Grad-CAM module pitch ("most visually persuasive artifact") not backed by metric evidence. **OVERCLAIMED-stale-targets.**

### 29. Branch B feature pipeline & fusion
ClassificationLinear, 10 features (T=0.7139), calibrated Branch-A prob feeds fusion; fuseEvidence REVIEW on A/B conflict; full-val verified (598/135). **PASS.**

### 30. Cascade router
CLEAR (both agree non-referable) / REVIEW (conflict or quality FAIL) / ABSTAIN (<0.50); 0.60 locked. **PASS.**

### 31. Ensemble & TTA (RF-3)
Best ensemble QWK 0.8933 @w(0.3/0.7); TTA acc 83.36%/QWK 0.8965, Mild+4.05/Severe−2.56/Prolif+5.08 pts; **nothing promoted** (champion untouched; code default unchanged). **PASS.**

### 32. OOD detection
Mahalanobis p99 = 34.2155 (512-d, n=3662), false-OOD 1.01% (train); `ood_detector` integrated at `predictSingleFundus.m:186`; `ood` in output. Caveat: no external-distribution AUROC test. **PASS (self-calibrated; external unverified).**

### 33. Inference pipeline (predictSingleFundus)
Verified order: quality gate (line 71) → OD locate (136-140) → lesion extraction (154) → model input = raw resized (68) → 5-class + binary heads → temperatureScale (99) → OOD (186) → cascade (197) → fusion (221-272) → buildExplanationNarrative (275). `result` struct carries all fields (calibrated prob, temperature, cascade.qualityGate/route, lesions.foveaSupplied, ood, explanation). **PASS.**

### 34. Test-set evaluation
1,928 test predictions; **no labels** (id_code only) → no accuracy, correctly reported. Binary pred-referable 60.06% vs val 40.65% (shift +0.194, flagged). Agreement 5-class/binary 0.8335; borderline n=47. **PASS (honestly prediction-only).**

### 35. Dashboard (T12)
5-tab app; all numbers source ONLY from committed artifacts (quality split 65.48/26.68/7.84; champion acc/mF1/qwk 0.8281/0.6805/0.8914; sens/spec 0.9060/0.9471; 0.1028 s/img→9.73 img/s; branchB pilot 0.858; referable 0.4065); Inspector tab does live inference. MLAPP packaged; headless verify PASS. **PASS.**

### 36. Simulink module — **CRITICAL**
`src/simulink/simulink_model.slx` is **56 bytes = a single MATLAB comment line**; `load_system` fails («not a valid Simulink model file»). No queueing model, no throughput graph, no 100k-patient analysis exists anywhere. PS requirement #5 **NOT MET**. But: `schedule/day-08-simulink.md` honestly leaves all checkboxes `[ ]`; `modules/simulink-workflow.md` labels its numbers "assumed"; risk-checklist anticipates the fallback. **DOCUMENTED-BUT-NOT-IMPLEMENTED.**

### 37. Demo script & pitch deck
Verified: Act 4 numbers (acc 82.81%, QWK 0.8914, sens 90.60%, spec 94.71%, ECE 0.045→0.030, ablations) — all correct. **Overclaims: Act 5 "our Simulink model shows bottleneck… automate 80%… only send borderline" and deck Slide-5 "throughput bottleneck graph/queue graph/needed ophthalmologists X" have NO computational artifact.** Clinical stats (77M diabetics, 18% DR prevalence, 1-ophth/100k) unsourced in repo. **Mixed.**

### 38. Task tracker & RF tracking
Tasks 0–13 and RF-1..7 all marked complete; each maps to a real script+artifact (verified row-by-row). RF negative results (3,4,5,6, fovea, T9B) properly recorded. **PASS.**

### 39. Documentation-vs-implementation (module matrix)
See CSV 03. Notables: `src/quality/quality_gate.m` is a dead 1-line placeholder (real gate = assessImageQuality, which IS integrated — so this is only a file-naming lapse); viewVessels legacy trap; enhancement pipeline diagrams unwired. Otherwise implemented modules are genuinely called. **PASS-with-3-flags.**

### 40. External validation (T10)
**Not performed.** BLOCKED honestly (Messidor-2 download/license required); `external-validation.md` = protocol only; no cross-dataset run (IDRiD↔APTOS generalization never executed). **BLOCKED-honest.**

### 41. Clinical/literature claims
Verified in-repo: Gulshan 2016 (with PLOS-ONE replication caveat noted), IDx-DR FDA 87.2/90.7, INR 400B (ORNATE 2023 citation), APTOS counts. Unsourced: 77M diabetics, 18% prevalence, 1/100k workforce, "95% preventable". **MIXED.**

### 42. Data gaps
Documented honestly: lesion-annotation cliff (54 IDRiD images), no quality labels (EyeQ referenced), no NV annotations. **PASS.**

### 43. Metric targets vs achieved (metrics.md)
Sens 0.906>0.90 ✓; Spec 0.947>0.85 ✓; AUC 0.9796>0.95 ✓; ECE 0.045<0.05 ✓ (raw), 0.030 (cal) ✓; Brier 0.056<0.15 ✓; explainability targets ✗ (see Part 28); MACE never measured ✗. **4/6 targets confirmed; 2 stale.**

### 44. Hypotheses & ablation study
All rows verified against artifacts except row 2 sens/spec (no day6-balanced referable artifact → UNVERIFIED portion) and row 8 (qwk 0.8877 artifact-consistent via verification mat). See CSV 18. **PASS (2 partial).**

### 45. Conflicts & discrepancies table
See CSV 19. All resolved except: (a) task8 DRIVE-dice doc 0.2576 vs artifact 0.2541 (+0.0035); (b) task8 humanDice doc 0.7881 vs artifact 0.7902 (−0.0021); (c) stale day3-quality-assessment threshold tables; (d) day6-training-results superseded metrics; (e) day7 report §2 scratch-spec internal inconsistency; (f) stale metrics.md targets. **5 doc-fix items.**

### 46. Final scorecard
Summarized in Executive Summary above. 47/47 parts completed.

### 47. Truth table + SIH verdict + priority roadmap
See CSV 20 for full truth table. **SIH verdict: 4 of 5 PS capabilities delivered and reproduced; Simulink (#5) is a placeholder — the single SIH-blocking gap. Everything else is at "defensible student-build" level.** Priority roadmap below.

---

## PRIORITY ROADMAP

| # | Action | Why | Effort |
|---|---|---|---|
| P0 | Build a real Simulink (or scripted) queueing/throughput model for 100k/yr with the measured 0.1028 s/img + 60-reviews/h reviewer rate; then either fix the `.slx` or explicitly remove the Simulink claim from PS/demo/deck and replace with the honest "scripted throughput analysis" | SIH PS #5 gap; currently an overclaim in demo Act 5 | 1 day |
| P0 | Update `docs/day3-quality-assessment.md` threshold tables to the live config v2.0.0 values | Stale docs contradict live gate | 15 min |
| P1 | Re-point `src/viewVessels.m` to `src/vessel/extractVessels.m` (or delete legacy), else anyone running it uses Dice-0.312 code | Latent trap | 10 min |
| P1 | Refresh `metrics.md` explainability targets (3.07% mass vs 2.2% areal; pointing 7.4%; Dice 0.051) or mark "aspirational" | Targets fail by 10–20× and mislead | 15 min |
| P1 | Fix task8 DRIVE-dice (0.2576→0.2541) and humanDice (0.7881→0.7902); mark superseded day6-training-results metrics; reconcile day7 §2 scratch-spec | Doc/artifact deltas | 30 min |
| P2 | Add an external OOD evaluation (e.g., a held-out non-APTOS set) to give the Mahalanobis gate an AUROC | Currently train-self-derived only | 0.5 day |
| P2 | Source the 3 clinical stats (77M/18%/1-per-100k) or label them estimates | Pitch hygiene | 15 min |
| P2 | Decide fate of DRIMDB (use for quality cross-check or remove from docs) | Listed but unused | 1 hr |

## FILES

- Evidence CSVs: `audit/final_project_audit/01..20_*.csv`
- Companion docs: `FINAL_DRISHTICARE_SIMPLE_EXPLANATION.md`, `FINAL_DRISHTICARE_INTERVIEW_GUIDE.md`
- Key harness re-run for this audit: `src/re_audit_T13.m` (63/63 PASS at 09-Sep-2026 19:00 IST)