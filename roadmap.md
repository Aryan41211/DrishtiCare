# Roadmap

## Team Split (6-person)

| Seat | Owns | Notes |
|---|---|---|
| 1 | Data pipeline, preprocessing, quality module | Owns dataset ingestion, FOV cropping, quality gating/enhancement loop |
| 2 | Structural segmentation | Optic disc, fovea, vessels |
| 3 | Lesion detection | Microaneurysms, hemorrhages, exudates, soft exudates — **hardest seat, give it the strongest classical-vision person on the team** |
| 4 | Grading model, calibration, validation statistics | More central than it sounds — the PS's hardest requirement is an evidence claim, not a build claim. This seat owns the ablation table, calibration, bootstrap CIs, and the literature comparison |
| 5 | Explainability, report generation, demo interface | Grad-CAM quantification, MATLAB App Designer GUI, the auto-generated clinical report |
| 6 | Simulink model, deployment story, documentation | Queueing model, resource-allocation analysis, README/report writing |

Assign these before writing any code — several downstream decisions (which datasets to prioritize, which lesion to tackle first) depend on who's actually confident in classical computer vision vs. deep learning vs. simulation.

---

## Phasing

### Day 0 — before any modeling work
- Request **Messidor-2** access via ADCIS
- Request **IDRiD** access via IEEE DataPort
- Download APTOS, DRIVE, and EyePACS 2015 (all instant, no license needed)
- Confirm MATLAB licenses for every team member, including whether **SimEvents** is included
- Confirm GPU access (campus lab, cloud credits, or personal hardware)
- Confirm your college's actual SIH 2026 internal hackathon date with your SPOC

### Phase 1 — end-to-end skeleton
- FOV cropping + quality scoring (Module 1, minus the enhancement loop initially)
- A baseline grader (deep classifier only, no calibration/fusion yet) trained on APTOS
- Get something running start-to-finish before perfecting any single stage — an integrated mediocre pipeline beats three excellent disconnected modules at every checkpoint

### Phase 2 — structural segmentation
- Optic disc + fovea localization (classical, no training data needed)
- Vessel segmentation (DRIVE + STARE/CHASE_DB1/HRF, patch-based U-Net)

### Phase 3 — lesion detection
- Microaneurysm candidate extraction + classification (two-stage design)
- Hemorrhage detection + per-quadrant counting
- Exudate segmentation + fovea-distance computation (feeds DME grading)

### Phase 4 — fusion, calibration, explainability
- Branch A (deep classifier) + Branch B (lesion-feature model) fusion
- Temperature scaling / isotonic calibration
- Grad-CAM quantification against IDRiD lesion masks (pointing-game score, IoU)
- Automated clinical-language report generation

### Phase 5 — Simulink (can run in parallel with Phase 3–4)
- Needs real inference-latency numbers from the pipeline, so start once Phase 1's skeleton is timed
- Build the queueing model, run the threshold-vs-staffing parameter sweep

### Phase 6 — validation and polish
- Full ablation sweep
- External validation on Messidor-2 (first and only look at it)
- Literature comparison table
- Report and demo polish

**If shortlisted to the grand finale: the 36 hours are a demo sprint, not a build sprint.** Arrive with a working system and spend the time on edge cases, live-demo robustness, and presentation — not on writing new modules.

---

## SIH 2026 Logistics

- Officially launched **August 21, 2026**; SPOC registration closed **July 31, 2026**
- Internal hackathons run through **September 2026** — varies by college, confirm your own SPOC's date directly
- SPOC uploads PPT + video demo for national screening after the internal round
- **Grand Finale: December 2026**, a 36-hour non-stop hackathon at a nodal center
- Team size typically **6 members**, with **at least one female member mandatory**
- Judges (often including a clinician for health-track statements) will expect the team to explain, modify, and defend every part of the solution live — don't hand off a component nobody but its author understands

---

## Immediate Next Actions

1. Request Messidor-2 (ADCIS) and IDRiD (IEEE DataPort) access — today, before any code
2. Confirm MATLAB licenses, SimEvents availability, and GPU access for every team member
3. Confirm your college's internal SIH 2026 hackathon date with your SPOC
4. Assign the 6 seats above
5. Start looking for an ophthalmologist willing to give 30 minutes late in the project, for the 30-second-review validation study
6. Get the Phase 1 skeleton (quality module + baseline grader) running before touching lesion detection
