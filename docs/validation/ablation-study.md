# Ablation Study — The Centerpiece

## Ablation Table

| # | Configuration | Sens (≥2) | Spec (≥2) | QWK | What It Proves |
|---|--------------|-----------|-----------|-----|----------------|
| 1 | CNN alone (Branch A) | | | | Single-technique baseline |
| 2 | Lesion features alone (Branch B) | | | | Interpretable-only baseline |
| 3 | Fused A+B (no agreement check) | | | | Fusion without safety |
| 4 | Fused A+B with agreement check | | | | Full evidence path |
| 5 | + Quality gating | | | | Module 1 value |
| 6 | + Calibration | | | | Confidence reliability |
| 7 | + TTA/ensemble | | | | Free accuracy |
| 8 | — without EyePACS pretraining | | | | Data ablation |
| 9 | — without preprocessing | | | | Enhancement value |

## The Story

**Integrated pipeline > any single technique.**

The PS explicitly asks for this. Cheap to produce, widely skipped. Design the whole project backwards from this table.
