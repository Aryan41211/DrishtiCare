# Pitch Deck Structure

**This file describes the deck that actually exists: `pitch/deck.pdf`, 11 pages,
3,685,132 bytes, generated from `pitch/deck.html` (11 `section.slide`
elements).**

Reconciled 2026-09-30. The previous revision of this file described a
**6-slide** deck and omitted five slides that are in the shipped artifact —
Title, Built vs Planned, Refusal + Rehearsal, Explainability and Impact. The old
6-slide outline is preserved below inside each slide that absorbed it, so nothing
was lost in the reconciliation. Slide numbering follows the HTML comments in
`deck.html` (`SLIDE 1 : TITLE` … `SLIDE 11 : TEAM / RESOURCES`).

Every number on a slide must be traceable to a committed artifact. Paths are
given inline so the deck is reproducible. Figures are referenced by path from
the repo root.

---

### Slide 1: Title
- "Smart India Hackathon 2026 · National Screening Stage — DrishtiCare".
- Subtitle: quality-aware, explainable DR screening for rural workflows, built
  in MATLAB and Simulink.
- Entry: problem statement **SIH 26038**, sponsor **MathWorks**, team of 6 plus
  mentors, SIH Team ID left blank.
- Carries the standing disclaimer on its face: **ENGINEERING PROTOTYPE — NOT A
  CLINICAL DEVICE**, no clinical validation performed, and grades / Grad-CAM
  overlays / OOD flags / lesion candidate counts must not be used for diagnosis,
  treatment or triage decisions.

*Not covered by the previous 6-slide outline.*

### Slide 2: Problem (1 min)
- Diabetic retinopathy is found late because **screening capacity is the
  constraint**, not because grading is un-automatable.
- **The defensible demand-side number (measured by us):** 153.6 specialist
  referrals per working day generated per 100,000 patients/year, = 38,406 a year.
  Source: `data/analysis/simulink_resource_simulation/scenario_results.csv`,
  row `D100`, field `referralsPerDay` = 153.63.
- General ophthalmology is not the binding constraint; for vitreoretinal grading
  it is retina specialists, at roughly **one per 1.26 million** population.
- Reframes the question: not "can a CNN grade a retina" but *what does the
  system do with an image it should not answer?* → a workflow whose quality gate
  runs before the model.

**Sourced 2026-09-26** — citations, years and DOIs in
`docs/background/clinical-statistics-sources.md`; wording in
`docs/background/clinical-background.md`. The three national figures now sit on
**slide 9**, with these honesty constraints preserved:
- **74.2 million** diabetic adults aged 20–79 in India, 2021 — IDF Diabetes Atlas
  10th ed. **Superseded**: the 9th ed. (2019) said 77 million; ~90M (2024,
  provisional). Present as a dated figure, never as current.
- The deck names **ICMR-INDIAB-17** alongside IDF (≈101 million) and states the
  two use different methods and are **not interchangeable**.
- **18%** DR prevalence needs age framing: 18.1% (age ≥50), 14.9% (age ≥30); the
  national survey reports **16.9%** for the same band. Do not print a bare "18%".
- ~~1 ophthalmologist per 100,000 rural population~~ — **NOT SUPPORTED,
  removed.** The defensible figure is ~**1 : 65,221** ophthalmologists
  (IJO 2025); the binding constraint is retina specialists at ~1 per 1.26M.

**Visual:** map of India with DR prevalence overlay. If no licensed prevalence
raster is available, drop the overlay and use the demand-side number as a bar
instead — do not shade a map with an unsourced figure.

### Slide 3: Workflow — the quality gate runs before the AI (1 min)
- The ordering **is** the design: a screening system that grades every image it
  is handed has no way to say "I don't know".
- Flow: **image** → **quality** (focus · brightness · foreground fraction) →
  **AI** (5-class grade + referable score) → **referral** (rule locked at 0.60) →
  **evidence** (model attention · lesion candidates) → **human** specialist
  review. A FAIL image yields **WITHHELD**: AI never executed, grade stays NaN,
  and the only safe outcomes are recapture or manual review.
- Quality FAIL is a hard gate, not a display setting: the classifier is never
  invoked and no Grad-CAM is computed.
- Key features: explainable, MATLAB-based, quality-first. Enhancement is
  **display-only** in the shipped path — the model input is the raw resized
  image, because enhancement measurably hurt grading
  (`docs/task-tracker.md` Task 9B).

*Absorbs the previous outline's "Slide 2: Architecture".*

**Visual:** pipeline block diagram.

### Slide 4: Built vs Planned (1 min)
Two columns — **Built** (running, measured, verified) versus the **hardening
programme** record.

Built, with the measured figure on the slide:
- Hardening programme P0–P25: **230/230 checks PASS**.
- Image quality gate — focus, brightness, foreground fraction. 3,662 images
  measured: **PASS 65.48% / WARNING 26.68% / FAIL 7.84%**.
- 5-class DR grader — ResNet-18, EyePACS-pretrained, class-balanced.
  **QWK 0.8914** on the locked 733-image split.
- Binary referable classifier — **sensitivity 0.9060 / specificity 0.9471** at
  the locked 0.60 threshold.
- OOD advisory detector — Mahalanobis, locked at its **p99 of 34.22**. Surfaces in
  the narrative; **never alters a route**.
- Cascade router — **CLEAR 648 / REVIEW 75 / ABSTAIN 10** on the validation split.

*Not covered by the previous 6-slide outline.*

### Slide 5: Performance (1 min)
Every figure is frozen under a written contract: no retuning of the threshold or
calibration temperature, and no use of the sealed official test set.

| Metric | Value |
|--------|-------|
| Accuracy | 0.8281 |
| Macro F1 | 0.6805 |
| Quadratic weighted kappa | 0.8914 |
| Sensitivity, referable DR | 0.9060 |
| Specificity, referable DR | 0.9471 |
| ROC-AUC | 0.9796 |
| PR-AUC | 0.7821 |
| Referral threshold | 0.60 — locked, provenance-pinned |
| Calibration temperature | 2.5382 — display-only |
| Validation images | 733 (2,929 train, seed 42) |

**Per-class recall — where the weakness is, on the slide:**
No DR 0.9834 · Mild NPDR 0.6081 · Moderate NPDR 0.7850 · **Severe NPDR 0.4872
(weak — the main 5-class weakness)**.

Also available for this slide, sourced in `docs/validation/metrics.md`:
- Calibration: ECE 0.0319 → 0.0087 (3.66x) at T = 2.5382, from
  `data/analysis/day8/calibration/firewalled/firewalled_calibration.mat`
  (n = 2429); 18/2429 decisions flipped (0.74%).
- Ablation: pretraining +0.203 QWK; balancing alone −0.079 QWK;
  enhancement −0.2445 QWK.

*Absorbs the previous outline's "Slide 4: Results".*

**Visual:** confusion matrix or metrics table.

### Slide 6: Refusal + rehearsal evidence (2–3 min) — the differentiator
- "It refuses. We tested that on images it had never seen."
- Every automated check had run on the same split the champions were selected
  on. The full pipeline was then run end to end on **19 unseen fundus images
  from three foreign cameras** — DRIVE test, the IDRiD B testing set, and
  real-world web fundus from DRIMDB.
- Nothing retrained or tuned, the 0.60 rule untouched, **model hashes unchanged**.
- **19/19 completed**, no crash, no unhandled exception. **4/4 contract checks
  PASS**: valid route band, quality FAIL never auto-answered, locked 0.60 rule
  still holds.
- **8 quality FAIL images — every one withheld before any model execution.**
- Real FAIL proof: in the committed run, 6 of 6 real FAIL images reached zero AI
  executions, with model SHA-256 hashes unchanged before/after.

*Not covered by the previous 6-slide outline; absorbs the failure-aware beat of
the old "Slide 3: Demo". The **live demo** is the separate GUI run and is still
open — see `EXECUTION_CHECKLIST.md`.*

**Visual / assets (all on disk):**
- `results/visual_qa/02_PASS_dashboard.png` — accepted image, full result
- `results/visual_qa/02_FAIL_dashboard.png` — rejected image, grading skipped
- `results/visual_qa/03_FAIL_Grad-CAM.png` — proof no Grad-CAM is produced
- `results/visual_qa/05_report_preview.png` — the A4 PDF
- `data/analysis/failure_aware_demo/figures/failure_aware_comparison.png` —
  good case beside poor case, drop-in slide
- `data/analysis/failure_aware_demo/figures/failure_aware_workflow.png` —
  pipeline with the hard gate
- `data/analysis/failure_aware_demo/figures/quality_gate_summary.png`

### Slide 7: Explainability (1 min)
- "Grad-CAM shows model attention. **It is not lesion localisation.**"
- Four views of one real case from the running application: **Original** (the
  model input, unchanged) · **Enhanced** (display aid only, *not* the model
  input) · **Grad-CAM** (regions that most influenced the decision) · **Overlay**
  (for the reviewer's eye, not a finding).
- **Measured against IDRiD lesion masks, on the slide:** saliency-in-lesion
  **3.1%**, pointing game **7.4%**, mean IoU **0.035** (top-20% pixels) —
  ~1.39x areal chance. **MACE not measured.** We did not retrain to improve a
  visualisation metric.
- Source: `data/analysis/gradcam_lesion_alignment/README.md`, also summarised in
  `data/analysis/failure_aware_demo/README.md` §7.4.

*Not covered by the previous 6-slide outline, which asked for this negative to
live on the Results slide or the next; it now has a slide of its own.*

### Slide 8: District-scale simulation (1 min)
- Real programmatic model: `src/simulink/DrishtiCare_DistrictScreening.slx`
  (reproduces the reference engine exactly, max abs diff 0.00e+00 over 250 days).
  11/11 sanity checks PASS, `matchesReference = 1`.
- Measured inputs are the *measured* locked-split operating point: sensitivity
  0.9060 / specificity 0.9471 at threshold 0.60.
- Five panels from one simulation: patient flow, referral demand, queue growth
  over the year, utilisation against capacity scenarios, and workload by referral
  threshold.

At 100,000 patients per year:

| Quantity | Value |
|----------|-------|
| Images reaching AI screening | 96,081 |
| Referrals generated | 38,406 (39.97% of screened) |
| Never consume specialist time | 60.03% |
| Referrals per working day | 153.6 |
| Specialists implied, 20 exams/reviewer/day | 7.68 |

- **The break point:** 60/day → backlog 23,406. 120/day → still 8,406. Only
  180/day clears the queue (85.3% utilisation). 50k patients/year already exceeds
  60 reviews/day.
- Corroborating second simulation (`src/phases/phase15_system_simulation.m`):
  nominal 600 img/day is stable; 4x volume grows the queue ~234 img/day. Same
  conclusion, independent model.

*Absorbs the previous outline's "Slide 5".*

**Label on the slide:** "Engineering resource-planning simulation. Not clinical
validation and not a staffing prescription." Prevalence and review capacity are
assumptions, labelled as such.
Source for every number: `data/analysis/simulink_resource_simulation/README.md`
§8–§14 and `scenario_results.csv`.

**Visual — the five figures that actually exist** (all under
`data/analysis/simulink_resource_simulation/figures/`):
`patient_flow.png` · `referral_volume.png` · `specialist_queue.png` ·
`specialist_utilization.png` · `threshold_workload.png`

### Slide 9: Impact — three national statistics (1 min)
- "Three national statistics, each carrying its source and its year."
- We verified every figure we quote; where an earlier draft did not survive
  verification, the slide says so rather than quietly swapping it.
- 1. **74.2 million** Indian adults aged 20–79 with diabetes, 2021 — IDF
   Diabetes Atlas 10th ed. (Sun H. et al., *Diabetes Res Clin Pract*
   2021;183:109119, doi:10.1016/j.diabres.2021.109119).
- 2. **ICMR-INDIAB-17** puts the same year nearer **101 million** — Anjana R.M. et
   al., *Lancet Diabetes Endocrinol* 2023,
   doi:10.1016/S2213-8587(23)00119-5. The two use different methods and are not
   interchangeable, so the slide names the body.
- 3. The age-framed DR prevalence figures, with the same framing constraints as
   slide 2 (no bare "18%").

*Not covered by the previous 6-slide outline, which carried these figures inside
"Slide 1: Problem".*

### Slide 10: What this system cannot do yet (1 min)
Bounded, owned, documented. Naming these is the point — and they are **on the
slide, not in the appendix**, because a prototype that hides its measured
negatives is not safe to hand to a screening programme.

- **External validation — BLOCKED.** Messidor-2 (ADCIS registration required)
  and Sin-NP DR 2019 (Notion request) both need a human download. The harness
  is written and passes 6/6; on the locked split it reproduces sensitivity
  0.9060 / specificity 0.9471 / AUC 0.9796 / PR-AUC 0.7821 exactly, so the metric
  path is faithful. **Not performed** — blocked on data access. The reported
  figures are **APTOS-internal, on a single dataset**. Owner: team, on dataset
  licensing. (`docs/task-tracker.md` P14 / P16)
- **Grad-CAM vs lesion masks — measured weak.** Saliency-in-lesion 3.1%, pointing
  game 7.4%, mean IoU 0.035, ~1.39x areal chance; MACE not measured. We did not
  retrain to improve a visualisation metric.
- **Confident exclusions** (the slide continues): the confident low-risk
  pathway is flagged as measured on the same single dataset.
- **Minority-recall experiments — deliberately switched off.** Task 5(b)
  target-boosted weighting and 5(c) targeted augmentation on Severe /
  Proliferative: `RUN_VARIANT_B = false` / `RUN_VARIANT_C = false` in
  `src/runs/run_task5_minority_recall.m:10-11` — the script itself prints
  "SKIPPED ... requires explicit user approval". Owner: mentor approval.
- **Fovea localization — honest negative result.** Patch CNN 0/10 IDRiD holdout
  images within 300 px of ground truth (mean error ~620 px); disc-relative
  estimate worse at ~1,400 px. The pipeline therefore does **not** emit a
  fovea-derived distance — `meanExudateDistToFovea` is initialised to `NaN` at
  `src/inference/predictSingleFundus.m:124` and stays `NaN` with an explicit
  "not available" narrative line unless the caller supplies a fovea centre
  (`predictSingleFundus.m:229`). Owner: revisit if fovea-labelled data appears.
- **Vessel segmentation — excluded from production.** Adding vessel features
  moved Branch-B AUC 0.8969 → 0.8810 (Δ −0.0159). Shipped without them.
- **MA detection is experimental** — patch-level ROC-AUC 0.976 with recall 0.113.
  Counts are reported as candidate detections, not diagnoses.
- **Datasets:** APTOS 2019 (used), IDRiD (lesion/OD/fovea ground truth, used for
  evaluation, **not** for classifier selection), DRIVE (vessel study, used).
  **DRIMDB — downloaded and licence-cleared, not used in any result.** Messidor-2 /
  Sin-NP DR 2019 — not downloaded (blocked).

*Absorbs the previous outline's "Slide 6: What We Have Not Done".*

**Visual:** table of item / measured / status / blocker-or-owner, with the
blocked item visually marked as blocked rather than as pending work.

### Slide 11: Team, resources and references
- Entry: problem statement SIH 26038 · sponsor MathWorks · team of 6 plus
  mentors · SIH Team ID (blank).
- Repository `github.com/Aryan41211/DrishtiCare`; launch `launchRetinaAI.m` from
  the repository root.
- Stack: MATLAB and Simulink; ResNet-18 transfer learning, EyePACS-pretrained,
  class-balanced.
- Governance: frozen model contract with SHA-256 hashes, a decision log, and a
  per-task evidence record.
- Datasets, stated plainly (APTOS / IDRiD / DRIVE / DRIMDB / Messidor-2 / Sin-NP
  with used-or-not status).
- Closing message: **"Everything here is reproducible from a public
  repository."**

*Not covered by the previous 6-slide outline.*

---

## Timing

| Slide | Section | Time |
|-------|---------|------|
| 1 | Title | 0.5 min |
| 2 | Problem | 1 min |
| 3 | Workflow / quality gate | 1 min |
| 4 | Built vs Planned | 1 min |
| 5 | Performance | 1 min |
| 6 | Refusal + rehearsal evidence | 2–3 min |
| 7 | Explainability | 1 min |
| 8 | District simulation | 1 min |
| 9 | Impact | 0.5 min |
| 10 | Limitations | 1 min |
| 11 | Team / references | 0.5 min |
| | **Total** | **10–11 min** |

Slides 1, 4, 9 and 11 are short; slide 6 is the long one. If the slot is 7–8
minutes, drop slide 4 (Built vs Planned) and compress slide 9 into slide 2 —
but do **not** cut slide 10, the limitations slide.

## Key Messages

1. **The constraint is screening capacity, and we measured it ourselves** —
   153.6 referrals per working day per 100k patients. The national prevalence
   and workforce figures (slides 2 and 9) are cited with organisation, year and
   DOI; the unsupported "1 ophthalmologist per 100,000" claim was removed.
2. **The design puts the quality gate first**, so the system can say "I don't
   know" instead of grading every image it is handed.
3. **We built something** — working pipeline, real `.slx` district model, real
   A4 PDF, not just slides.
4. **The system says "I don't know", and we proved it on unseen data** — 19/19
   unseen images from three foreign cameras, 4/4 contract checks PASS, 8 quality
   FAIL images all withheld before any model execution, hashes unchanged.
5. **We're honest** — real numbers plus the weak Grad-CAM alignment result and
   the open items, **on the slides rather than in the appendix**.
6. **We have a plan** — each open item has a named blocker and an owner.
7. **It is reproducible** — public repository, frozen contract, per-task
   evidence record.

## References
- `docs/validation/metrics.md`, `docs/task-tracker.md` (frozen metrics, open items)
- `docs/background/clinical-statistics-sources.md` (organisations, years, DOIs)
- `data/analysis/simulink_resource_simulation/README.md` + `figures/`
- `data/analysis/failure_aware_demo/README.md` + `figures/`
- `data/analysis/gradcam_lesion_alignment/README.md`
- `docs/validation/2026-09-10-hardening-phase15-simulation.md`
- `docs/validation/2026-09-10-hardening-phase14-external-harness.md`
- `docs/validation/2026-09-26-unseen-input-rehearsal.md` (19/19 rehearsal)
- `docs/validation/2026-09-30-gradcam-rendering-audit.md`
- `docs/validation/2026-09-30-layout-and-lesion-audit.md`
- `results/_verify_retinaai_verdict.txt`, `results/_verify_extended_verdict.txt`
- `audit/final_project_audit/FINAL_DRISHTICARE_TECHNICAL_AUDIT.md` (items 37,
  40, 41, 42 — the claims this deck previously overstated)
