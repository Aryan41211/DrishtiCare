# DrishtiCare — Research Dossier

**Repository:** `C:\projects\DrishtiCare` · **Commit at time of writing:** `d59e2ba` (+ uncommitted UI layout changes)
**Scope:** 33-part research-grade description of what this system is, what was measured, what was not, and what a reviewer must verify independently.

**Evidence rules used throughout**

- Every number carries a source (`file` or `file:line`, or an artifact path). Numbers not present in the repository are marked **UNKNOWN**.
- Nothing in this dossier is inferred from outside the repository. Where docs and code disagree, both values are shown and flagged.
- This is an engineering research project. **No clinical validation has been performed**; nothing here supports diagnosis, treatment, or triage use. Publication readiness must be determined after literature review and additional experiments.
- Grad-CAM results are reported as *saliency/lesion-overlap measurements*, not as lesion localization.

---

## Part 1 — Project identity and core research question

| Field | Value | Source |
|---|---|---|
| Name | DrishtiCare | `README.md:1` |
| Problem statement | SIH 26038 | `README.md:3` |
| Sponsor | MathWorks | `README.md:3` |
| Competition stage | National screening round, 2026 (Smart India Hackathon 2026; finale Dec 2026) | `README.md:3`, `docs/background/sih-logistics.md:7-13` |
| Stack | MATLAB + Simulink (image processing, deep learning, App Designer-style app class, discrete-event simulation) | `README.md`, `docs/ARCHITECTURE.md` |
| Domain | Diabetic retinopathy (DR) retinal-fundus screening for rural healthcare workflows | `README.md:32` |

**Explicitly stated research question:** No single sentence phrased as a research question/hypothesis exists in the repository (grep for "research question", "hypothesis" returns only audit-table references). The functional equivalent is stated in `docs/project-management/ROADMAP.md:19-21` ("DrishtiCare is a MATLAB/Simulink, quality-aware and explainable diabetic-retinopathy screening prototype for rural healthcare workflows") and by the product claim in `docs/project-management/ROADMAP.md:44-46`: the differentiator is *the complete workflow* — refusal behavior, auditability, uncertainty handling, explainability analysis, district-scale simulation — not a new network. The closest thing to a testable claim set is the frozen contract in `docs/project-management/FROZEN_CONTRACT.md`.

**Stated purpose of the repo as a research artifact:** README's "What is measured, and what is not" section (`README.md:44-60`) is an explicit self-audit: measured internally, measured-and-weak, not-performed, excluded-on-evidence.

---

## Part 2 — Central claims and their epistemic status

| # | Claim | Status | Source |
|---|---|---|---|
| C1 | Referable-DR sensitivity 0.9060 / specificity 0.9471 at locked threshold 0.60 | Measured internally, re-verified 21/21 | `docs/validation/metrics.md`; `docs/validation/2026-09-08-task0-reverification-report.md:26-53` |
| C2 | 5-class QWK 0.8914, accuracy 0.8281, macro-F1 0.6805 on n=733 | Measured internally | same |
| C3 | Quality gate runs *before* the classifier; failing images are withheld and the model is never called; over-referral is the intended failure direction | Code-verified contract | `README.md:34-36`; `src/inference/predictSingleFundus.m` |
| C4 | Calibration (T=2.5382) reduces ECE 0.0319→0.0087, display-only; decisions use raw pRef | Measured, firewall-proven | `docs/validation/2026-09-10-hardening-phase8-firewall.md:24,59` |
| C5 | Confidence router concentrates errors outside CLEAR (acc 0.8781 / 0.4667 / 0.3000) | Measured | `docs/validation/2026-09-10-hardening-phase2-router.md:38-46` |
| C6 | Explainability: Grad-CAM produced | Measured; overlap with lesion masks is *weak* (see Part 16) | `data/analysis/gradcam_lesion_alignment/run_log.txt` |
| C7 | District-scale service behavior can be simulated deterministically | Modeled, not validated against real clinic data | `src/simulink/drishti_sim_default_params.m:12-19` |
| C8 | External (clinical-grade) validation | **Not performed** — blocked on Messidor-2 (ADCIS) / Sin-NP DR 2019 licensing | `docs/validation/2026-09-08-task10-external-validation-status.md:81-90` |

---

## Part 3 — System architecture (end-to-end)

Authoritative map: `docs/ARCHITECTURE.md`; executable contract: `src/inference/predictSingleFundus.m` (the single frozen boundary between all callers — CLI demo, GUI, dashboard).

**20-stage trace of `predictSingleFundus.m` (abridged to stage groups; full line-level trace was produced during review):**

1. Input validation / image read.
2. **Quality gate on the raw image, before any model call** — brightness, contrast, focus, foreground fraction, illumination (`src/quality/assessImageQuality.m`, thresholds from `src/quality/defaultQualityConfig.m`). FAIL ⇒ withhold + recapture advice; `SkipModelOnFail` differs by caller: CLI demo passes `false`, GUI passes `true` (`RetinaAIApp.m:916-918`).
3. Preprocess → 224×224 (resize, normalization per training config).
4. OOD advisory: Mahalanobis distance on 512-d pool5 features, threshold p99 = 34.22 (`docs/validation/2026-09-10-hardening-phase9-ood.md:19-33`). **Advisory only — never alters the decision.**
5. 5-class grading (ResNet-18 stage-2) → class probabilities; argmax grade.
6. Binary referral head (separate model) → pRef (raw); referral decision at 0.60 (raw, not calibrated).
7. Temperature-scaled probability (T=2.5382) for **display only**.
8. Lesion/anatomical evidence: OD CNN (locator, with classical fallback and refusal), MA/HE/EX candidate detectors, fovea hook (weak prior), optional vessel features (excluded from production).
9. Branch B (10-feature logistic) cross-check → agreement/conflict signals.
10. Router: CLEAR / REVIEW / ABSTAIN (Part 14).
11. Grad-CAM overlay (GUI, display only).
12. Screening report assembly (quality result, grade, referral, routes, evidence counts, OOD flag, disclaimers).

Full pipeline figure and stage list: `docs/ARCHITECTURE.md`; roadmap flow diagram: `docs/project-management/ROADMAP.md:23-42`.

**Key architectural invariant (frozen):** the quality gate precedes inference; a withheld image never reaches a model. `docs/project-management/FROZEN_CONTRACT.md`.

---

## Part 4 — Frozen model inventory

Frozen champions (`docs/project-management/FROZEN_CONTRACT.md`, hashes verified during review):

| Model | File | SHA-256 |
|---|---|---|
| 5-class grader (champion) | `data/models/day7_pretrained_resnet18_5class_stage2.mat` | `DD152C917689146F6DEC4687B263EC5E5F237ECF60EC719A59F9FCEEFF737C1B` |
| Binary referable (champion) | `data/models/day7_pretrained_resnet18_binary_stage2.mat` | `43E8DF33B429231EE5BD60A775FDB3629AD81F28717AFAA9308EA87D311F9A0` |

- Architecture: ResNet-18, 224×224 input (MATLAB `resnet18`).
- Inventory: 16 primary model files + 47 checkpoint `.mat` files under `data/models/` and `data/analysis/` (counted during review).
- Non-champion artifacts retained for ablation/history: `day8_5class_v2a_stage2` (variant, not promoted), `day6_binary_referable_v1`, `day9_*` raw/enhanced (not promoted), Branch B `ClassificationLinear`, vessel CNN, OD CNN, MA CNN, fovea CNN (`audit/final_project_audit/05_model_metrics.csv`).
- **No ONNX, no exported/deploy format, no `deploy/` directory in this repository** (only `scripts/deploy.ps1` publishing to a Windows share for the app bundle — `scripts/deploy.ps1:1-16`).

---

## Part 5 — Training protocol and hyperparameters

From `src/grading/defaultTrainingConfig.m` and `src/grading/defaultPretrainedConfig.m`:

- **Stage 1:** frozen backbone, head only, LR `1e-3`, batch 32, max 15 epochs.
- **Stage 2:** full unfreeze, LR `1e-5`, batch 16, max 15 epochs.
- Optimizer: Adam; schedule: piecewise ×0.5 every 5 epochs; early-stopping patience 8.
- Seed: split seed **42** (permutation of the 2,929-image training pool for the calibration firewall is also `rng(42)` — `docs/validation/2026-09-10-hardening-phase8-firewall.md:12`).
- Initialization: `config.model.initialization = 'ImageNet'` (`src/grading/defaultPretrainedConfig.m:15`).
- **Known defect:** class weights are *not* wired into `trainNetwork` (documented during review as a training-config bug; balancing is implemented by oversampling to ≤800/class instead — `docs/validation/ablation-study.md:13`).
- Data split: train 2,929 / val 733 from APTOS-2019 train (3,662 images), seed 42 (Part 7).

**Contradiction (claim audit):** several documents describe the champion as "EyePACS-pretrained" (`docs/validation/ablation-study.md:14`, `pitch/deck.html:394`, `pitch/demo-script.md:104`, `audit/final_project_audit/05_model_metrics.csv:5`), but the code sets `initialization='ImageNet'`, the day7 report states ImageNet pretraining, EyePACS data is gitignored and absent (`audit/final_project_audit/01_repository_inventory.csv:17`), and CURRENT_STATUS says EyePACS is not present. **The repository evidence supports ImageNet initialization; the "EyePACS-pretrained" wording is unsupported as written.** See Part 28.

---

## Part 6 — Datasets: inventory and provenance

| Dataset | Role | Present in repo? | Source |
|---|---|---|---|
| APTOS 2019 train | Primary train/val (3,662 PNG; class distro 1805/370/999/193/295) | Images gitignored, stats in repo | `audit/final_project_audit/FINAL_DRISHTICARE_TECHNICAL_AUDIT.md:168` |
| APTOS 2019 test | 1,928 PNG, **no local GT — test set CLOSED** | gitignored | `docs/task-tracker.md:14` |
| IDRiD | Grading + segmentation masks (54 train/27 test, 2848×4288); Grad-CAM lesion masks; detector evals | gitignored | technical audit `:168`; `data/analysis/gradcam_lesion_alignment/README.md` |
| DRIVE | Vessel segmentation (20/20 + 1st/2nd manual masks); rehearsal images | gitignored | technical audit `:168` |
| DRIMDB | Unseen-input rehearsal (9 images); ~216 downloaded, **zero code references** beyond rehearsal | gitignored | technical audit `:168`; `docs/validation/2026-09-26-unseen-input-rehearsal.md` |
| HRF / STARE / CHASE_DB1 / EyePACS | **Directory stubs only / not present** | no | `audit/final_project_audit/02_dataset_inventory.csv:8` |
| Messidor-2 / Sin-NP DR 2019 | Intended external validation; **not obtained** (license/registration) | no | `docs/validation/2026-09-08-task10-external-validation-status.md:81-90` |
| EyeQ | Quality-gate label provenance (docs only) | no images | `docs/licenses/license-inventory.md:26` |

Licensing position: `docs/licenses/license-inventory.md` (research terms, pretraining-only/no-images-in-repo claims). Dataset sources: `docs/references/dataset-sources.md`.

**"Referenced but not used":** EyePACS/HRF/STARE/CHASE (`docs/project-management/CURRENT_STATUS.md:179`), Messidor-2, e-ophtha, DIARETDB1 (appearing only in the license-audit checklist `src/phases/phase19_license_audit.m:26,76`).

---

## Part 7 — Splits, seeds, and leakage analysis

- **Split:** APTOS 3,662 → train 2,929 / val 733, `seed 42`; val referable prevalence 298/733 = 0.4065 (classes 3/4/5). Sources: `docs/validation/metrics.md`; `audit/final_project_audit/06_referable_metrics.csv` (verifies n=298 and notes the "n=313" figure found nowhere is a phantom).
- **Calibration firewall:** train pool 2,929 permuted with `rng(42)`; first 500 = calibration fit, remaining 2,429 = calibration evaluation; disjoint from the 733 val (`docs/validation/2026-09-10-hardening-phase8-firewall.md:24,59`; `src/phases/phase8_firewall_proof.m:73-75,121-122`).
- **Leakage verdict:** no patient IDs exist in APTOS filenames; overlap between calibration/eval/val sets verified = 0 (T0 re-verification). Grad-CAM and detector evaluations use IDRiD (disjoint from APTOS). **Residual risk:** all headline metrics come from a single internal val split of one dataset; no patient-level dedup possible (dataset does not ship patient IDs in the artifacts used) — UNKNOWN whether cross-dataset image duplicates exist (not testable without image data in repo).
- **Test set:** APTOS 1,928 test has no local GT ⇒ accuracy/F1/QWK **not computable**; the set is closed (`docs/task-tracker.md:14`).
- **Seed inventory:** split seed 42; bootstrap seed 2026; temperature fit deterministic (`fminbnd`).

---

## Part 8 — Preprocessing and augmentation

- Resize to 224×224; training augmentation for the champion: rotation ±15°, reflection, translation, shear, oversampling to ≤800/class (`docs/validation/ablation-study.md:14-15`).
- Enhancement path (`enhanceImage()`: CLAHE + denoise) exists but is **display-only by policy** — see Part 18 (enhancement A/B was strongly negative).
- Day-3 quality thresholds derived as percentiles (P1/P5/P95/P99) of brightness/contrast/focus/foreground/illumination over all **3,662 APTOS training images** (`src/quality/computeDay3Thresholds.m`; provenance restated in `docs/validation/2026-09-10-hardening-phase6-decision-lock.md:13`).

---

## Part 9 — Quality gate

- Metrics: brightness, contrast, focus_score, foreground_fraction, illumination_metric (`src/quality/assessImageQuality.m`, `src/quality/defaultQualityConfig.m`).
- Operating points (n=3,662): PASS 65.483% / WARNING 26.679% / FAIL 7.837% — `docs/validation/metrics.md:164`, re-audited `audit/final_project_audit/19_verification_checks.csv` (T13 103-108).
- On val 733: PASS 490 / WARNING 194 / FAIL 49.
- **Question-G null finding:** 5-class accuracy by quality bucket — PASS 0.8122, WARNING 0.8711, FAIL 0.8163: *no degradation* on this split; the gate is kept as a safety control, not an accuracy lever (`docs/validation/2026-09-09-hardening-phase1-quality-gate.md:66-79`).
- On the 19-image unseen rehearsal, quality FAIL rate was 42% (vs 7.84% in-distribution) — the gate fires appropriately on unfamiliar imagery (`docs/validation/2026-09-26-unseen-input-rehearsal.md`).

---

## Part 10 — Out-of-distribution detection

- Method: Mahalanobis distance on 512-d pool5 features; fit on all 3,662 APTOS train+val images; threshold = 99th percentile = **34.22** (`docs/validation/2026-09-10-hardening-phase9-ood.md:19-33`).
- Behavior: real val mean 22.63 (in-distribution); noise 103.42, black 54.03, gray 60.89 (all flagged); in-sample false-OOD 1.01% (`phase9:23-33,47-48`).
- **Policy: advisory only — never alters the decision** (`phase9`; `docs/ARCHITECTURE.md`).
- Rehearsal: OOD fired on 5/19 unseen images (distances 34.5–62.1).
- Limitations stated by the repo itself: single-dataset fit, no external OOD benchmark; canary images are synthetic.

---

## Part 11 — Grading heads: 5-class and binary

**5-class (champion `day7_pretrained_resnet18_5class_stage2.mat`), n=733 val:**

| Metric | Value |
|---|---|
| Accuracy | 0.8281 (0.828104) |
| Macro-F1 | 0.6805 (0.680459) |
| QWK | 0.8914 (0.891401) |
| Per-class recall | [0.9834, 0.6081, 0.7850, 0.4872, 0.5254] |
| Per-class precision | [0.9807, 0.5769, 0.7772, 0.5000, 0.5849] |
| MAE / weighted-F1 | 0.2278 / 0.8274 (vs scratch 0.4000/0.7000) |

Sources: `docs/validation/metrics.md`, `audit/final_project_audit/05_model_metrics.csv:5`, `data/analysis/day7/pretrained_vs_scratch.csv`.

**Binary referable (champion `day7_pretrained_resnet18_binary_stage2.mat`), n=733, threshold 0.60:**

| Metric | Value |
|---|---|
| Sensitivity | 0.9060 (270/298) |
| Specificity | 0.9471 (412/435) |
| Confusion | TP 270 / FP 23 / FN 28 / TN 412 |
| ROC-AUC | 0.9796 (0.979619) |
| PR-AUC | 0.7821 (0.782054) |
| PPV / NPV @0.60 | 0.9215 / 0.9364 (derived) |
| Default 0.50 metrics (different operating point) | acc 0.9345, sens 0.9228, spec 0.9425 (tp275/fp25/fn23/tn410) |

Sources: `audit/final_project_audit/06_referable_metrics.csv` (VERIFIED rows), `docs/validation/2026-09-10-hardening-phase7-metric-freeze.md:41-43`.

Bootstrap 95% CIs (B=1000, seed 2026; `src/verify/bootstrap_cis_T4.m`, `data/analysis/day8/bootstrap_T4.mat`): sens [0.8702, 0.9390], spec [0.9253, 0.9667], acc [0.8001, 0.8540], macro-F1 [0.6353, 0.7231], QWK [0.8660, 0.9146], Severe recall [0.3374, 0.6400], Prolif recall [0.3913, 0.6605].

**Metric definitions are frozen:** `src/phases/phase7_metric_freeze.m:82-84` (macro-F1, QWK formulas), referable = grade ≥ moderate under the frozen contract. Note: a helper script (`src/verify/fill_ablation_T3.m:18-24`) computes a sens/spec under a *different* mapping (grade ≥1) — the published table uses the frozen definition.

**Not computed:** per-grade confusion counts beyond recall/precision are available via `confusionmat` in audit scripts; the full 5×5 matrix values are stored in `reverify_audit_T0.mat` and quoted per-grade in `FINAL_DRISHTICARE_INTERVIEW_GUIDE.md:72-73` — the matrix cell-by-cell table is **UNKNOWN in text form** (artifact-only).

---

## Part 12 — Threshold selection and robustness

- **Origin of 0.60:** Day-6 threshold sweep rule `find(thrSens>=0.90,1,'last')` on `day6_binary_referable_v1_metrics.mat`; locked by Phase-6 decision lock (`docs/validation/2026-09-10-hardening-phase6-decision-lock.md:13`).
- **Robustness (Phase 21 sweep, t = 0.55–0.65):** sens 0.8960–0.9128, spec 0.9448–0.9494, PPV 0.8936–0.9297, F1 0.9097–0.9158, referrals 289–296; t=0.60 reproduces the frozen values → **not knife-edge** (`docs/validation/2026-09-10-hardening-phase21-threshold-robustness.md:11-29`).
- Calibration never moves the decision threshold: decisions use raw pRef (Part 13).

---

## Part 13 — Calibration

Two protocols exist; both documented:

| Protocol | Fit set | T | ECE before→after | NLL | Flips |
|---|---|---|---|---|---|
| Firewalled (promoted) | 500 train images (`rng(42)`), eval on disjoint 2,429 | **2.53818939 (2.5382)** | 0.0319→0.0087 (0.0087196) | 0.1998→0.1243 | 18/2429 = 0.0074105 |
| Standard (confirmatory) | train, evaluated on val 733 | 2.67224388 | 0.0450→0.0297 (0.029653) | 0.2899→0.1767 | 12/733 = 0.016371 (T=2.6722); 11/733 = 1.50% (T=2.5382) |

- Fit method: `T = argmin NLL(sigmoid(z/T), y)` over T∈[0.1,8] via `fminbnd` (`docs/validation/2026-09-10-hardening-phase3-calibration.md:23`).
- `T_eval = 2.69843831` (fit on the eval split) is an upper bound, **never promoted** (`phase8_firewall_proof.json:1`).
- **Policy: temperature-scaled outputs are display-only; referral decisions use RAW pRef at 0.60** (frozen contract; `phase8:59`).
- 5-class temperature was never fitted; top-1 ECE on val = 0.1255 (overconfidence), per-class ECE 0.0168–0.0925 (`docs/validation/2026-09-08-task5-calibration.md:76-101`).
- Flip audit (RF-4): 11 flip cases hand-audited — 3 correct, 8 errors ⇒ calibration flips were net-negative in absolute terms but the calibration itself was retained for display (`docs/task-tracker.md:39`).
- Logit-clip divergence (Phase 3): 278 pRef==1.0 cases clipped to z=±40; pre-clip bug would have given T 2.3867 vs 2.5382 — fixed, reproduces to 5e-5 (`phase3-calibration.md:28-41`).

**Three distinct "flip fractions" exist and are not in conflict:** 18/2429 (firewalled), 12/733 (standard T=2.6722), 11/733 (val with T=2.5382).

---

## Part 14 — Decision routing (CLEAR / REVIEW / ABSTAIN)

Rules (frozen; `docs/validation/2026-09-10-hardening-phase2-router.md`):

- **ABSTAIN:** confidence < 0.50, or |pRef − 0.60| < 0.05.
- **REVIEW:** confidence < 0.75, or top-2 margin < 0.20, or screen/grade conflict (screening binary vs 5-class grade disagree).
- **CLEAR:** otherwise.

Results on val 733:

| Route | n | share | 5-class accuracy |
|---|---|---|---|
| CLEAR | 648 | 88.4% | 0.8781 |
| REVIEW | 75 | 10.2% | 0.4667 |
| ABSTAIN | 10 | 1.4% | 0.3000 |

True-referable fraction by route: 0.355 / 0.800 / 0.800. Router synthetic edge cases: `src/phases/phase2_cascade_router_audit.m:47-52`. Parameter trade-off note: `marginThr=0.20`, `reviewConf=0.75`, `abstainConf=0.50` trade auto-rate for risk (`phase5-errors.md:66`).

---

## Part 15 — Lesion and anatomical detectors

| Component | Headline | Verdict / use | Source |
|---|---|---|---|
| OD CNN (locator) | patch AUC **0.9955**, acc 0.9958 (409 held-out); IDRiD 10/10 located, 9/10 within 300 px (prose-only); APTOS val acceptance 78/733 = 10.64%, refused 655; classical fallback ~44% (n=50), combined ~50% | **Deployed with refusal + classical fallback** | `data/analysis/day8/od_cnn/od_cnn_metrics.mat`; `od_discrepancy_investigation.mat`; `docs/task-tracker.md:21,36` |
| MA CNN | patch AUC 0.976 (0.9755); **detection recall 0.113, precision 0.595 @0.9** (tol 12 px) | LOW-RECALL cue only; never used for grade | `docs/validation/metrics.md:82`; `layout-and-lesion-audit.md:178-180` |
| Classical lesion GT check | MA recall 0.0023/prec 0.0029; HE 0.3329/0.1118; EX 0.0737/0.1600 (n=10 IDRiD, tol 20 px) | Counts = candidates only | `audit/.../FINAL_DRISHTICARE_TECHNICAL_AUDIT.md:228` |
| Fovea CNN | patch AUC 0.7487, acc 0.6479, **0/10 within 300 px** (mean err ~620 px); disc-relative 0/10 | Honest negative — closed; `foveaSupplied` hook only | `docs/validation/2026-09-08-task11-fovea-closure.md:16-21` |
| Vessel CNN | Dice **0.2576** vs 1st manual (human inter-observer Dice 0.7881), IoU 0.1481, pxAUC 0.6110 (20 DRIVE test) | Unfit — excluded from production | `docs/task-tracker.md`; `metric-provenance-resolution.md:44-49` |
| Classical vessel pipelines | 64 dev experiments; phase-1 test Dice 0.7428; session champion 0.7535; phase-3 locked test 0.7438 (champion preset 0.7549) | Prototype only, not wired; test-tuning limitation disclosed | `docs/vessel-segmentation.md:12-43,63-79`; `data/analysis/vessel/phase3/metrics.txt:15-47` |
| RF-7 latent bug | scalar-capture reshape bug in 4-output OD locator fixed; post-fix counts verified | Fixed | `docs/task-tracker.md:42` |

---

## Part 16 — Explainability (Grad-CAM) — measured, weak

This section deliberately avoids the phrase "lesion localization". What was measured is the **overlap between class-discriminative saliency and expert lesion masks**.

Protocol: Grad-CAM at `res5b_relu`, top-20%-pixel cumulative attention, vs IDRiD MA/HE/EX/SE masks, n=81 (54 train + 27 test of IDRiD), champion SHA `DD152C91…7C1B`, **0 evaluation errors** (`data/analysis/gradcam_lesion_alignment/run_log.txt:1195-1215`).

| Measure | Value | Reference |
|---|---|---|
| Saliency mass in any lesion | **0.0307 (3.07%)** | areal chance 0.0220 → **1.39×** |
| Pointing (max-saliency pixel in lesion) | 0.074 | annotator-chance 0.20 → **0.37× (below chance)** |
| IoU / Dice | 0.035 / 0.051 | — |
| Per-type mass | MA 0.0013, HE 0.0126, EX 0.0145, SE 0.0049 (n=40) | ×chance 1.24 / 1.23 / 1.61 / 1.30 |
| Retina-disk confound | 78% of saliency mass on the retina disk; only 3.8% of on-retina mass on any lesion | `docs/validation/2026-09-08-task6-gradcam.md:36-38` |
| Proxy split | correct n=72: 3.4% mass / 8.3% pointing / IoU 0.039; incorrect n=9: 0.3% / 0.0% / 0.002; proxy confusion TP72/FN9/FP0/TN0 | `run_log.txt:1208-1211` |
| Runtime / rendering | 97.5 s full run; rendering audit PASS 9/9 (norm [0,1], bicubic range ±0.003, colormap deviation 0, α recovery) | `docs/validation/2026-09-30-gradcam-rendering-audit.md:31-146` |

**Honest conclusion stated by the repo itself:** saliency is weakly above areal chance, below annotator chance for pointing, and heavily confounded by the optic disc/retina background. **Grad-CAM here is a visualization, not evidence of lesion finding.**

---

## Part 17 — Branch B and fusion

- Branch B: 10-feature lesion/OD feature logistic model (`ClassificationLinear`), AUC **0.8969**, sens 0.6913 / spec 0.9126 @0.60, agreement with Branch A 0.8295; deployed **as cross-check only** (`docs/validation/2026-09-08-task7-branchb-fullval.md:30-66`).
- Correlations: corr(pRefB, grade)=0.707; corr(pRefB, PRef)=0.741 (`task7:52`).
- Fusion (inference-time): 598 agree (81.6%) / 135 review (18.4%) on val (`audit/.../18_hypotheses_ablation.csv` row 6).
- λ sweep (RF-5): best λ=3e-2 gives AUC 0.9054 (+0.0085) but match 0.8172 (−0.012) → **not promoted** (`docs/task-tracker.md:40`).
- Pilot (pre-T7): 250-image model, eval AUC 0.858, match 0.760 — superseded (`task-tracker.md:27`).
- Vessel features added to Branch B: AUC 0.8810, Δ −0.0159, bootstrap CI [−0.0312, −0.0004], P(diff>0)=0.022 → **excluded** (Part 18, Part 20).

---

## Part 18 — Negative results and excluded components

The repository records negatives explicitly (a strength of the evidence chain):

| Component | Change vs baseline | Result | Decision | Source |
|---|---|---|---|---|
| Image enhancement (T9B) | CLAHE+denoise before resize | acc 0.8322→**0.5416**, macroF1 0.6828→0.4039, QWK 0.8952→**0.6507**; inference 78.9 s→781.2 s (~10×); NoDR recall 0.9806→0.7452 | **Excluded — display-only** | `docs/validation/2026-09-08-task9b-enhancement-ab.md:37-63`; artifact `data/analysis/day9/task9b_ab_eval.mat` |
| Cross-condition mismatch | netRaw on enhanced input | acc 0.4925, QWK 0.0000 (all-NoDR collapse) | Models are input-conditioned | `task9b:58-63` |
| Vessel features in Branch B | +8 vessel features (18 total) | AUC 0.8969→0.8810 (Δ −0.0159) | **Excluded** | `docs/validation/2026-09-08-task8-vessel-segmentation.md:155-247` |
| Vessel CNN | small patch CNN | Dice 0.2576 vs human 0.7881 | **Excluded** | `task8:64-79` |
| Fovea localization | CNN + disc-relative | 0/10 within 300 px | **Closed honest negative** | `task11:16-38` |
| Balanced oversampling alone (day6) | scratch + balance | QWK 0.7672→0.6887 (−0.079); sens/spec 0.8020/0.8966 | Negative without pretraining | `docs/validation/ablation-study.md:13` |
| Corrected class weighting (day8 v2a) | 800/800/800/1000/1000 | Severe/Prolif recall unchanged (0.4872/0.5254); QWK 0.8914→0.8877 | **Negative on target classes; champion retained** | `docs/task-tracker.md:15,117-128` |
| Ensemble (day7+day8, w-sweep) | score mix | best QWK 0.8933 (w 0.3/0.7) vs 0.8914 | Not promoted | `task-tracker.md:38` |
| TTA (h-flip + rot ±5°) | inference-time | acc 0.8281→0.8336, QWK 0.8914→0.8965, **Severe recall −2.56 pts** | Not promoted | `ablation-study.md:48-49` |
| Quality gate as accuracy lever | bucket comparison | PASS 0.8122 / WARN 0.8711 / FAIL 0.8163 — no degradation | **Null finding**; gate kept for safety | `phase1-quality-gate.md:66-79` |
| Grad-CAM lesion overlap | vs chance baselines | 1.39× areal chance, pointing 0.37× annotator chance | Weak; visualization only | Part 16 |
| Day-6 bug era | label-mismatch bug | acc 49.25%, QWK 0.0000 | Bug, not a result | `docs/day6-training-results.md:36-40` |

**PR-AUC trade-off (diagnostic-only finding):** scratch→pretrained binary improved ROC-AUC 0.9496→0.9796 and spec@0.60 0.8575→0.9471, but PR-AUC **0.9070→0.7821** fell (`data/analysis/day7/pr_auc_investigation.mat`; `docs/task-tracker.md:13`). This is recorded as an investigation, not an error.

---

## Part 19 — Ablation table (centerpiece)

All rows on APTOS n=733 val, frozen metric definitions (`phase7-metric-freeze.m`). Full row-by-row provenance: `docs/validation/ablation-study.md` + `audit/final_project_audit/18_hypotheses_ablation.csv`.

| # | Experiment | Sens | Spec | QWK | Verdict |
|---|---|---|---|---|---|
| 1 | Scratch 5-class, no balance (day5) | 0.8322 | 0.9080 | 0.7672 | Baseline (acc 0.7367, mF1 0.5083) |
| 2 | Scratch + class balancing (day6) | 0.8020 | 0.8966 | 0.6887 | **Negative** — balancing alone hurts |
| 3 | Pretrained + balancing (day7) — **CHAMPION** | **0.9060** | **0.9471** | **0.8914** | **Adopted, frozen** |
| 4 | Corrected class weighting (day8 v2a) | — | — | 0.8877 | Negative on target classes; not promoted |
| 5 | Branch B feature model | 0.6913 | 0.9126 | — (AUC 0.8969) | Cross-check only |
| 6 | Vessel features | — | — | — (AUC 0.8810) | Excluded |
| 7 | Enhancement A/B | 0.5416 acc arm | — | 0.6507 | Excluded (display-only) |
| 8 | TTA | — | — | 0.8965 | Not promoted |
| 9 | Ensemble w=0.3/0.7 | — | — | 0.8933 | Not promoted |
| 10 | Quality gating | not measured on 733 as an accuracy lever | — | — | Honest unmeasured (safety control) |

Derived: pretraining ablation (row 3 − row 1) = QWK **+0.124** (arithmetic, verified); vs row 2 = +0.2027. Day5→day7 per-class recall gains: 0.4459→0.6081 (Mild), 0.6850→0.7850 (Moderate), 0.1795→0.4872 (Severe), 0.2203→0.5254 (Prolif) (`pretrained_vs_scratch.csv:2-3`).

**Significance:** only two bootstrap procedures exist (Part 20); the ablation table itself carries **no** statistical tests between rows.

---

## Part 20 — Statistical testing inventory

**Present:**

1. **Bootstrap percentile CIs** (B=1000, seed 2026, n=733) for sens/spec/acc/macro-F1/QWK/per-class Severe+Prolif recall — `src/verify/bootstrap_cis_T4.m:24-25,77`; `data/analysis/day8/bootstrap_T4.mat` (exact values in Part 11).
2. **Bootstrap AUC-difference test** (B=500): vessel vs base ΔAUC −0.0159, CI [−0.0312, −0.0004], P(diff>0)=0.022 — `src/eval_vessel_T8.m` per `task8:158,209`; restated `FINAL_DRISHTICARE_TECHNICAL_AUDIT.md:213`.
3. **Temperature fit** by NLL minimization (`fminbnd`) — Part 13.
4. **ECE (10 equal-width bins)/Brier/NLL** definitions locked — `src/calibration/calibrationStats.m`.
5. **Areal-chance baselines** for Grad-CAM (geometry-derived, not inferential) — `gradcam_lesion_alignment/README.md:58-60`.
6. **Pearson correlations** — Branch B (0.707/0.741), vessel features (−0.206..+0.085).

**Absent (repo-wide grep, 0 hits):** McNemar, DeLong, permutation tests, Wilcoxon, t-tests, Fisher exact. (The only "permutation" hit is the `rng(42)` train-index shuffle for the split.)

⇒ **All significance claims in this project rest on two bootstrap procedures.** Pairwise model comparisons in the ablation table are descriptive only.

---

## Part 21 — Error analysis

From `docs/validation/2026-09-10-hardening-phase5-errors.md:16-61` (n=733):

- 607 correct / 126 errors; 92 adjacent-grade (±1) vs 34 far (≥2).
- Far-error tail: 18/34 originate from Proliferative (misread rate 0.4746); Severe misread 0.5128.
- Binary FP 23 / FN 28.
- By route: CLEAR 79 errors (0.1219), REVIEW 40 (0.1719→rate shown as 0.4667 acc), ABSTAIN 7.
- **Confidence disciplining:** error rate by argmax-confidence band — ≥0.75: 0.1409; 0.50–0.75: 0.5179; <0.50: 0.6667 (monotone; confidence tracks error likelihood).
- Quality-intersection: FAIL-quality FP 0.0408 / FN 0.0612 vs PASS 0.0286 / 0.0367.
- BN-finalization note: in-loop val acc 70.5% vs proper-inference 82.81% (`FINAL_DRISHTICARE_INTERVIEW_GUIDE.md:81`).

**Confidence distribution:** no published histogram/table of p̂ exists; the band-wise error rates above are the closest recorded summary (script comment `src/phases/phase5_error_analysis.m:17`). A full distribution is **UNKNOWN** (artifact-only in `phase5` results .mat).

---

## Part 22 — Unseen-input rehearsal

`docs/validation/2026-09-26-unseen-input-rehearsal.md` (n=19: DRIVE 5, IDRiD-B 5, DRIMDB 9):

- 19/19 completed; **8 FAIL quality → withheld**; routes C8 / R11 / A0; OOD fired on 5 (34.5–62.1); quality FAIL rate 42% vs 7.84% in-distribution; median latency 1.81 s (IDRiD up to 35.6 s).
- **New negative:** DRIMDB ungradable case (`DRIMDB-Bad-10`) graded **4 (Severe), pRef 0.9690, routed CLEAR/REFERABLE** — a confident wrong referral on an ungradable image (`rehearsal.md:94-105`).
- IDRiD lesion-candidate over-firing (HE=85, EX=53) on individual images (`rehearsal.md:124-129`).
- Contract-level conclusion: pipeline holds (withholding works), but calibration of confidence on truly unseen distributions does not.

---

## Part 23 — Simulink service simulation

- Model: deterministic FIFO single-server discrete-event simulation, 250 daily steps (`docs/ARCHITECTURE.md`; `src/simulink/`).
- Parameters (`src/simulink/drishti_sim_default_params.m:12-19`): patientsPerDay 400, qUsable 0.9216, qFail 0.0784, recapture 0.50, prevalence 0.4065, sens 0.9060, spec 0.9471, specialist capacity 60/day.
  - Note: qUsable/qFail (0.9216/0.0784) come from the *unseen* rehearsal-style quality accounting, while the in-repo quality FAIL rate on 3,662 APTOS is 7.837% — the parameter provenance should be confirmed before citing either (`phase1-quality-gate.md` vs sim params).
- Scenario study (P15): 600/1200/2400 images/day — 600/day stable (453 auto-clear, 149 flagged, zero backlog, 3 specialists @60/day); 4× volume unstable (`docs/task-tracker.md:79`).
- Inputs are the *measured* router fractions from Part 14; the simulation is an engineering capacity model. **No validation against real clinic throughput data — UNKNOWN.**

---

## Part 24 — Performance envelope

`docs/validation/2026-09-10-hardening-phase23-performance-envelope.md:6-19`:

- **Model-only:** 0.1028 s/image ≈ 9.73 img/s (pure model path — must not be conflated with the full path).
- **Full demo path (n=10):** median 11.03 s, mean 15.16 s (skew 1.37).
- **Memory:** +2.63 GB upper bound.
- Unseen rehearsal latency: median 1.81 s, IDRiD worst 35.6 s (large originals).
- Two labelled operating points are kept separate deliberately (phase23 audit check).

---

## Part 25 — Deployment and runtime surface

- **No container/server deployment in this repo.** Runtime = desktop MATLAB: `launchRetinaAI.m` → `RetinaAIApp` (app class at repo root, `matlab.apps.AppBase`, ~1430 lines) → `predictSingleFundus`.
- Optional share publishing: `scripts/deploy.ps1` (Windows share copy of the app bundle; `scripts/deploy.ps1:1-16`).
- Historical Python/dash app exists in the *other* working repository (`C:\projects\Drishti`), not here.
- Dashboard: `src/dashboard/load_dashboard_data.m` + `verify_app_layout.m` (layout gate; currently uncommitted changes — see Part 31).
- Environment pinning: `src/phases/phase18_environment_pin.m` (MATLAB release/toolbox capture).

---

## Part 26 — Reproducibility and determinism

- **Determinism audit (P22):** 3/3 bit-identical reruns; RNG state unchanged after full inference; limitation disclosed (regex scan first-match-only, 13→12 function names after `quality_gate.m` deletion) — `docs/validation/2026-09-10-hardening-phase22-determinism.md:6-43`.
- **Re-verification:** T0 fresh re-inference PASS 21/21 (all headlines reproduce to 6 dp; confusion 270/23/28/412; overlap=0) — `docs/validation/2026-09-08-task0-reverification-report.md:26-53`. T13 artifact-only re-audit PASS 63/63 — `2026-09-09-task13-final-re-audit.md:5`.
- **Locked-file inventory:** `data/analysis/audit_locked_files.sha256`; frozen hashes in FROZEN_CONTRACT (Part 4).
- **Phase audits:** phases 1–23 + S1/S9/S10 series, all recorded with pass counts in `docs/task-tracker.md:56-98`.
- **Known reproducibility gaps:** datasets are gitignored (not distributable from repo); MATLAB + specific toolboxes required (no environment spec for headless CI — CI status **UNKNOWN**); no test framework/CI config found in this repo.
- Manifest defect noted by P25: `baseline_manifest.md` lists `day8_5class_v2a_stage1.mat`, which does not exist (only `_stage2.mat`) — `src/phases/phase25_final_capstone.m:67`.

---

## Part 27 — Evidence chain and experiment tracking

- Central tracker: `docs/task-tracker.md` (every task/phase with verdict).
- Validation reports: `docs/validation/*.md` (one per phase/task, dated).
- Audit outputs: `audit/final_project_audit/` — 20 CSV inventories (repo/dataset/code/artifact/model/referral/calibration/quality/enhancement/vessel/lesion/explainability/ensemble-TTA/OOD/test/fusion/dashboard/ablation/verification/final truth table) + technical audit, interview guide, `baseline_manifest.{json,md}`.
- Metric provenance resolution: `docs/validation/2026-09-26-metric-provenance-resolution.md` (3 disputed values adjudicated against artifacts; no headline changes).
- **No MLflow/W&B/DVC/Comet** — experiment tracking is filesystem + markdown (grep verified). No automated test harness beyond `src/runs/runSmokeTest` and phase scripts.

---

## Part 28 — Claim audit: misleading or unsupported statements

Reviewer-facing list (all verified during this review):

1. **"EyePACS-pretrained" champion** — repeated in `docs/validation/ablation-study.md:14,41`, `pitch/deck.html:394,778`, `pitch/demo-script.md:104`, `pitch/build_deck_pptx.py`, `audit/.../05_model_metrics.csv:5`. Code says `initialization='ImageNet'` (`src/grading/defaultPretrainedConfig.m:15`); no EyePACS data in repo. **Unsupported as written; evidence supports ImageNet init.** (Also makes "pretraining ablation (+EyePACS)" wording misleading — the ablation is pretraining-vs-scratch.)
2. **OD patch AUC 0.993** (docs) vs artifact `od_cnn_metrics.mat` = **0.9955**; cited artifact `od_discrepancy_investigation.mat` has no AUC field. Minor doc/artifact mismatch.
3. **"9/10 within 300 px" (OD)** is prose-only; artifact records 10/10 *located*, no distance field.
4. **T_eval transcription**: "2.6979" in `phase8-firewall.md:24` and `task-tracker.md:63` vs canonical **2.69843831** (`phase8_firewall_proof.json:1`).
5. **`fill_ablation_T3.m` sens/spec definition** (grade ≥1) differs from the published table's frozen definition (grade ≥2) — script output would not reproduce table rows.
6. **"n=313 positives"** — phantom; true val referable n=298 (`06_referable_metrics.csv`).
7. **day5 sens/spec dual derivation**: 0.8322/0.9080 (authoritative, artifact-matched) vs 0.8307/0.8667 (pre-freeze) — resolved in `metric-provenance-resolution.md:110-115`.
8. **`legacy "spec 0.919"`** doc claim — not found anywhere in repo (resolved: no conflict).
9. **Repo self-label:** README correctly states no clinical validation and no external validation — the repo is *honest at the top level*; the issues above are localized in pitch/ablation wording.

**Not claimed anywhere (good):** the repo does not claim to beat specialist performance, does not claim FDA/CE-style clearance, and does not claim lesion-level diagnostic accuracy.

---

## Part 29 — External validation status

- Harness self-test (P14): a label-mapping bug (referable = Yt≥2 instead of ≥3) gave sens 0.788/spec 1.000; corrected mapping reproduces 0.9060/0.9471/AUC 0.9796 — harness ready (`docs/task-tracker.md:69`).
- **Real external data never touched:** Messidor-2 requires ADCIS registration; Sin-NP DR 2019 requires a data request (`docs/validation/2026-09-08-task10-external-validation-status.md:81-90`). Explicit prohibition on substituting another dataset for Messidor-2 (`task10:90`).
- Cross-dataset *behavioral* evidence exists only for: IDRiD/DRIVE/DRIMDB rehearsal (n=19, Part 22) and detector/Grad-CAM evals on IDRiD (n=81/10).
- ⇒ **External validation of the grading performance: NOT PERFORMED.**

---

## Part 30 — Clinical validation and publication readiness

- **Clinical validation: none.** The repo states this in README, FINAL_RELEASE_STATUS, and every pitch disclaimer: outputs are engineering demonstrations and must not be used for diagnosis, treatment, triage, or any patient-facing decision (`README.md:38-46`).
- No ophthalmologist graders, no reader study, no prospective data, no IRB/ethics approval mentioned anywhere — **UNKNOWN/absent from repo**.
- Class performance caveats relevant to any clinical reading: Severe recall 0.4872 and Prolif recall 0.5254 with wide bootstrap CIs (Part 11); far-grade errors concentrated on Proliferative (Part 21); confident wrong referral on an ungradable image (Part 22).
- **Publication readiness must be determined after literature review and additional experiments** — no literature-review artifact, related-work baseline comparison table, or submission draft exists in this repository (docs/background/ contains dataset/literature-verification notes only: `docs/background/literature-verification.md`).

---

## Part 31 — Known defects, limitations, risk register

| # | Item | Severity | Source |
|---|---|---|---|
| L1 | Class weights not wired into `trainNetwork` (training-config bug) | Medium (training fidelity) | review of `defaultTrainingConfig` |
| L2 | `SkipModelOnFail` differs between CLI demo (false) and GUI (true) — two callers behave differently on quality FAIL | Medium (contract consistency) | `RetinaAIApp.m:916-918` |
| L3 | Confident CLEAR referral on ungradable DRIMDB image | High (safety-relevant behavior) | `2026-09-26-unseen-input-rehearsal.md:94-105` |
| L4 | Grad-CAM overlap weak; disc-confounded (Part 16) | Medium (explainability claim) | `run_log.txt` |
| L5 | MA recall 0.113; lesion counts are candidates only | Medium | `metrics.md:82` |
| L6 | Single internal val split; no external validation (Part 29) | High (generalization) | task10 |
| L7 | No statistical tests beyond two bootstraps (Part 20) | Medium (inference strength) | grep audit |
| L8 | Uncommitted UI changes: `RetinaAIApp.m`, `src/dashboard/verify_app_layout.m` (pre-existing dirty state, layout-grid work, 123 insertions/59 deletions) | Low (process) | `git status` |
| L9 | `main` ahead of `origin/main` by 5 commits at dossier time (`d59e2ba`…) | Low (process) | `git log` |
| L10 | `baseline_manifest.md` references non-existent `day8_5class_v2a_stage1.mat` | Low | `phase25_final_capstone.m:67` |
| L11 | Day-6 historical rows in docs use pre-frozen metric definitions (superseded, banner present) | Low | `day6-training-results.md` |
| L12 | Test set (1,928) has no GT locally — headline metrics exist only for the 733 val | Medium | `task-tracker.md:14` |
| L13 | Datasets gitignored — third parties cannot reproduce from repo alone | Medium (reproducibility) | `.gitignore:9` |
| L14 | Quality-gate null finding on val (Part 9) — gate unproven as accuracy control | Low (disclosed) | `phase1-quality-gate.md:66-79` |

---

## Part 32 — UNKNOWN register (explicit data gaps)

Items a reviewer will look for and will **not** find in this repository:

1. Full 5×5 confusion matrix as a text/table (artifact-only: `reverify_audit_T0.mat`; per-class prec/rec in `INTERVIEW_GUIDE.md:72-73`).
2. Confidence (p̂) distribution histogram/table — only band-wise error rates exist (Part 21).
3. CI status (GitHub Actions/Jenkins etc.) — none found.
4. Unit-test framework / coverage numbers — none (only smoke tests + phase audits).
5. External-validation metrics — none (Part 29).
6. Reader-study / clinician agreement / ethics approval — none.
7. Hyperparameter search logs (LR/batch/epoch sweeps) — only the two-stage recipe is documented; no sweep artifacts identified.
8. Cross-dataset duplicate/image-hash analysis — not performed.
9. Simulink model validated against real clinic throughput — not performed.
10. License text for APTOS/IDRiD/DRIVE as actually accepted (inventory table exists; receipts/registration records absent).
11. Model-export (ONNX etc.) and serving benchmarks — absent by scope.
12. Per-patient identifiers/dedup — dataset does not expose them in-repo.
13. `qUsable 0.9216 / qFail 0.0784` sim-parameter provenance — not traced to a named measurement (Part 23).

---

## Part 33 — Recommended next research steps

Ordered by expected information gain, given the current evidence chain:

1. **External validation** on Messidor-2 (after ADCIS registration) or another genuinely untouched dataset using the frozen harness — the single largest gap (Part 29).
2. **Statistical comparison machinery**: add paired McNemar/DeLong/permutation tests for future model comparisons; today's ablation deltas are descriptive (Part 20).
3. **Ungradable-image handling**: the DRIMDB confident-referral failure (Part 22/L3) motivates an explicit "ungradable/abstain" class or a quality-model ensembles before any deployment claim.
4. **Class-4/5 recall**: Severe 0.4872 / Prolif 0.5254 with wide CIs — targeted data or calibration of those grades.
5. **Claim cleanup**: fix "EyePACS-pretrained" wording across pitch/ablation/audit CSV (Part 28, item 1); align OD AUC doc value with artifact.
6. **Explainability honesty**: present Grad-CAM as visualization with the measured 1.39× areal-chance overlap and 0.37× pointing, or invest in a localization-capable method if lesion-level claims are wanted.
7. **Reproducibility packaging**: publish dataset acquisition scripts + environment pin so the 733-val metrics are reproducible by third parties (currently blocked by gitignored data).
8. **Confidence distribution artifact**: publish the p̂ histogram and reliability diagram as first-class evidence (currently UNKNOWN).

---

*End of dossier. Companion machine-readable facts: `DRISHTICARE_RESEARCH_FACTS.json`. Reviewer entry point: `CLAUDE_RESEARCH_HANDOFF.md`.*
