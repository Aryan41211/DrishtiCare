# Hardening Phase 1 — Quality Gate → Model Integration Audit

Date: 09-Sep-2026 23:49
Auditor: `src/phase1_quality_gate.m` (additive hardening + measurement; no retraining, no metric changes)
Result: **PASS — 34/34 checks**, with one explicitly reported **null finding** (Question G).

## Hypothesis tested

The quality gate already runs before the model stack in `predictSingleFundus.m`
and forces route `REVIEW` on FAIL. But previously the models **still executed on
FAIL** and a DR decision was still produced — the FAIL path did not truly
withhold an auto-answer. Phase 1 added an **additive** short-circuit
(`SkipModelOnFail`, default `false` = zero behavior change for existing callers)
that returns a fully **withheld** result on FAIL:

- `binaryDecision = 'WITHHELD (quality FAIL - not assessed)'`, `grade = NaN`,
  `gradeLabel = 'NOT ASSESSED (quality FAIL)'`, `classProbabilities = NaN(1,5)`,
  `confidence = NaN`
- `cascade.route = 'REVIEW'`, `qualityGate.enforced = true`,
  `qualityGate.autoAnswerBlocked = true`, `qualityGate.modelsSkipped = true`
- Branch B fusion and OOD detections marked unavailable ("not run")
- `runtimeSec` added to the normal path for fair timing

`buildExplanationNarrative.m` gained the matching `qBlocked` branch so a withheld
decision is narrated as *"no DR severity assessment was produced … recapture or
manual review",* never as a DR finding.

## Results — 34/34 checks

### 1. Integration order (static source check) — 3 PASS
- `assessImageQuality(raw)` occurs at source offset **3214**, before the binary
  `predict(...)` at **7186** → gate provably precedes the model stack — PASS
- `SkipModelOnFail` hook present — PASS
- binary threshold parameter present (locked default 0.60, untouched) — PASS

### 2. Behavioral matrix (representative val images) — 14 PASS
| Case                     | Observed                                              | Expected                                   | Status |
|--------------------------|-------------------------------------------------------|--------------------------------------------|--------|
| FAIL, default            | route=REVIEW, qualityGate.enforced, status=FAIL       | FAIL forces REVIEW                         | PASS |
| FAIL + SkipModelOnFail   | route=REVIEW, autoAnswerBlocked=true, modelsSkipped   | decision withheld, not auto-answered       | PASS |
| FAIL + skip: grade       | NaN                                                    | no grade                                   | PASS |
| FAIL + skip: binary prob | NaN                                                    | no binary prob                             | PASS |
| FAIL + skip: calibrated  | NaN                                                    | no calibrated prob                         | PASS |
| FAIL + skip: Branch B    | fusion.available=false                                 | Branch B not run                           | PASS |
| FAIL + skip: lesions     | odLocated=false, maCount=0                            | lesion CNNs not run                        | PASS |
| WARNING                  | grade computed, status=WARNING, route=CLEAR, not enforced | inference allowed with warning flag   | PASS |
| PASS                     | grade computed, status=PASS                           | normal inference                           | PASS |

### 3. Quality-bucket rates (committed artifacts, no recompute for train)
- Train (`data/analysis/day3/quality_assessment_summary.mat`, n=3662): PASS
  **0.6548**, WARNING **0.2668**, FAIL **0.0784** — exactly reproduces documented
  values — PASS
- Val (fresh full scan of all 733, sorted order matching T0 cache): PASS **0.669**,
  FAIL **0.067** — consistent with train — PASS

### 4. Runtime (PASS image, 3 reps, median)
- gate only: **0.085 s**; full pipeline: **4.57 s** → gate is **1.9%** of total
  cost. The safety check is cheap — PASS

### 5. Model calls avoided by FAIL short-circuit (estimate)
- At the measured 7.84% train FAIL rate: ≈287 FAIL images × 7 skipped
  sub-calls (bin + 5-class net + OD + MA CNNs + OOD + Branch B) ≈ **2009 model
  calls skipped** — PASS (informational)

### 6. Question G — do poor-quality images have higher model error? **NULL FINDING**
| Quality bucket | n (val) | 5-class accuracy |
|----------------|---------|------------------|
| PASS           | 490     | 0.8122           |
| WARNING        | 194     | 0.8711           |
| FAIL           | 49      | 0.8163           |

FAIL-quality images show **no degradation** in accuracy versus PASS (0.816 vs
0.812) on the dev set. Binomial sensitivity/sp are not the lever here either.
**Honest interpretation:** the quality gate is **not** justified by a measurable
accuracy gain — it is a **safety control**. Its benefit is operational: images a
reviewer could not grade (non-analyzable) are routed to manual review instead of
being auto-answered. This null finding is reported as-is; the gate is retained
for decisional safety and the Phase 1 claim is *"FAIL never auto-answers"*, not
*"gating improves accuracy."*

## Artifacts

- `src/phase1_quality_gate.m` (audit/measurement script)
- `data/analysis/day10/phase1/phase1_quality_gate.mat` (full results struct +
  per-image val quality + cached-T0 alignment)
- Modified (hardening): `src/inference/predictSingleFundus.m`
  (`SkipModelOnFail`, withheld result, `runtimeSec`)
- Modified (hardening): `src/explainability/buildExplanationNarrative.m`
  (`qBlocked` branch)

## Rollback

`SkipModelOnFail` defaults to `false`, so all pre-existing callers
(dashboard, `verify_dashboard.m`, `demoSingleImage.m`, `re_audit_T13.m`)
behave exactly as before. Removing the two added branches restores the exact
pre-phase source; no metrics, models, thresholds, or splits were changed.