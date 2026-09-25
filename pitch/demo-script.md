# Demo Script

## Duration
6-8 minutes. Acts 3b and 4b are droppable if running long.

Every number spoken below is traceable to a committed artifact. The
"Artifact" line under each act names it. If you cannot name the file, do not
say the number.

## Script

### Act 1: Problem (1 minute)
"Diabetic retinopathy in India is found late, because the screening capacity
isn't there. Three national figures usually get quoted — 77 million diabetic
adults, 18% DR prevalence, one ophthalmologist per 100,000 rural population.
**Those three are unverified estimates in our deck right now.** We haven't
sourced them, and we won't invent a citation to fill the gap — they're flagged
on the slide and we will source them before the final round.

What we *have* measured is the demand side, from our own simulation: at
100,000 patients a year our pipeline generates 153.6 specialist referrals per
working day. That's the number I can defend today."

- Note: the clinical figures are labelled unverified on the slide. Say so out
  loud; it costs nothing and it is the honest move.
- Artifact: `data/analysis/simulink_resource_simulation/scenario_results.csv`
  (row D100, `referralsPerDay` 153.63). Clinical figures: carried over from
  `docs/background/clinical-background.md` §"Global Disease Burden", which
  carries no citation — hence the label.

### Act 2: Architecture (1 minute)
"Our system takes a raw fundus image and runs it through 6 stages: quality
assessment, enhancement, classification (ResNet-18 pretrained on EyePACS), a
lesion-feature cross-check branch, calibration, and explainability. The output
is a clinical-grade report with Grad-CAM overlay and a confidence-gated
referral decision."

- Artifact: `docs/task-tracker.md` (Task 0–13 rows); pipeline order verified in
  audit item 33.

### Act 3: Live Demo (2-3 minutes)
"Let me show you how it works."

1. Open the **DRISHTI** dashboard — branded header, three panels: Retinal
   Image, AI Screening Result, Model Explanation & Visual Evidence.
2. Load a sample image → show the Image ID and resolution in the status strip.
3. Quality check → show the judge-terms badge: ACCEPT (PASS) /
   BORDERLINE (WARNING) / REJECT (FAIL), plus per-metric readouts (focus,
   brightness, foreground fraction).
4. **Switch the four view buttons** — Original → Enhanced → Grad-CAM → Overlay.
   The enhanced view is a display aid only; the model input is unchanged, and
   the label says so.
5. Show the result panel: ICDR severity (grade + label), Model Score as
   P(referable), and the recommendation banner.
6. **Hit "Save PDF Report"** — a branded A4 PDF lands on disk with seven
   sections: screening summary, DR grade, quality assessment, Grad-CAM visual
   evidence, interpretation, recommendation, and a footer disclaimer.

"Two things to notice. First, the Grad-CAM is the model's attention for the
grade it predicted — the evidence, not the diagnosis; our own IDRiD
lesion-alignment study says that alignment is weak (saliency-in-lesion 3.1%,
pointing game 7.4%) and we did not retrain to chase a better number. Second,
the PDF is a real artifact on disk, not a screenshot — the same result struct
drives the screen and the report."

- Artifacts: `RetinaAIApp.m` (four view buttons at
  `RetinaAIApp.m:908-911`; badge text at `RetinaAIApp.m:1036-1043`);
  `src/reporting/generateDrishtiReport.m` (section build order, lines 96-183);
  Grad-CAM alignment: `data/analysis/gradcam_lesion_alignment/README.md`;
  headless PASS verdict in `results/_verify_extended_verdict.txt` and
  screenshots in `results/visual_qa/`.

### Act 3b: The System Refuses (30-45 s) — failure-aware screening
"Now let me load an image the system should *not* answer."

1. Load `class_1/cae51154e1ce.png` — a real held-out image, not a synthetic
   one.
2. Quality gate returns **REJECT (FAIL)** on focus: measured focus score
   9.69e-05 against a lower-Fail threshold of 1.42e-04.
3. The screen shows **"AI GRADING: SKIPPED"** (`RetinaAIApp.m:964`), the grade
   fields are `-`, there is no Grad-CAM, and the recommendation is recapture.
4. Under the hood, `predictSingleFundus` was **never called**. In our committed
   failure-aware run, 6 of 6 real FAIL images reached zero AI executions — not
   a suppressed display, an actual short circuit. Model SHA-256 hashes are
   identical before and after the run.
5. Also flag the honesty item: one quality role, `case_fail_mask`, has **no
   natural example** in the 733-image val split (0 mask-validity failures), so
   we left the slot empty instead of fabricating an image.

"Six real images, zero AI calls. A screening system that never says 'I don't
know' is not safe to deploy, and this one does say it."

- Artifacts: `data/analysis/failure_aware_demo/README.md` (§1, §4, §7.5);
  `data/analysis/failure_aware_demo/audit_log.csv`;
  `src/demo/run_failure_aware_demo.m` (decision at the `isFail` branch);
  `src/demo/tests/test_failure_aware_demo.m` (TEST 1-11, all pass).

### Act 4: Results (1 minute)
"Our champion 5-class grader (ResNet-18, EyePACS-pretrained, class-balanced) on 733 held-out validation images: 82.81% accuracy, macro F1 0.6805, QWK 0.8914, and for referable DR (Moderate or worse) sensitivity 90.60% with specificity 94.71% at the locked 0.60 threshold, ROC-AUC 0.9796 and PR-AUC 0.7821. Temperature calibration cuts calibration error by ~2x (ECE 0.045 to 0.030). This is honest — we're not claiming to beat the clinical standard yet, but the numbers are measured on a locked split."

- Artifacts: `docs/task-tracker.md` T13 / P4 / P7 rows; metric definitions
  frozen verbatim in
  `docs/validation/2026-09-10-hardening-phase7-metric-freeze.md`.

### Act 4b: Ablation (30-45 s, if slides allow)
"Three isolated levers measured on the same split: pretraining is decisive (QWK 0.6887 to 0.8914), class balancing alone does not help a scratch model (QWK -0.079), and enhancement hurts grading (QWK 0.8952 to 0.6507). We report what hurts too — that's what makes the ablation credible. That's also why the deployed path feeds the model the raw image and shows enhancement only as a display aid."

- Artifacts: `docs/validation/ablation-study.md`; `docs/task-tracker.md` Task 9B.

### Act 5: District Simulation (1 minute)
"Our Simulink model takes the *measured* sensitivity (90.60%) and specificity
(94.71%) from that locked split and pushes them through a district screening
workflow. This is a real `.slx` model, and it reproduces the reference engine
exactly — max absolute difference 0.00e+00 over 250 days.

Here is what it actually says, at the planning assumption of 100,000 patients
per year. About 96,081 images reach AI screening. **39.97% of them — 38,406
referrals, 153.6 per working day — go to a specialist. The other 60.03% are
resolved by the AI stage and never consume ophthalmologist time.** That is the
automation number, and it is measured, not asserted.

Now the part that matters. At the assumed 60 reviews per day, demand is 2.6x
capacity: the queue grows all year to a 23,406 backlog. Double capacity to
120/day and it still ends at 8,406. Only at 180 reviews per day does the queue
clear, at 85.3% utilisation. At 20 exams per reviewer per day, keeping pace at
100k patients a year takes about 8 specialists.

So: the bottleneck the model exposes is specialist review, not AI processing —
that is the reported finding, and the queue is where the simulation says a
district would actually break. And the model shows this breaks at every volume
we tested against 60 reviews a day, 50,000 patients a year included. A second,
independent discrete-event simulation agrees: at a nominal 600 images a day the
queue is stable, and at 4x volume it grows about 234 images a day with capacity
held flat.

To be explicit: this is an engineering resource-planning simulation. It is not
clinical validation and not a staffing prescription — prevalence and review
capacity are assumptions we have labelled as such."

- Artifacts: `src/simulink/DrishtiCare_DistrictScreening.slx` (built by
  `src/simulink/build_DrishtiCare_DistrictScreening.m`);
  `data/analysis/simulink_resource_simulation/README.md` (§8-§14, all 11 sanity
  checks PASS, `matchesReference = 1`);
  `data/analysis/simulink_resource_simulation/scenario_results.csv` (rows A,
  B, C, D50, D100, D150, D200, E60, E120, E180);
  `data/analysis/simulink_resource_simulation/figures/` (5 PNGs);
  `docs/validation/2026-09-10-hardening-phase15-simulation.md` (4/4 PASS).
- Do NOT say "we automate 80% of screening." No artifact produced 80%. The
  measured figure is 60.03% not-referred at the locked threshold.

### Act 6: What We Have Not Done (1 minute)
"Four open items, all documented, none of them hidden.

One: **external validation is blocked, and we say so.** Messidor-2 and Sin-NP DR
2019 both need a human download — an ADCIS registration and a Sin-NP request.
The harness is already written and passes 6/6 checks: run on the locked split
it reproduces sensitivity 0.9060, specificity 0.9471, AUC 0.9796 and PR-AUC
0.7821 exactly, so the metric path is faithful. The moment labelled external
data arrives it runs. We have not done it, because we cannot without the data.
Owner: us, on dataset access.

Two: the **minority-recall experiments are deliberately switched off** —
target-boosted weighting and targeted augmentation on Severe and Proliferative.
They are disabled in code and skipped by operator decision, not overlooked.
Owner: mentor approval.

Three: **fovea localization failed, honestly.** A patch CNN hit 0 of 10 IDRiD
holdout images within 300 pixels of ground truth — mean error about 620 pixels.
A disc-relative anatomical estimate did worse, about 1,400 pixels. So the
pipeline does not emit a fovea-derived distance; it stays `NaN` with an
explicit 'not available' line unless the caller supplies a fovea centre. Code
is retained for future fovea-labelled data.

Four: **vessel segmentation is out of production.** Adding vessel features
moved Branch-B AUC from 0.8969 down to 0.8810. That is a measured negative, so
we shipped the branch without vessel features rather than keep a feature that
makes the model worse.

Also on the data slide: DRIMDB is downloaded and licence-cleared but **not
used** in any result. We would rather list it as unused than quietly imply it
contributed.

That is our list. Every item is written down in our task tracker, with the
blocker named."

- Artifacts: `docs/task-tracker.md` P14/P16 rows (blocked external data),
  Task 5(b)/5(c) rows, Fovea-localization row, RF-6 row; audit items 40 and 41.

## Backup Plan

If live demo fails:
1. Switch to screen-recorded video
2. Say: "Let me show you a recording of the pipeline"
3. Play the backup video
4. Continue with results

If the app is slow, drop Act 3b and go straight from Act 3 to Act 4 — the
recorded failure-aware run in `data/analysis/failure_aware_demo/figures/` covers
the same claim in 15 seconds.

## Tips

- Speak slowly and clearly
- Make eye contact with judges
- Don't rush the demo
- If something fails, stay calm and switch to backup
- Practice 2+ times before the real thing
- **If a judge asks a number you cannot trace to a file, say "I don't have that
  measured" — do not estimate on stage.**

## References
- Section 8 of 10-day roadmap
- `docs/validation/metrics.md` and `docs/task-tracker.md` (frozen metrics)
- `data/analysis/simulink_resource_simulation/README.md` (district simulation)
- `data/analysis/failure_aware_demo/README.md` (failure-aware run)
- `audit/final_project_audit/FINAL_DRISHTICARE_TECHNICAL_AUDIT.md` (items 37,
  40, 41 — the overclaim this script used to carry)
