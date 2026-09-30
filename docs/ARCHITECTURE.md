# Architecture

Authoritative map of this repository. `src/` is the single source of truth for
what the system is made of. Prose descriptions of modules elsewhere in the
repo are explanatory only — if one disagrees with this file or with `src/`,
`src/` wins and the prose is stale.

## Read in this order

1. This file — how the code is organised and why.
2. `docs/project-management/FROZEN_CONTRACT.md` — what must never change.
3. `docs/project-management/FINAL_RELEASE_STATUS.md` — what is verified, and
   what is deliberately not done.
4. `docs/validation/` — the evidence behind each claim.

## Runtime pipeline

The live path a fundus image takes. Everything else in `src/` supports,
validates, or visualises one of these stages.

```
image
  |
  v
quality/        quality gate ......... PASS | WARNING | FAIL
  |                                  FAIL stops here; model never runs
  v
inference/      predictSingleFundus.m .. 5-class + binary heads
  |              cascade_router.m ...... CLEAR | REVIEW | ABSTAIN
  v
ood_detection/  Mahalanobis bound 34.22 ... advisory only, never routes
  |
  +--> grading/          confusion, per-class error analysis
  +--> explainability/   buildExplanationNarrative.m
  +--> lesions/          MA / HE / EX candidate counts (experimental)
  +--> reporting/        generateDrishtiReport.m -> branded A4 PDF
  +--> ui/               colormap, theme, Grad-CAM render helpers
```

`predictSingleFundus.m` is the contract boundary. It is the frozen entry
point: the two champion models, seed 42, threshold 0.60, temperature 2.5382
and the locked 733-image split all resolve through it. Do not change its
signature, its return shape, or the order the gates run in — phase 11 audits
that order and phase 17 audits model immutability.

## Module map

| Module | Files | Responsibility |
|---|---:|---|
| `quality/` | 13 | Image quality gate. Runs **before** the model. Measured 65.48% PASS / 26.68% WARNING / 7.84% FAIL on APTOS; 42% withheld on foreign cameras. |
| `inference/` | 3 | The frozen pipeline: `predictSingleFundus.m`, `cascade_router.m`, `demoSingleImage.m`. |
| `grading/` | 13 | Per-class error analysis, confusion, the 5-class weakness in Severe NPDR. |
| `ood_detection/` | 2 | Mahalanobis detector, locked p99 34.22. Advisory. |
| `calibration/` | 6 | Temperature scaling. T = 2.5382, display-only, never routes. |
| `explainability/` | 1 | `buildExplanationNarrative.m` — the sentence set shown in the report. |
| `lesions/` | 24 | MA / HE / EX candidate counting. **Experimental**; recall 0.113. Every output is qualified. |
| `vessel/` | 11 | Vessel features and segmentation. Excluded from production on evidence (Branch-B AUC 0.8969 -> 0.8810). |
| `enhancement/` | 3 | Image enhancement A/B. Excluded on evidence; it degraded grading. |
| `reporting/` | 6 | Branded A4 PDF via the headless Edge engine (Report Generator is unlicensed). |
| `dashboard/` | 9 | `DRScreeningDashboard.m` figure and its headless runner. |
| `ui/` | 4 | Shared theme, colormap, Grad-CAM colourbar. |
| `data_loaders/` | 5 | Dataset readers. Datasets themselves are gitignored. |
| `runs/` | 29 | Model-evaluation entry points. See the note below. |
| `demo/` | 7 | Demo figure rendering and `run_unseen_rehearsal.m`. |
| `analysis/` | 8 | Saliency/lesion metric computation, small shared helpers. |
| `simulink/` | 5 | District resource-planning `.slx` model and its engine check. |
| `setup/` | 4 | Environment pinning. |
| `verify/` | 27 | The headless test suite. This is the gate surface. |
| `phases/` | 24 | Chronological audit scripts. Deliberately not restructured — see below. |

## Two directories that break the pattern, on purpose

`src/` is otherwise organised by **function**. Two directories are organised
by **time** instead, and both are deliberate. `src/` holds 20 modules in all.

**`src/phases/` — keeps the P0-P25 claim traceable.**
`phase1_quality_gate.m` through `phase25_final_capstone.m` are the hardening
programme, and deck slide 4 plus `docs/project-management/ROADMAP.md` both
publish the claim "Hardening programme P0-P25, 230/230 checks PASS". Those 24
files are the evidence for that claim. Renumbering or regrouping them by
function would break the traceability of a number we have already presented,
for no functional gain. Left as-is deliberately.

**`src/runs/` — the evaluation entry points.**
29 scripts that run models against data. These are the public interface to the
work; they are kept together rather than scattered by function so that "how do
I evaluate this?" has one answer. Nine of them were invisible to git until
commit `184c31e`, because `.gitignore` patterns without a leading slash matched
them at every depth. Fixed; all 29 are now tracked.

## Verification surface

Everything that can fail automatically lives in `src/verify/` and is
headless. These four are the gates, and all four must pass before a commit
that touches them is considered done:

| Gate | Function | Asserts |
|---|---|---|
| App layout | `verify_app_layout` | 217/217 measurable components inside the 1360x760 canvas; 0 clipped; three content panels disjoint. |
| Grad-CAM rendering | `verify_gradcam_rendering` | Deterministic overlay output. |
| PDF report | `verify_drishti_report_extended` | Real PDF saved through the Edge engine; extended checks. |
| Deck geometry | `pitch/audit_deck_pptx.ps1` | PowerPoint-rendered deck: 0 text overflows, 0 text-on-text overlaps, 11 pictures. |

Run them from the repo root:

```matlab
addpath('src/verify'); addpath('src/dashboard'); addpath('src/reporting');
addpath('src/inference');
verify_app_layout
verify_gradcam_rendering
verify_drishti_report_extended
```

```powershell
powershell -ExecutionPolicy Bypass -File pitch\audit_deck_pptx.ps1
```

Chromium `fallback_task_provider` lines in the MATLAB log are Edge engine
startup noise, not failures.

## Conventions

- **Naming:** 114 of 204 `.m` files are `snake_case`, 1 is `PascalCase`. The
  snake_case majority is consistent, so it stands. Do not mass-rename — the
  churn would risk every `addpath` chain for no functional gain.
- **Data is never committed.** Datasets are gitignored. Regenerate from
  `data/`; nothing under `src/` depends on a checked-in image.
- **Commit granularity.** One logical change per commit, Conventional Commits
  messages, pushed immediately. The audit trail is part of the product here:
  a claim in the deck must be traceable to the commit that established it.
- **Chromium noise is expected.** See above.

## Where the prose lives

`docs/` is the only home for documentation. `docs/modules/` holds the
per-module narrative, `docs/schedule/` the historical day-by-day plan, and
`docs/project-management/` the release and contract records. If you find a
markdown file at the repo root describing the system, it is a candidate to
move here.
