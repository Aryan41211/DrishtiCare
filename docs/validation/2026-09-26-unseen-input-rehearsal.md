# Unseen-Input Rehearsal — 2026-09-26

**Closes:** ROADMAP P3 ("one surprise/unseen image test") and the
`EXECUTION_CHECKLIST.md` Phase H item *"surprise-input case"* — previously unticked
because, as that checklist noted, *"the app verifier and demo both use the labelled
val split; the only unseen data (official APTOS test) is unlabeled and firewalled."*

**Script:** `src/demo/run_unseen_rehearsal.m`
**Artifacts:** `data/analysis/day11/rehearsal/unseen_rehearsal_results.csv` / `.mat`
**Frozen contract respected:** no training, no tuning, no model modification,
`BinaryThreshold` left at its locked `0.60`. Model hashes untouched.

---

## Why this test existed

Every automated check in this repo runs on the APTOS validation split — the same data
the champions were selected on. The Grand Finale is judged on a **live demo where
judges may feed surprise inputs** (`docs/background/sih-logistics.md`). The system had
therefore never been run end-to-end on fundus photography it had never seen.

Three genuinely unseen sources were used, none of which contributed to the classifier
champions:

| Source | What it is | Why it is a fair surprise input |
|---|---|---|
| **DRIVE test** (5 `.tif`) | Retinal photographs, different camera + FOV convention | Previously used only by the now-excluded vessel segmenter |
| **IDRiD B testing set** (5 `.jpg`) | Disease-grading fundus from a third camera, 4288×2848 | IDRiD fed the lesion/OD models, **not** the classifiers |
| **DRIMDB** (9 `.jpg`, Good/Bad/Outlier) | Real-world web fundus | "Outlier" is the closest available analogue of a judge's surprise input |

## Result: 19/19 completed, 4/4 contract checks PASS

| Contract check | Result |
|---|---|
| No crash / no unhandled exception | **PASS** — 19/19 |
| Every completed run returned a valid route band | **PASS** — CLEAR/REVIEW/ABSTAIN |
| Quality FAIL never auto-answers (grade stays `NaN`) | **PASS** — 8 FAIL images, all withheld |
| Locked 0.60 rule still holds on unseen data | **PASS** — `referable == raw pRef >= 0.60` |

### Full run

| Source | Quality | Grade | pRef | Route | Decision | OOD (Mah) | s |
|---|---|---:|---:|---|---|---|---:|
| DRIVE 01 | WARNING | 0 | 0.0000 | CLEAR | NON-REF | in (26.9) | 15.3 |
| DRIVE 02 | FAIL | NaN | NaN | REVIEW | WITHHELD | n/a | 1.0 |
| DRIVE 03 | PASS | 0 | 0.0001 | CLEAR | NON-REF | **OOD (36.4)** | 3.3 |
| DRIVE 04 | WARNING | 0 | 0.0000 | CLEAR | NON-REF | in (32.7) | 2.4 |
| DRIVE 05 | PASS | 0 | 0.0000 | CLEAR | NON-REF | **OOD (41.4)** | 1.9 |
| IDRiD 001 | FAIL | NaN | NaN | REVIEW | WITHHELD | n/a | 1.2 |
| IDRiD 002 | PASS | 2 | 0.9723 | REVIEW | REFERABLE | in (23.4) | 30.8 |
| IDRiD 003 | PASS | 1 | 0.9978 | REVIEW | REFERABLE | in (22.2) | 43.6 |
| IDRiD 004 | WARNING | 4 | 0.9847 | REVIEW | REFERABLE | in (23.9) | 38.2 |
| IDRiD 005 | PASS | 4 | 0.9999 | CLEAR | REFERABLE | **OOD (34.5)** | 35.6 |
| DRIMDB Good 1 | FAIL | NaN | NaN | REVIEW | WITHHELD | n/a | 0.9 |
| DRIMDB Good 10 | WARNING | 0 | 0.0000 | CLEAR | NON-REF | **OOD (62.1)** | 2.1 |
| DRIMDB Good 100 | WARNING | 0 | 0.0000 | CLEAR | NON-REF | **OOD (44.6)** | 1.8 |
| DRIMDB Bad 1 | FAIL | NaN | NaN | REVIEW | WITHHELD | n/a | 0.9 |
| **DRIMDB Bad 10** | **PASS** | **4** | **0.9690** | **CLEAR** | **REFERABLE** | in (33.9) | 1.4 |
| DRIMDB Bad 11 | FAIL | NaN | NaN | REVIEW | WITHHELD | n/a | 0.6 |
| DRIMDB Outlier 1 | FAIL | NaN | NaN | REVIEW | WITHHELD | n/a | 0.5 |
| DRIMDB Outlier 10 | FAIL | NaN | NaN | REVIEW | WITHHELD | n/a | 0.8 |
| DRIMDB Outlier 11 | FAIL | NaN | NaN | REVIEW | WITHHELD | n/a | 0.6 |

Distributions: quality FAIL 8 / WARNING 5 / PASS 6. Route CLEAR 8 / REVIEW 11 /
ABSTAIN 0.

---

## What the rehearsal established

### 1. The system does not crash on foreign cameras — the safety contract holds
All 19 unseen images completed. Every quality FAIL was withheld **before** any model
execution (grade `NaN`, route REVIEW, OOD `n/a` = the detector never ran). The locked
decision rule was reproduced on every image that did reach the model. This is the
single most valuable result for the Grand Finale: the refusal behaviour is not an
APTOS-only artefact.

### 2. The quality gate is far more conservative on unseen cameras
**8 of 19 (42%) were withheld**, against a 7.84% FAIL rate on APTOS train. The gate's
thresholds are Day-3 APTOS percentiles, so they over-reject foreign-camera imagery.
This is the **safe** direction to fail — a WITHHELD image is never auto-answered — but
it must be understood before a judge feeds an unusual image:

> **Expect the app to say "AI grading skipped, please recapture" on a surprising
> image. That is the designed behaviour, and it is the strongest thing to show.**

### 3. The OOD detector genuinely fires out-of-distribution
Against its locked threshold of 34.22 (Phase 9), it flagged DRIVE 03 (36.4), DRIVE 05
(41.4), IDRiD 005 (34.5) and both graded DRIMDB Good images (62.1, 44.6). The two
sources it did *not* flag are the small DRIVE images it already saw as in-distribution.
This is the first evidence that the OOD gate works on data outside APTOS — though it
remains **advisory only** and never altered a route in this rehearsal.

### 4. NEW NEGATIVE FINDING — confident false-positive on an ungradable image
`drimdb_bad (10).jpg` — an image DRIMDB itself labels as **Bad** (i.e. not
diagnosable) — **passed** the quality gate, was graded **4 (proliferative)** with
`pRef = 0.9690`, routed **CLEAR**, and came back **REFERABLE** with the OOD distance
(33.9) just under the threshold.

So on out-of-distribution real-world imagery the system can emit a **confident,
clear, referable grade on an image a human would reject**, and neither the quality
gate nor the OOD gate caught it. This is recorded as an honest negative result per
`DECISION_LOG.md` D008. It is **not** a frozen-contract violation and must **not** be
"fixed" by tuning the threshold or the OOD bound — those are provenance-pinned
(Phase 6, Phase 9). The correct response is to state it and to demo accordingly.

### 5. High-resolution images are slow — a live-demo risk
Median wall-clock on unseen data was 1.81 s/img, but that average hides the real
hazard:

| Source | Median s/img |
|---|---:|
| DRIMDB Bad / Outlier | 0.6–0.9 |
| DRIMDB Good | 1.8 |
| DRIVE (565×584) | 2.4 |
| **IDRiD (4288×2848)** | **35.6** |

The committed "full demo path median 11.03 s/img" (Phase 12/P23) was measured on
512×512 APTOS images and **understates** the cost of a high-resolution input by ~3×.
A judge feeding a full-resolution fundus photo should expect **~30–45 s**, not ~11 s.
It completes correctly — it does not hang — but **rehearse the demo on
APTOS-resolution images**, or pre-resize anything a judge might supply.

### 6. Lesion evidence over-fires on unseen images
IDRiD runs reported implausibly high candidate counts (`HE=85 EX=53`,
`HE=83 EX=15`, `HE=27 EX=93`, `HE=56 EX=99`). This is consistent with the already
documented weakness of the classical HE/EX detectors and the low-recall MA CNN
(patch AUC 0.976 but detection recall 0.113). It reinforces D005: these counts are
candidates, not findings, and the narrative already labels them as such.

---

## Harness note (not a product defect)

The first rehearsal run failed 7/14 with `Undefined function 'enhanceImage'`. That was
a **defect in the rehearsal script**, which added only selected `src/` folders, not a
product bug — `launchRetinaAI.m:9-10` and `RetinaAIApp.m:132-133` both call
`addpath(genpath(fullfile(projectRoot,'src')))`, and the script now does the same.

Worth knowing, though: `predictSingleFundus.m:47` self-bootstraps only *part* of the
`src` tree (it adds `ood_detection` and others explicitly). It relies on the caller
having set up the path. Calling it from a clean MATLAB session without
`addpath(genpath(...,'src'))` will fail. **The demo must be launched via
`launchRetinaAI.m`**, which handles this.

---

## Recommended demo implications

1. Launch with `launchRetinaAI.m`; do not call `predictSingleFundus` ad hoc.
2. Demo on APTOS-resolution images so latency stays in the ~1–3 s range.
3. **Lean into the refusal beat.** A withheld image on a foreign or poor-quality
   input is the strongest, most defensible thing in the project.
4. Do not feed `drimdb_bad (10).jpg` in the demo, and do not claim the quality gate
   catches every ungradable image — it does not (finding 4).
5. If a judge supplies a surprise image, the honest answer is: *"It either returns a
   grade with a confidence band, or it refuses and asks for a recapture. Both are
   designed behaviour. Here is the measured refusal rate on unseen cameras: 42%."*
