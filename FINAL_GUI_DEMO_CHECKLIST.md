# Final GUI demo checklist

Run this live, in front of the team, once per rehearsal. It is the last thing
standing between the repo and a submittable SIH entry: everything in
`docs/project-management/EXECUTION_CHECKLIST.md` is closed except a human
screen-captured run and the video.

Nothing in this file is automated. It exists because a clean-session
*headless* run is already recorded
(`docs/validation/2026-09-26-unseen-input-rehearsal.md`, 19/19 images, 4/4
contract checks PASS) and that is not the same thing as watching it work.

## Pre-flight (5 min)

- [ ] Close **all** MATLAB windows. Relaunch from the desktop icon, not from
      a session that already has the models cached.
- [ ] Confirm the machine is on AC power and the screen is at 100% brightness.
- [ ] Confirm `1366x768` or larger. `RetinaAIApp` is a fixed `1360x760`
      canvas with `Resize','off'` and no `uigridlayout`, so it does **not**
      reflow. A `1366`-wide laptop clips about 34 px on the right at the
      hard-coded `[40 8]` origin. If you are on 1366, widen the desktop
      resolution first or drag the window fully onto a larger area.
- [ ] No second monitor scaling mismatch. 100% on both, or the app blurs.
- [ ] `ffmpeg`/OBS: OBS Studio is the intended recorder (it remuxes MKV to
      MP4 with no CLI ffmpeg). Launch it now and confirm the display capture
      is the *primary* screen, not a stale monitor index.
- [ ] Clear `results/visual_qa/` and `results/visual_qa_failed/` so the run
      writes fresh evidence rather than appending to old evidence.

## The run (about 3 min on camera)

- [ ] `launchRetinaAI.m` from a fresh MATLAB. The app opens without error.
- [ ] Load one known-PASS image: `results/visual_qa/04_PASS_fundus.png`.
- [ ] Analyze. The route appears as CLEAR or REVIEW **with** the binary
      referable answer, the quality verdict, confidence, and Grad-CAM.
- [ ] Load one known-FAIL image: `results/visual_qa/04_FAIL_fundus.png`.
- [ ] Analyze. The app must say the image will not be graded and route to
      recapture. The classifier is never invoked. **This is the most important
      20 seconds of the demo** - do not skip it, and do not rush it.
- [ ] Save the A4 branded report. The PDF is produced through the Edge engine
      because MATLAB Report Generator is unlicensed on this machine; that is
      expected, not a fault.
- [ ] Open the saved PDF and scroll to section 5. The lesion-candidate
      paragraph is there, above the table, stating that the counts are
      experimental second-opinion numbers, not clinical-grade measurements,
      not a validated detection of any lesion type, and not a diagnosis.
- [ ] Repeat once with a **foreign-camera** image. The withheld rate is far
      higher than on APTOS (42% vs 7.84% FAIL) and the OOD flag fires. Say so
      out loud - it is a measured weakness, and owning it is the point.

## What the audience will ask

- [ ] Can you show a case the model got wrong? Slide 6 of the deck. The
      DRIMDB ungradable image that passed the gate and came back a confident
      referable grade.
- [ ] What is the sensitivity, and on what split? 0.9060 on the locked
      733-image APTOS split. Internal, single-dataset. Not external validation.
- [ ] Has this been validated on another hospital's data? No. Messidor-2
      needs ADCIS registration; Sin-NP DR 2019 needs a data request. The
      harness is written and 6/6 passes. It has not been run on their data.
- [ ] Why does it refuse 8 of 19 foreign images? The quality gate is tuned on
      APTOS and over-rejects other cameras. Over-refusal is the safe direction
      to fail: a withheld image is never auto-answered.
- [ ] Does the heatmap point at the lesion? Weakly. Saliency-in-lesion 3.1%,
      pointing game 7.4%, mean IoU 0.035, MACE not measured. It is a
      plausibility cue, not localisation evidence.
- [ ] Why is the threshold 0.60 and the temperature 2.5382? Both frozen and
      provenance-pinned before this build. They are not re-tuned to improve a
      demo.

## After the run

- [ ] Record the verdict: which step felt slow, which number you fumbled.
- [ ] `git status --short` is still clean apart from the new `results/`
      evidence you just generated. Commit that evidence separately.
- [ ] Mark `EXECUTION_CHECKLIST.md` line 111 done once a human, GUI, live,
      screen-captured run exists and has been watched by a second person.
