# STATISTICAL VALIDATION — Phase 3

**Date:** 2026-11-25  
**Method:** Bootstrap 95% confidence intervals (2000 resamples, seed=42)  
**Environment:** 16 CPU cores, 15.65 GB RAM, CPU-only

---

## 1. CONFIDENCE INTERVAL METHODOLOGY

All per-query metrics are aggregated with 95% confidence intervals computed via non-parametric bootstrap:

```python
def _ci95(values, n_bootstrap=2000, seed=42):
    rng = np.random.RandomState(seed)
    boot_means = [np.mean(rng.choice(values, size=len(values), replace=True)) for _ in range(n_bootstrap)]
    boot_means.sort()
    lo = percentile(boot_means, 2.5)
    hi = percentile(boot_means, 97.5)
    return (lo, hi)
```

This is appropriate for small sample sizes where normality assumptions may not hold.

---

## 2. NYAYASAATHI — RECALL@5 WITH 95% CI

### Auto-Generated Labels (232 queries)

| System | Recall@5 | 95% CI | Precision@5 | 95% CI | Significant vs Baseline? |
|--------|----------|--------|-------------|--------|--------------------------|
| BM25 | 0.1618 | [0.1538, 0.1701] | 0.7552 | — | — |
| TF-IDF | 0.1027 | [0.0949, 0.1105] | 0.4819 | — | — |
| MiniLM (384d) | 0.1768 | [0.1694, 0.1841] | 0.8328 | — | — |
| **MPNet (768d)** | **0.1867** | **[0.1786, 0.1948]** | **0.8698** | — | Baseline |
| E5-base (768d) | 0.1836 | [0.1758, 0.1910] | 0.8595 | — | No (CI overlaps) |
| BGE-base (768d) | 0.1819 | [0.1741, 0.1898] | 0.8483 | — | No (CI overlaps) |
| MPNet + normalization | 0.1870 | [0.1789, 0.1952] | 0.8716 | — | No (CI overlaps) |
| MPNet + multi-query | 0.1865 | [0.1781, 0.1946] | 0.8698 | — | No (CI overlaps) |
| Hybrid BM25+MPNet (RRF) | 0.1751 | [0.1671, 0.1828] | 0.8207 | — | No (CI overlaps) |

**Conclusion:** All improvements on auto-generated labels are within noise. MPNet baseline CI [0.1786, 0.1948] overlaps with all other systems.

### Human-Validated Labels (90 queries)

| System | Recall@5 | 95% CI | Significant vs Baseline? |
|--------|----------|--------|--------------------------|
| BM25 | 0.0133 | [0.0044, 0.0244] | — |
| TF-IDF | 0.0222 | [0.0089, 0.0378] | — |
| MiniLM | 0.0200 | [0.0067, 0.0378] | — |
| MPNet | 0.0178 | [0.0067, 0.0311] | Baseline |
| E5-base | 0.0200 | [0.0089, 0.0333] | No (CI overlaps) |
| MPNet + normalization | 0.0200 | [0.0067, 0.0333] | No (CI overlaps) |
| MPNet + multi-query | 0.0200 | [0.0089, 0.0333] | No (CI overlaps) |
| Hybrid BM25+MPNet (RRF) | 0.0200 | [0.0089, 0.0333] | No (CI overlaps) |

**Conclusion:** All human-validated CIs overlap extensively. No system is statistically superior. The label data is invalid (sequential blocks, cross-category reuse), so these metrics cannot support quality claims regardless of CI width.

---

## 3. RETRIEVAL INTELLIGENCE PLATFORM — CONTEXT PRECISION

| Method | Context Precision | Notes |
|--------|------------------|-------|
| Phase 2 (offline, pre-written) | 1.0000 | Trivial: 1 context/query, 0.4 threshold |
| Phase 3 (end-to-end, dense) | 0.5579 | Real retrieval on 31-doc corpus |
| Phase 3 (end-to-end, BM25) | 0.3684 | Real retrieval on 31-doc corpus |

**Conclusion:** The 1.0000 context precision from Phase 2 is methodologically invalid. Real retrieval shows 0.37-0.56 context precision, which is more representative of actual system behavior.

---

## 4. ML PIPELINE MONITOR — SVM ROC-AUC FIX

| System | Before Fix | After Fix | Change |
|--------|-----------|-----------|--------|
| SVM (iris) | 0.0000 | 0.9967 | +0.9967 (bug fix) |
| SVM (breast_cancer) | 0.0000 | 0.9950 | +0.9950 (bug fix) |
| SVM (wine) | 0.0000 | 1.0000 | +1.0000 (bug fix, easy dataset) |

**Conclusion:** The SVM ROC-AUC = 0.0000 values were a silent exception-swallowing bug. After fixing, SVM correctly computes ROC-AUC on all datasets.

---

## 5. EQUIPILOT AI — GRAPH NODE COVERAGE

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| Nodes in execution path | 4 | 5 | +1 (merge_results was orphaned) |
| Graph compilation | ✅ | ✅ | No change |
| End-to-end execution | ❌ (merge_results skipped) | ✅ (all nodes execute) | Fixed |

---

## 6. LIMITATIONS

1. **Small sample sizes:** NyayaSaathi n=90, RIP n=60 — CIs are wide, reflecting genuine uncertainty
2. **Single-seed runs:** All experiments use seed=42; multiple seeds not yet implemented
3. **No paired statistical tests:** Wilcoxon signed-rank or paired t-test not yet applied to per-query comparisons
4. **Bootstrap assumptions:** Bootstrap CI assumes exchangeable queries; may not hold if queries are correlated

---

## 7. REPRODUCIBILITY STATEMENT

All results in this document are reproducible using the scripts listed in `MASTER_EXPERIMENT_INDEX.json`. Random seeds are fixed at 42 for all stochastic operations. Confidence intervals use bootstrap with seed=42.
