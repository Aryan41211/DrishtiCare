# Individual Image Inference

Run a full DrishtiCare pass (quality → screening → grading → Grad-CAM →
lesion evidence) on one fundus image.

## Setup (once per MATLAB session)

```matlab
cd('C:\projects\DrishtiCare')
addpath('src','src/setup','src/quality','src/enhancement','src/grading','src/inference','src/lesions')
```

## Demo

```matlab
demoSingleImage("C:\path\to\fundus.jpg")
```

This prints quality, referable probability/decision (threshold 0.60),
grade with confidence, and shows a 5-panel figure
(original | enhanced | Grad-CAM | report | lesion evidence).

Where "lesion evidence" shows classical MA/HE/EX candidate overlays plus a
green optic-disc ring (when the disc is reliably located):

- MA (red dots) = microaneurysm candidates
- HE (cyan dots) = haemorrhage candidates
- EX (yellow dots) = exudate candidates (optic-disc region excluded)
- quadHE = [TR TL BL BR] per-quadrant haemorrhage counts
- meanExudateDistToFovea: only meaningful when called with IDRiD-style
  markups; on arbitrary images (no fovea markup) it is NaN.

## Programmatic use

```matlab
result = predictSingleFundus("C:\path\to\fundus.jpg");
result = predictSingleFundus("C:\path\to\fundus.jpg", ...
    'BinaryThreshold', 0.5, 'ShowFigure', false);
result = predictSingleFundus("C:\path\to\fundus.jpg", ...
    'RunLesions', false);      % skip lesion step for speed
```

Top-level fields: `qualityStatus`, `qualityScore`, `binaryProbability`,
`binaryDecision`, `binaryThreshold`, `grade` (0–4), `gradeLabel`,
`classProbabilities` (sums to 1), `confidence`, `gradCAM`.

Lesion sub-struct `result.lesions`:
`odLocated` (logical), `od` ([cx cy radius] or []), `maCount`, `heCount`,
`exCount`, `quadrantHemorrhage`, `meanExudateDistToFovea`,
`minExudateDistToFovea`, `overlay` (downscaled masks for plotting).

## Models used

- Screening: `day7_pretrained_resnet18_binary_stage2` (thr 0.60)
- Grading: `day7_pretrained_resnet18_5class_stage2`
- Preprocessing is identical to training (`imresize` 224, same input
  normalization). Override via `'BinaryModel'` / `'GradeModel'`.

## Optic disc + exudate caveat (measured, honest)

- The disc is located by a classical heuristic (`estimateOpticDisc`:
  illumination flattening, bright-disc detection, scale-aware acceptance
  band + brightness gate). It is NOT deep-learning and NOT guaranteed.
  Measured on the 10-image IDRiD task-6 set: 5/10 located within 300 px of
  the ground-truth center (mean accepted-center error 292 px), and the rest
  are safely REFUSED (returns empty). A refused disc means exudate counts
  MAY include the optic-disc region; the report prints
  "OD NOT located: exudates may include OD" as an explicit flag. This is a
  documented honest fallback, not a silent error.
- Exudates are hard to separate from the disc region classically; treat EX
  counts as relative features, and trust MA/HE more than EX.

## Rules

- Validation/demo images only. Never point this at the official test
  set during development.
- Output is an engineering demo, not a clinical diagnosis.
