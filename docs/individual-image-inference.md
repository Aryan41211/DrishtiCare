# Individual Image Inference

Run a full DrishtiCare pass (quality → screening → grading → Grad-CAM)
on one fundus image.

## Setup (once per MATLAB session)

```matlab
cd('C:\projects\DrishtiCare')
addpath('src','src/setup','src/quality','src/enhancement','src/grading','src/inference')
```

## Demo

```matlab
demoSingleImage("C:\path\to\fundus.jpg")
```

This prints quality, referable probability/decision (threshold 0.60),
grade with confidence, and shows a 4-panel figure
(original | enhanced | Grad-CAM | report).

## Programmatic use

```matlab
result = predictSingleFundus("C:\path\to\fundus.jpg");
result = predictSingleFundus("C:\path\to\fundus.jpg", ...
    'BinaryThreshold', 0.5, 'ShowFigure', false);
```

Fields: `qualityStatus`, `qualityScore`, `binaryProbability`,
`binaryDecision`, `binaryThreshold`, `grade` (0–4), `gradeLabel`,
`classProbabilities` (sums to 1), `confidence`, `gradCAM`.

## Models used

- Screening: `day7_pretrained_resnet18_binary_stage2` (thr 0.60)
- Grading: `day7_pretrained_resnet18_5class_stage2`
- Preprocessing is identical to training (`imresize` 224, same input
  normalization). Override via `'BinaryModel'` / `'GradeModel'`.

## Rules

- Validation/demo images only. Never point this at the official test
  set during development.
- Output is an engineering demo, not a clinical diagnosis.
