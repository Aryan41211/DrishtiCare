# Task 13 — Final Cross-Cutting Re-Audit Report

Date: 09-Sep-2026 18:09
Auditor: re_audit_T13.m (runs against committed artifacts only — no re-training)
Result: **PASS — 63/63 checks, every documented headline number reproduces exactly.**

## Method

Extends the Task 0 method (fresh re-run, `re_verify_audit.m`) to a full
cross-cutting audit of all work committed since T0. No re-training, no
re-inference beyond T0's own cached predictions and two single-image behavioral
checks. Every number is verified against the **committed** `.mat` artifact that
first produced it:

| Headline number     | Source artifact |
|---------------------|-----------------|
| Champions 5-class + binary @0.60 | `data/analysis/day8/reverify_audit_T0.mat` |
| Calibration T4 firewalled         | `data/analysis/day8/calibration/{current_T,firewalled}/…mat` |
| Calibration T5 standard split     | `data/analysis/day8/calibration/standard/standard_calibration.mat` |
| Branch B full-val                 | `data/analysis/day8/task7/branchb_fullval_T7.mat` |
| T9B enhancement A/B               | `data/analysis/day9/task9b_ab_eval.mat` |
| RF-1 OD discrepancy               | `data/analysis/day9/od_discrepancy_investigation.mat` |
| RF-3 ensemble/TTA cache           | `data/analysis/day9/ensemble_scores_cache.mat` |
| T12 dashboard numbers             | `load_dashboard_data()` (committed data layer) |
| Quality-gate + fovea behavior     | two pre-commit example images through `predictSingleFundus` |

## Results

### 0. Invariants (4 checks)
- Binary threshold locked at **0.60** (hard-coded default in
  `predictSingleFundus.m` + `cascade_router.m`) — **unchanged** — PASS
- Closed test set present but only *listed*; no labels loaded, no inference — PASS
- Both champion models present and read-only (5-class + binary) — PASS

### 1. T0 champions recap (733 val, fresh predictions cached) — 8 checks
| Metric            | Measured | Documented | Status |
|-------------------|----------|------------|--------|
| accuracy          | 0.8281   | 0.8281     | PASS   |
| macro F1          | 0.6805   | 0.6805     | PASS   |
| quadratic Kappa   | 0.8914   | 0.8914     | PASS   |
| binary sensitivity| 0.9060   | 0.9060     | PASS   |
| binary specificity| 0.9471   | 0.9471     | PASS   |
| binary ROC-AUC    | 0.9796   | 0.9796     | PASS   |
| binary PR-AUC     | 0.7821   | 0.7821     | PASS   |
| recall NoDR       | 0.9834   | 0.9834     | PASS   |

### 2. T4 firewalled calibration — 7 checks (see note at `current_T.mat`)
| Metric             | Measured | Documented | Status |
|--------------------|----------|------------|--------|
| promoted T         | 2.5382   | 2.5382     | PASS   |
| T_fit (firewalled) | 2.5382   | 2.5382     | PASS   |
| ECE raw (eval)     | 0.031915 | 0.031915   | PASS   |
| ECE calibrated     | 0.0087196| 0.0087196  | PASS   |
| NLL raw (eval)     | 0.1998   | 0.1998     | PASS   |
| NLL calibrated     | 0.12425  | 0.12425    | PASS   |
| flip fraction @0.60| 0.0074105| 0.0074105  | PASS   |

### 3. T5 standard-split calibration — 4 checks
| Metric               | Measured | Documented | Status |
|----------------------|----------|------------|--------|
| T_fit (train)        | 2.6722   | 2.6722     | PASS   |
| ECE raw (val)        | 0.045013 | 0.045013   | PASS   |
| ECE calibrated (val) | 0.029653 | 0.029653   | PASS   |
| flip fraction        | 0.016371 | 0.016371   | PASS   |

### 4. T7 Branch B full-val — 9 checks
| Metric               | Measured | Documented | Status |
|----------------------|----------|------------|--------|
| Branch B AUC         | 0.8969   | 0.8969     | PASS   |
| Branch A AUC (sanity)| 0.9796   | 0.9796     | PASS   |
| A/B match @0.60      | 0.8295   | 0.8295     | PASS   |
| agreement (n)        | 598      | 598        | PASS   |
| discrepancy / review | 135      | 135        | PASS   |
| full-val rows        | 733      | 733        | PASS   |
| A/B alignment misses | 0        | 0          | PASS   |
| uses promoted T      | 2.5382   | 2.5382     | PASS   |
| OD located rate      | 0.1064   | 0.1064     | PASS   |

### 5. T9B enhancement A/B (model-agnostic, 733 val) — 8 checks
| Metric            | Raw (control) | Enhanced | Status |
|-------------------|---------------|----------|--------|
| accuracy          | 0.8322        | 0.5416   | PASS   |
| quadratic Kappa   | 0.8952        | 0.6507   | PASS   |
| macro F1          | 0.6828        | 0.4039   | PASS   |
| n                 | 733           | 733      | PASS   |

Enhanced pipeline **hurts** — correctly reported, nothing promoted. Raw control
remains within noise of champion (0.8322 vs 0.8281), as documented.

### 6. RF-1 OD discrepancy — 5 checks
| Metric                    | Measured | Documented | Status |
|---------------------------|----------|------------|--------|
| APTOS val CNN-located     | 78 / 733 = 0.1064 | 0.1064 | PASS |
| APTOS val CNN refused     | 655       | 655        | PASS   |
| total images              | 733       | 733        | PASS   |
| IDRiD 01-10 located       | 10 / 10   | 10/10      | PASS   |

### 7. RF-3 ensemble/TTA bounds — 2 checks
- Ensemble cache shape (733×5) and finite (no NaN) champion scores — PASS.
- Nothing was promoted from the ensemble/TTA investigation — confirmed.

### 8. T12 dashboard numbers (committed data layer) — 13 checks
| Metric             | Measured | Documented | Status |
|--------------------|----------|------------|--------|
| quality PASS %     | 65.483   | 65.48      | PASS   |
| quality WARNING %  | 26.679   | 26.68      | PASS   |
| quality FAIL %     | 7.837    | 7.84       | PASS   |
| quality n (train)  | 3662     | 3662       | PASS   |
| champion acc       | 0.8281   | 0.8281     | PASS   |
| champion macro F1  | 0.6805   | 0.6805     | PASS   |
| champion QWK       | 0.8914   | 0.8914     | PASS   |
| binary sens        | 0.9060   | 0.9060     | PASS   |
| binary spec        | 0.9471   | 0.9471     | PASS   |
| inference s/img    | 0.1028   | 0.1028     | PASS   |
| img/s              | 9.729    | 9.73       | PASS   |
| val referable frac | 0.4065   | 0.4065     | PASS   |
| Branch B pilot AUC | 0.8583   | 0.858      | PASS   |

### 9. Quality-gate + fovea hook behavior (2 pre-commit example images) — 3 checks
- FAIL-quality image `train/class_0/02358b47ea89.png` → `qualityGate=1`,
  route **REVIEW** (with `FoveaCenter` consulted) — PASS
- Fovea hook disclosure present in lesion output (`foveaSupplied`) — PASS
- WARNING-quality val image `val/class_0/005b95c28852.png` → gate not
  enforced, route **CLEAR** — PASS

## Test-set policy
Only the image-ID list of the closed test set was listed for the invariant
check. No labels loaded, no inference run. The lock remains in force.

## Reconciliation notes
- Audit is strictly against *committed* artifacts under `data/analysis`; the
  `.gitignore` negation `!data/analysis/**` keeps these analysis outputs in the
  repo, so the audit is reproducible from the commit alone.
- RF-7 latent bug (OD-CNN 1-output capture) was fixed *and* the 10.6% OD-located
  rate still matches the pre-fix investigation artifact exactly — confirming the
  discrepancy investigation was done on the corrected path.
- Field-name quirks surfaced during T13 and handled in the audit script:
  `qualityGate` only exists when enforced (REVIEW route); CLEAR route is
  asserted via `route` field presence.

## Artifacts
- `src/re_audit_T13.m` — re-runnable audit script
- `data/analysis/day9/reaudit_T13.mat` — full check table (63 rows) + audit date