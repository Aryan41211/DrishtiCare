# DrishtiCare — Demo Video Plan (SIH 2026 national screening submission)

**Target runtime: 3 minutes exactly (3:00).**
**Shot count: 9.**
**Narration pace: ~150 words/min. Full script is 435 words + 3 marked pauses.**

All paths are relative to the repo root `C:\projects\DrishtiCare`.
Every number spoken in this video is traceable to a committed artifact; the
traceability column is the authority. If you cannot fill that column, cut the
sentence.

---

## 0. Two things this document is honest about up front

1. **MP4 assembly is a human step, not an agent step.** No `ffmpeg` (and no
   `ffprobe`, no OBS, no DaVinci Resolve) is installed on this machine —
   verified: `Get-Command ffmpeg,ffprobe,obs64,Resolve` all return nothing.
   Therefore *this plan stops at "record these shots"*. A human records the
   screen with **OBS Studio (free, https://obsproject.com)** and produces the
   MP4 with OBS itself. See §5 for the exact click path — it needs no ffmpeg
   CLI.
2. **Voiceover audio is also a human step.** The script below is written to be
   read aloud; the final mix is done by a person. See §5.

No frames were faked for this plan. §6 records the one real automated capture
that was actually executed.

---

## 1. Shot map (summary)

| # | Dur | Beat | Image file loaded | Cumulative |
|---|---:|---|---|---:|
| 1 | 0:10 | Hook + app launch | — (idle dashboard) | 0:10 |
| 2 | 0:10 | Workflow beat | — (pipeline chips) | 0:20 |
| 3 | 0:24 | Good image, full pipeline runs | `data/splits/val/class_2/77f69c7ff324.png` | 0:44 |
| 4 | **0:38** | **Poor-quality image — AI withheld (longest shot)** | `data/splits/val/class_1/cae51154e1ce.png` | 1:22 |
| 5 | 0:26 | Explainability views + "attention, not localisation" | `data/splits/val/class_2/77f69c7ff324.png` | 1:48 |
| 6 | 0:20 | Branded A4 report generation | (re-analyse the shot-3 image) | 2:08 |
| 7 | 0:22 | Simulink district-scale story | `src/simulink/DrishtiCare_DistrictScreening.slx` + `results/presentation/simulink_district_summary.png` | 2:30 |
| 8 | 0:24 | Honest limitations (deliberate, not defensive) | — (on the withheld screen from shot 4) | 2:54 |
| 9 | 0:06 | Close | — | **3:00** |

10 + 10 + 24 + 38 + 26 + 20 + 22 + 24 + 6 = **180 s = 3:00**.

---

## 2. Shot-by-shot

### Shot 1 — 0:00 → 0:10 (10 s) — Hook + launch

- **Show:** the launched `RetinaAIApp` window, full screen, no cursor theatrics.
  Let the branded header and the three panels settle for ~2 s before speaking.
- **Image file:** none. Idle dashboard, nothing loaded.
- **Say** (VOICEOVER-SCRIPT.md §Shot 1):
  > "This is DrishtiCare — a diabetic-retinopathy screening prototype, built for
  > the case where the AI is not allowed to answer."
- **Must be visible:** the DRISHTI branded header; the three panel titles
  (Retinal Image / AI Screening Result / Model Explanation & Visual Evidence);
  the five pipeline chips along the bottom bar — `Image · Quality · Screening ·
  Evidence · Report`.
- **Traceability:** no numeric claim in this shot. `RetinaAIApp.m:542` defines
  the chip names; `RetinaAIApp.m:11` states the pipeline order.

---

### Shot 2 — 0:10 → 0:20 (10 s) — Workflow beat

- **Show:** the bottom-bar pipeline chips. Point at them with the cursor, left to
  right, without moving the window. Do **not** start with metrics.
- **Image file:** none.
- **Say** (script §Shot 2):
  > "Here is the whole path, top to bottom: image, quality, screening, evidence,
  > report — and then a person makes the final call."
- **Must be visible:** all five chip labels legible at recording resolution; the
  persistent footer line *"Human-in-the-loop: final clinical decision by a
  qualified ophthalmologist."* (`RetinaAIApp.m:640`).
- **Fallback if the chips are too small at your zoom:** cut to
  `data/analysis/failure_aware_demo/figures/failure_aware_workflow.png` (the
  committed hard-gate diagram) for the same 10 s. It is a committed artifact,
  not a mock.
- **Traceability:** workflow order from `docs/project-management/DEMO_AND_SUBMISSION_PLAN.md` §1
  and `RetinaAIApp.m:11`.

---

### Shot 3 — 0:20 → 0:44 (24 s) — Good image, the full pipeline runs

- **Show:**
  1. Click **Upload Image** (the sample dropdown does **not** contain this file —
     see §4 pre-flight item P4) and load:
     `data/splits/val/class_2/77f69c7ff324.png`
  2. Click **ANALYZE IMAGE**. Let the real inference run on camera.
  3. Hold on the result panel. Do not click anything else.
- **Image file (absolute):** `C:\projects\DrishtiCare\data\splits\val\class_2\77f69c7ff324.png`
- **Say** (script §Shot 3):
  > "This is a real held-out image. Quality returns ACCEPT. The model returns
  > grade four, proliferative, model score one — so it routes REFERABLE. In our
  > committed run on this exact file that is what happened: grade four,
  > referable, uncertainty router CLEAR. And the footer says the final clinical
  > decision is the ophthalmologist's."
- **Must be visible, all simultaneously:** the fundus thumbnail; the quality
  badge reading **ACCEPT** (`RetinaAIApp.m:857` → `ACCEPT (PASS)`); the ICDR
  grade value `4` and label `Proliferative`; the model score reading `100%`
  (raw P(referable) = 1.0); the referral/recommendation line reading
  **REFERABLE**; and the `Screening` chip lit while the run is in progress.
- **Traceability:** `data/analysis/failure_aware_demo/audit_log.csv` row
  `case_pass_referable` — quality `PASS`, grade `4 Proliferative`,
  `referable_probability = 1`, `binary_decision = REFERABLE`,
  `cascade_route = CLEAR`, `inference_executed = 1`, `runtime_sec = 13.41`
  (cold first call in that session).
  Human-in-the-loop footer: `RetinaAIApp.m:640`.

> **⚠ RE-CHECK BEFORE RECORDING.** `model score 100%` is a display rounding of
> a raw probability of exactly 1.0 in the committed log. Re-run this image on
> the recording machine and confirm the dashboard still shows 100% and grade 4.
> If the number moved, read the number the screen actually shows — never the
> number you remember.

---

### Shot 4 — 0:44 → 1:22 (38 s) — **The strongest moment: AI withheld**

**This is the longest shot in the video on purpose.** It is the single most
defensible behaviour in the project and it gets the most screen time.

- **Show:**
  1. Click **Upload Image** and load:
     `data/splits/val/class_1/cae51154e1ce.png`
  2. Click **ANALYZE IMAGE**. Note the near-instant return (the gate
     short-circuits, so no model runs) — let that contrast land.
  3. **Hold the frame for a full 3 s in silence** after the narration reaches
     "zero model calls" territory, so the judges can read the empty fields.
  4. Point at, in this order: the quality badge, the reason text, the grade
     field, the evidence panel, the status line.
- **Image file (absolute):** `C:\projects\DrishtiCare\data\splits\val\class_1\cae51154e1ce.png`
- **Alternate if that file is unavailable** (should not happen — it is committed):
  `data/splits/val/class_0/d91635f380b4.png` (underexposed, brightness 0.1635
  vs lowerFail 0.1901 — a clean single-reason FAIL).
  A third option, if you want the WARNING band shown as a bridge:
  `data/splits/val/class_0/cffc50047828.png`.
- **Say** (script §Shot 4, includes a marked PAUSE):
  > "Now the important one. This is also a real held-out image, and it fails our
  > own quality gate. The badge says REJECT. It names the reason: too dark, very
  > low contrast, blurry. Focus measured nine-point-seven times ten to the
  > minus five, against a fail threshold of one-point-four-two times ten to the
  > minus four.
  > **[PAUSE — 2 s of silence, let them read the empty grade field]**
  > Notice what is missing. No grade. No heat map. The status line reads AI
  > grading skipped, model stack not executed. That is not a suppressed
  > display — in our committed run, predictSingleFundus was never called for
  > any of the six failing images."
- **Must be visible:** quality badge **REJECT**; the reason string naming all
  three failures (too dark / very low contrast / blurry); the ICDR grade field
  showing a dash or `NOT ASSESSED`, **never a number**; the Grad-CAM canvas
  reading *"No Grad-CAM: analysis withheld (quality FAIL)"*
  (`RetinaAIApp.m:947`); the status/recommendation line reading
  *"AI GRADING: SKIPPED (model stack not executed)"* (`RetinaAIApp.m:964`); the
  `Quality` chip lit and the `Screening` chip **not** lit.
- **Traceability:** `data/analysis/failure_aware_demo/audit_log.csv` row
  `case_fail_blur` — `quality_status = FAIL`, `primary_metric = focus`,
  `primary_value = 9.69488461572011e-05`, `primary_bound = lowerFail`,
  `primary_threshold = 0.000142`, `inference_executed = 0`,
  `engine = "quality-gate-skip (predictSingleFundus NOT called)"`,
  `grade = NaN`, `binary_decision = "WITHHELD (quality FAIL - not assessed)"`,
  `cascade_route = REVIEW`.
  The "six failing images" count: the same CSV has 6 `FAIL` rows, all with
  `inference_executed = 0`. See also
  `data/analysis/failure_aware_demo/README.md` §4 and §5.

> **⚠ RE-CHECK BEFORE RECORDING.** The focus value and threshold quoted here are
> from the committed 2026-09-21 run. Re-analyse this exact file on the recording
> machine and read the numbers the quality table actually shows. Quality
> thresholds are Day-3 APTOS percentiles and are provenance-pinned — they will
> not have changed, but the *displayed rounding* may differ from the CSV.

> **⚠ DO NOT SUBSTITUTE** `data/drimdb/DRIMDB/Bad/drimdb_bad (10).jpg` here or
> anywhere else. See §4 (Prohibited).

---

### Shot 5 — 1:22 → 1:48 (26 s) — Explainability views

- **Show:**
  1. Re-load `data/splits/val/class_2/77f69c7ff324.png` (Upload Image) and
     re-analyse — you need a real Grad-CAM, which the withheld image in shot 4
     does not have.
  2. Click the four view buttons in order, ~2 s each:
     **Original → Enhanced → Grad-CAM → Overlay**.
  3. Rest on **Overlay**.
- **Image file (absolute):** `C:\projects\DrishtiCare\data\splits\val\class_2\77f69c7ff324.png`
- **Say** (script §Shot 5):
  > "Four views on one image: original, enhanced, Grad-CAM, overlay. And I want
  > to be precise about this heat map. It is the model's attention — the regions
  > that most influenced the decision. It is not lesion localisation. We measured
  > that ourselves: on IDRiD lesion masks, three-point-one percent of saliency
  > mass lands inside a lesion. The pointing game hits seven-point-four. We did
  > not retrain to chase a better number."
- **Must be visible, in the final held frame:** the **Overlay** view filling the
  evidence panel; the panel title *"Fundus + Grad-CAM Overlay (attention blend)"*
  (`RetinaAIApp.m:911`); the 0–1 colourbar on the right of the panel
  (`RetinaAIApp.m:451-460`); and, directly under the panel, the persistent
  disclaimer line — this is the single most important on-screen honesty element
  in the whole video:
  > **"Model attention visualization - not validated lesion localization."**
  > (`RetinaAIApp.m:463`)
- **Traceability:** Grad-CAM alignment numbers from
  `data/analysis/gradcam_lesion_alignment/README.md` §"Aggregate Results" —
  "Saliency mass in lesion: 0.031", "Pointing-game accuracy: 0.074", over 81
  valid image+mask pairs. Disclaimer text is in the app source, quoted verbatim.

> **⚠ RE-CHECK BEFORE RECORDING.** Re-run the view buttons on the recording
> machine and confirm the disclaimer line is visible at your zoom level. If it
> is clipped, zoom the browser-equivalent / MATLAB window out one notch and
> re-take — this line must be legible in the final frame.

---

### Shot 6 — 1:48 → 2:08 (20 s) — Branded A4 report generation

- **Show:** with the shot-5 image still analysed, open the kebab (three-dot)
  menu → **Save PDF Report**. Then switch to File Explorer / the MATLAB
  `results/` folder and open the newly written PDF so the judges see it as a
  file on disk, not a claim.
- **Image file:** re-use of `data/splits/val/class_2/77f69c7ff324.png`; the
  report is generated from whatever is currently loaded.
- **Output file pattern (real):**
  `results/DrishtiScreeningReport_<patientID>_<yyyyMMdd_HHmmss>.pdf`
  A committed example exists:
  `results/DrishtiScreeningReport_005b95c28852_20260926_005327.pdf`
  (3,119,259 bytes, written by the automated capture in §6).
- **Say** (script §Shot 6):
  > "One click and the same result structure becomes a real A4 PDF on disk, in
  > results, timestamped. Screening summary, grade, quality table, the Grad-CAM
  > evidence, interpretation, recommendation, and a footer that says this is not
  > a clinical device. Same struct, same numbers, not a screenshot."
- **Must be visible:** the seven numbered sections in order — 1. Screening
  Summary, 2. Diabetic Retinopathy Grade, 3. Image Quality Assessment,
  4. Visual Evidence (Grad-CAM), 5. Interpretation, 6. Recommendation, and the
  un-numbered footer disclaimer. Section order is fixed in
  `src/reporting/generateDrishtiReport.m` (`buildDrishtiReportBlocks`, blocks 1–7).
- **Traceability:** `src/reporting/generateDrishtiReport.m` — section build
  order and the footer text *"This report was produced by an ENGINEERING DEMO
  screening prototype (DRISHTI). It is NOT a clinical device…"*.

> **⚠ RE-CHECK BEFORE RECORDING.** The report generator has two engines
> (tier-1 MATLAB Report Generator, tier-2 headless Edge/Chrome fallback). On
> *this* machine the tier-2 Edge path fired — an `.html` sibling is written next
> to the `.pdf` and Edge's "N bytes written to file" message appears in the log.
> Check which engine fires on the recording laptop. **Say "A4 PDF" either way**
> (the script is worded that way deliberately) and do not name an engine on
> camera.

---

### Shot 7 — 2:08 → 2:30 (22 s) — Simulink district-scale story

- **Show, in this order:**
  1. **~6 s** — the real Simulink model window:
     `src/simulink/DrishtiCare_DistrictScreening.slx`
     (Simulink **is** installed on this machine — `license('test','Simulink')`
     returns 1 — so this is a real open, not a picture of a model). Show the
     block diagram: Patient Arrival & Image Capture → Quality Gate → AI
     Screening & Referral → Specialist Queue & Review → System Metrics.
  2. **~16 s** — the committed five-panel summary figure:
     `results/presentation/simulink_district_summary.png`
     Panels: patient funnel, referral volume, specialist queue/backlog,
     specialist utilisation, referral workload vs threshold.
- **Say** (script §Shot 7):
  > "Scale. This is a real Simulink model, running our measured sensitivity and
  > specificity through a district year. At a hundred thousand patients:
  > ninety-six thousand screened, thirty-eight thousand four hundred referrals,
  > a hundred fifty-three point six a day. The queue only clears near a hundred
  > eighty reviews a day. This is an engineering simulation."
- **Must be visible:** the `.slx` block diagram in shot 7a; in 7b, the funnel
  panel with `96,081` / `38,406` and the utilisation panel where the
  `180 reviews/day` scenario drops utilisation to 85.3% with a zero
  year-end backlog. Point at the queue panel, not the funnel, when you say
  "the queue only clears".
- **Traceability:** `data/analysis/simulink_resource_simulation/scenario_results.csv`
  — row `D100` (annualVolume 100000, annualAiScreened 96081.4,
  annualReferrals 38406.3, referralsPerDay 153.63) and row `E180`
  (capPerDay 180, utilizationPct 85.3, yearEndBacklog 0, flag "Review capacity
  sufficient"). The 60.03% not-referred figure is
  `results/presentation/simulink_district_summary.txt`. Model file built by
  `src/simulink/build_DrishtiCare_DistrictScreening.m`; the committed README
  header reads *"ENGINEERING / RESOURCE-PLANNING SIMULATION - NOT clinical
  validation."*

> **⚠ SAY IT EXACTLY THIS WAY.** "Engineering simulation." Not "model", not
> "prediction", not "forecast". The volume, prevalence and review-capacity
> numbers are labelled **assumptions** in
> `data/analysis/simulink_resource_simulation/README.md` §4. If a judge asks,
> the honest answer is in §4 of that README.

> **⚠ RE-CHECK BEFORE RECORDING.** Re-open
> `results/presentation/simulink_district_summary.png` and confirm the numbers
> in the figure still read 96,081 / 38,406 / 153.6 / 180. If the figure was
> regenerated, re-read the CSV before recording and update the script.

---

### Shot 8 — 2:30 → 2:54 (24 s) — Honest limitations (deliberate, not defensive)

- **Show:** stay on the **withheld** screen from shot 4 (the FAIL dashboard).
  Framing choice: we are listing limitations *on top of the screen where the
  system refused to answer* — it reads as composure, not as an apology. Do not
  switch to slides here.
- **Image file:** none to load; `data/splits/val/class_1/cae51154e1ce.png`
  remains the loaded image.
- **Say** (script §Shot 8):
  > "Three things we have not done. External validation is blocked on dataset
  > access — the harness is written but has not been run on external data.
  > Severe and proliferative recall is weaker than the headline number. And on
  > nineteen unseen images the gate refused forty-two percent of the time, and
  > let one bad image through anyway. We did not tune that away; it's locked."
- **Must be visible:** the REJECT badge and the *"AI GRADING: SKIPPED"* status
  line still on screen behind the narration, plus the footer metric strip
  (`RetinaAIApp.m:643-649`) reading *"Accuracy 82.81% · Referable sensitivity
  90.60% · Specificity 94.71% · APTOS held-out validation · Prototype, not
  clinically validated"*. That last clause is the visual anchor for this shot.
- **Traceability:**
  - external validation blocked: `docs/validation/2026-09-08-task10-external-validation-status.md`,
    harness written and passing, labelled data not obtained.
  - Severe/Proliferative recall weaker: `docs/validation/metrics.md`; already
    narrated in `pitch/demo-script.md` Act 6.
  - 19 unseen images, 8 withheld = 42%: `data/analysis/day11/rehearsal/unseen_rehearsal_results.csv`
    (19 data rows; `quality = FAIL` on 8 of them) and
    `docs/validation/2026-09-26-unseen-input-rehearsal.md` §2.
  - "let one bad image through": `drimdb_bad (10).jpg` → quality PASS, grade 4,
    pRef 0.9690, route CLEAR, REFERABLE. Same CSV, same rehearsal doc §4.
    **This sentence is the reason we never demo that image and never claim the
    gate catches every ungradable image.** It is stated on camera on purpose.

> **⚠ RE-CHECK BEFORE RECORDING.** If the rehearsal is ever re-run, the
> 8-of-19 and 42% figures move. Re-read
> `data/analysis/day11/rehearsal/unseen_rehearsal_results.csv` and update the
> count in the script before you record.

---

### Shot 9 — 2:54 → 3:00 (6 s) — Close

- **Show:** the dashboard at rest on the PASS result, no cursor movement.
- **Image file:** none to load.
- **Say** (script §Shot 9):
  > "DrishtiCare. AI-assisted screening, specialist in the loop. Thank you."
- **Must be visible:** the DRISHTI header and the footer line
  *"Human-in-the-loop: final clinical decision by a qualified ophthalmologist."*
  Keep both in frame for the full 6 s — do not fade to black early.
- **Traceability:** claims vocabulary from
  `docs/project-management/DEMO_AND_SUBMISSION_PLAN.md` §5.

---

## 3. Banned words and banned footage (hard rules)

### Never say

| Banned | Say instead |
|---|---|
| "lesion localisation" / "lesion localization" (for Grad-CAM) | "model attention" / "attention visualisation" |
| "clinically validated" | "held-out validation on 733 APTOS images" |
| "doctor-level" / "replaces doctors" / "diagnoses with certainty" | "AI-assisted screening" / "specialist review" |
| "we automate 80% of screening" | "60.03% are not referred at the locked 0.60 threshold" |
| "the model found the haemorrhages" | "the model's attention concentrated here" |
| "real-time" (about inference) | "a few seconds per image on this laptop" |

The "80%" trap is real: **no artifact in this repo produced 80%.** The measured
figure is 60.03% not-referred (`results/presentation/simulink_district_summary.txt`).
See also `pitch/demo-script.md` Act 5's explicit warning.

### Never show

1. **`data/drimdb/DRIMDB/Bad/drimdb_bad (10).jpg`.** Do not demo it, do not
   offer it if a judge asks for "a bad one from outside", and do not show it in
   a thumbnail. It produces a **confident referable grade 4 (pRef 0.9690, route
   CLEAR) on an image DRIMDB itself labels Bad** — i.e. not diagnosable. Both
   the quality gate and the OOD gate missed it. If you show it, you have shown
   a false positive and you will be asked to defend it live.
   Source: `docs/validation/2026-09-26-unseen-input-rehearsal.md` §4.
2. **Any hardcoded result.** Every number on camera must come from a live
   inference or from a committed artifact that names its source file. The demo
   is graded under SIH guidance that says explicitly *"Demo live, not
   hardcoded"* (`docs/background/sih-logistics.md`). If the app is not running,
   cut to shot 8 and finish — do **not** show a pre-rendered results slide as
   if it were live.
3. **Any number you cannot name a file for.** If a judge asks for a figure you
   do not have measured, the correct answer is *"I don't have that measured"* —
   not an estimate.

### Never claim

- Do **not** claim the quality gate catches every ungradable image. It does not
  — `drimdb_bad (10).jpg` is the counter-example and shot 8 says so out loud.
- Do **not** claim external validation has been performed. It has not.
- Do **not** call the Simulink district model a clinical or staffing result.
  "Engineering simulation", every time.

---

## 4. Pre-flight checklist (do all of this before you press record)

**Launch and path**

- [ ] **P1 — Launch via `launchRetinaAI.m`, never by calling `predictSingleFundus`
      directly.** `predictSingleFundus.m:47` self-bootstraps only *part* of the
      `src` tree; it relies on the caller having already set up the path. From a
      clean MATLAB session it will fail with `Undefined function`. Only
      `launchRetinaAI.m:9-10` and `RetinaAIApp.m:132-133` do the full
      `addpath(genpath(fullfile(projectRoot,'src')))`. Launch with:
      ```matlab
      cd('C:\projects\DrishtiCare')
      launchRetinaAI
      ```
- [ ] **P2 — Launch the app 5+ minutes before recording** and let MATLAB's JIT
      warm up. The committed audit log shows the *first* inference in a session
      at **13.41 s** (`case_pass_referable`) and later calls at **6.38 s** and
      **1.36 s** (`case_warning`). Run one throwaway analysis before you record
      so the on-camera inference is in the fast band.
- [ ] **P3 — Demo on APTOS-resolution images only.** On 512×512 APTOS val
      images the app's analyze step is in the **~1–3 s** band. On a full
      resolution 4288×2848 fundus photograph (e.g. an IDRiD frame) the measured
      median is **35.6 s** — the rehearsal's high-resolution band is
      **~30–45 s**. It completes correctly, it does not hang, but it will stall
      a 3-minute video. Source:
      `docs/validation/2026-09-26-unseen-input-rehearsal.md` §5, and
      `data/analysis/day11/rehearsal/unseen_rehearsal_results.csv`
      (`seconds` column, IDRiD rows 30.8 / 43.6 / 38.2 / 35.6).
- [ ] **P4 — Pre-stage both images and pre-navigate the file dialog.** The app's
      sample dropdown (`RetinaAIApp.m:652-671`) only lists the **first three
      files per class folder** of `data/splits/val`. Neither
      `class_2/77f69c7ff324.png` nor `class_1/cae51154e1ce.png` is in that list,
      so **you must use the Upload Image button** for shots 3, 4 and 5. Open
      File Explorer on `C:\projects\DrishtiCare\data\splits\val\class_2` and
      `...\val\class_1` before you start so the dialog opens in the right place.
- [ ] **P5 — Delete stale report PDFs** from `results/` before recording
      (`DrishtiScreeningReport_*.pdf`) so the one you generate in shot 6 is
      unambiguous.
- [ ] **P6 — Verify the two shot-4 strings are on screen at your zoom:**
      *"No Grad-CAM: analysis withheld (quality FAIL)"* and *"AI GRADING: SKIPPED
      (model stack not executed)"*.
- [ ] **P7 — Verify the explainability disclaimer is legible:**
      *"Model attention visualization - not validated lesion localization."*
- [ ] **P8 — Open `src/simulink/DrishtiCare_DistrictScreening.slx` once, ahead of
      time, so Simulink's cold start is not inside shot 7.**
- [ ] **P9 — Confirm `results/presentation/simulink_district_summary.png` is the
      current version** (compare against `scenario_results.csv` rows D100/E180).
- [ ] **P10 — Confirm you have read `pitch/VOICEOVER-SCRIPT.md` end to end, and
      that every ⚠ item there has been re-checked against a live run.**
- [ ] **P11 — Set the recording window to a fixed size** (1920×1080 if the
      display allows) so the dashboard layout does not reflow between shots.
      Never zoom the app mid-take.
- [ ] **P12 — Rehearse the full 9-shot sequence twice with a stopwatch** before
      recording. Target 2:55–3:00 on the timing slates.

**Camera/mic**

- [ ] P13 — Narration pace ~150 wpm. 435 words + 3 marked pauses = 3:00.
- [ ] P14 — Do a 20 s audio-only test take and check levels before the real take.

---

## 4b. Contingency: "if a judge feeds a surprise image"

This is the SIH Grand Finale scenario (`docs/background/sih-logistics.md`:
"Judges may feed surprise inputs"). Rehearse it out loud; do not improvise it.

### The rule

The system has exactly two honest outcomes, and **both are designed behaviour**:

1. it returns a grade with a confidence band, or
2. it refuses and asks for a recapture.

### The script — say this, close to word for word

> "Load it. [pause while it runs]
>
> Either of two things just happened, and both are designed. The image passed
> our quality gate, so the model graded it and you get a severity grade, a
> referable score with a confidence band, and a Grad-CAM attention map. Or it
> failed the gate, in which case you get no grade at all — the screen says AI
> grading skipped and asks for a recapture. We cannot hide the second case: on
> nineteen fundus photographs from three cameras the model had never seen, the
> gate refused **eight of them — forty-two percent**. That is a high refusal
> rate, and it is the safe direction to fail in, because a refused image is
> never auto-answered.
>
> I want to be straight with you about the failure mode too. That rehearsal also
> found one image the dataset itself labels ungradable, and our system graded it
> confidently as referable. Neither the quality gate nor the out-of-distribution
> gate caught it. We did not retune the threshold to hide that, because the
> threshold's provenance is pinned, and a system that has been tuned until its
> known failure disappears is a system you cannot trust on the image you have
> never seen."

### Numbers you are allowed to quote here (and nothing else)

| Claim | Value | Source |
|---|---|---|
| Unseen images run | 19, all completed, 0 crashes | `data/analysis/day11/rehearsal/unseen_rehearsal_results.csv` (19 rows) |
| Withheld (quality FAIL) | 8 of 19 = **42%** | same CSV, `quality` column |
| Same gate on APTOS train | 7.84% FAIL (n=3,662) | `docs/validation/metrics.md` |
| Route bands used | CLEAR / REVIEW / ABSTAIN | `src/inference/cascade_router.m` |
| The known false positive | `drimdb_bad (10).jpg` → PASS, grade 4, pRef 0.9690, CLEAR, REFERABLE | rehearsal CSV + `docs/validation/2026-09-26-unseen-input-rehearsal.md` §4 |

### Latency warning to have ready

If the judge's image is high resolution, **say this while it is still running**,
so the wait is narrated rather than awkward:

> "This is a full-resolution frame — 4288 by 2848. On our rehearsal set those
> take thirty to forty-five seconds. It completes; it is just doing far more
> pixel work than our 512-pixel validation images. That is a measured number
> from our own rehearsal, not a guess."

If it is a foreign camera and the gate refuses quickly (the common case —
0.5–2.4 s for the small unseen frames), the pause is short; do not narrate
filler over it.

### Things **not** to say to a judge

- Do not say the gate catches every ungradable image.
- Do not say the system is safe to deploy autonomously.
- Do not offer `drimdb_bad (10).jpg` as a demo image, even if they ask for
  "another bad one".
- Do not estimate an unmeasured number. *"I don't have that measured"* is a
  complete answer.

---

## 5. Final assembly — a HUMAN step (no ffmpeg on this machine)

**Nothing in this repository can produce the MP4.** Verified absent on this
machine: `ffmpeg`, `ffprobe`, `obs64`, `DaVinci Resolve`, `Clipchamp`,
`Audacity`, `vlc`. Do not try to script the assembly here.

### Recommended path (single pass, no external tool needed beyond one install)

1. **Install OBS Studio** (free, Windows) from https://obsproject.com.
2. In OBS: *Sources* → **+** → **Window Capture** → pick the MATLAB window.
   Set the canvas to **1920×1080**, FPS **30**. In *Settings → Output* set
   **Recording Path** to `C:\projects\DrishtiCare\pitch\` and the format to
   **MKV** (do not record MP4 directly — a crash corrupts an MP4 but not an MKV).
3. In *Settings → Audio*, enable **Mic/Aux** and set
   **Audio Track 2 = "Mic/Aux"** so narration lands on a separate track.
4. Do a full 9-shot run following §2, speaking `pitch/VOICEOVER-SCRIPT.md`
   verbatim. You do not need to stop between shots — but *do* leave the 2 s
   silence at the marked PAUSE in shot 4, because that pause is the beat.
5. Stop recording. **File ▸ Remux Recordings** → select the `.mkv` → remux to
   `.mp4`. This is built into OBS, is a container copy (no re-encode, no
   quality loss), and **requires no ffmpeg on your PATH**.
6. Upload the resulting MP4. If the portal caps file size and you need to
   re-encode, use **DaVinci Resolve (free)** or the **Clipchamp** app that
   ships with Windows 11 — both encode H.264 MP4 with a GUI, and neither needs
   an ffmpeg CLI.

### If you want narration recorded separately (recommended if the room is noisy)

- Record the voice take in a second OBS pass (or in Audacity, free) against a
  clap, then sync and mix in **DaVinci Resolve → Edit → Fairlight** (free) and
  export H.264/AAC MP4. This is the cleanest way to get consistent levels
  across shots, and it is the only part of the pipeline that genuinely needs a
  second tool.

### What the agent did **not** do

- Did not create, trim, encode, mux or caption an MP4.
- Did not generate a voiceover audio track.
- Did not modify `src/dashboard/run_drishti_visual_qa.m` or any other existing
  file.

---

## 6. Real captured frames (what actually ran)

`src/dashboard/run_drishti_visual_qa.m` was executed **unmodified** in this
environment (MATLAB R2026a Update 5, 26.1.0.3346908, `-batch`, headless).

- **Result: ran cleanly. No errors. 20 PNG frames written.**
- **Output location:** `C:\projects\DrishtiCare\results\visual_qa\`
- **Frames (all written 2026-09-26, 00:52–00:53):**
  - `01_dashboard_idle.png`
  - `02_PASS_dashboard.png`, `03_PASS_Original.png`, `03_PASS_Enhanced.png`,
    `03_PASS_Grad-CAM.png`, `03_PASS_Overlay.png`, `04_PASS_fundus.png` (6)
  - `02_WARNING_dashboard.png`, `03_WARNING_Original.png`,
    `03_WARNING_Enhanced.png`, `03_WARNING_Grad-CAM.png`,
    `03_WARNING_Overlay.png`, `04_WARNING_fundus.png` (6)
  - `02_FAIL_dashboard.png`, `03_FAIL_Original.png`, `03_FAIL_Enhanced.png`,
    `03_FAIL_Grad-CAM.png`, `03_FAIL_Overlay.png`, `04_FAIL_fundus.png` (6)
  - `05_report_preview.png` (1)
- **Cases the capture drove** (printed by the script, from the real dropdown /
  ANALYZE callbacks):
  - PASS `data/splits/val/class_0/0212dd31f623.png`
  - WARNING `data/splits/val/class_0/005b95c28852.png`
  - FAIL `data/splits/val/class_2/026dcd9af143.png`
- **Two new side artifacts** the script wrote as part of its normal run (report
  generation for the preview shot), both new files, neither overwriting an
  existing one:
  - `results/DrishtiScreeningReport_005b95c28852_20260926_005327.html`
  - `results/DrishtiScreeningReport_005b95c28852_20260926_005327.pdf`
    (3,119,259 bytes — a real A4 PDF on disk, which is the artifact shot 6
    needs)
- **No frames were copied, renamed, or presented as new.** The 20 files above
  are genuine captures from this run. Frames were not copied anywhere else and
  no screenshot is being passed off as a fresh capture.
- **Useful for the video:** `05_report_preview.png` is a rendered preview of the
  real report layout and is a legitimate cutaway for shot 6 if the on-camera
  File Explorer window is slow to open — but shot 6 should still show the PDF
  *file* being produced, because "a real artifact on disk" is the claim.

---

## 7. Artifact index (everything this plan cites)

| Used for | File |
|---|---|
| Required demo story, claims policy | `docs/project-management/DEMO_AND_SUBMISSION_PLAN.md` |
| Unseen-input rehearsal (42%, 35.6 s, `drimdb_bad (10)`) | `docs/validation/2026-09-26-unseen-input-rehearsal.md` |
| Rehearsal raw data | `data/analysis/day11/rehearsal/unseen_rehearsal_results.csv` |
| SIH rules, "demo live not hardcoded" | `docs/background/sih-logistics.md` |
| App source (badges, chips, disclaimer, skip message) | `RetinaAIApp.m` |
| Launcher (the only correct launch path) | `launchRetinaAI.m` |
| Failure-aware driver | `src/demo/run_failure_aware_demo.m` |
| Case selection (deterministic, real images) | `src/demo/select_demo_cases.m` |
| Per-case audit numbers for shots 3 and 4 | `data/analysis/failure_aware_demo/audit_log.csv` |
| Failure-aware narrative + limitations | `data/analysis/failure_aware_demo/README.md` |
| Workflow / hard-gate cutaway figure | `data/analysis/failure_aware_demo/figures/failure_aware_workflow.png` |
| Quality gate distribution figure | `data/analysis/failure_aware_demo/figures/quality_gate_summary.png` |
| Grad-CAM alignment (3.1% / 7.4%) | `data/analysis/gradcam_lesion_alignment/README.md` |
| Report generator, section order, footer | `src/reporting/generateDrishtiReport.m` |
| Simulink model | `src/simulink/DrishtiCare_DistrictScreening.slx` |
| Simulink scenarios (D100, E180) | `data/analysis/simulink_resource_simulation/scenario_results.csv` |
| Simulink assumptions + disclaimer | `data/analysis/simulink_resource_simulation/README.md` |
| Five-panel Simulink summary figure | `results/presentation/simulink_district_summary.png` |
| Same figures as text (for narration check) | `results/presentation/simulink_district_summary.txt` |
| Frozen metric set | `docs/validation/metrics.md` |
| Longer stage script (6–8 min) | `pitch/demo-script.md` |
| Headless capture (ran, 20 frames) | `src/dashboard/run_drishti_visual_qa.m` → `results/visual_qa/` |

---

## 8. If you have to cut for time

Priority order if you are over 3:00 — cut in this sequence, never higher:

1. Shot 2, workflow beat → 0 s (the chips are visible in every other shot anyway).
2. Shot 1, hook → 6 s.
3. Shot 6, report → 14 s (show the file, trim the narration to one sentence).
4. Shot 7, Simulink → 16 s (drop the 96,081 / 38,406 pair, keep 153.6 and 180).

**Never cut shot 4** (the refusal), **never cut shot 8** (the limitations), and
**never cut the "model attention, not lesion localisation" line** in shot 5.
Those three are the video.
