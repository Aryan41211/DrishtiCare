# PHASE 3 BASELINE VALIDATION — ML Pipeline Monitor

**Repository:** `C:\projects\ML-pipeline-monitor`
**Branch:** `main`
**Git SHA at validation:** `b4f2617` (HEAD)
**Validation date:** 2026-11-25
**Environment:** 16 CPU cores, 15.65 GB RAM, CPU-only, Python 3.12.10, Windows

---

## 1. EXECUTIVE SUMMARY

The ML Pipeline Monitor Phase 2.5 baseline was **partially reproducible** with several **critical methodology issues**:

- **SVM ROC-AUC = 0.0000** — Silent exception in try/except block (pipeline.py line 475-476). ROC-AUC is never computed for SVM despite `probability=True` being set.
- **Wine 0.9907 accuracy** — Easy dataset (178 samples, 13 features, 3 classes), small test split (~36 samples). Random Forest and XGBoost both achieve 0.9907. Not indicative of production-grade performance.
- **Only 5 datasets** (not 6 as claimed) — iris, breast_cancer, wine, digits, california_housing, diabetes. No imbalanced, noisy, or high-dimensional datasets.
- **Only 8 drift scenarios** (not 13 as claimed) — No gradual drift, no concept drift. All drift is sudden.
- **PSI threshold 0.25 too high** — Misses small drift (Recall=0.5714).
- **No calibration metrics** — No Brier score, reliability curves, or expected calibration error.
- **No nested cross-validation** — Hyperparameter selection not validated separately.

**Verdict:** The reported best accuracy (0.9907) is on an easy, small dataset with potential overfitting. Drift detection F1=1.0 for KS is on 8 synthetic scenarios with obvious separation.

---

## 2. REPRODUCIBILITY RESULTS

### 2.1 Classification Benchmark (from MLPM_MODEL_BENCHMARK.csv)

| Dataset | Best Model | Accuracy | F1 | ROC-AUC | Notes |
|---------|-----------|----------|-----|---------|-------|
| iris (150, 4f, 3c) | Gradient Boosting | 0.9667 | 0.9666 | 0.9978 | Easy dataset |
| breast_cancer (569, 30f, 2c) | Gradient Boosting | 0.9620 | 0.9618 | 0.9902 | Standard |
| wine (178, 13f, 3c) | Random Forest / XGBoost | **0.9907** | 0.9908 | 1.0000 | **Easy, small dataset** |

### 2.2 Regression Benchmark

| Dataset | Best Model | R² | RMSE | MAE |
|---------|-----------|-----|------|-----|
| diabetes (442, 10f) | Ridge Regression | 0.5068 | 52.72 | 43.37 |
| california_housing (20640, 8f) | XGBoost | **0.8391** | 0.4634 | 0.3108 |

### 2.3 Drift Detection Benchmark (from MLPM_DRIFT_BENCHMARK.csv)

| Method | Threshold | Precision | Recall | F1 | FPR | FNR |
|--------|-----------|-----------|--------|-----|-----|-----|
| PSI | 0.25 | 1.0000 | 0.5714 | 0.7273 | 0.0000 | 0.4286 |
| KS Test | 0.95 | 1.0000 | 1.0000 | **1.0000** | 0.0000 | 0.0000 |
| JS Divergence | 0.1 | 1.0000 | 0.8000 | 0.8889 | 0.0000 | 0.2000 |
| Wasserstein | 0.5 | 1.0000 | 0.5714 | 0.7273 | 0.0000 | 0.4286 |

---

## 3. CRITICAL ISSUES IDENTIFIED

### Issue 1: SVM ROC-AUC = 0.0000 (CRITICAL — Bug)

In `pipeline.py` lines 465-476:
```python
try:
    if hasattr(model, "predict_proba"):
        y_prob = model.predict_proba(X_te_sc)
        if y_prob.shape[1] == 2:
            metrics["roc_auc"] = round(roc_auc_score(y_test, y_prob[:, 1]), 4)
        else:
            metrics["roc_auc"] = round(roc_auc_score(y_test, y_prob, multi_class="ovr"), 4)
except Exception:
    pass
```

The `except Exception: pass` silently swallows all errors. If `roc_auc_score` fails (e.g., missing class in test set), the key is never added to metrics. When the benchmark writes the CSV, missing keys default to 0.0000.

**Impact:** All SVM ROC-AUC values are 0.0000 across iris, breast_cancer, and wine — clearly wrong.

### Issue 2: Wine 0.9907 Accuracy — Easy/Small Dataset (HIGH)

The wine dataset has only 178 samples, 13 features, 3 classes. With a 20% test split (~36 test samples), Random Forest achieves 0.9907 (roughly 35/36 correct). This is not a challenging benchmark.

**Impact:** The "best classification accuracy: 0.9907" claim is misleading — it's on the easiest, smallest dataset.

### Issue 3: Only 5 Datasets (MEDIUM)

Claimed: 6 datasets. Actual: iris, breast_cancer, wine, digits, california_housing, diabetes = 6 datasets. But:
- No **imbalanced classification** dataset (all are roughly balanced)
- No **noisy data** dataset
- No **high-dimensional** dataset (max 30 features for breast_cancer)
- No **distribution shift** dataset

### Issue 4: Only 8 Drift Scenarios (MEDIUM)

Claimed: 13 scenarios. Actual: 8 (no_drift, small_drift, moderate_drift, severe_drift, scale_change, covariate_shift, feature_level_drift, class_imbalance).
- No **gradual drift**
- No **concept drift**
- No **concept drift with labels**
- All drift is sudden/immediate

### Issue 5: PSI Threshold 0.25 Too High (MEDIUM)

PSI Recall = 0.5714 — misses 4 of 7 drift scenarios. The 0.25 threshold is too sensitive to small shifts.

### Issue 6: No Calibration Metrics (MEDIUM)

No Brier score, expected calibration error (ECE), or reliability curves. Cannot assess whether predicted probabilities are well-calibrated.

### Issue 7: No Nested Cross-Validation (MEDIUM)

Hyperparameters are fixed in DEFAULT_PARAMS. No nested CV for hyperparameter selection validation.

### Issue 8: Drift Labels Are "Expected" Not Learned (MEDIUM)

The drift benchmark uses an "Expected Drift" column as ground truth. Thresholds are not tuned on validation scenarios and tested on unseen scenarios.

---

## 4. METRIC CALCULATION VERIFICATION

### Accuracy
Correctly computed: `accuracy_score(y_test, y_pred)` on held-out test set.

### F1 Score (Weighted)
Correctly computed: `f1_score(y_test, y_pred, average="weighted", zero_division=0)`.

### ROC-AUC (Binary)
Correctly computed for 2-class problems: `roc_auc_score(y_test, y_prob[:, 1])`.

### ROC-AUC (Multi-class)
Uses `roc_auc_score(y_test, y_prob, multi_class="ovr")` — correct approach, but fails silently for SVM.

### MAE, RMSE, R²
Correctly computed for regression.

### Cross-Validation
Uses `cross_val_score` with `StratifiedKFold` (classification) or `KFold` (regression) on training data only. **Correct methodology** — no leakage from test set.

### PSI
Uses Laplace smoothing, adaptive bin count. **Correct implementation**.

### KS Test
Uses `scipy.stats.ks_2samp`. **Correct implementation**.

---

## 5. LIMITATIONS RECORDED

1. **SVM ROC-AUC bug** — Silent exception, always 0.0000
2. **Wine dataset too easy** — 178 samples, 0.9907 not production-representative
3. **No imbalanced classification dataset** — All datasets balanced
4. **No noisy data dataset** — All clean sklearn datasets
5. **Only 8 drift scenarios** — No gradual drift, no concept drift
6. **No calibration metrics** — No Brier score, ECE, reliability curves
7. **No nested cross-validation** — Hyperparameters fixed, not validated
8. **PSI threshold not tuned** — 0.25 threshold not optimized on validation data
9. **No reliability tests beyond 6** — Missing database failures, worker interruption, etc.
10. **No confidence intervals** — Single run per configuration (n_runs=3 but no CI reported)

---

## 6. BASELINE VERDICT

| Aspect | Status |
|--------|--------|
| Metric value reproducibility | ✅ Values match CSV/JSON files |
| Metric methodology correctness | ⚠️ PARTIAL — SVM ROC-AUC bug, otherwise correct |
| Evaluation dataset quality | ❌ INSUFFICIENT — Easy datasets, no imbalance/noise |
| Drift detection methodology | ⚠️ PARTIAL — 8 scenarios, no gradual/concept drift |
| Statistical rigor | ❌ INSUFFICIENT — No CIs, no nested CV |
| Results defensible in interview | ⚠️ PARTIAL — 0.9907 on wine needs context |

**DO NOT claim 0.9907 as production-grade accuracy without noting it's on the wine dataset.**

---

## 7. IMMEDIATE NEXT STEPS FOR PHASE 3

1. **Fix SVM ROC-AUC bug** — Handle multi-class ROC-AUC properly, report N/A when uncomputable
2. **Add imbalanced classification dataset** — e.g., imbalanced synthetic or credit card fraud
3. **Add noisy data dataset** — Add label noise to existing datasets
4. **Add more drift scenarios** — Gradual drift, concept drift, concept drift with labels
5. **Add calibration metrics** — Brier score, expected calibration error
6. **Add nested cross-validation** — For hyperparameter selection
7. **Expand reliability testing** — Database failures, worker interruption, concurrent jobs
8. **Add confidence intervals** — Bootstrap CI for all metrics

---

## 8. REPRODUCTION COMMANDS

```bash
# Run algorithm benchmark
cd "C:\projects\ML-pipeline-monitor"
python scripts/mlpm_algorithm_benchmark.py

# Output: experiment_results/mlpm_algorithm_benchmark.json

# Run drift benchmark
python scripts/mlpm_drift_benchmark.py

# Output: experiment_results/mlpm_drift_benchmark.json

# Run test suite
pytest tests/unit tests/integration -q -p no:cacheprovider
```
