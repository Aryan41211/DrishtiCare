# Task 9B — A/B Experiment: Effect of Day-4 Image Enhancement on 5-Class DR Grading

**Date:** 2026-09-08/09
**Scope (binding):** 5-class DR grading only. Nothing in this document claims any conclusion
extends to the binary screening model — that is out of scope and would require its own separate A/B.

## Objective

Isolate the net effect of the day-4 `enhanceImage()` preprocessing on 5-class DR grading, holding
every other part of the training/eval protocol identical. Two 5-class ImageNet-pretrained resnet18
networks were trained:

- **Variant A (control / raw):** raw input → `imresize` 224×224 — exactly what the deployed champion does.
- **Variant B (enhanced):** `enhanceImage()` → `imresize` 224×224.

## Methodology

Both variants share the SAME protocol (only the input preprocessing differs):

- Architecture: ImageNet-pretrained resnet18 via `defaultPretrainedConfig.m` (same as the champion).
- Data: `data/splits/train` (2929) / `data/splits/val` (733), seed 42. Variant B consumed
  `data/splits_enhanced` (precomputed enhanced copies), variant A consumed the raw splits.
- `trainClassifier` protocol (identical to champion provenance): in-memory oversample to
  maxPerClass=800/class post-split, augmentedImageDatastore (rot ±15, xreflect, x/y-trans ±10,
  x/y-shear ±5), validation resize-only.
- Stage 1: freeze first 60 backbone layers, 15 epochs, lr 1e-3, batch 32.
- Stage 2: unfreeze all, **5 epochs** (T9B budget override; champion used 15), lr 1e-5, batch 16.
- Optimizer adam, piecewise LR drop 0.5/5ep, validationPatience 8, shuffle every-epoch.
- Evaluation: identical preprocessing to each network's training condition.

**The ONLY difference between A and B is whether `enhanceImage()` is applied before `imresize`.**

## Results (5-class only, 733-val, matching preprocessing)

| Metric | Champion ref (raw) | A (raw) | B (enh) | Delta (B−A) |
|--------|-------------------|---------|---------|-------------|
| Accuracy   | 0.8281 | **0.8322** | **0.5416** | **−0.2906** |
| Macro-F1   | 0.6805 | **0.6828** | **0.4039** | **−0.2789** |
| QWK        | 0.8914 | **0.8952** | **0.6507** | **−0.2445** |

Per-class recall (A vs B):

| Class         | Champion ref | A (raw) | B (enh) | Delta |
|---------------|--------------|---------|---------|-------|
| NoDR          | 0.9834 | **0.9806** | **0.7452** | −0.2355 |
| Mild          | 0.6081 | **0.5811** | **0.4459** | −0.1351 |
| Moderate      | 0.7850 | **0.8150** | **0.2950** | −0.5200 |
| Severe        | 0.4872 | **0.4872** | **0.4359** | −0.0513 |
| Proliferative | 0.5254 | **0.5254** | **0.3220** | −0.2034 |

Champion reference is labeled **reference-on-raw** (Task 0 reverification). Variant A here is the
faithful raw reproduction of the same protocol (5-ep stage 2 vs the champion's 15-ep stage 2) and
lands within measurement noise of the champion on every headline metric (acc +0.0041, qwk +0.0038),
confirming both that A is a valid control and that stage-2 5-ep is a near-equivalent protocol.

## Cross-Condition Diagnostic (preprocessing-mismatch robustness)

| Condition                     | Acc    | Macro-F1 | QWK    |
|-------------------------------|--------|----------|--------|
| netRaw on raw val (matched)   | 0.8322 | 0.6828   | 0.8952 |
| netRaw on enhanced val (mismatch) | 0.4925 | 0.1320 | 0.0000 |
| netEnh on enhanced val (matched)  | 0.5416 | 0.4039   | 0.6507 |
| netEnh on raw val (mismatch)  | 0.5116 | 0.1995   | 0.2594 |

**Implication:** The raw-trained model (A) is highly sensitive to preprocessing mismatch — feeding it
enhanced inputs collapses QWK to 0.0000 (predictions become nearly class-invariant). The enhanced
model (B) is less catastrophic under mismatch but its matched-condition performance (0.5416 acc)
is already far below A's matched performance (0.8322). Both models are strongly preconditioned on
their training input distribution; there is no free robustness to swap.

## Wall-Clock Table

| Step | Duration |
|------|----------|
| Precompute enhanced splits (3662 files; resumed) | ~9284 s total (invocation 1 ≈3600 s for 2268 train files + invocation 2 = 5684.5 s for remaining 661 train + 733 val) |
| Variant A stage 1 (raw) | 3158.9 s (52.6 min) |
| Variant A stage 2 (raw) | 2830.7 s (47.2 min) |
| Variant B stage 1 (enh) | 3874.8 s (64.6 min) |
| Variant B stage 2 (enh) | 2894.3 s (48.2 min) |
| Evaluation (4 conditions × 733 imgs) | 1488.0 s (24.8 min) — A 78.9 s (no enhancement), B 781.2 s, crossRaw-on-enh 575.9 s (enhanceImage is the dominant cost), crossEnh-on-raw 52.0 s |

## Honesty Notes

- **Variant A stage 1 early-stopped at 9 of 15 epochs** (validationPatience 8 met; final val acc
  73.53%). Variant B stage 1 also **early-stopped at 9 of 15 epochs** (final val acc 66.71%). Both
  stages 2 ran the full budgeted 5 epochs.
- **Precompute resumed across two MATLAB invocations** (invocation 1 wrote 2268 train files before
  the 60-min tool timeout; invocation 2 finished the remaining 661 train + all 733 val in 5684.5 s).
  The info artifact captures the 5684.5 s of invocation 2 plus a note; the combined wall time was
  ≈9284 s. Also, the info mat's `trainCount` was corrected (the last invocation only counted its own
  newly-written files) to the true total of 2929 / 733.
- **Variant B stage 1 first attempt failed** after 34 s due to ONE corrupted enhanced PNG
  (`data/splits_enhanced/train/class_2/a505981d1cab.png`, PNG library read error). The file was
  regenerated and verified (size [1424 2144 3], uint8); training then succeeded. The enhanced-split
  integrity scan reported exactly 1 bad file, now fixed.
- **Variant B produced "failed to save checkpoint" warnings** (filesystem, did not
  abort training; the final models saved normally). Checkpoints are ancillary — no impact on the
  reported stage1/stage2 mats.
- Numbers in this report are quoted from the saved artifacts (`data/analysis/day9/task9b_ab_eval.mat`
  and the per-stage `.mat` files), not from memory.

## Explicit Scope / Safety Statements

- **5-class-only finding.** No claim here extends to the binary screening model.
- **Champions untouched:** `data/models/day7_pretrained_resnet18_5class_stage{1,2}.mat`,
  `day7_pretrained_resnet18_binary_*.mat` were neither read for training nor modified.
- **Threshold (0.60), APTOS test set, and all Day-7 artifacts untouched.**
- New experiment IDs `day9_5class_raw` / `day9_5class_enh`; no existing model file was overwritten.
