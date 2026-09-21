# IDRiD lesion dataset audit (Grad-CAM alignment evaluation)

Generated: 21-Sep-2026 02:21:26

## Summary

- Total candidate images: 81
- Valid image+mask pairs (usable for evaluation): 81
-   of which train split: 54, test split: 27
- Skipped images: 0 (every skip has a documented reason)

## Skip reasons (an image can carry several)

- missing/unreadable image: 0
- missing mask file: 0 (per type: MA 0, HE 0, EX 0, SE 0)
- unreadable mask: 0
- empty mask (0 lesion px): 0 (per type: MA 0, HE 0, EX 0, SE 0)
- mask/image dimension mismatch: 0
- no valid lesion pixels in any type: 0
- other: 0

## Per-lesion-type coverage (usable masks)

| Type | files on disk | usable (candidates) | usable (valid pairs) | median mask px (full res) |
|---|---|---|---|---|
| MA | 81 | 81 | 81 | 10367 |
| HE | 80 | 80 | 80 | 58861 |
| EX | 81 | 81 | 81 | 52629 |
| SE | 40 | 40 | 40 | 38471 |

Note: the IDRiD Disease-Grading label CSVs cover IDRiD_001..IDRiD_413
(train) and IDRiD_001..IDRiD_103 (test) only; the segmentation images
IDRiD_01..IDRiD_81 are a distinct image set with NO 5-class grade labels.
Lesion metrics therefore do not require a grade label (documented
limitation; see the main report for the proxy correctness definition).
