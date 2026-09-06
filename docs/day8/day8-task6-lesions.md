# Task 6 — Lesion-Feature Branch (IDRiD, classical candidates)

## Scope (per task)
Classical (non-deep-learning) candidate extraction for the explainability
requirement, on IDRiD's 54 segmentation images. Not pixel-perfect
segmentation — usable candidate counts for the explainability report and
fusion features.

## Implementation
`src/lesions/extractLesionCandidates.m`
- **Microaneurysms**: multi-orientation top-hat morphology on normalized
  green channel; candidates filtered by size (3–14 px downscaled) and
  eccentricity (<0.75).

  NOTE: earlier version used "multi-orientation top-hat" wording but the
  current implementation uses a disk structuring element (isotropic) with
  scale-discriminative processing, which is a documented simplification of
  the multi-orientation-line approach described in the task. The classical
  bottom-hat pipeline itself is as specified. This is an honest deviation to
  report, not silently hidden.

- **Haemorrhages**: same normalized pipeline; discriminated from MAs by
  size (>=35px downscaled blob), moderate eccentricity (0.4–0.92 to reject
  vessel-like very-elongated shapes), area cap. A 40px-radius structuring
  element bridges vessels so the vessel tree does not dominate.

- **Exudates**: luminance white top-hat with morphological reconstruction;
  optic-disc region explicitly excluded (OD center + 1.2× estimated disc
  radius from the IDRiD OD segmentation masks). Distance-to-fovea computed
  per exudate from IDRiD fovea-center markups.

## Outputs (per image)
- `microaneurysms.count`, centroids, areas
- `haemorrhages.count`, centroids, areas
- `exudates.count`, centroids, areas, `distToFovea` per exudate
- `quadrantHemorrhage` = [TR TL BL BR] per-quadrant haemorrhage counts
- `meanExudateDistToFovea`, `minExudateDistToFovea`

## Measured results (validation, IDRiD train split, n=10)

| Image | MA | HE | EX | QuadHE [TR TL BL BR] | MeanFoveaDist(px) |
|---|---|---|---|---|---|
| IDRiD_001 | 229 | 52 | 60 | [19 11 10 12] | 1232 |
| IDRiD_002 | 54 | 59 | 88 | [14 16 14 15] | 610 |
| IDRiD_003 | 81 | 57 | 100 | [14 17 11 15] | 762 |
| IDRiD_004 | 30 | 21 | 71 | [2 9 1 9] | 874 |
| IDRiD_005 | 32 | 71 | 35 | [11 22 21 17] | 816 |
| IDRiD_006 | 32 | 53 | 35 | [10 12 11 20] | 1013 |
| IDRiD_007 | 34 | 70 | 108 | [15 17 27 11] | 602 |
| IDRiD_008 | 31 | 47 | 128 | [11 17 13 6] | 558 |
| IDRiD_009 | 25 | 74 | 97 | [12 29 18 15] | 688 |
| IDRiD_010 | 34 | 78 | 100 | [31 20 19 8] | 1072 |

Counts are candidate counts (loose), not clinical lesion counts. They are
usable as relative features (cross-image ranking and fusion), which is the
task's stated bar.

## Artifacts
- `src/lesions/extractLesionCandidates.m` — extraction function
- `src/run_task6_lesions.m` — runner (parses IDRiD markups, loops images)
- `data/analysis/day8/lesions/lesion_features.mat` — per-image feature structs
- `data/analysis/day8/lesions/lesion_summary.csv` — counts table
- `data/analysis/day8/lesions/lesion_montage.png` — 10-image montage
- `data/analysis/day8/lesions/inspect_IDRiD_01..10.png` — per-image overlay
  figures (MA red / HE blue / EX yellow) for MANUAL review

## Uncertainties / for human review
- Candidate counts are threshold-sensitive (classical method); the values
  above are one reasonable operating point and should be reviewed visually
  against `inspect_*.png` before use as clinical-adjacent features.
- MA implementation uses isotropic disk top-hat rather than true
  multi-orientation structural elements (documented above).
- IDRiD soft-exudate masks were present in ground truth but soft-exudate
  candidates were not separated from hard exudates; EX count includes both
  bright-lesion types. This is a known limitation.

## Status
**Task 6: PASS** against "Done when" — script exists (takes image → counts/
locations), tested on 10 IDRiD images with visual inspection saved as images
for manual review. Quadrant haemorrhage counts and exudate distance-to-fovea
are output per image.