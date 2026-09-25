# Pitch Deck Structure

## 6-Slide Deck

Every number on a slide must be traceable to a committed artifact. Paths are
given inline so the deck is reproducible. Figures are referenced by path from
the repo root.

### Slide 1: Problem (1 min)
- Diabetic retinopathy in India is found late because screening capacity is
  not there.
- **SOURCED 2026-09-26** — citations, years and DOIs in
  `docs/background/clinical-statistics-sources.md`; wording in
  `docs/background/clinical-background.md`. The three figures below are now
  citable, with these honesty constraints:
  - **77 million** diabetic adults in India — IDF Diabetes Atlas 9th ed. (2019).
    **Superseded**: 74.2M (2021); ~90M (2024, provisional). Present as a dated
    figure or a range, never as current.
  - **18%** DR prevalence — needs age framing: 18.1% (age ≥50), 14.9% (age
    ≥30). The national survey reports **16.9%** for the same age band. Do not
    print a bare "18%".
  - ~~1 ophthalmologist per 100,000 rural population~~ — **NOT SUPPORTED,
    removed.** The defensible figure is ~**1 : 65,221** ophthalmologists
    (IJO 2025); the binding constraint is retina specialists at ~1 per 1.26M.
- **The defensible demand-side number (measured by us):** 153.6 specialist
  referrals per working day generated per 100,000 patients/year.
  Source: `data/analysis/simulink_resource_simulation/scenario_results.csv`,
  row `D100`, field `referralsPerDay` = 153.63.

**Visual:** Map of India with DR prevalence overlay. If no licensed prevalence
raster is available, drop the overlay and use the demand-side number as a
bar instead — do not shade a map with an unsourced figure.

### Slide 2: Architecture (1 min)
- System diagram: Quality gate → Classification → Calibration → Grad-CAM →
  Report
- Key features: explainable, MATLAB-based, quality-first (a FAIL image is never
  graded), referral decision locked at threshold 0.60
- Note: enhancement is **display-only** in the shipped path — the model input
  is the raw resized image, because enhancement measurably hurt grading
  (`docs/task-tracker.md` Task 9B).

**Visual:** Pipeline block diagram.

### Slide 3: Demo (2-3 min)
- Live or recorded demo in the DRISHTI dashboard
- Quality badge first: ACCEPT (PASS) / BORDERLINE (WARNING) / REJECT (FAIL)
- Four on-screen views, switchable live: Original / Enhanced / Grad-CAM /
  Overlay
- **Then the failure-aware beat:** load a real FAIL image, show
  "AI GRADING: SKIPPED". In the committed run, 6 of 6 real FAIL images reached
  zero AI executions — the model was never called, and model SHA-256 hashes are
  unchanged before/after.
- End on the branded A4 PDF report being written to disk (7 sections:
  summary, grade, quality assessment, Grad-CAM evidence, interpretation,
  recommendation, disclaimer).

**Visual / assets (all on disk):**
- `results/visual_qa/02_PASS_dashboard.png` — accepted image, full result
- `results/visual_qa/02_FAIL_dashboard.png` — rejected image, grading skipped
- `results/visual_qa/03_FAIL_Grad-CAM.png` — proof no Grad-CAM is produced
- `results/visual_qa/05_report_preview.png` — the A4 PDF
- `data/analysis/failure_aware_demo/figures/failure_aware_comparison.png` —
  good case beside poor case, drop-in slide
- `data/analysis/failure_aware_demo/figures/failure_aware_workflow.png` —
  pipeline with the hard gate
- `data/analysis/failure_aware_demo/figures/quality_gate_summary.png` — the
  733-image quality split (PASS 490 / WARNING 194 / FAIL 49)

### Slide 4: Results (1 min)
- Real numbers, 733-image held-out validation split, locked:
  - Accuracy 82.81% | Macro F1 0.6805 | QWK 0.8914
  - Referable-DR sensitivity 90.60% / specificity 94.71% @ threshold 0.60
  - ROC-AUC 0.9796 | PR-AUC 0.7821
  - Calibration: ECE 0.0319 → 0.0087 (3.66x) at T = 2.5382, from
    `data/analysis/day8/calibration/firewalled/firewalled_calibration.mat`
    (n = 2429); 18/2429 decisions flipped (0.74%)
  - Ablation: pretraining +0.203 QWK; balancing alone −0.079 QWK;
    enhancement −0.2445 QWK
- Honest framing: "Here's what we achieved, here's what we have not done."
- **Carry the negative Grad-CAM number on this slide or the next.** IDRiD
  lesion-alignment: saliency-in-lesion 3.1%, pointing game 7.4%, mean IoU 0.035
  (~1.39x areal chance). We did not retrain to improve it.
  Source: `data/analysis/gradcam_lesion_alignment/README.md`, also summarised
  in `data/analysis/failure_aware_demo/README.md` §7.4.

**Visual:** Confusion matrix or metrics table.

### Slide 5: District Simulation (1 min)
- Real programmatic model: `src/simulink/DrishtiCare_DistrictScreening.slx`
  (reproduces the reference engine exactly, max abs diff 0.00e+00 over 250
  days). 11/11 sanity checks PASS, `matchesReference = 1`.
- Measured inputs are the *measured* locked-split operating point: sensitivity
  90.60% / specificity 94.71% at threshold 0.60.
- Measured outputs at the 100,000 patients/year planning assumption:
  - 96,081 images reach AI screening
  - 38,406 referrals/year = 39.97% of screened → **60.03% never consume
    specialist time**
  - 153.6 referrals/working day vs an assumed 60 reviews/day → 23,406
    year-end backlog
  - 7.68 specialists required at 20 exams/reviewer/day
- **The break point:** 60/day → backlog 23,406. 120/day → still 8,406. Only
  180/day clears the queue (85.3% utilisation). 50k patients/year already
  exceeds 60 reviews/day.
- Corroborating second simulation (`src/phases/phase15_system_simulation.m`):
  nominal 600 img/day is stable; 4x volume grows the queue ~234 img/day. Same
  conclusion, independent model.

**Visual — use the five figures that actually exist**
(all under `data/analysis/simulink_resource_simulation/figures/`):
- `patient_flow.png` — arrivals → quality gate → AI screening → referral queue
- `referral_volume.png` — referral demand vs volume
- `specialist_queue.png` — queue growth / backlog over the year
- `specialist_utilization.png` — utilisation against the capacity scenarios
- `threshold_workload.png` — workload at t = 0.50 / 0.60 / 0.70

**Label on the slide:** "Engineering resource-planning simulation. Prevalence
and review capacity are assumptions, labelled as such. Not clinical validation,
not a staffing prescription."
Source for every number: `data/analysis/simulink_resource_simulation/README.md`
§8–§14 and `scenario_results.csv`.

### Slide 6: What We Have Not Done (1 min)
Bounded, owned, documented. Naming these is the point.
- **External validation — BLOCKED.** Messidor-2 (ADCIS registration required)
  and Sin-NP DR 2019 (Notion request) both need a human download. The harness
  is written and passes 6/6; on the locked split it reproduces sensitivity
  0.9060 / specificity 0.9471 / AUC 0.9796 / PR-AUC 0.7821 exactly, so the
  metric path is faithful. **Not performed** — blocked on data access.
  Owner: team, on dataset licensing. (`docs/task-tracker.md` P14 / P16)
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
- **Datasets:** APTOS 2019 (used), IDRiD (lesion/OD/fovea ground truth, used),
  DRIVE (vessel study, used). **DRIMDB — downloaded and licence-cleared, not
  used in any result.** Messidor-2 / Sin-NP DR 2019 — not downloaded (blocked).

**Visual:** Timeline or roadmap diagram, with the blocked item visually marked
as blocked rather than as pending work.

## Timing

| Section | Time |
|---------|------|
| Problem | 1 min |
| Architecture | 1 min |
| Demo (incl. failure-aware beat) | 2-3 min |
| Results | 1 min |
| District Simulation | 1 min |
| What We Have Not Done | 1 min |
| **Total** | **7-8 min** |

## Key Messages

1. **Problem is real** — the demand side is measured by us: 153.6 referrals per
   working day per 100k patients. (The national prevalence/workforce figures on
   slide 1 are now cited with organisation, year and DOI; the unsupported
   "1 ophthalmologist per 100,000" claim was removed.)
2. **We built something** — working pipeline, real `.slx` district model, real
   A4 PDF, not just slides.
3. **The system says "I don't know"** — 6 of 6 FAIL images reached zero AI
   executions, and one demo slot was left empty because no natural example
   existed.
4. **We're honest** — real numbers, plus four documented open items and the
   weak Grad-CAM alignment result, on the slides rather than in the appendix.
5. **We have a plan** — each open item has a named blocker and an owner.

## References
- Section 8 of 10-day roadmap
- `docs/validation/metrics.md`, `docs/task-tracker.md` (frozen metrics, open items)
- `data/analysis/simulink_resource_simulation/README.md` + `figures/`
- `data/analysis/failure_aware_demo/README.md` + `figures/`
- `docs/validation/2026-09-10-hardening-phase15-simulation.md`
- `docs/validation/2026-09-10-hardening-phase14-external-harness.md`
- `results/_verify_extended_verdict.txt` (headless UI/report PASS)
- `audit/final_project_audit/FINAL_DRISHTICARE_TECHNICAL_AUDIT.md` (items 37,
  40, 41, 42 — the claims this deck previously overstated)
