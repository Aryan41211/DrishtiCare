# CLAUDE Research Handoff — DrishtiCare

**Purpose:** onboard a fresh Claude/research session to this repository in minutes.
**Companions:** `DRISHTICARE_RESEARCH_DOSSIER.md` (33-part narrative), `DRISHTICARE_RESEARCH_FACTS.json` (machine-readable facts).
**State at writing:** branch `main` at `d59e2ba` + 2 uncommitted UI files (`RetinaAIApp.m`, `src/dashboard/verify_app_layout.m`); 5 commits ahead of `origin/main` until pushed.

---

## 1. What this project is

MATLAB/Simulink diabetic-retinopathy screening prototype (SIH 26038, sponsor MathWorks, national screening round 2026). The frozen pipeline: quality gate **before** the model → OOD advisory → 5-class + binary referral grading → calibration (display-only) → lesion/anatomy evidence → CLEAR/REVIEW/ABSTAIN routing → Grad-CAM → report → human review.

**Hard boundaries:**
- ML is **frozen** — do not retrain, retune thresholds, or edit `data/models/` (`docs/project-management/FROZEN_CONTRACT.md`).
- **No clinical validation**; no external validation (Messidor-2 license-blocked). Never present outputs as diagnostic.
- Grad-CAM = saliency-vs-lesion-mask *overlap measurement* (weak: 1.39× areal chance, pointing 0.37× annotator chance) — never call it lesion localization.
- Publication readiness is undetermined: it must be judged after literature review and additional experiments.

## 2. Where the truth lives (verification order)

1. `README.md` — self-audit "what is measured, and what is not".
2. `docs/project-management/FROZEN_CONTRACT.md` — locked models/hashes/rules.
3. `docs/project-management/FINAL_RELEASE_STATUS.md` — verified vs not-verified.
4. `docs/validation/metrics.md` + `docs/validation/2026-*` — one report per phase/task.
5. `docs/task-tracker.md` — every task with verdict.
6. `audit/final_project_audit/*.csv` — 20 machine-checkable inventories + truth table.
7. Artifacts under `data/analysis/` (`.mat` decoded read-only with scipy/h5py when needed) — **artifacts beat prose**.

Disputed values were already adjudicated once: `docs/validation/2026-09-26-metric-provenance-resolution.md`.

## 3. Headline facts (all re-verified)

- Val n=733 (train 2,929 / pool 3,662; seed 42); referable n=298 (frac 0.4065).
- Binary @0.60: sens **0.9060**, spec **0.9471**, TP/FP/FN/TN 270/23/28/412, ROC-AUC **0.9796**, PR-AUC **0.7821**.
- 5-class: acc **0.8281**, macro-F1 **0.6805**, QWK **0.8914**; Severe recall 0.4872, Prolif 0.5254.
- Calibration: T=2.5382, ECE 0.0319→0.0087, **display-only**; decisions use raw pRef.
- Router: CLEAR 648 (acc 0.8781) / REVIEW 75 (0.4667) / ABSTAIN 10 (0.3000).
- Quality gate: FAIL 7.837% of 3,662; null finding on accuracy by bucket.
- OOD: Mahalanobis p99=34.22, advisory-only.
- Model-only 0.1028 s/img; full demo median 11.03 s; +2.63 GB.
- Model SHA-256s in dossier Part 4 / `FROZEN_CONTRACT.md`.

## 4. What is NOT true / not present

- No external validation, no clinical validation, no reader study, no CI, no test framework, no MLflow/W&B.
- No McNemar/DeLong/permutation tests anywhere — significance rests on two bootstraps (B=1000 seed 2026; B=500 for ΔAUC).
- "EyePACS-pretrained" wording in pitch/ablation docs is **unsupported** (code says ImageNet init; no EyePACS data).
- Enhancement, vessel features, fovea localization: measured negatives, excluded on evidence.
- Confidence histogram, 5×5 confusion-as-text: artifact-only/UNKNOWN (see JSON `unknown_register`).

## 5. Working rules for the next session

- Evidence discipline: cite `file:line` or artifact path; mark UNKNOWN; never invent data; prefer artifact over document when they disagree and report the discrepancy.
- Keep claims inside the repo's own framing (engineering measurements, internal split).
- Do not touch frozen models/metrics/thresholds; do not rewrite git history.
- `rg` is unavailable in this PowerShell — use the `grep` tool.
- Datasets are gitignored: you cannot re-run training/eval without acquiring APTOS/IDRiD/DRIVE data; audits and doc work run fine without them.
- Pre-existing dirty UI state (Part 31 L8) may need a separate commit before other commits.

## 6. Suggested research agenda (ranked)

1. External validation via the frozen harness once Messidor-2 (or equivalent untouched data) is obtained.
2. Paired significance tests (McNemar/DeLong/permutation) for all future comparisons.
3. Ungradable-image handling — DRIMDB case graded 4 with pRef 0.9690 and routed CLEAR.
4. Severe/Proliferative recall (0.487/0.525, wide CIs).
5. Claim cleanup ("EyePACS-pretrained", OD AUC doc value, T_eval transcription).
6. Reproducibility packaging (dataset acquisition + environment pin).
7. Publish reliability diagram + confidence distribution as first-class evidence.

## 7. Entry commands

```text
launchRetinaAI.m            # GUI app
run src/runs/runSmokeTest   # smoke test from repo root
git log --oneline -10       # recent history (5 commits were ahead at writing)
```

Start reading at `README.md`, then the dossier Part 1 → Part 33 in order.
