# Hardening Phase 2 — Confidence Router (CLEAR/REVIEW/ABSTAIN) Audit

Date: 10-Sep-2026 00:01
Auditor: `src/phase2_cascade_router_audit.m` (cached-T0 predictions only; no
re-inference, no retraining, no threshold changes)
Result: **PASS — 18/18 checks**, route fractions + per-route error measured on
the full locked 733-val set.

## Locked decision math (contract)

Defaults in `cascade_router.m` (verified reproducible from committed source):

| Parameter      | Value | Meaning |
|----------------|-------|---------|
| `abstainConf`  | 0.50  | grade confidence below this → ABSTAIN |
| `pRefBand`     | 0.05  | \|pRef − 0.60\| < band → ABSTAIN (near locked threshold) |
| `reviewConf`   | 0.75  | confidence below this → REVIEW |
| `marginThr`    | 0.20  | top1−top2 margin below → REVIEW (adjacent-grade ambiguity) |
| `agreePRef`    | 0.50  | screen/grade direction disagreement pivot → REVIEW |
| `pRefLocked`   | 0.60  | binary referral threshold — **LOCKED, read-only here** |

Priority: **ABSTAIN > REVIEW > CLEAR.** All three synthetic-rule arms verified
(12 synthetic cases): healthy/severe/prolif confident → CLEAR; uniform
confidence, pRef∈[0.55,0.65) → ABSTAIN; screen/grade conflict, conf<0.75,
margin<0.20 → REVIEW.

**Float-boundary finding (documented, not a defect):** at `pRef = 0.55` exactly,
`|0.55−0.60|` computes as `0.049999… < 0.05` in IEEE double, so the band check
fires and the router ABSTAINs (safest branch). At `pRef = 0.53` (clear of the
band) the same scores route REVIEW via `conf<0.75`. Behavior is safe in both
branches; reported for reproducibility.

## Measured results — full locked val (n=733, cached T0 predictions)

Router applied to cached `s5` probs + binary `pRef` (1-based labels converted to
0-based grade for the router). Locked decision stays `pRef ≥ 0.60`.

| Route  | n        | %      | acc5  | binSens | binSpec | TP | FN | TN | FP |
|--------|----------|--------|-------|---------|---------|----|----|----|----|
| CLEAR  | 648      | 88.4%  | 0.8781| 0.9478  | 0.9665  | 218| 12 | 404| 14 |
| REVIEW | 75       | 10.2%  | 0.4667| 0.7833  | 0.4667  | 47 | 13 | 7  | 8  |
| ABSTAIN| 10       | 1.4%   | 0.3000| 0.6250  | 0.5000  | 5  | 3  | 1  | 1  |
| ALL    | 733      | 100%   | 0.8281| 0.9060  | 0.9471  | 270| 28 | 412| 23 |

True-referable fraction: CLEAR **0.355**, REVIEW **0.800**, ABSTAIN **0.800**
(overall 0.407).

## Interpretation (honest)

- **The router works as designed:** the auto-answer subset (CLEAR, 88% of
  cases) is *safer and more accurate* than the pool — acc5 0.878 vs 0.828,
  binary sensitivity 0.948 vs 0.906, specificity 0.967 vs 0.947. Screening
  decisions auto-answered on CLEAR are measurably nearer-reliable than
  unfiltered screening.
- **REVIEW/ABSTAIN concentrate uncertainty:** 80% of cases sent to a human are
  genuinely referable, and 5-class accuracy there collapses to 0.47 / 0.30 —
  exactly the ±1-grade and near-threshold cases a grader should arbitrate.
  ABSTAIN is the least-trustworthy subset (acc5 0.30) — the router correctly
  flags "do not auto-route" where the model is confessing doubt.
- CLEAR still contains 12 FN referables (grade≥2 whose pRef<0.60). That is the
  locked-threshold behavior (sens 0.948), not a router flaw; CLEAR documents
  which cases the system *will* auto-answer and at what estimated reliability,
  so the operating headroom is explicit.
- No threshold was changed; nothing was retuned on validation; the sealed test
  set was untouched (cached predictions only).

## Artifacts

- `src/phase2_cascade_router_audit.m`
- `data/analysis/day10/phase2/phase2_cascade_router_audit.mat` (results +
  per-image routes + per-route TP/FN/TN/FP/acc/sens/spec)

## Rollback

Read-only audit; no production code changed in Phase 2.
---
Engineering demo, NOT a clinical device: all cited metrics are engineering measurements on validation-set artifacts from the frozen protocol (Phase 10); no clinical validation is claimed.
