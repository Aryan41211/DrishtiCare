# RETINA-AI Judge Demo App — Design Spec

Date: 2026-09-11 | Status: approved + implemented 2026-09-11 | Owner: SIH 26038 team

> Display name is **DRISHTI** (user decision 2026-09-11; was RETINA-AI).
> Class/file name stays `RetinaAIApp` so `launchRetinaAI.m` and the
> verify scripts keep working.

## 1. Goal

Upgrade the existing programmatic App Designer front-end
(`RetinaAIApp.m` at the **repo root**, `matlab.apps.AppBase`) into a
judge-ready RETINA-AI screening demo. No ML pipeline rebuild: the app
is a thin caller of `predictSingleFundus()` (`src/inference/`).

> *Path correction, 2026-09-25: this spec named the class
> `src/dashboard/RetinaAIApp.m`. In the very same commit that added this spec
> (`4560f4b`, 2026-09-13) the file was **relocated to the repo root** as
> `RetinaAIApp.m` (git records it as a rename:
> `src/dashboard/RetinaAIApp.m => RetinaAIApp.m`), so the path below was stale
> from the moment it was written. `src/dashboard/` holds the separate 5-tab
> `DRScreeningDashboard.m` plus the verifiers. `launchRetinaAI.m` is the
> launcher and is also at the root.*

## 2. Non-goals

- No new classifier, quality metric, or Grad-CAM implementation.
- No lesion/vessel segmentation claims (both parked: over-segmentation /
  poor MA performance).
- No clinical-validation language anywhere in UI or report.
- No invented performance numbers; metrics only from committed artifacts.

## 3. Entry contract (verified in repo, do not assume)

- Inference: `predictSingleFundus(imagePath, 'ShowFigure', false,
  'RunLesions', true, 'RunBranchB', true, 'SkipModelOnFail', true)`
  returns fields: `qualityStatus` (PASS/WARNING/FAIL), `qualityScore`,
  `qualityFailureReasons`, `qualityRecaptureAdvice`, `qualityGate`
  (`.enforced`), `binaryProbability`, `binaryDecision`
  (REFERABLE/NON-REFERABLE/WITHHELD…), `binaryThreshold` (0.60, locked),
  `grade` (0–4), `gradeLabel`, `classProbabilities`, `confidence`,
  `gradCAM` (overlay image), `cascade` (`.route` CLEAR/REVIEW/ABSTAIN),
  `lesions` (candidate counts + `error`), `ood`, `fusion`,
  `explanation` (`.recommendation`, `.paragraph`, `.caveats`),
  `runtimeSec`.
- Quality: `assessImageQuality(img)` → `overall` PASS/WARNING/FAIL,
  per-check structs, weighted `qualityScore`. Thresholds are engineering
  prototypes (`defaultQualityConfig`, v2.0.0, Day-3 APTOS stats).
- Enhancement: `enhanceImage(raw)` — display aid always computed by the
  pipeline; model input preprocessing is unchanged.
- Grad-CAM: `gradCAM(net5, input, gradeIdx, 'FeatureLayer',
  'res5b_relu')`; overlay via `imfuse`.

## 4. UI design (App Designer, AppBase class)

Header: RETINA-AI / AI Retinal Screening Assistant / ● System Ready.
Left: fundus preview axes, Upload button, sample dropdown (val split),
ANALYZE IMAGE button (disabled until image loaded).
Result card: DR Severity (gradeLabel), ICDR `grade / 4`, Referable DR
YES/NO (from `binaryDecision`), Model Score (`binaryProbability×100`,
labeled exactly "Model Score"), locked-threshold note.
Quality card: badge `ACCEPT (PASS)` green / `BORDERLINE (WARNING)` amber
/ `REJECT (FAIL)` red, `qualityScore`, per-check lines, recapture advice.
Enhancement badge: PASS → "Enhancement: not required"; WARNING →
"Adaptive enhancement: APPLIED (display aid)"; FAIL → hidden (withheld).
Explainability panel: 4 switch buttons Original / Enhanced / Grad-CAM /
Overlay on one large axes; defaults to Overlay after analysis; caption
"Model Attention Visualization — not lesion localization".
Recommendation banner: grade≥3 urgent / grade 2 or REFERABLE → refer /
cascade REVIEW-ABSTAIN → specialist check / else routine follow-up /
FAIL → recapture-or-manual-review (WITHHELD, no grade shown).
Footer: engineering-demo disclaimer + human-in-the-loop line.
Report: Save Report → `.txt` + current Overlay `.png`; Copy to Clipboard
kept. Simulink "system performance" tab deferred (no measured numbers in
scope).

## 5. Flows

- ACCEPT: upload → analyze → quality → grade/ICDR/referable/score →
  overlay → recommendation → optional report.
- BORDERLINE: + enhancement badge, Original vs Enhanced views, then as
  above; caution note in report.
- REJECT: `SkipModelOnFail=true` → WITHHELD path; UI shows "IMAGE NOT
  SUITABLE FOR ANALYSIS", failure reasons, recapture advice; no grade,
  no Grad-CAM, no classification executed.

## 6. Wording guards (mandatory)

- "Model Score", never "calibrated/confident".
- "Model Attention Visualization", never "lesion detection".
- Thresholds labeled "engineering prototype thresholds".
- Lesion counts (if shown) labeled "automated candidates, supportive
  evidence only".
- Verified metrics (§15 of brief) reproduced only from committed
  artifacts; 20-image 35% test labeled diagnostic-only.

## 7. Verification

Extend `src/dashboard/verify_retinaai.m` headless checks: badge texts
(ACCEPT (PASS)/BORDERLINE (WARNING)/REJECT (FAIL)), 4-view switching
populates axes, FAIL short-circuit yields WITHHELD + no grade,
report `.txt` content, checkpoint file non-zero. Run:
`matlab -batch "run('src/dashboard/verify_retinaai.m')"`.
Manual judge-flow rehearsal on ≥3 real val images (one per quality
status) on desktop MATLAB. Packaging path: the class is a plain `.m` file
at the repo root (`RetinaAIApp.m`) launched via `launchRetinaAI.m`; that
`.m` file is the source of truth. **No `.mlapp` is produced** — the
App Designer Save-As step described in the original spec was dropped
rather than ticked, because as of 2026-09-25 the repo contains **zero**
`.mlapp` files and a class-file launcher is the path actually taken.

## 8. Checkpoint (MATLAB Drive / repo source of truth)

`results/V2_DrishtiApp_checkpoint.mat` containing: app config
(threshold 0.60, SkipModelOnFail, layer res5b_relu), quality config
version, model file paths, timestamp, verification log. Verified
non-zero after save.

> *Path correction, 2026-09-25: this spec originally named
> `results/V2_RetinaAIApp_checkpoint.mat`. The file the saver
> (`src/dashboard/save_drishti_checkpoint.m`) actually writes — and the
> file that exists — is `results/V2_DrishtiApp_checkpoint.mat` (14,008
> bytes). The name follows the DRISHTI display-name decision, per plan
> Task 3.*

## 9. Self-review

No TBDs. No contradictions (§5 REJECT uses pipeline-supported WITHHELD
path; §4 enhancement badge is display-only, consistent with pipeline).
Scope is one plan (app upgrade + verify + checkpoint + package).
"Model Score" defined as `binaryProbability×100` unambiguously.
