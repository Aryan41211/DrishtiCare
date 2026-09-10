# Hardening Phase 4 — Stability / Reproducibility Audit

Date: 10-Sep-2026 00:18
Auditor: `src/phase4_stability_audit.m`
Result: **PASS — 13/13 checks.** Locked models byte-for-byte intact; T0
headline metrics recompute from the cached val arrays to committed precision;
inference is bit-deterministic under repeated runs.

## 1. Locked-model integrity vs Phase 0 manifest — 2 PASS

Both champions re-hashed and compared against the baseline manifest SHA-256:

| Model | Manifest SHA-256 (exact, uppercase, 64 hex) | Status |
|-------|---------------------------------------------|--------|
| 5-class `day7_pretrained_resnet18_5class_stage2.mat` | `DD152C91…F737C1B` | ✔ match |
| Binary `day7_pretrained_resnet18_binary_stage2.mat`  | `43E8DF33…11F9A0` | ✔ match |

No retraining, no overwrite. (First run of this audit reported the hashes as
short strings — a **bug in the audit script's .NET hash loop**, not file
corruption; fixed to use certutil SHA-256 and re-verified exact-match.)

## 2. T0 headline metrics recomputed fresh from cached arrays — 5 PASS

Independently recalculated from `reverify_audit_T0.mat` (733 val predictions,
no re-inference) using the committed definitions (per-class precision/recall→
macro F1; `computeQWK` with weights `(i−j)²/16`, chance-normalized; referable =
grade≥2 → pRef∈[3,4,5] in 1-based labels; locked decision pRef≥0.60):

| Metric | Recomputed | Committed | Δ | Match |
|--------|-----------|-----------|-----|-------|
| accuracy | 0.828104 | 0.8281 | <5e-5 | ✔ |
| macro F1 | 0.680459 | 0.6805 | <5e-5 | ✔ |
| QWK      | 0.891401 | 0.8914 | <5e-5 | ✔ |
| bin sens (ref) | 0.906040 | 0.9060 | <5e-5 | ✔ |
| bin spec (ref) | 0.947126 | 0.9471 | <5e-5 | ✔ |

## 3. Inference determinism — 6 PASS

The locked nets are run twice on the same 3 val images (classes 0/1/2). Both
5-class softmax vectors and binary referable probabilities were **bit-identical**
(`isequal` on doubles) across runs. Nothing stochastic on the eval path — the
cached T0 predictions are exactly reproducible at the model level.

## Tolerance windows (locked for Phase 4)

- Model hashes: exact (SHA-256, 64 hex, uppercase).
- Metrics: ≤ 5e-4 absolute (matches the artifacts' own 4-decimal print
  precision; measured deltas were ≤ 5e-5).
- Determinism: bit-exact.

## Artifacts

- `src/phase4_stability_audit.m`
- `data/analysis/day10/phase4/phase4_stability_audit.mat`

## Rollback

Read-only audit; no production code changed.
---
Engineering demo, NOT a clinical device: all cited metrics are engineering measurements on validation-set artifacts from the frozen protocol (Phase 10); no clinical validation is claimed.
