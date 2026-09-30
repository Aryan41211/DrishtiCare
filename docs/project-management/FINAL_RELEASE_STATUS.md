# Final release status

DrishtiCare - Smart India Hackathon 2026, national screening stage.

This is the authoritative closing record. It states what is verified, what
is deliberately not done, and what only a human can finish. Anything not
listed as verified here is not verified.

- Problem statement: SIH 26038
- Sponsor: MathWorks
- Last refreshed: 2026-09-30

## Verified at this commit

Re-run commands and their observed output. These are not recollections; each
one was executed against the tree that is now pushed.

| Gate | Command | Result |
|---|---|---|
| App layout | `verify_app_layout` | `ALL DRISHTI APP LAYOUT CHECKS PASS` - 217/217 measurable components inside the 1360x760 canvas, 0 clipped, 0 zero-extent, three content panels disjoint and correctly ordered |
| Grad-CAM rendering | `verify_gradcam_rendering` | `ALL GRADCAM RENDERING AUDIT CHECKS PASS` |
| PDF report | `verify_drishti_report_extended` | `ALL DRISHTI PDF REPORT CHECKS PASS (engine=edge)` and `ALL EXTENDED DRISHTI PDF REPORT CHECKS PASS (engine=edge)` |
| Deck geometry | `pitch/audit_deck_pptx.ps1` | `ALL DRISHTI DECK PPTX GEOMETRY CHECKS PASS` - 960x540pt, 11 slides, 474 shapes, 11 pictures, 0 text overflows, 0 text-on-text overlaps |
| Deck round trip | PowerPoint 16.0 COM | opens `pitch/deck.pptx` as 11 slides and exports an 11-page `%PDF-1.7` |
| Model integrity | `Get-FileHash -Algorithm SHA256` | both hashes match `FROZEN_CONTRACT.md` exactly |

Chromium `fallback_task_provider` lines in the MATLAB log are Edge engine
startup noise and are not failures.

### Model hashes, unchanged

| Model | SHA-256 |
|---|---|
| `day7_pretrained_resnet18_5class_stage2.mat` | `DD152C917689146F6DEC4687B263EC5E5F237ECF60EC719A59F9FCEEFF737C1B` |
| `day7_pretrained_resnet18_binary_stage2.mat` | `43E8DF33B429231EE5BD60A775FDB3629AD81F287617AFAA9308EA87D311F9A0` |

Both match `docs/project-management/FROZEN_CONTRACT.md` exactly. Nothing in
this cycle touched a model, a threshold, a seed, or a split.

## Frozen contract: intact

Seed `42`. Binary threshold `0.60`. Temperature `2.5382`. Metrics as published.
The 733-image locked split, the task-B and Branch-B heads, and the sealed test
set are all untouched. This cycle was presentation and verification work only.

Frozen headline metrics: accuracy 0.8281, macro F1 0.6805, QWK 0.8914,
sensitivity 0.9060, specificity 0.9471, ROC-AUC 0.9796, PR-AUC 0.7821, n=733.

## What changed in this cycle

Nothing scientific. Everything below is a presentation, disclosure, or
verification defect that was real and is now closed.

1. **Grad-CAM rendering was never audited.** Added
   `src/verify/verify_gradcam_rendering.m` as a deterministic test and
   `docs/validation/2026-09-30-gradcam-rendering-audit.md` as the record. The
   result is weak and is now stated: saliency-in-lesion 3.1%, pointing game
   7.4%, mean IoU 0.035, MACE not measured. It is a plausibility cue, not
   localisation evidence.
2. **Lesion counts were printed with no caveat.** The generated PDF listed
   MA/HE/EX candidate counts as bare numbers beside a confident DR grade, with
   the machine-readable `.evidence` in the JSON but nothing on the page. Added
   a qualifier above the table in section 5. `predictSingleFundus.m` was not
   changed.
3. **The GUI had no layout test.** Added `src/dashboard/verify_app_layout.m`.
   It is a fixed `1360x760` canvas with `Resize','off'` and no `uigridlayout`,
   so multi-size responsiveness is not applicable rather than untested.
4. **The deck could not be edited.** It existed only as a PDF, so the team
   could not fill in their SIH Team ID. Rebuilt as a native
   `pitch/deck.pptx` (2,901,413 bytes) from `pitch/build_deck_pptx.py`, with
   11 embedded figures and live text.
5. **70 real layout defects in the PPTX.** `pitch/audit_deck_pptx.ps1` drives
   PowerPoint via COM and measures the rendered result instead of trusting the
   layout input. The first build had 70 problems, the worst a 326x75pt
   text-on-text collision on slide 8, plus 11 heading overflows and a full
   grid of KPI value/label overlaps. Root cause in the builder: font sizes are
   in points but geometry is in pixels, so boxes were short by 1/0.75 and
   omitted the font's own line box. Fixed with a shared `est_h` estimator;
   the audit now reports zero.
6. **The docs still said the deck was PDF-only.** Retired in `ROADMAP.md` and
   `EXECUTION_CHECKLIST.md`.

## Deliberately not done, with reasons

These are open by decision or by data access, not by accident. None of them is
a coding task waiting to be picked up.

| Item | State | Reason |
|---|---|---|
| External validation | **Blocked, not performed** | Messidor-2 needs ADCIS registration; Sin-NP DR 2019 needs a data request. The harness is written and passes 6/6, but it has never seen their data. Do not claim otherwise. |
| Minority-recall retraining | **Switched off by decision** | Target-boosted weighting and targeted augmentation on Severe and Proliferative are disabled in the training script pending mentor approval. This is why Severe NPDR is the weak 5-class. |
| Fovea localisation | **Failed, feature not shipped** | 0 of 10 held-out images within 300 px, so the pipeline emits no fovea-derived distance at all. |
| Grad-CAM retraining | **Not attempted** | The number is weak. Retraining to chase a better figure would have meant touching the frozen contract for presentation convenience. It was not done. |
| Image enhancement in production | **Excluded on evidence** | The A/B experiment degraded grading, so the deployed path feeds the raw resized image. Negative result kept. |
| Vessel features in Branch B | **Excluded on evidence** | Adding them moved Branch-B AUC from 0.8969 to 0.8810. |
| MA detection quality | **Experimental** | Patch AUC 0.976 but recall 0.113. Reported with the qualifier it now carries in the PDF. |
| Responsive GUI | **N/A** | Fixed canvas, `Resize','off'`, no `uigridlayout`. The layout verifier covers the one canvas that exists. |
| `1366x768` window clipping | **Known, not fixed** | The app hard-codes its origin at `[40 8]`, leaving about 34 px off-screen right on a 1366-wide laptop. Changing it is a product decision for the team; `FINAL_GUI_DEMO_CHECKLIST.md` tells the presenter to widen the desktop first. |
| Demo video | **Open, human step** | `pitch/video-plan.md` (9 shots, exactly 3:00) and `pitch/VOICEOVER-SCRIPT.md` (435 words) are written and ready. No `ffmpeg` and no OBS/DaVinci/Clipchamp on this machine, so MP4 assembly cannot be automated here. |
| Human GUI demo | **Open, human step** | A clean-session *headless* run is recorded and passing (19/19 unseen images, 4/4 contract checks). A human, GUI, live, screen-captured run has not been done. |
| SIH Team ID | **Open, human step** | Deliberately left as `________________` on slides 1 and 11. Now trivial to fill in because the deck is editable. |
| MATLAB Report Generator | **Unlicensed** | `license('test','Report_Generator')` = 0, so `mlreportgen.pptx` is unavailable. The PDF is produced through the headless Edge engine, which is why the report verifiers report `engine=edge`. This is a supported path, not a defect. |

## Checklist state

`docs/project-management/EXECUTION_CHECKLIST.md` is **67/69**. The two open
boxes are the demo video and the final human GUI demo, and both are blocked on
a person, not on code. Everything else in that checklist is closed with
evidence.

## Human actions required

1. Fill the SIH Team ID into `pitch/deck.pptx` on slides 1 and 11, and save.
2. Work through `FINAL_GUI_DEMO_CHECKLIST.md` on the actual presentation
   machine and record the run.
3. Assemble the MP4 per `pitch/video-plan.md` using OBS Studio; watch the
   result end to end with a second person.
4. Work through `FINAL_REHEARSAL_CHECKLIST.md` with the whole team, including
   the adversarial pass.
5. Commit the `results/` evidence from that run, separately.
6. Confirm `git status --short` is clean and `main` == `origin/main`.

## Blockers

- **Data licensing** for external validation. Unresolvable inside this repo.
- **Missing video tooling** on this machine. Resolvable by installing OBS
  Studio, or by a human editing the footage.
- **No second pair of eyes yet.** Every review and rehearsal so far has been
  single-operator. Pass 3 of the rehearsal checklist exists specifically to
  fix this.

## Where the evidence lives

- `docs/validation/2026-09-30-gradcam-rendering-audit.md`
- `docs/validation/2026-09-30-layout-and-lesion-audit.md`
- `docs/validation/2026-09-26-unseen-input-rehearsal.md`
- `docs/project-management/FROZEN_CONTRACT.md`
- `docs/task-tracker.md`
- `pitch/deck.pptx`, `pitch/deck.pdf`, `pitch/deck.html`
- `FINAL_GUI_DEMO_CHECKLIST.md`, `FINAL_REHEARSAL_CHECKLIST.md`
