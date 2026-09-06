# IDRiD Lesion Annotation Format (Task 6 prep)

**Purpose:** Reference for Task 6 (lesion-feature branch). Documents the
structure of the IDRiD lesion-annotation data (pixel-level masks for
Microaneurysms, Haemorrhages, Hard Exudates, Soft Exudates, Optic Disc) as it
exists in this repo's local copy. **No pipeline code has been written yet** —
this is data understanding only, per the Task 6 prep scope.

All counts, pixel values and dimensions below were **measured on the local
copy** on 2026-09-07 (file enumeration + pixel sampling). No MATLAB run was
needed; masks were inspected directly.

## 1. Where the files are

Root: `data/idrid/A. Segmentation/` (gitignored — raw data never committed).
License files live next to the data: `CC-BY-4.0.txt`, `LICENSE.txt`.

```
A. Segmentation/
├── 1. Original Images/
│   ├── a. Training Set/        IDRiD_01.jpg … IDRiD_54.jpg   (54 images, 4288×2848 JPEG)
│   └── b. Testing Set/         IDRiD_55.jpg … IDRiD_81.jpg   (27 images)
└── 2. All Segmentation Groundtruths/
    ├── a. Training Set/
    │   ├── 1. Microaneurysms/   54 masks  (IDRiD_01_MA.tif … IDRiD_54_MA.tif)
    │   ├── 2. Haemorrhages/     53 masks  (IDRiD_01_HE.tif … IDRiD_54_HE.tif)
    │   ├── 3. Hard Exudates/    54 masks  (IDRiD_01_EX.tif … IDRiD_54_EX.tif)
    │   ├── 4. Soft Exudates/    26 masks  (only images that contain SE lesions)
    │   └── 5. Optic Disc/       54 masks  (IDRiD_01_OD.tif … IDRiD_54_OD.tif)
    └── b. Testing Set/          same 5 subfolders, 27/27/27/14/27 masks
                                  (IDRiD_55_* … IDRiD_81_*)
```

## 2. Naming convention and image→mask mapping

- One mask file per lesion type, in a per-type folder.
- Mask filename = image ID + type suffix: `IDRiD_<NN>_<TYPE>.tif`
  where `<TYPE>` ∈ {`MA`, `HE`, `EX`, `SE`, `OD`}.
- Mapping is by numeric ID only: `IDRiD_07.jpg` ↔ `IDRiD_07_MA.tif`,
  `IDRiD_07_HE.tif`, etc. No sidecar CSV is needed.

## 3. Mask pixel semantics (measured)

- Format: 1-bit bilevel TIFF (Windows reports `Format1bppIndexed`),
  resolution **exactly matches the original image (4288×2848)** — masks are
  pixel-aligned with the JPGs, so no resize/registration is needed.
- Pixel values are exactly **{0, 255}** (measured by sampling all five mask
  types): `0` = background, `255` = lesion pixels of that type.
- Each lesion type has its own mask; a pixel can be positive in several
  masks (e.g. inside OD and also an EX).

## 4. Missing-file semantics (IMPORTANT, flagged for human confirmation)

- `HE` has 53/54 training masks — the only missing file is `IDRiD_43_HE.tif`
  (measured). `SE` has only 26/54 training masks; present for image IDs:
  03, 08, 13, 14, 17, 18, 19, 22, 23, 25, 30, 31, 32, 33, 35, 38, 39, 46,
  47, 48, 49, 50, 51, 52, 53, 54 (measured list).
- Working interpretation: **an absent mask file means "no annotated
  instances of that lesion type in that image"** (the official IDRiD
  convention), while MA/EX/OD are provided for every image even when the
  mask may be empty. Treat `nnz(mask)==0` exactly like a missing file when
  building candidate extraction. This interpretation is from the dataset's
  published convention, not re-verified against an official manifest —
  confirm once against the IDRiD paper/docs before relying on it in Task 6.

## 5. How to load one mask in MATLAB (correct idiom)

```matlab
projRoot  = fileparts(fileparts(mfilename('fullpath')));   % if run from src/
gtRoot    = fullfile(projRoot, 'data', 'idrid', 'A. Segmentation', ...
    '2. All Segmentation Groundtruths', 'a. Training Set');
typeDirs  = struct( ...
    'MA', '1. Microaneurysms', ...
    'HE', '2. Haemorrhages', ...
    'EX', '3. Hard Exudates', ...
    'SE', '4. Soft Exudates', ...
    'OD', '5. Optic Disc');

imgId    = 'IDRiD_01';
maskFile = fullfile(gtRoot, typeDirs.MA, [imgId '_MA.tif']);

M = imread(maskFile);          % 4288x2848; imread may return a LOGICAL array
                               % for 1-bit TIFFs, or uint8 with values {0,255}
lesionMap = (M > 0);           % robust binary lesion map, works either way

fprintf('%s MA: %d lesion pixels (%.4f%% of image)\n', imgId, ...
    nnz(lesionMap), 100 * nnz(lesionMap) / numel(lesionMap));

% Overlay sanity check against the original image:
img = imread(fullfile(projRoot, 'data', 'idrid', 'A. Segmentation', ...
    '1. Original Images', 'a. Training Set', [imgId '.jpg']));  % 4288x2848
figure; imshow(img); hold on;
vis = imshow(lesionMap); vis.AlphaData = 0.35 * lesionMap;  % red-ish overlay
title(sprintf('%s: Microaneurysm ground truth', imgId));
```

Notes:
- `M > 0` is the safe predicate regardless of whether MATLAB returns the
  mask as `logical` or as `uint8 {0,255}`.
- Guard for missing SE/HE files: `if exist(maskFile, 'file'), ... end` and
  treat absence as an all-zero map (see §4).

## 6. Relevance to Task 6 (not implemented yet)

- MA/HE/EX/SE masks give per-lesion pixel truth for candidate extraction
  (connected components → lesion candidates → features for the
  lesion-feature branch).
- `OD` masks are anatomy (optic disc), not a lesion; useful to exclude the
  OD region from candidate search or as a reference landmark.
- Test-set masks (27 images) exist but stay untouched until any final
  lesion-branch evaluation, mirroring the project's test-set hygiene.

## 7. Explicitly out of scope of this document

- No candidate-extraction implementation, no training, no evaluation was
  run for this prep (Task E scope: understanding the data only).
