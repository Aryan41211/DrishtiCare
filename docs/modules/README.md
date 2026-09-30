# Module specs

Per-module narrative for the seven modules that were specified up front, written
during the 10-day build. Kept as design history.

**`src/` is authoritative.** If anything here disagrees with the code or with
[`../ARCHITECTURE.md`](../ARCHITECTURE.md), the code wins and this is stale. The
module map in `ARCHITECTURE.md` is the current statement of what exists and what
each part is responsible for.

| File | Module | Current code |
|---|---|---|
| [quality-assessment.md](quality-assessment.md) | Quality assessment | `src/quality/` (13 files) |
| [image-enhancement.md](image-enhancement.md) | Image enhancement | `src/enhancement/` (3 files) — **excluded on evidence**, see below |
| [grading-classifier.md](grading-classifier.md) | Grading classifier | `src/grading/` (13 files), `src/calibration/` (6) |
| [gradcam-explainability.md](gradcam-explainability.md) | Grad-CAM explainability | `src/explainability/`, `src/ui/renderGradCAMViews.m` |
| [segmentation-od-vessels.md](segmentation-od-vessels.md) | Segmentation | `src/vessel/` (11 files) — **vessel features excluded on evidence** |
| [simulink-workflow.md](simulink-workflow.md) | Simulink workflow | `src/simulink/` (5 files) |
| [future-roadmap.md](future-roadmap.md) | Future roadmap | superseded by [`../project-management/ROADMAP.md`](../project-management/ROADMAP.md) |

## Two of these shipped differently than specified

Recorded here so a reader of the spec is not misled:

- **Image enhancement** was specified as a stage in the pipeline. The A/B
  experiment showed it degraded grading, so the deployed path feeds the model
  the raw resized image. The code remains in `src/enhancement/` as the
  experiment, not as a pipeline stage.
- **Vessel features** were specified for Branch B. Adding them moved Branch-B
  AUC from 0.8969 to 0.8810, so the branch ships without them. The negative
  result is kept in the record rather than deleted.

Both are the intended behaviour of the build: measure, then exclude on evidence.
Neither is an oversight.

## Naming

These files predate `src/` and use the `MODULE-n-NAME.md` scheme referenced by
[`../../archive/architecture.md`](../../archive/architecture.md). The filenames
were flattened when the directory moved; the numbering is no longer meaningful
and the table above is the real index.
