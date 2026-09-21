# Failure-Aware Screening Demo — DrishtiCare

**ENGINEERING DEMO — NOT a clinical device. Not clinically validated.**
Quality thresholds are prototype values (config v2.0.0, derived from 3,662
APTOS images). This is not a diagnosis and does not replace a clinician.

This folder is the self-contained deliverable for the failure-aware,
quality-aware screening demonstration: a real-image case set, an auditable
run, automated sanity tests, and presentation visuals.

---

## 1. What this demo proves

DrishtiCare does **not** blindly produce an AI prediction for every retinal
image. The pipeline is **quality-first**:

```
IMAGE
  -> QUALITY CHECK  (existing Day-3 module: assessImageQuality)
       PASS / WARNING  -> AI screening -> DR grade -> referral -> evidence
       FAIL            -> STOP. The AI stage is NOT executed at all.
                          reason + metric + threshold are reported;
                          recapture / manual review is advised.
```

Demonstrated facts from the committed run:

- 6 real FAIL images reached **zero** AI executions
  (`inference_executed = false`, not merely a suppressed display).
- 3 real PASS/WARNING images ran the full AI pipeline
  (`predictSingleFundus`, `SkipModelOnFail=true`) and produced grades.
- Model SHA-256 unchanged before/after the run (no retraining, no weight edits).
- 11/11 automated checks pass.

The heavy inference entry point (`src/inference/predictSingleFundus.m`) also
carries its own `SkipModelOnFail` guard as **defence in depth**; that guard is
verified live by TEST 11 in addition to the harness-level short circuit.

---

## 2. How to run it

MATLAB R2026a (not on PATH on this machine):

```powershell
# 1. pick real cases from the held-out split (scans 733 images; cached)
& "C:\Program Files\MATLAB\R2026a\bin\matlab.exe" -batch "addpath('src\demo'); select_demo_cases('Rescan',true)"

# 2. run the failure-aware demo (quality-first; FAIL skips inference)
& "C:\Program Files\MATLAB\R2026a\bin\matlab.exe" -batch "addpath('src\demo'); run_failure_aware_demo()"

# 3. run the sanity contract (11 checks; non-zero exit on failure)
& "C:\Program Files\MATLAB\R2026a\bin\matlab.exe" -batch "addpath('src\demo\tests'); test_failure_aware_demo"
```

The interactive experience (unchanged behaviour) is the existing App Designer
app: `launchRetinaAI.m` → `RetinaAIApp.m`. For a FAIL image it already shows
"REVIEW BY HEALTHCARE PROFESSIONAL" and, after this change, an explicit
`AI GRADING: SKIPPED` line with per-metric threshold detail.

### Code map

| Path | Role |
|---|---|
| `src/demo/select_demo_cases.m` | Scans `data/splits/val`, selects real representative cases |
| `src/demo/run_failure_aware_demo.m` | Quality-first driver, audit log, results, figures, report |
| `src/demo/render_comparison_figure.m` | Good-vs-poor left/right visual |
| `src/demo/render_workflow_figure.m` | Pipeline / hard-gate diagram |
| `src/demo/render_scan_summary_figure.m` | Val split quality split + FAIL reasons |
| `src/demo/tests/test_failure_aware_demo.m` | TEST 1–11 sanity contract |
| `src/quality/quality_failure_detail.m` | Reusable "which threshold was missed" helper (display/audit only) |

No existing function was replaced; `predictSingleFundus`, the quality module
and the models are used as-is.

---

## 3. Case set used

Source: the project's held-out validation split `data/splits/val/class_{0..4}`
(733 real APTOS-train images; counts 361 / 74 / 200 / 39 / 59). The **official
APTOS test set is never touched** (TEST 9 proves the harness source cannot
reference it).

Scan of all 733 images with the Day-3 quality module:

| Overall | count | share |
|---|---|---|
| PASS | 490 | 66.8% |
| WARNING | 194 | 26.5% |
| FAIL | 49 | 6.7% |

Per-check FAIL counts: focus 9, brightness 13, contrast 15, foreground 12,
illumination 11, mask-validity 0.

Selected cases (`demo_cases.csv`) — real images, **no synthetic degradation**:

| id | role | expected | image |
|---|---|---|---|
| case_pass_referable | PASS, true referable grade | PASS | `class_2/77f69c7ff324.png` |
| case_pass_nodr | PASS, true no-DR | PASS | `class_0/a7673ac44509.png` |
| case_warning | WARNING (illumination flag) | WARNING | `class_0/cffc50047828.png` |
| case_fail_blur | focus FAIL | FAIL | `class_1/cae51154e1ce.png` |
| case_fail_dark | underexposed | FAIL | `class_0/d91635f380b4.png` |
| case_fail_bright | overexposed | FAIL | `class_2/4ed31cc07366.png` |
| case_fail_illumination | illumination FAIL | FAIL | `class_3/913490237ad4.png` |
| case_fail_fov | foreground FAIL | FAIL | `class_0/ccd6dcb2f568.png` |
| case_fail_contrast | contrast FAIL | FAIL | `class_2/e65a2ff90494.png` |
| case_fail_mask | mask-validity FAIL | FAIL | **unavailable — see §7.5** |

Selection is deterministic (filenames sorted, fixed rules) and recorded in
`demo_cases.csv`; the full scan is in `quality_scan.csv`.

---

## 4. Where the quality gate stops inference

In `run_failure_aware_demo.m` the decision is made **before** the AI call:

```matlab
isFail = strcmp(qres.overall, 'FAIL');
if isFail
    % quality-first: predictSingleFundus is NOT called
    rec.inference_executed = false;
    rec.grade = NaN; rec.confidence = NaN; rec.referable_probability = NaN;
    rec.binary_decision = 'WITHHELD (quality FAIL - not assessed)';
    rec.cascade_route = 'REVIEW';
else
    r = predictSingleFundus(imgPath, 'SkipModelOnFail', true, 'ShowFigure', false);
end
```

So on FAIL there is no grade, no class probabilities, no confidence, no
Grad-CAM and no referral — only a reason and an action. From the committed run:

| case | quality | inference executed | grade | referral | route |
|---|---|---|---|---|---|
| case_pass_referable | PASS | yes | 4 (Proliferative) | REFERABLE | CLEAR |
| case_pass_nodr | PASS | yes | 0 (No DR) | NON-REFERABLE | REVIEW |
| case_warning | WARNING | yes | 0 (No DR) | NON-REFERABLE | CLEAR |
| case_fail_blur | FAIL | **no** | not assessed | WITHHELD | REVIEW |
| case_fail_dark | FAIL | **no** | not assessed | WITHHELD | REVIEW |
| case_fail_bright | FAIL | **no** | not assessed | WITHHELD | REVIEW |
| case_fail_illumination | FAIL | **no** | not assessed | WITHHELD | REVIEW |
| case_fail_fov | FAIL | **no** | not assessed | WITHHELD | REVIEW |
| case_fail_contrast | FAIL | **no** | not assessed | WITHHELD | REVIEW |

**3 of 9** available cases reached AI; **6 of 6** FAIL cases were stopped.

---

## 5. What each FAIL case shows

Each FAIL row in `audit_log.csv` carries the exact metric, the violated bound
and the configured threshold. Headline values from the run:

| case | defining metric | value | violated bound | threshold |
|---|---|---|---|---|
| case_fail_blur | focus (var. Laplacian) | 9.69e-05 | lowerFail | 1.42e-04 |
| case_fail_dark | brightness | 0.1635 | lowerFail | 0.1901 |
| case_fail_bright | brightness | 0.5524 | upperFail | 0.5154 |
| case_fail_illumination | illumination | 1.4822 | upperFail | 1.3541 |
| case_fail_fov | foreground fraction | 0.1232 | lowerFail | 0.2651 |
| case_fail_contrast | contrast | 0.02252 | lowerFail | 0.0315 |

Note that real degraded images often violate several checks at once (e.g. a
blurred image is frequently also dark and low-contrast). The audit log records
**all** violated checks; the "headline" metric above is the one that defines
the case's role. This multi-failure reality is expected and is reported, not
hidden.

The presentation visual `figures/failure_aware_comparison.png` renders one
good case (full AI flow with a Grad-CAM overlay) beside one poor case
(explicit `AI GRADING: SKIPPED` card). `figures/failure_aware_workflow.png`
shows the pipeline with the hard gate.

---

## 6. How audit logging works

Every case writes exactly one row to `audit_log.csv` (one row per image, always
— PASS, WARNING and FAIL alike). Columns include:

- identity: `case_id`, `role`, `image_relpath`, `timestamp`
- quality decision: `quality_status`, `quality_score`, `quality_reason`,
  `failure_categories`
- raw metrics: `brightness`, `contrast`, `focus_score`, `foreground_frac`,
  `illumination`, `mask_valid`
- per-check status: `*_status` for all six checks
- headline failure: `primary_metric`, `primary_value`, `primary_bound`,
  `primary_threshold`, `primary_message`
- outcome: `inference_executed`, `engine`, `grade`, `grade_label`,
  `confidence`, `referable_probability`, `binary_decision`,
  `referral_decision`, `cascade_route`, `gradcam_available`, `runtime_sec`,
  `note`

`demo_results.mat` stores the same results plus provenance (config version,
threshold snapshot, model hashes, `modelsUnchanged`). `run_log.txt` is the
transcript. `reports/generated_summary.md` is a machine-generated roll-up.

---

## 7. Known limitations / honest failure report

1. **Prototype thresholds.** The quality gate is not clinically validated
   (config `validationStatus = 'Prototype - NOT clinically validated'`). The
   gate decides *usability*, not disease.
2. **Illumination severity inconsistency (real).** `defaultQualityConfig`
   declares `severity.illumination = 'WARNING'`, but `assessImageQuality`'s
   `evaluateRangeCheck` never reads `config.severity`; it classifies any
   out-of-`upperFail`/`lowerFail` value as `FAIL`. Consequence: the
   `case_fail_illumination` image is treated as a hard FAIL and blocks
   inference, contrary to the documented intent. The same applies to the
   declared `severity` of brightness/contrast/focus/foreground (currently
   unused config). **This was deliberately not "fixed"** to avoid silently
   changing validated production behaviour without review. Recommended fix
   (future, reviewed): have `evaluateRangeCheck` consult `config.severity` so
   illumination can only WARN.
3. **Foreground category mislabelled.** `categorizeFailures` matches the
   keyword `foreground`, but the foreground feedback message reads
   "Insufficient retinal area visible…", so foreground failures are bucketed
   as category `Other` (see `case_fail_fov`). A display/category bug only;
   the gate decision itself is correct.
4. **Grad-CAM is model visual evidence, not a clinical explanation.** On the
   independent IDRiD lesion-alignment study (`data/analysis/gradcam_lesion_alignment`),
   top-20%-attention overlap was weak: saliency-in-lesion **3.1%**, pointing-game
   **7.4%**, mean IoU **0.035** (~**1.39×** areal chance). Reported honestly;
   the model was not retrained to chase a better number.
5. **No natural mask-validity FAIL.** 0 of 733 val images produced a
   mask-validity FAIL, so the `case_fail_mask` role is marked **unavailable**.
   We did **not** fabricate an image to fill the slot.
6. **Small, non-representative selection.** The demo cases are hand-picked for
   clarity, not sampled for accuracy. `case_pass_referable` happening to be
   grade 4 is not a performance estimate.
7. **Not a clinical claim.** Nothing here demonstrates "doctor-level"
   performance or that the system replaces an ophthalmologist.

---

## 8. How this connects to the Simulink model

The Simulink district resource model
(`data/analysis/simulink_resource_simulation`) models *volume and queue*, using
the same quality-gate fractions as an input:

| Simulink baseline input | value |
|---|---|
| Quality gate PASS / WARN / FAIL | 65.48% / 26.68% / 7.84% |
| Annual volume | 100,000 |
| AI-screened | 96,081 / year |
| Referrals | 38,406 / year (153.6 / day) |
| Specialist capacity | 60 / day |
| Year-end backlog | 23,406 |
| Specialists required | 7.68 |

This demo is the **image-level mechanism** behind those numbers: the PASS/FAIL
split is produced by the same Day-3 gate, and every FAIL image is removed from
the automatic AI path and routed to recapture / manual review (the Simulink
model assumes a 0.50 recapture rate). The measured 6.7% FAIL rate here is
consistent with the 7.84% used by the Simulink baseline. The bottleneck the
Simulink model exposes is specialist review, not AI processing — and the
quality gate reduces, never increases, the AI/referral workload.

---

## 9. What is reusable in the final SIH demo

- **The hard gate itself** (`assessImageQuality` + quality-first ordering):
  reusable logic for "no AI answer without a usable image".
- **`quality_failure_detail.m`**: turns a gate result into an explicit
  `metric / value / bound / threshold` explanation for any UI or report.
- **`audit_log.csv` schema**: a ready template for regulatory-style traceability
  (one row per image, every decision and metric recorded).
- **`test_failure_aware_demo.m` (TEST 1–11)**: an executable contract that a
  FAIL image can never leak a prediction and models/weights never change.
- **`select_demo_cases.m`**: reproducible real-case selection from the held-out
  split for a live demo.
- **The three figures**: drop-in slides for the SIH presentation.

---

### Integrity notes

- Models (read-only, hashes verified before and after every run):
  - binary: `43E8DF33B429231EE5BD60A775FDB3629AD81F287617AFAA9308EA87D311F9A0`
  - 5-class: `DD152C917689146F6DEC4687B263EC5E5F237ECF60EC719A59F9FCEEFF737C1B`
- Referral threshold remains locked at 0.60.
- No training, no weight/architecture changes, official APTOS test set untouched.
- `Grad-CAM`, class probabilities and referral outputs are engineering outputs,
  not clinical diagnoses.
