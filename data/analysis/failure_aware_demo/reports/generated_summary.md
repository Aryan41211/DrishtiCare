# Failure-aware demo - generated summary

Generated: 2026-09-21 19:49:28

- Quality config: `2.0.0` (Prototype - NOT clinically validated)
- Cases available: 9
- Cases that reached AI inference: 3
- Models unchanged during run: 1
- Binary model SHA-256: `43E8DF33B429231EE5BD60A775FDB3629AD81F287617AFAA9308EA87D311F9A0`
- 5-class model SHA-256: `DD152C917689146F6DEC4687B263EC5E5F237ECF60EC719A59F9FCEEFF737C1B`

## Held-out val scan (733 images)

| overall | count |
|---|---|
| PASS | 490 |
| WARNING | 194 |
| FAIL | 49 |

### FAIL categories

| category | count |
|---|---|
| Blur | 4 |
| High Sharpness | 5 |
| Low Contrast | 15 |
| Low Foreground | 5 |
| Other | 7 |
| Overexposure | 5 |
| Underexposure | 8 |
| Uneven Illumination | 11 |

## Per-case audit

| case | role | quality | inference | grade | referral | route | reason |
|---|---|---|---|---|---|---|---|
| case_pass_referable | pass_referable | PASS | true | 4 (Proliferative) | REFERABLE | CLEAR |  |
| case_pass_nodr | pass_nodr | PASS | true | 0 (No DR) | NON-REFERABLE | REVIEW |  |
| case_warning | warning | WARNING | true | 0 (No DR) | NON-REFERABLE | CLEAR | Image has unusual sharpness. May contain noise or artifacts. / Uneven illumination (edges brighter than center). |
| case_fail_blur | fail_blur | FAIL | false | not assessed | WITHHELD | REVIEW | Image is too dark. Consider retaking with better illumination. / Image has very low contrast. Lesions may be hard to detect. / Image appears blurry. Please retake with steady camera. |
| case_fail_dark | fail_dark | FAIL | false | not assessed | WITHHELD | REVIEW | Image is too dark. Consider retaking with better illumination. / Image has very low contrast. Lesions may be hard to detect. / Image appears blurry. Please retake with steady camera. / Insufficient retinal area visible. Adjust camera position. |
| case_fail_bright | fail_bright | FAIL | false | not assessed | WITHHELD | REVIEW | Image is overexposed. Consider retaking with reduced flash. / Image has unusual sharpness. May contain noise or artifacts. |
| case_fail_illumination | fail_illumination | FAIL | false | not assessed | WITHHELD | REVIEW | Image has unusually high contrast. May indicate artifacts. / Unusually large foreground. May include non-retinal tissue. / Uneven illumination (center brighter than edges, vignetting). |
| case_fail_fov | fail_fov | FAIL | false | not assessed | WITHHELD | REVIEW | Image is too dark. Consider retaking with better illumination. / Insufficient retinal area visible. Adjust camera position. / Uneven illumination (center brighter than edges, vignetting). |
| case_fail_contrast | fail_contrast | FAIL | false | not assessed | WITHHELD | REVIEW | Image has very low contrast. Lesions may be hard to detect. |
