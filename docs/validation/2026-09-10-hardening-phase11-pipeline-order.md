# DrishtiCare Hardening — Phase 11: Inference Pipeline Order & Robustness Audit

Date: 2026-09-10. Runs: 3 (initial run exposed two audit-check defects, corrected; final 11/11 PASS).

## Purpose

Verify that `predictSingleFundus.m` executes the frozen pipeline in production
order, that no auxiliary stage leaks into the referable decision, and that user
safety paths (quality FAIL / Branch B discrepancy / OOD) behave correctly at
runtime. Phase 10 froze the *measurement* path; Phase 11 audits the *production*
entry point.

## Defect found and fixed (latent runtime crash)

`predictSingleFundus.m:321` (pre-fix):

```matlab
if strcmp(det.routeOverride,'REVIEW') && result.cascade.available
    result.cascade.detail = [result.cascade.detail ' | Branch B conflict ...'];
```

`cascade.detail` is a **struct** (from `cascade_router`); `[struct + char]`
throws a concatenation error in MATLAB. Triggered whenever Branch B
(slash-feature model) contradicted Branch A on the referral direction and the
cascade was available — exactly the case that *should* escalate to manual
review. Additionally, the old code never changed the route, so even without the
crash a discrepancy left a "CLEAR" case answered when the fusion contract says
REVIEW. Reproducer recorded in the audit (`P11 concat_repro`): struct+char
concatenation errors.

**Fix** (`predictSingleFundus.m`): on `routeOverride=='REVIEW'` the cascade
route is now escalated to `REVIEW`, `cascade.fusionConflict=true`, and the
fusion reason is stored; the detail struct is preserved. Regression-exercised in
the audit on a real val image (#16 in the sorted val scan, first discrepancy
case): discrepancy → route REVIEW, no crash.

## Order invariants (all PASS)

1. Referable decision is made from RAW `pRef >= 0.60` **before** any
   calibration output is computed (source lines 144 vs 151); `binaryDecision`
   is never derived from `pCalibrated`.
2. OOD runs before routing but is **never passed to** `cascade_router`
   (advisory-only, confirmed at source) — consistent with Phase 9.
3. Quality-gate FAIL escalates to REVIEW (Task 9A), after the router runs.
4. `SkipModelOnFail` WITHHELD short-circuits before the first model predict
   (source lines 39 vs 141).
5. Branch B fusion runs after routing so it can escalate (source 244 vs 300).

## Runtime robustness (all PASS)

- Synthetic black image + `SkipModelOnFail=true`: full WITHHELD result, route
  REVIEW, `grade=NaN`, `autoAnswerBlocked=true`, lesion/ood/fusion defaults
  present, narrative builds.
- Same black image without skip: completes the full stack, still forced to
  REVIEW by the quality override.
- Real val image with Branch B discrepancy: escalates to REVIEW without
  crashing (the fixed bug), `fusionConflict=true`.

## Honest notes

- Branch-A-referable in `fuseEvidence` uses the *calibrated* `pRef` (auxiliary),
  so in the ~11/733 cases where calibrated and raw disagree near 0.60 the fusion
  view can differ from the raw referable decision. Fusion only influences
  governance/recall narrative, never the decision.
- The escalation change turns previously-CLEAR discrepancy cases into REVIEW for
  the production entry point. It does not alter the frozen headline numbers,
  which come from the locked T0 cache / router rules (Phases 4-9 inputs).

## Artifacts
- `src/phase11_pipeline_order_audit.m`
- `data/analysis/day10/phase11/phase11_pipeline_order.mat`
- Source fix: `src/inference/predictSingleFundus.m` (fusion escalation; docstring
  pipeline order corrected)
---
Engineering demo, NOT a clinical device: all cited metrics are engineering measurements on validation-set artifacts from the frozen protocol (Phase 10); no clinical validation is claimed.
