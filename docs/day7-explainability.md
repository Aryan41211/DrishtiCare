# DrishtiCare Day 7 — Explainability (Grad-CAM)

## Method
- `gradCAM` on champion nets, feature layer `res5b_relu`, target = predicted class.
- 14 curated validation cases: 1 correct + 1 error per 5-class grade,
  plus 2 binary false negatives and 2 false positives (thr 0.60).
- Overlays + manifest in `data/analysis/day7/`.

## Quantitative sanity check
Fraction of heatmap mass inside the retinal foreground mask
(`createRetinalMask`):

| Case | Kind | Mass inside |
|------|------|-------------|
| 005b95c28852 (NoDR→NoDR) | correct | 0.495 |
| 0cbcc7b23613 (NoDR→Moderate) | error | 0.754 |
| 0fb1053285cf (Mild→Mild) | correct | 0.797 |
| 06b71823f9cd (Mild→Proliferative) | error | 0.673 |
| 026dcd9af143 (Moderate→Moderate) | correct | 0.713 |
| 000c1434d8d7 (Moderate→Proliferative) | error | 0.616 |
| 15bed5adde74 (Severe→Severe) | correct | 0.518 |
| 05cd0178ccfe (Severe→Moderate) | error | 0.849 |
| 187f6ccda87a (Proliferative→Proliferative) | correct | 0.731 |
| 03a7f4a5786f (Proliferative→Moderate) | error | 0.613 |
| 0c55d58bebaf (binary FN) | binary_FN | 0.895 |
| 144a1a426137 (binary FN) | binary_FN | 0.697 |
| 0cbcc7b23613 (binary FP) | binary_FP | 0.754 |
| 2a2274bcb00a (binary FP) | binary_FP | 0.923 |

**Mean: 0.716.** No systematic background/border focus — the model
attends to retinal content, not frame artifacts. Two correct cases near
0.50 (005b95c28852, 15bed5adde74) are flagged for visual review.

## Notable error patterns (for Day 8 review)
- NoDR→Moderate with pRef 0.969 (0cbcc7b23613): confident FP, also the
  binary FP — candidate for quality-gate review.
- Mild→Proliferative (06b71823f9cd) and Moderate→Proliferative
  (000c1434d8d7): overcalls toward Proliferative.
- Proliferative→Moderate with pRef 0.309 (03a7f4a5786f): undercall,
  referable but low confidence — threshold choice matters here.
- Binary FN 144a1a426137 (Moderate→NoDR, pRef 0.216): hardest miss.

## Limitations
- Grad-CAM is coarse (7×7 upsampled); it localizes regions, not lesions.
- Heatmaps explain *where*, never *why* clinically.
- Visual inspection of overlays still required before SIH demo.

## Contrast analysis: true-class vs predicted-class evidence
For all 5 error cases, heatmaps for the true and predicted grades were
compared (correlation of the two maps):

| Error | True → Pred | Correlation |
|-------|-------------|-------------|
| 0cbcc7b23613 | NoDR → Moderate | 0.19 |
| 06b71823f9cd | Mild → Proliferative | -0.27 |
| 000c1434d8d7 | Moderate → Proliferative | -0.55 |
| 05cd0178ccfe | Severe → Moderate | -0.46 |
| 03a7f4a5786f | Proliferative → Moderate | -0.14 |

All near-zero or negative: the model attends to **different regions**
for each hypothesis. Errors are attention failures (looking at the
wrong place), not borderline-feature disagreements.

## Class-average attention (20 correct images per grade)

| Grade | n | Mass inside retina | Self-consistency |
|-------|---|--------------------|------------------|
| NoDR | 20 | 0.619 | 0.715 |
| Mild | 20 | 0.830 | 0.652 |
| Moderate | 20 | 0.784 | 0.444 |
| Severe | 7 | 0.705 | 0.694 |
| Proliferative | 13 | 0.768 | 0.504 |

Readings: Mild is the most retina-focused grade; Moderate attention is
the least consistent (0.44) — the model looks at different places for
different Moderate images, matching its broad middle-grade nature; the
Severe pool holds only 7 correctly classified images, itself a measure
of Severe recall weakness. Average maps saved as `avgmap_*.png`.

## Files
- `src/grading/gradcamExplain.m`, `src/run_day7.m`
  (modes: verify / full / contrast / avgmaps)
- `data/analysis/day7/`: manifest, contrast pairs, average maps,
  28 case overlays (PNGs)
