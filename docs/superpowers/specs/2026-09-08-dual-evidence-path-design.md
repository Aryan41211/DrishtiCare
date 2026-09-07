# Dual-Evidence Path — Branch A + Branch B + Evidence Agreement

Date: 2026-09-08
Status: Approved (design); follow-up creates the implementation plan.

## Problem

The roadmap's Phase 2 "Grand Finale" (`modules/future-roadmap.md`) lists a
dual-evidence path (Branch A + Branch B) as the clinical-safety mechanism,
and the archived architecture (`archive/architecture.md`) specifies an
evidence-agreement layer: Branch A (deep grading) and Branch B (lesion
features) produce independent assessments; agreement commits the grade,
disagreement forces human review. Today only Branch A runs.

## Goals

1. Build a lightweight, interpretable Branch B (lesion-feature → referable
   probability) on the lesion features already produced by
   `extractLesionCandidates`.
2. Add an evidence-fusion / agreement layer that flags referable/non-referable
   discrepancies between Branch A and Branch B for review.
3. Surface the fused result in the single-image report (decision panel +
   explanation narrative) without changing the locked 0.60 referability
   decision or the OS-closed test-set policy.

## Non-negotiable constraints

- Official APTOS test set is CLOSED. Never read or touch
  `data/aptos2019/test_images`.
- Binary referable threshold locked at 0.60; the screening decision stays on
  the raw Branch A P(referable). Fusion may only *add* review flags, never
  silently downgrade a referable call.
- `data/models/day7_pretrained_resnet18_*` are read-only.
- Report only measured numbers. Branch B is a PILOT (lesion candidate
  counts are low-recall cues), so claims stay hedged and honest.
- Disjoint file ownership across background agents; the coordinator edits
  `predictSingleFundus.m` / `buildExplanationNarrative.m` only after agents
  return.

## Approach

### Branch B feature cache (single sequential pass)

`src/lesions/build_aptos_feature_cache.m`

- Stratified subsample of APTOS train (~400 images, balanced across grades
  0–4) for feature caching. Rationale: full 2929-image lesion extraction is
  slow (MA requires a CNN); a balanced subsample keeps Branch B pilot honest
  without a multi-hour cache build.
- For each image: `extractLesionCandidates(imgPath, ...)` with
  `returnVisual=false` for speed, `maScoreThr=0.90`.
- Features per image: MA_count, HE_count, EX_count, quadrant hemorrhage
  vector (4), OD located flag, EX near disc flag (or disc-relative EX
  distance).
- Also record `grade` (ground truth) and `isVal` split membership (reuse the
  day7 733-val membership via the same cache/split source of truth).
- Save `data/analysis/day8/branch_b/feat_cache.mat`.

### Branch B classifier

`src/lesions/trainBranchB.m` → fitted model saved as
`data/analysis/day8/branch_b/branchB_model.mat`.

- Target: referable = (grade >= 2).
- Input: the cached feature vector (MA/HE/EX counts, quadrants, OD flag,
  disc-relative EX).
- Model: logistic (fitclinear) OR gradient-boosted trees
  (fitcensemble/fitcecoc on the referable target); compare both, pick by
  held-out AUC on the firewalled eval slice.
- Fit/eval protocol: disjoint fit/eval split of the feature cache, seeded,
  replicated-and-reported. Honest caveat documented: lesion counts are
  low-recall relative cues; Branch B accuracy will be below Branch A.
- `branch_b_predict.m`: `pRefB = branchBPredict(feat)` → P(referable).
- Report AUC, ECE (calibrated-equivalent view), match-rate vs Branch A on
  the eval slice.

### Fusion / evidence-agreement module

`src/lesions/fuseEvidence.m`

```
[agree, discrepancy, detail] = fuseEvidence(aInfo, bInfo, opts)
```
- `aInfo` = Branch A: grade, confidence, raw pRef, calibrated pRef.
- `bInfo` = Branch B: pRefB (and a neutral value if Branch B unavailable).
- Outputs:
  - `agree` logical: both agree on referable/non-referable direction (with
    Branch A confidence gate: A confident & B concurs — even if B is a weak
    classifier — counts as agreement toward CLEAR; A confident & B disagrees
    → discrepancy → REVIEW).
  - `discrepancy` logical: A and B conflict on direction.
  - `detail`: a struct with flags (aReferable, bReferable, neutralB,
    routeOverride).
- Rule: discrepancy → suggests cascade REVIEW (callback to cascade_router or
  a direct routeOverride='REVIEW'). Never downgrades a referable.

### Report integration (coordinator, after agents return)

- In `predictSingleFundus.m`: optional `'RunBranchB'` (default on). When on,
  after Branch A + cascade, if the case would otherwise be CLEAR, run Branch
  B (load cached feature extractor + Branch B model) and call
  `fuseEvidence`. Populate `result.fusion`:
  - `.branchB` (pRefB), `.agree`, `.discrepancy`, `.routeOverride`, `.available`.
  - If discrepancy → `result.cascade.route` escalated to REVIEW (honest:
    the cascade router was already run; the override is flagged, not silently
    mutated).
- In the report decision panel: add a line
  `Branch B (lesion): pRefB=..%  agree/discrepancy`.
- In `buildExplanationNarrative.m`: add a sentence describing the fused
  evidence when Branch B ran (e.g. "Branch B (lesion-feature) reads
  [X]; it agrees with / conflicts with the deep model, flagged for review").

## Testing / verification

- Smoke: `fuseEvidence` on synthetic agree/disagree/neutral cases.
- End-to-end: `test_lesion_report.m` across the 5 APTOS grades — confirm
  `result.fusion` present, decision path unchanged, narrative renders.
- `verify_branch_b.m`: Branch B AUC on the firewalled eval slice + a
  discrepancy rate vs Branch A on the eval slice (report only measured).

## Files touched (disjoint ownership)

Owned by Agent F1 (Branch B):
- `src/lesions/build_aptos_feature_cache.m` (new)
- `src/lesions/trainBranchB.m` (new)
- `src/lesions/branch_b_predict.m` (new)
- `src/verify_branch_b.m` (new)
- `data/analysis/day8/branch_b/feat_cache.mat`, `branchB_model.mat` (new)

Owned by Agent F2 (fusion + integration hooks; no predictSingleFundus edits):
- `src/lesions/fuseEvidence.m` (new)
- (Optional) `src/verify_fuseEvidence.m` (new, synthetic cases)

Coordinator (after agents return):
- `src/inference/predictSingleFundus.m` (Branch B wiring + panel line)
- `src/explainability/buildExplanationNarrative.m` (fusion narrative)
- Regenerate report PNGs; run `test_lesion_report.m` end-to-end.

## Open / deferred

- Full 2929-image feature cache (would enable a stronger Branch B) — deferred
  for CPU-time; subsample is the pilot scope.
- Deep lesion detector as Branch B — out of scope (roadmap lists it under
  Phase 2 but lesion segmentation is too heavy; the pilot Branch B uses the
  existing candidates).