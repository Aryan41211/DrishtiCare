# Future Roadmap — SUPERSEDED

> **This file is superseded. Do not use it as a plan.**
>
> It described the 10-day internal round (target 12 Sep 2026), which is **done**.
> Its "Phase 2 future work" list and its "Internal Round vs Full System" table are
> both wrong about the present: they list components as missing that shipped
> before the internal round, and claim `None` for calibration, OOD and cascade.
>
> **Canonical roadmap:** [`docs/project-management/ROADMAP.md`](../docs/project-management/ROADMAP.md)
> (snapshot 2026-09-26). Companion files: `FROZEN_CONTRACT.md` (do-not-change
> list), `DECISION_LOG.md`, `CURRENT_STATUS.md`, `EXECUTION_CHECKLIST.md`, and the
> evidence record [`docs/task-tracker.md`](../docs/task-tracker.md).

## What the old "future work" actually is now

| Old "planned" item | Reality | Status |
|---|---|---|
| Lesion-level segmentation | Classical MA/HE/EX candidates + trained MA detector and optic-disc locator, 10 features into Branch B. **Not** deep lesion segmentation; fovea localization failed (0/10 within 300 px) | **BUILT (as lesion evidence)** — true segmentation still PLANNED |
| Dual-evidence path (Branch A + Branch B) | Independent lesion-feature referable classifier + `fuseEvidence`; A/B conflict forces REVIEW | **BUILT (pilot)** |
| Cascade router | `CLEAR` 648 / `REVIEW` 75 / `ABSTAIN` 10 on the locked 733-image validation split | **BUILT** |
| OOD detection | Mahalanobis on `pool5`, threshold p99 = 34.22 — **advisory only**, never alters grade or referral | **BUILT** |
| Calibration ("None" in old table) | Constrained single temperature, **T = 2.5382**; display-only, screening decision stays on raw `pRef` at the locked threshold 0.60 | **BUILT** |
| ">90% sensitivity / >85% specificity" | Binary sensitivity **0.9060**, specificity **0.9471** at 0.60 on the validation split (not external) | **ACHIEVED (in-distribution)** |
| "Simple Simulink model" | Real `.slx`, model-vs-reference parity `matchesReference = 1`, 11/11 internal sanity checks | **BUILT** |
| Multi-dataset validation (Messidor-2 licence) | Harness ready and passing; the labelled external data needs a human registration/download | **BLOCKED (P14 / P16)** |
| Clinical trials, CDSCO approval, real-world deployment, edge/camera integration | Out of scope for a hackathon prototype | **PLANNED / post-hackathon** |

## Still genuinely open

Packaging and evidence, not modelling: the submission deck and demo video, one
curated Simulink presentation figure, sourced impact statistics, three metric
provenance discrepancies, and external validation once data access exists.

The ML contract is frozen — accuracy 0.8281, macro F1 0.6805, QWK 0.8914,
ROC-AUC 0.9796, PR-AUC 0.7821. Documented negative results (weak Grad-CAM
localization, failed fovea localization, low MA recall, excluded vessel
segmentation, enhancement hurting accuracy) stand as recorded. See
`ROADMAP.md` §4 and §6 for the full list and the do-not-do list.
