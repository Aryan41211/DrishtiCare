# Metric Provenance Resolution — 2026-09-26

**Scope:** ROADMAP P6 — the three documented numeric discrepancies. Investigated by
reading the authoritative `.mat` artifacts directly (this is what the earlier
"unresolved" notes said required re-running MATLAB).

**Scripts (new, read-only):**
- `src/verify/verify_metric_provenance.m` — recursive numeric search of every
  candidate artifact for the disputed values, tolerance `5e-4` (the project's own
  committed-precision tolerance from Phase 4).
- `src/verify/confirm_provenance_resolutions.m` — decisive per-claim checks.

**Artifacts:**
- `data/analysis/day11/provenance/provenance_findings.mat`
- `data/analysis/day11/provenance/provenance_resolutions.mat`

**Rules honoured:** nothing was retrained, no threshold was tuned, no model was
touched, and **no value was chosen because it looked better**. Each resolution below
is decided by what the artifact actually contains.

---

## Summary

| # | Discrepancy | Outcome | Authoritative value |
|---|---|---|---|
| 1 | DRIVE task8 mean Dice: `0.2576` vs `0.2541` | **Doc correct.** `0.2541` is not reproducible from the artifact at all. | **0.2576** (mean of `dice1`, 20 images) |
| 2 | Human inter-observer Dice: `0.7881` vs `0.7902` | **Both are real, from two different pipelines.** Not a conflict once labelled. | **0.7881** for the task8 CNN; `0.7902` belongs to the classical vessel module |
| 3 | Day-7 scratch baseline: `0.8307/0.8667` vs `0.8322/0.9080` | **Resolved — pre-freeze vs frozen evaluation protocol.** | **`0.8322 / 0.9080`** (frozen protocol) |

**None of the three changes a frozen headline metric, a conclusion, or a
production decision.** The vessel negative result, the enhancement negative result
and the champion contract are all untouched.

---

## 1. DRIVE task8 mean Dice — the document was right

`data/analysis/day8/task8/drive_test_dice.mat` contains six 20-element vectors.
Directly recomputed:

| Variable | n | mean | median | min | max |
|---|---:|---:|---:|---:|---:|
| `dice1` (vs 1st_manual, official) | 20 | **0.257599** | 0.261347 | 0.199038 | 0.302788 |
| `dice2` (vs 2nd_manual, independent) | 20 | **0.253191** | 0.256032 | 0.202875 | 0.304726 |
| `iou1` | 20 | 0.148093 | 0.150317 | 0.110517 | 0.178403 |
| `iou2` | 20 | 0.145242 | 0.146811 | 0.112889 | 0.179750 |
| `humanDice` | 20 | 0.788123 | 0.788397 | 0.743293 | 0.829774 |
| `pixelAuc` | 20 | 0.610989 | 0.613087 | 0.552801 | 0.665882 |

The report's §3 table (`Mean Dice 0.2576 | 0.2532`, `Mean IoU 0.1481 | 0.1452`,
`Human inter-observer Dice 0.7881`, `Pixel ROC-AUC 0.6110`) reproduces **exactly**
from these means. Every cell of that table is correct.

**The `0.2541` claim is refuted.** It is not the mean of any vector in the file, and
not any single element either (the nearest, `dice1(19)`, is `0.253743`; the two
genuine aggregates are `0.2576` and `0.2532`). It appears to have been a
transcription of neither.

**Resolution:** §3 table stands unchanged. `0.2576` is confirmed as the mean Dice
against the official 1st_manual annotation.

## 2. Human inter-observer Dice — two pipelines, not a conflict

Two artifacts each hold a correct 20-image human inter-observer mean:

- `data/analysis/day8/task8/drive_test_dice.mat` → `humanDice`, mean **0.788123** → `0.7881`
  Produced by `src/eval_segmenter_drive.m` on the 20 DRIVE test images at native
  584×565 (STRIDE 4), scored inside the **un-eroded** `mask` FOV.
- `data/analysis/vessel/drive_vessel_metrics.mat` → `results.meanHumanDice` = **0.790240** → `0.7902`
  Produced by the classical vessel pipeline, which scores inside a **FOV eroded by
  5 px** (`data/analysis/vessel/phase3/metrics.txt:6`, and its line 47 records
  "human inter-observer ~0.790").

These are different masking conventions over the same 20 DRIVE test images, so they
**should** differ slightly. Neither is wrong; the fault was presenting them as a
single disputed quantity.

**Resolution:** the task8 report keeps `0.7881` (its own artifact, un-eroded FOV).
`0.7902` must always be labelled as the classical/eroded-FOV pipeline. This confirms
the reasoning already recorded in that report's existing note — the warning against
mixing the pipelines was correct, and is now verified rather than merely argued.

## 3. Day-7 scratch baseline — pre-freeze vs frozen protocol

The two committed sources disagreed on the **binary referable sens/spec** of the same
Day-5 scratch baseline. Verified from both artifacts:

| | `day5_resnet18_baseline_results.mat` (`metrics2`) | `day7/eval_fixed_day5_resnet18_baseline_stage2.mat` (`m`) |
|---|---|---|
| accuracy | 0.736698 | 0.736698 |
| macroF1 | 0.508335 | 0.508335 |
| QWK | 0.767181 | 0.767181 |
| referable sensitivity | 0.830671 | **0.832215** |
| referable specificity | 0.866667 | **0.908046** |
| referable tp / fp / fn / tn | 260 / 56 / 53 / 364 | 248 / 40 / 50 / 395 |
| implied positives (tp+fn) | **313** | **298** |

Decisive checks:

- `YTrue` identical: **yes**. `YPred` identical: **yes**. The 5-class predictions are
  bit-for-bit the same, which is why accuracy / Macro F1 / QWK agree exactly. Only the
  binary operating point differs.
- `sum(YTrue>=3)` = **298** — exactly the `eval_fixed` positive count. The `eval_fixed`
  numbers are computed under the **frozen referable definition** (`label>=3`, Phase 7).
- `sum(YTrue>=2)` = 372, which is **not** 313. So the older figure is **not** a
  different label definition; it is a different operating threshold on the referable
  probability, applied before the 0.60 threshold was provenance-pinned in Phase 6.

**Resolution:** `0.8322 / 0.9080` is authoritative — it is the frozen protocol.
`0.8307 / 0.8667` is a **pre-freeze** derivation (313 positives) and is retained for
historical traceability only. Consequently the §2 first bullet of
`docs/day7/pretrained-resnet-report.md` (73.67% / F1 0.5083 / QWK 0.7672 / sens
83.22% / spec 90.80%) is **already correct under the frozen protocol** — it needed a
provenance citation, not a number change.

**Correction to an earlier working note:** the scratch-baseline pair was initially
suspected to be a category error (accuracy/QWK mislabelled as sens/spec). It is not —
`docs/day7/pretrained-resnet-report.md` labels the row "Scratch baseline sens / spec"
correctly. The real fault was mixing a pre-freeze operating point into a
frozen-protocol table.

---

## What did NOT change

- Champion models, both SHA-256 hashes, threshold `0.60`, `T=2.5382`, and every
  headline metric in the frozen contract.
- The vessel negative result: the segmenter (Dice ~0.26) is far below DRIVE
  deep-learning SOTA (~0.80) and stays excluded from production
  (`predictSingleFundus.m:231`).
- The decision to exclude vessel features from Branch B.
- `data/analysis/vessel/phase3/metrics.txt`, which remains valid **as the classical
  pipeline's own record** and must keep its own FOV convention.

## Follow-ups this does *not* close

- `src/eval_segmenter_drive.m` has not been re-executed; this resolution reads the
  committed artifact rather than regenerating it. The means reproduce the table to
  6 decimal places, so regeneration is not required to settle the question.
- `audit/final_project_audit/06_referable_metrics.csv`, `10_vessel_metrics.csv` and
  `19_verification_checks.csv` still contain the pre-resolution `0.2541` / `0.7902`
  framing. They are point-in-time audit records and are **not** rewritten; the
  correction is recorded here and cross-linked from the two affected reports.
