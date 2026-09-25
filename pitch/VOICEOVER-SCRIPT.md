# DrishtiCare — Voiceover Script (word for word)

**Companion to:** `pitch/video-plan.md` (9 shots, target **3:00**)
**Total words: 435. Target pace: 150 words/minute. Three marked `[PAUSE]`s.**

Read it exactly as written. Where a sentence is marked **⚠ RE-CHECK**, confirm
it against a live run on the recording machine **before you record**, then keep
it or replace it with what the screen actually shows. Never keep a stale number
because it sounds good.

Two hard rules that override everything else in this file:

1. **Grad-CAM is "model attention".** Never "lesion localisation".
2. **The Simulink model is "an engineering simulation".** Never "a model of
   the district", never "a forecast", never "a staffing recommendation".

---

## How to pace it

| Shot | In–out | Dur | Words | Speech time @150wpm | Slack |
|---|---|---:|---:|---:|---:|
| 1 | 0:00–0:10 | 0:10 | 20 | 0:08 | 0:02 |
| 2 | 0:10–0:20 | 0:10 | 22 | 0:09 | 0:01 |
| 3 | 0:20–0:44 | 0:24 | 59 | 0:24 | 0:00 |
| 4 | 0:44–1:22 | 0:38 | 95 | 0:38 | 0:00 + a 0:02 marked pause |
| 5 | 1:22–1:48 | 0:26 | 68 | 0:27 | −0:01 (speak 2 wpm faster) |
| 6 | 1:48–2:08 | 0:20 | 45 | 0:18 | 0:02 |
| 7 | 2:08–2:30 | 0:22 | 53 | 0:21 | 0:01 |
| 8 | 2:30–2:54 | 0:24 | 64 | 0:26 | −0:02 (speak 2 wpm faster) |
| 9 | 2:54–3:00 | 0:06 | 9 | 0:04 | 0:02 |
| **Total** | | **3:00** | **435** | **2:54** | **0:06 of slack** |

The 0:06 of slack is the three `[PAUSE]`s. If a take runs long, cut the three
sentences listed under §Trim before you cut anything else.

---

## SHOT 1 — 0:00 → 0:10 (10 s)

> This is DrishtiCare — a diabetic-retinopathy screening prototype, built for
> the case where the AI is not allowed to answer.

*Delivery:* let the dashboard sit for ~2 s of silence before the first word.
**No numeric claim.**

---

## SHOT 2 — 0:10 → 0:20 (10 s)

> Here is the whole path, top to bottom: image, quality, screening, evidence,
> report — and then a person makes the final call.

*Delivery:* trace the five chips with the cursor, left to right. No numbers.

---

## SHOT 3 — 0:20 → 0:44 (24 s)

> This is a real held-out image. Quality returns ACCEPT. The model returns grade
> four, proliferative, model score one — so it routes REFERABLE. In our
> committed run on this exact file that is what happened: grade four, referable,
> uncertainty router CLEAR. And the footer says the final clinical decision is
> the ophthalmologist's.

**Claims and where they come from**

| Spoken | Value | Source file |
|---|---|---|
| "grade four, proliferative" | grade 4, label `Proliferative` | `data/analysis/failure_aware_demo/audit_log.csv`, row `case_pass_referable` |
| "model score one" | `referable_probability = 1` | same row |
| "REFERABLE" | `binary_decision = REFERABLE` | same row |
| "uncertainty router CLEAR" | `cascade_route = CLEAR` | same row |
| "final clinical decision is the ophthalmologist's" | footer string | `RetinaAIApp.m:640` |
| image identity | `data/splits/val/class_2/77f69c7ff324.png` | `data/analysis/failure_aware_demo/demo_cases.csv` |

> **⚠ RE-CHECK BEFORE RECORDING — "grade four" and "model score one".**
> The committed log is from 2026-09-21. Re-load and re-analyse
> `data/splits/val/class_2/77f69c7ff324.png` on the recording machine. If the
> dashboard shows anything other than grade 4 / 100%, **say the number the
> screen shows.** Do not say "one" because the CSV says 1.
>
> **⚠ RE-CHECK — "uncertainty router CLEAR".** This is the sentence most likely
> to confuse a judge, because the patient is REFERABLE *and* the router says
> CLEAR. The two mean different things: CLEAR is the *uncertainty* band
> (`src/inference/cascade_router.m` → the auto-answer subset), not a clinical
> clearance. If a judge looks confused, add the clarifying half-sentence:
> "CLEAR means the model was confident — it is not a clearance for the patient."

---

## SHOT 4 — 0:44 → 1:22 (38 s) — longest shot, do not rush it

> Now the important one. This is also a real held-out image, and it fails our
> own quality gate. The badge says REJECT. It names the reason: too dark, very
> low contrast, blurry. Focus measured nine-point-seven times ten to the minus
> five, against a fail threshold of one-point-four-two times ten to the minus
> four.
>
> `[PAUSE — 2 seconds of silence. Let them read the empty grade field. Do not
> talk over it. This silence is the shot.]`
>
> Notice what is missing. No grade. No heat map. The status line reads AI
> grading skipped, model stack not executed. That is not a suppressed display —
> in our committed run, predictSingleFundus was never called for any of the
> six failing images.

**Claims and where they come from**

| Spoken | Value | Source file |
|---|---|---|
| image identity | `data/splits/val/class_1/cae51154e1ce.png` | `data/analysis/failure_aware_demo/demo_cases.csv`, `case_fail_blur` |
| "badge says REJECT" | `quality_status = FAIL` → `REJECT (FAIL)` | audit_log row `case_fail_blur`; `RetinaAIApp.m:859` |
| "too dark, very low contrast, blurry" | `quality_reason` string, 3 clauses | audit_log row `case_fail_blur` |
| "focus measured nine-point-seven times ten to the minus five" | `primary_value = 9.69488461572011e-05` | audit_log row `case_fail_blur` |
| "fail threshold one-point-four-two times ten to the minus four" | `primary_threshold = 0.000142`, `primary_bound = lowerFail` | audit_log row `case_fail_blur` |
| "no grade" | `grade = NaN`, label `NOT ASSESSED (quality FAIL)` | audit_log row `case_fail_blur` |
| "no heat map" | `gradcam_available = 0` → *"No Grad-CAM: analysis withheld (quality FAIL)"* | audit_log row; `RetinaAIApp.m:947` |
| "AI grading skipped, model stack not executed" | status line text | `RetinaAIApp.m:964` |
| "not a suppressed display … never called" | `inference_executed = 0`, `engine = "quality-gate-skip (predictSingleFundus NOT called)"` | audit_log row `case_fail_blur` |
| "any of the six failing images" | 6 `FAIL` rows, all `inference_executed = 0` | `data/analysis/failure_aware_demo/audit_log.csv` |

> **⚠ RE-CHECK BEFORE RECORDING — the focus number and threshold.** Read them
> off the live quality table, not off this document. The CSV carries 15
> significant figures; the screen may show a rounded value. Say the rounded
> value that is on screen and treat that as the truth. Quality thresholds are
> Day-3 APTOS percentiles and provenance-pinned, so they will not have moved —
> but confirm anyway, it costs 20 seconds.
>
> **⚠ RE-CHECK — "six failing images".** Count the `FAIL` rows in
> `audit_log.csv` on the day you record. It was 6 on 2026-09-21.
>
> **⚠ NEVER substitute** `data/drimdb/DRIMDB/Bad/drimdb_bad (10).jpg` for this
> image. See shot 8 and `video-plan.md` §3.

---

## SHOT 5 — 1:22 → 1:48 (26 s)

> Four views on one image: original, enhanced, Grad-CAM, overlay. And I want to
> be precise about this heat map. It is the model's attention — the regions that
> most influenced the decision. It is not lesion localisation. We measured that
> ourselves: on IDRiD lesion masks, three-point-one percent of saliency mass
> lands inside a lesion. The pointing game hits seven-point-four. We did not
> retrain to chase a better number.

**Claims and where they come from**

| Spoken | Value | Source file |
|---|---|---|
| four view buttons | `Original / Enhanced / Grad-CAM / Overlay` | `RetinaAIApp.m:407` |
| "model attention" | panel titles *"Grad-CAM Attention Map (model attention)"*, *"attention blend"* | `RetinaAIApp.m:910-911` |
| "not lesion localisation" | on-screen disclaimer *"Model attention visualization - not validated lesion localization."* | `RetinaAIApp.m:463` |
| "IDRiD lesion masks" | 81 valid image+mask pairs, MA/HE/EX/SE | `data/analysis/gradcam_lesion_alignment/README.md` §Dataset Audit |
| "three-point-one percent of saliency mass lands inside a lesion" | `Saliency mass in lesion: 0.031` | same README, §Aggregate Results → Overall |
| "pointing game hits seven-point-four" | `Pointing-game accuracy: 0.074` | same README, §Aggregate Results → Overall |
| "did not retrain to chase a better number" | stated as an offline-analysis-only experiment | same README header: *"This is an offline analysis experiment only. No training, no model modification…"* |

> **⚠ THIS IS THE MOST IMPORTANT SENTENCE IN THE VIDEO.** "It is the model's
> attention … it is not lesion localisation." Deliver it slowly and do not
> paraphrase. Judges have heard "lesion localisation" claimed for Grad-CAM by
> other teams; being the team that refuses the claim is a differentiator.
>
> **⚠ RE-CHECK — the two alignment numbers.** Re-read
> `data/analysis/gradcam_lesion_alignment/README.md` on the day you record. The
> experiment is frozen, so 0.031 and 0.074 should be unchanged, but confirm.
>
> **Optional honesty add-on, only if you have 4 spare seconds** (do not add it
> if you are over time): "…and the on-screen disclaimer says exactly that, in
> those words."

---

## SHOT 6 — 1:48 → 2:08 (20 s)

> One click and the same result structure becomes a real A4 PDF on disk, in
> results, timestamped. Screening summary, grade, quality table, the Grad-CAM
> evidence, interpretation, recommendation, and a footer that says this is not a
> clinical device. Same struct, same numbers, not a screenshot.

**Claims and where they come from**

| Spoken | Value | Source file |
|---|---|---|
| "one click … A4 PDF on disk" | `Save PDF Report` → `generateDrishtiReport` writes `DrishtiScreeningReport_<patientID>_<yyyyMMdd_HHmmss>.pdf` | `RetinaAIApp.m:484,580`; `src/reporting/generateDrishtiReport.m` header |
| "same result structure" | the report consumes the *same* `result` struct the dashboard renders | `src/reporting/generateDrishtiReport.m` header comment |
| the seven sections, in order | 1 Screening Summary · 2 DR Grade · 3 Quality Assessment · 4 Visual Evidence (Grad-CAM) · 5 Interpretation · 6 Recommendation · footer | `src/reporting/generateDrishtiReport.m`, `buildDrishtiReportBlocks` |
| "footer … not a clinical device" | footer text *"…ENGINEERING DEMO screening prototype (DRISHTI). It is NOT a clinical device…"* | same function, final `blocks{end+1}` |

> **⚠ Do not name the rendering engine on camera.** The generator has tier-1
> (MATLAB Report Generator) and tier-2 (headless Edge) paths and picks at
> runtime. On this machine the tier-2 path fired (a `.html` sibling appears next
> to the `.pdf`). The script says "A4 PDF" so it is correct either way. Leave
> it there.
>
> **⚠ RE-CHECK** that the report actually writes to disk on the recording
> machine before you record shot 6 — and clear stale
> `results/DrishtiScreeningReport_*.pdf` first so the new file is unambiguous.

---

## SHOT 7 — 2:08 → 2:30 (22 s)

> Scale. This is a real Simulink model, running our measured sensitivity and
> specificity through a district year. At a hundred thousand patients:
> ninety-six thousand screened, thirty-eight thousand four hundred referrals, a
> hundred fifty-three point six a day. The queue only clears near a hundred
> eighty reviews a day. This is an engineering simulation.

**Claims and where they come from**

| Spoken | Value | Source file |
|---|---|---|
| "a real Simulink model" | `src/simulink/DrishtiCare_DistrictScreening.slx` (genuine OPC/zip container, 25 entries incl. `simulink/blockdiagram.xml`) | `docs/task-tracker.md` row S1 |
| "our measured sensitivity and specificity" | 0.9060 / 0.9471 @ locked 0.60, n=733 | `data/analysis/simulink_resource_simulation/README.md` §3 Measured Inputs |
| "a hundred thousand patients" | `annualVolume = 100000` (labelled *planning assumption*) | `scenario_results.csv` row `D100`; README §4 Assumptions |
| "ninety-six thousand screened" | `annualAiScreened = 96081.4` | `scenario_results.csv` row `D100` |
| "thirty-eight thousand four hundred referrals" | `annualReferrals = 38406.3` | `scenario_results.csv` row `D100` |
| "a hundred fifty-three point six a day" | `referralsPerDay = 153.63` | `scenario_results.csv` row `D100` |
| "queue only clears near a hundred eighty reviews a day" | `capPerDay = 180` → `utilizationPct = 85.3`, `yearEndBacklog = 0`, flag *"Review capacity sufficient"* | `scenario_results.csv` row `E180` |
| "an engineering simulation" | header *"ENGINEERING / RESOURCE-PLANNING SIMULATION - NOT clinical validation."* | `data/analysis/simulink_resource_simulation/README.md` line 3 |

> **⚠ "This is an engineering simulation" is mandatory.** Do not drop it, do
> not soften it to "just a model". Volume (100,000/yr), prevalence (40.65%),
> specialist capacity and recapture rate are **explicitly labelled assumptions,
> not measurements** (README §4). If a judge asks where 100,000 came from, the
> correct answer is: "it is our stated planning assumption, and the model is
> parameterised so you can change it — that is the point of shipping the
> simulation rather than the number."
>
> **⚠ RE-CHECK** the four figures against
> `data/analysis/simulink_resource_simulation/scenario_results.csv` on the day
> you record, and confirm `results/presentation/simulink_district_summary.png`
> is the current render.
>
> **Note what is deliberately *not* said:** the 60.03% not-referred figure and
> the 7.68 specialists figure are available in the same artifacts but are left
> out to protect the 22 s budget. If you have 3 spare seconds, the safe one to
> add is: "Sixty percent never reach a specialist at all."
> **Never say "we automate 80% of screening"** — no artifact in this repo
> produced 80%.

---

## SHOT 8 — 2:30 → 2:54 (24 s) — say this slowly; it is not an apology

> Three things we have not done. External validation is blocked on dataset
> access — the harness is written but has not been run on external data. Severe
> and proliferative recall is weaker than the headline number. And on nineteen
> unseen images the gate refused forty-two percent of the time, and let one bad
> image through anyway. We did not tune that away; it's locked.

**Claims and where they come from**

| Spoken | Value | Source file |
|---|---|---|
| "external validation is blocked on dataset access" | Messidor-2 and Sin-NP DR 2019 both require human download / registration; harness written, 6/6 checks pass on the locked split, not run on labelled external data | `docs/validation/2026-09-08-task10-external-validation-status.md`; `pitch/demo-script.md` Act 6 |
| "Severe and proliferative recall is weaker than the headline number" | per-class recall on grades 3 and 4 lags the macro figures | `docs/validation/metrics.md`; `DEMO_AND_SUBMISSION_PLAN.md` §2 Beat 5 |
| "nineteen unseen images" | 19 rows, `completed = 1` for all, 0 crashes | `data/analysis/day11/rehearsal/unseen_rehearsal_results.csv` |
| "refused forty-two percent of the time" | 8 of 19 `quality = FAIL` → 42% | same CSV; `docs/validation/2026-09-26-unseen-input-rehearsal.md` §2 |
| "let one bad image through anyway" | `drimdb_bad (10).jpg`: quality **PASS**, grade **4**, pRef **0.9690**, route **CLEAR**, decision **REFERABLE** | same CSV; rehearsal doc §4 |
| "we did not tune that away; it's locked" | the finding must not be fixed by re-tuning: threshold and OOD bound are provenance-pinned (Phase 6, Phase 9) | rehearsal doc §4; `docs/validation/2026-09-10-hardening-phase6-decision-lock.md` |

> **⚠ THE MOST IMPORTANT SENTENCE IN THE VIDEO — "let one bad image through
> anyway."** This is a real, recorded negative result about our own system on an
> image the dataset itself labels ungradable. It is in the video **on purpose**.
> Never soften it to "occasionally it is conservative", and never pair it with a
> claim that the gate catches every ungradable image. It does not. Say it, then
> say why you did not tune it away.
>
> **⚠ RE-CHECK** the 19 / 8 / 42% figures on the day you record. They come from
> a frozen CSV, so they should not move — but if the rehearsal is ever re-run,
> update this sentence *and* the contingency script in `video-plan.md` §4b.

---

## SHOT 9 — 2:54 → 3:00 (6 s)

> DrishtiCare. AI-assisted screening, specialist in the loop. Thank you.

*Delivery:* hold the closing frame for the full 6 s. Do not fade early.
Vocabulary is taken directly from the approved claims policy
(`docs/project-management/DEMO_AND_SUBMISSION_PLAN.md` §5).

---

## §Trim — cut these three sentences first if a take runs over 3:00

In this order. Each is worth roughly 4–6 seconds.

1. Shot 3, last sentence: *"And the footer says the final clinical decision is
   the ophthalmologist's."* (13 words) — the same footer is visible on screen
   anyway.
2. Shot 5, last sentence: *"We did not retrain to chase a better number."*
   (8 words)
3. Shot 6, second half: *"Same struct, same numbers, not a screenshot."*
   (7 words)

**Do not cut:** anything in shot 4; anything in shot 8; the sentence *"It is the
model's attention … it is not lesion localisation."*; or the sentence *"This is
an engineering simulation."*

---

## §If a judge feeds a surprise image (spoken, not in the 3:00 cut)

The 3:00 video has no room for this, so it is a **stage** script. Rehearse it
out loud. Full contingency detail is in `video-plan.md` §4b.

> Either of two things just happened, and both are designed. The image passed our
> quality gate, so the model graded it and you get a severity grade, a referable
> score with a confidence band, and a Grad-CAM attention map. Or it failed the
> gate, in which case you get no grade at all — the screen says AI grading
> skipped and asks for a recapture. On nineteen fundus photographs from three
> cameras the model had never seen, the gate refused eight of them, forty-two
> percent. That is a high refusal rate, and it is the safe direction to fail in,
> because a refused image is never auto-answered.
>
> I want to be straight with you about the failure mode too. That rehearsal also
> found one image the dataset itself labels ungradable, and our system graded it
> confidently as referable. Neither the quality gate nor the out-of-distribution
> gate caught it. We did not retune the threshold to hide that, because the
> threshold's provenance is pinned — and a system tuned until its known failure
> disappears is a system you cannot trust on the image you have never seen.

**If the image is high resolution and the screen is taking 30–45 s,** narrate
the wait rather than sit in it:

> This is a full-resolution frame — 4288 by 2848. On our rehearsal set those take
> thirty to forty-five seconds. It completes; it is just doing far more pixel
> work than our 512-pixel validation images. That is a measured number from our
> own rehearsal, not a guess.

---

## §Words that must never appear in this recording

| Never say | Say instead |
|---|---|
| lesion localisation / lesion localization (of Grad-CAM) | model attention, attention visualisation |
| clinically validated | held-out validation on 733 APTOS images |
| doctor-level, replaces doctors, diagnoses with certainty | AI-assisted screening, specialist review |
| "we automate 80% of screening" | "60.03% are not referred at the locked 0.60 threshold" |
| "the model found the haemorrhages" | "the model's attention concentrated here" |
| real-time (about inference) | "a few seconds per image on this laptop" |
| "clinically validated model", "AI diagnosis" | "AI-assisted screening prototype" |

If a judge asks for a number you cannot trace to a file, the complete and
correct answer is: **"I don't have that measured."**
