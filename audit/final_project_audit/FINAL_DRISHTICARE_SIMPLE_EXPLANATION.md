# FINAL DRISHTICARE — SIMPLE EXPLANATION

*A plain-English walkthrough of what DrishtiCare is, what it actually does, what it measured, and what it still needs.*

---

## 1. What is DrishtiCare?

DrishtiCare is a MATLAB program that looks at a photo of the back of a person's eye (a **retinal photograph**), checks whether the photo is good enough to use, and then grades how severe diabetic retinopathy (DR) looks in it — from "No DR" up to "Proliferative DR" (the dangerous stage where new, leaking blood vessels grow).

It was built as a 10-day team project for a hackathon (SIH-style problem statement) and is **not a medical device**.

## 2. What goes in, and what comes out

**In:** one retinal image (PNG/JPG).

**Out (a "report" object):**
- Quality verdict: **PASS / WARNING / FAIL** (5 measurements: brightness, contrast, focus/sharpness, how much of the frame is actually retina, illumination balance). A FAIL image is sent to REVIEW, not graded silently.
- DR grade: No DR / Mild / Moderate / Severe / Proliferative, plus the model's confidence.
- A second opinion: **referable vs not referable** (should a specialist look at this?) using a second, simpler "Branch B" model.
- Triage route: **CLEAR** (both models agree it's fine) or **REVIEW** (they disagree, or photo is bad).
- Extra analysis: optic-disc location, rough lesion candidates (microaneurysms, haemorrhages, exudates), vessel map (research prototype only), an out-of-distribution check, and a written explanation.

## 3. How it works (the 6 real stages)

1. **Quality gate** — check the photo is usable (else REVIEW).
2. **Enhancement** — a contrast tool exists, but it is *only for display*; the model actually reads the raw photo (we proved enhancement makes the model *worse*).
3. **Classification** — a ResNet-18 CNN, pre-trained on ImageNet/EyePACS-style data and fine-tuned on APTOS, grades the 5 severity levels.
4. **Cross-check (Branch B)** — a second, 10-feature statistical model summarizes the image (tissue texture, vessel density, colour, lesion hints) and must agree with the CNN. If they disagree → REVIEW.
5. **Calibration** — a temperature tweak so the model's "90% sure" really is right ~90% of the time.
6. **Explainability** — a Grad-CAM heatmap shows *which pixels* drove the decision.

## 4. How well does it work? (measured, reproduced)

- **5-class accuracy ≈ 83%**, quadratic-weighted agreement (QWK) ≈ **0.891** on 733 held-out validation images (seeded, no leakage).
- **"Referable" detection:** 90.6% of truly-referable eyes flagged, 94.7% of healthy/non-referable eyes let through, at a locked 0.60 threshold. ROC area 0.980.
- **Calibration:** error drops from 0.045 → 0.030 (standard split).
- **Speed:** ≈ 0.10 seconds per image on CPU (≈9.7 images/s) — fast enough for screening workloads.
- **Confidence:** every number above was recomputed twice from saved evidence (a "63/63 checks pass" re-audit).
- Training data: 3,662 labelled APTOS photos; validation 733; the official 1,928-image test set was **never used for tuning** (and it has no labels anyway, so no "test accuracy" is claimed).

## 5. What genuinely works well

- Data hygiene (zero train/validation overlap, test set untouched, seed fixed).
- The cascade idea (two independent models agreeing = higher trust).
- Honest, reproducible numbers — every result has a saved artifact and a re-run script.
- Negative results documented: enhancement hurts, vessel features hurt, small lesions aren't reliably found, fovea localization isn't reliable. We say so.

## 6. What is weak / not done (the honest list)

1. **Simulink module: NOT built.** The project's problem statement asks for a Simulink "workflow simulation" (queueing/bottleneck for 100k patients/yr). The `.slx` file is a 2-line text placeholder. The pitch's "automate 80% of screening" line has **no simulation behind it**.
2. **Real-world (external) validation: not done.** No Messidor-2 or similar independent dataset has been run (licensing). We only validated on APTOS/IDRiD.
3. **Minority classes are hard.** Severe and Proliferative recall are ~0.49/0.53 — a real screening system needs much better here.
4. **Small lesions/fovea: unreliable.** MA detection recall is very low; fovea CNN no better than chance-level (we moved to a "clinician supplies the fovea" hook).
5. **Explainability is weak in practice.** Grad-CAM fires mostly at the optic disc; lesion overlap is only marginally above chance. We report it as a limitation, not a feature.
6. **A few documents are stale** (old quality-threshold tables; outdated day-6 summary numbers; two tiny vessel-metric deltas).

## 7. Bottom line

- **What it is:** a well-engineered, honestly-benchmarked **CNN + statistical cross-check** DR screener prototype with quality gating, calibration, and explainability — all reproducible in MATLAB.
- **What it is not:** a validated clinical device, and it is **missing the Simulink deliverable** that the statement explicitly required.
- **Fix order:** build/patch the Simulink (or explicitly scripted) throughput analysis first; then docs hygiene (5 small items); then, if time, strengthen minority recall and add external validation.

---

*Companion docs: `FINAL_DRISHTICARE_TECHNICAL_AUDIT.md` (full 47-part forensic report) and `FINAL_DRISHTICARE_INTERVIEW_GUIDE.md` (Q&A prep).*