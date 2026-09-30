# Final rehearsal checklist

Two or three passes, with the team in the room. The purpose is not to rehearse
the demo - it is to rehearse being *interrupted*, because SIH screening puts
judges in the room while you run.

## Pass 1 - content, 20 min, sitting down

Read the deck out loud, slide by slide, against `pitch/deck.pptx`. Time it.
It is built to 3:00, with the longest single shot being the AI-withheld
refusal on slide 2.

- [ ] Every number spoken aloud matches the slide. No improvisation of figures.
- [ ] Slide 4 is the honesty slide. Both columns read cleanly and nobody
      tries to spin the PLANNED/BLOCKED column. Do not skip it.
- [ ] Slide 6, the DRIMDB negative, is delivered as a finding, not an apology.
- [ ] Assign the Team ID on slide 1 and slide 11 in the `.pptx` and save.
- [ ] `pitch/VOICEOVER-SCRIPT.md` (435 words) matches what people will say.

## Pass 2 - demo, 20 min, standing up, one person drives

- [ ] `FINAL_GUI_DEMO_CHECKLIST.md` pre-flight, every box, on the actual
      presentation machine.
- [ ] Full run with screen capture, including the withheld case.
- [ ] The PDF is opened and section 5 is shown. The lesion qualifier is
      legible on a projector, not just present.
- [ ] One person narrates, one person drives, one person watches the clock.
- [ ] The 3:00 budget holds with 20 seconds of slack.

## Pass 3 - adversarial, 20 min

Each member takes a turn being the hostile judge. Questions to have answers
for, all with real numbers already agreed:

- [ ] "Your sensitivity is 0.91. Why should I trust that on my patients?" -
      locked 733-image APTOS split, internal, single-dataset, threshold frozen
      at 0.60 before this build.
- [ ] "You refused 42% of the foreign images. That is a broken gate." - agreed,
      the gate is tuned on APTOS; over-refusal is the safe failure direction.
- [ ] "The heatmap does not localise the lesion." - 3.1% / 7.4% / IoU 0.035.
      It is a plausibility cue. We measured it and did not hide it.
- [ ] "Where is your external validation?" - not performed. Messidor-2 needs
      ADCIS registration, Sin-NP DR 2019 needs a data request. Harness written,
      6/6 passes, no data.
- [ ] "Your fovea localisation failed completely." - 0 of 10 within 300 px, so
      the pipeline emits no fovea-derived distance at all.
- [ ] "You turned off the minority-recall work." - deliberate operator decision,
      needs mentor approval, and it is why Severe NPDR is the weak class.
- [ ] "You tested image enhancement and it made things worse?" - it degraded
      grading, so the deployed path feeds the raw resized image. The A/B
      negative result is kept in the record.
- [ ] "Vessel segmentation hurt your Branch B AUC." - 0.8969 to 0.8810, so the
      branch ships without vessel features.
- [ ] "Is this a medical device?" - no. It is an engineering prototype. No
      clinical validation has been performed and nothing it outputs may be
      used for diagnosis, treatment or triage.

## Hard stops before submitting

- [ ] Every presenter can answer every adversarial question without opening
      the deck to find the number.
- [ ] The `.pptx` has the real SIH Team ID in both places.
- [ ] The MP4 exists, is 3:00 or under, has narration, and has been watched
      start to finish by someone who did not record it.
- [ ] `docs/project-management/FINAL_RELEASE_STATUS.md` is accurate as of the
      pushed commit.
- [ ] `git status --short` clean, `main` == `origin/main`.
- [ ] Nobody presents a claim that is not in the deck or the repo. The whole
      value of this submission is that every number in it is traceable.
