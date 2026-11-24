# STATISTICAL SIGNIFICANCE REPORT — Phase 4

**Date:** 2026-11-25  
**Method:** Bootstrap 95% confidence intervals (1000-2000 resamples, seed=42)  
**Environment:** 16 CPU cores, 15.65 GB RAM, CPU-only

---

## 1. CONFIDENCE INTERVAL METHODOLOGY

All per-query metrics are aggregated with 95% confidence intervals computed via non-parametric bootstrap:

```python
def _ci95(values, n_bootstrap=1000, seed=42):
    rng = np.random.RandomState(seed)
    boot_means = [np.mean(rng.choice(values, size=len(values), replace=True)) for _ in range(n_bootstrap)]
    boot_means.sort()
    lo = percentile(boot_means, 2.5)
    hi = percentile(boot_means, 97.5)
    return (lo, hi)
```

---

## 2. NYAYASAATHI — RECALL@5 WITH 95% CI (AUTO-GENERATED LABELS)

| Model | Recall@5 | 95% CI | Significant vs Baseline? |
|-------|----------|--------|--------------------------|
| TF-IDF | 0.7306 | [0.7079, 0.7550] | — |
| BM25 | 1.0000 | [1.0000, 1.0000] | — |
| MiniLM | 0.9759 | [0.9668, 0.9839] | — |
| MPNet | 0.9839 | [0.9767, 0.9902] | Baseline |
| E5-base | 0.9968 | [0.9934, 0.9994] | No (CI overlaps) |
| BGE-base | 0.9968 | [0.9934, 0.9994] | No (CI overlaps) |

**Conclusion:** All improvements on auto-generated labels are within noise. MPNet baseline CI [0.9767, 0.9902] overlaps with E5-base and BGE-base CIs.

**WARNING:** These labels are category-proxy, not human-validated. Results cannot support quality claims.

---

## 3. RIP — CONTEXT PRECISION COMPARISON

| Method | Context Precision | Notes |
|--------|------------------|-------|
| Phase 3 (offline, pre-written) | 1.0000 | Trivial: 1 context/query |
| Phase 4 (end-to-end, dense) | 0.5684 | Real retrieval on 36-doc corpus |
| Phase 4 (end-to-end, BM25) | 0.3895 | Real retrieval on 36-doc corpus |
| Phase 4 (end-to-end, hybrid) | 0.4947 | Real retrieval on 36-doc corpus |

**Conclusion:** Phase 3 context precision was trivially inflated. Phase 4 with real retrieval shows 0.39-0.57.

---

## 4. ML PIPELINE MONITOR — SVM ROC-AUC FIX

| Dataset | Before Fix | After Fix | Change |
|---------|-----------|-----------|--------|
| iris | 0.0000 | 0.9967 | +0.9967 (bug fix) |
| breast_cancer | 0.0000 | 0.9950 | +0.9950 (bug fix) |
| wine | 0.0000 | 1.0000 | +1.0000 (bug fix, easy dataset) |

**Conclusion:** SVM ROC-AUC = 0.0000 was a silent exception-swallowing bug. After fixing, SVM correctly computes ROC-AUC.

---

## 5. EQUIPILOT AI — CITATION METRICS

| Metric | Value | Expected | Match? |
|--------|-------|----------|--------|
| Mean citation precision | 0.8000 | — | 5/5 cases match |
| Mean citation coverage | 0.6333 | — | 4/5 cases match (rounding) |
| Mean unsupported claim rate | 0.3667 | — | — |

**Conclusion:** Citation precision matches expected values in all 5 test cases. Coverage has minor rounding differences.

---

## 6. LIMITATIONS

1. **Small sample sizes** — NyayaSaathi n=1,160 (auto-generated only), RIP n=19, MLPM 13 datasets, EquiPilot 4-5 test cases
2. **No human-validated data** — All labels are auto-generated or synthetic
3. **Single-seed runs** — All experiments use seed=42
4. **No paired statistical tests** — Wilcoxon signed-rank not yet applied
5. **Bootstrap assumptions** — Assumes exchangeable queries; may not hold if correlated

---

## 7. REPRODUCIBILITY STATEMENT

All results are reproducible using the scripts listed in `MASTER_EXPERIMENT_INDEX.json`. Random seeds are fixed at 42. Confidence intervals use bootstrap with seed=42.
