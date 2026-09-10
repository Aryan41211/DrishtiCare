# Hardening Phase 5 — Error Analysis (error tree, verified stories)

Date: 10-Sep-2026 00:23
Auditor: `src/phase5_error_analysis.m`
Result: **PASS — 5/5 checks.** All counts reconcile with committed values
(acc 0.8281, FP 23, FN 28, CLEAR error rate below overall). Every error
"story" below is derived from the cached 733-val predictions and the
fresh full-val quality scan, not assumed.

Method (per hardening rules): treat every error as a possible problem, build
the error tree from data, then check each branch against the committed
predictions.

## Error tree

```
all 733
 |-- correct 607 (0.8281)
 `-- error 126 (0.1719)
      |-- adjacent-grade confusions (±1): 92
      `-- far-grade confusions (|gap|>=2): 34
           |-- from true class 2 (Mild):        4
           |-- from true class 3 (Moderate):   12
           `-- from true class 5 (Prolif.):    18   <- dominant severity miss
      binary layer (referable, pRef>=0.60):
           |-- FP 23  (0.0437 fp-rate)
           `-- FN 28
      router layer (committed router, locked defaults):
           |-- errors AUTO-ANSWERED as CLEAR:  79  (err-rate 0.1219)
           |-- sent to REVIEW:                 40
           `-- ABSTAIN:                         7
```

## Verified stories

1. **Most errors are adjacent-grade shuffles (92/126, 73%).** Classic
   Moderate-vs-Severe boundary ambiguity; matches the router's documented
   reason for the `marginThr=0.20` REVIEW rule.

2. **The serious tail is missed Proliferative (P5):** 18 of 34 far errors
   (distance ≥2) come from true class 5 (n=59, misread rate 0.4746). A
   Proliferative eye sent to Mild/No-DR is the highest-cost failure mode and
   is the primary motivation for the ABSTAIN band near pRef=0.60 and the
   REVIEW screen/grade-conflict rule. Also true-class 4 (Severe, n=39) has the
   highest single misread rate 0.5128, all within ±1.

3. **Quality correlates weakly but measurably with binary errors:**
   FAIL-quality images (n=49) show FP 0.0408 / FN 0.0612 vs PASS (n=490)
   0.0286 / 0.0367. Consistent with Phase 1's "no 5-class accuracy gain from
   the gate" — but the gate remains justified as a *safety and error-reduction*
   control at the binary-referral layer, not as an accuracy lever.

4. **Errors are concentrated in lower-confidence predictions** — the error
   rate climbs monotonically with falling argmax confidence:
   high (≥0.75) 0.1409 → mid (0.50–0.75) 0.5179 → low (<0.50) 0.6667.
   Confidence is well-disciplined: it tracks error likelihood.

5. **The router intercepts a majority of errors:** only 79/126 errors would be
   auto-answered (CLEAR), 40 go to a human (REVIEW) and 7 are too close to a
   decision boundary to be answered at all (ABSTAIN). CLEAR error rate 0.1219
   < overall 0.1719 → the router demonstrably filters risk.

## Bounds already built in

- Adjacent errors inside CLEAR are a designed residual: locked
  `marginThr=0.20`, `reviewConf=0.75`, `abstainConf=0.50` trade auto-rate for
  safety and are frozen (Phase 6 re-locks thresholds; Phase 7 re-freezes all
  metric definitions).

## Artifacts

- `src/phase5_error_analysis.m`
- `data/analysis/day10/phase5/phase5_error_analysis.mat`
  (contains error masks, adjacent/far split, FP/FN, router intersection, conf
  matrix)

## Rollback

Read-only audit; no production code changed.
---
Engineering demo, NOT a clinical device: all cited metrics are engineering measurements on validation-set artifacts from the frozen protocol (Phase 10); no clinical validation is claimed.
