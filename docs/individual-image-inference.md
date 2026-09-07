# Individual Image Inference

Run a full DrishtiCare pass (quality → screening → grading → Grad-CAM →
lesion evidence) on one fundus image.

## Setup (once per MATLAB session)

```matlab
cd('C:\projects\DrishtiCare')
addpath('src','src/setup','src/quality','src/enhancement','src/grading','src/inference','src/lesions','src/explainability','src/ood_detection','src/cascade_router')
```

## Demo

```matlab
demoSingleImage("C:\path\to\fundus.jpg")
```

This prints quality, referable probability/decision (threshold 0.60),
grade with confidence, and shows a 2-row explanation figure with panels:
original | enhanced | Grad-CAM // lesion evidence | decision metrics |
explanation narrative.

The decision-metrics panel also reports the out-of-distribution (OOD)
status (Mahalanobis distance vs. a 99th-percentile threshold on training
features) and the confidence-router (cascade) decision: CLEAR / REVIEW /
ABSTAIN. These feed the narrative's governance sentence and, when OOD or
uncertain, force a "manual review / follow-up" recommendation over an
auto-answered screening.

Where "lesion evidence" shows lesion candidate overlays plus a green
optic-disc ring (when the disc is reliably located):

- MA (red dots) = microaneurysm candidates from a trained CNN ensemble
- HE (cyan dots) = haemorrhage candidates (classical)
- EX (yellow dots) = exudate candidates (optic-disc region excluded)
- quadHE = [TR TL BL BR] per-quadrant haemorrhage counts
- meanExudateDistToFovea: only meaningful when called on images where a
  fovea center is available upstream (e.g. an API caller supplying the
  fovea markup). On arbitrary images (no fovea markup) it is NaN.
  Fovea localization from the retina alone is NOT reliable (see below).

The "explanation narrative" panel is a generated, clinical-style, hedged
paragraph assembled from the model's own evidence: severity grade,
confidence, screening decision, lesion-candidate counts (with quadrant
spread and exudate-to-fovea distance), optic-disc located/refused flag,
image quality, and a referral recommendation. It is explicitly flagged as
an engineering demonstration, NOT clinical advice; lesion counts are
automated candidate detections, not clinical-grade measurements.

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
`classProbabilities` (sums to 1), `confidence`, `gradCAM`,
`explanation` (see below).

Lesion sub-struct `result.lesions`:
`odLocated` (logical), `od` ([cx cy radius] or []), `maCount`, `heCount`,
`exCount`, `quadrantHemorrhage`, `meanExudateDistToFovea`,
`minExudateDistToFovea`, `overlay` (downscaled masks for plotting).

Explanation sub-struct `result.explanation` (from
`src/explainability/buildExplanationNarrative.m`): `.paragraph`
(full text), `.assessment`, `.evidence`, `.screening`, `.recommendation`,
`.quality`, `.governance` (OOD/cascade sentence), `.caveats`.

OOD sub-struct `result.ood`: `available`, `flag` (true = out-of-distribution,
review), `mahalanobis`, `threshold`, `nearestClass`. When not available
(module/data missing), `available=false` and the pipeline degrades
gracefully rather than erroring.

Cascade sub-struct `result.cascade`: `available`, `route`
('CLEAR'/'REVIEW'/'ABSTAIN'), `detail` (thresholds + reasons used).

## Models used

- Screening: `day7_pretrained_resnet18_binary_stage2` (thr 0.60)
- Grading: `day7_pretrained_resnet18_5class_stage2`
- Preprocessing is identical to training (`imresize` 224, same input
  normalization). Override via `'BinaryModel'` / `'GradeModel'`.

## Optic disc location (CNN, measured)

- The disc is located by a trained CNN (`locateOpticDiscCnn`): a 192×192
  patch-level OD/background classifier (ensemble of two nets: first-pass +
  hard-negative retrain) applied on a sliding grid (stride 48 at s4), with
  the disc center taken as the grid cell of maximum ensemble P(OD).
  `predictSingleFundus` uses the CNN first and falls back to the classical
  `estimateOpticDisc` heuristic only when the CNN's max P(OD) is below the
  acceptance gate (honest refusal). Both can refuse; the report prints
  "OD NOT located: exudates may include OD" as an explicit flag.
- Measured on the 10-image IDRiD holdout (IDRiD_01..10, compared against
  the OD segmentation-mask centroids, which align with the images): CNN
  locates 10/10 and lands **9/10 within 300 px** of the ground-truth disc
  center (mean accepted-center error ~230 px; located peaks sit on bright
  disc regions). The classical detector on the same reference: 5/10 located,
  4/10 within 300 px (mean 390 px over all located).
- The CSV center markups were NOT used as reference: they disagree with the
  segmentation masks by up to ~2000 px on some images (e.g. IDRiD_05/06/08/10),
  while the masks align with the images (bright disc regions). Mask centroids
  are the reliable reference here.
- Exudates are hard to separate from the disc region classically; treat EX
  counts as relative features (classical, moderate), and treat HE counts as
  weak (classical, recall ~0.10).

### OD refinement attempts — tested and measured (incl. lessons, 2026-09-07)

Classical bright-blob attempts were tested and rejected on evidence:

- **Attempt 1 (vessel-density peak rescue):** blurred vessel mask, take
  global density peak as the disc hub. Result: 0/10 within 300 px (was
  3/10); peak lands on the vascular arcade, not the disc.
- **Attempt 2 (directional line-voting rescue):** vote along each vessel's
  local orientation into a Hough-style accumulator. Result: 0/10 within
  300 px (was 3/10); vessels radiate OUTWARD from the disc, so extended
  lines cross away from the hub.
- **Root cause (per-blob diagnostics on the classically-refused images):**
  where the disc is not the largest bright blob, the true disc blob is
  absent (no disc-shaped blob at any threshold: 001/004/006) or too dim to
  pass the brightness gate (005/008). The bright-blob heuristic was at its
  honest ceiling.
- **CNN locator (the fix):** a patch CNN trained on the 54 IDRiD
  segmentation masks (44 train / 10 holdout) replaces the heuristic. Its
  first sliding-window version FAILED (1/10 within 300 px) because of a
  coordinate-scrambling bug — `reshape(score,[ny nx])` reorders a
  row-major crop sequence column-wise for non-square grids (19×11), so the
  heat map was transposed/jumbled and peaks landed on arbitrary bright
  structures. Fixing the layout (explicit row/col map) + ensemble of both
  nets gives the 9/10 result above. The offline probe that first declared
  "classifier fires everywhere" was itself reading misaligned cells.
- **Known residual failure (IDRiD_10):** the single miss. The true disc
  cell scores P(OD)≈0.999, but several large confluent bright plates also
  saturate to P≈1.0 (pre-softmax logit ~18 higher at a far cluster), so
  max-cell selection picks an impostor. A disc-shape/brightness prior
  (radial-std + eccentricity) was tested across all 10 and REGRESSED the
  other 9 images, so it was rejected. img10 is a genuinely hard case
  (bright plate resembling a disc) and remains a documented 1/10 failure
  with the honest report flag preserved.

## Fovea localization (tested and rejected — honest negative result)

We attempted to localize the fovea to compute a clinically meaningful
"exudate distance to fovea." Two approaches were built and measured on the
IDRiD 01–10 holdout against the fovea-center CSV markups:

- **CNN locator** (`locateFoveaCnn`, patch-based, trained on the 54 IDRiD
  training images): located 9/10 with accept-gate on, but **0/10 within
  300 px** of ground truth (mean accepted error ~620 px). The fovea is a
  subtle, low-contrast feature that a small-patch CNN cannot localize
  reliably; the network effectively anchors on brighter surrounding tissue.
- **Disc-relative anatomical estimate** (fovea ≈ K × disc-radius temporal to
  the disc center; K swept 2.0–3.5): even worse — mean error ~1400 px. The
  disc–fovea offset in x is not a consistent multiple of disc radius across
  these images.

**Consequence (honest):** the pipeline does NOT emit a fovea-derived
distance by default. `meanExudateDistToFovea` / `minExudateDistToFovea`
remain `NaN` unless a fovea center is supplied by the caller (e.g. from a
standard automated eye-parameter pipeline). We prefer an explicit `NaN`
over an invented number that would mislead. The code stays in the repo
(`src/lesions/locateFoveaCnn.m`, `buildFoveaDataset.m`,
`trainFoveaCnn.m`) for future work if fovea-labeled training data becomes
available.

## Microaneurysm counts (CNN, measured operating point)

- `maCount` comes from a trained CNN ensemble (`detectMaCnn`), replacing the
  previously broken classical MA stage (recall 0.002 / precision 0.003 at
  scale 4).
- Detector: dark-dot candidate generation (black-hat, top ~13k/image) →
  48×48 full-res crops → ensemble of two CNNs (original + hard-negative
  retrained) → non-max suppression (24 px radius) → threshold 0.90 on P(MA).
- Held-out IDRiD images 01–10 (never trained), tol 12 px, matching per GT
  blob: **recall 0.113, precision 0.595** at threshold 0.90. Patch-level
  held-out AUC 0.976 (2409 MA positives from 54 images, 44/10 holdout).
- Trained nets are committed at `data/analysis/day8/ma_cnn/ma_cnn_net.mat`;
  training code at `src/lesions/{buildMaDataset,trainMaCnn,hardNegMineMaCnn}.m`.
- This is a LOW-RECALL relative severity cue (~11% of MAs found), useful for
  highlighting present MAs, NOT a clinical-grade count. `maScoreThr` can be
  lowered (e.g. 0.5 → recall 0.874) at the cost of precision (0.019).

## Rules

- Validation/demo images only. Never point this at the official test
  set during development.
- Output is an engineering demo, not a clinical diagnosis.
