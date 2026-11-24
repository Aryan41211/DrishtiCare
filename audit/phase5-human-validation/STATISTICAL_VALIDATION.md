# Statistical Validation — Phase 5

**Date:** 2026-11-25  
**Status:** No statistical validation performed yet — no human annotations collected

---

## 1. Agreement Statistics

When pilot annotation is complete, the following will be calculated:

| Statistic | Formula | Use Case |
|-----------|---------|----------|
| Exact agreement | |agreements| / |total| | Any scale |
| Weighted Cohen's kappa | (po - pe) / (1 - pe) | Two reviewers, ordinal scale |
| Krippendorff's alpha | 1 - (Do / De) | Multiple reviewers, any scale |

Where po = observed agreement, pe = expected agreement by chance, Do = observed disagreement, De = expected disagreement by chance.

**Target:** Cohen's kappa ≥ 0.60 (substantial) for pilot

---

## 2. Retrieval Metrics (NyayaSaathi)

| Metric | Formula |
|--------|---------|
| Recall@K | |relevant ∩ retrieved[:K]| / |relevant| |
| Precision@K | |relevant ∩ retrieved[:K]| / K |
| MRR | 1 / rank_of_first_relevant |
| nDCG@K | DCG / IDGC using graded relevance 0-3 |
| MAP | Mean average precision |
| Hit Rate@K | 1 if any relevant in top-K |

**Confidence intervals:** Bootstrap 95% CI (1000-2000 resamples, seed=42) where sample size permits.

---

## 3. RAG Metrics (RIP)

| Metric | Definition |
|--------|-----------|
| Faithfulness rate | Fraction of answers fully supported by context |
| Answer correctness rate | Fraction of answers factually correct |
| Citation precision | Fraction of citations backed by source |
| Citation coverage | Fraction of answer sentences with citation |
| Unsupported claim rate | Fraction of claims without source support |
| Correct abstention rate | Fraction of unanswerable questions correctly declined |
| Answer completeness rate | Fraction of answers fully addressing question |

---

## 4. Drift Metrics (ML Pipeline Monitor)

| Metric | Definition |
|--------|-----------|
| Precision | TP / (TP + FP) |
| Recall | TP / (TP + FN) |
| F1 | 2 × P × R / (P + R) |
| FPR | FP / (FP + TN) |
| FNR | FN / (FN + TP) |
| Detection delay | Samples between onset and detection |
| Alert stability | Consistency across repeated runs |

**Confidence intervals:** Bootstrap 95% CI across multiple random seeds.

---

## 5. Financial Research Metrics (EquiPilot)

| Metric | Definition |
|--------|-----------|
| Numerical correctness | Fraction of computed metrics matching reference |
| Citation precision | Fraction of citations backed by source |
| Citation coverage | Fraction of claims with citation |
| Claim support rate | Fraction of claims supported by source |
| Unsupported claim rate | Fraction of claims without support |
| Source freshness | Fraction of sources with recent timestamps |

---

## 6. Statistical Rigor Rules

1. **No p-hacking:** Test set fixed before inspection of results
2. **No data leakage:** Train/val/test split by document identity
3. **Multiple seeds:** Drift evaluation uses multiple random seeds
4. **Appropriate CIs:** Bootstrap CI only when sampling design supports it
5. **Report raw counts:** Always report n (sample size) alongside rates
6. **Distinguish reviewed vs. adjudicated:** Report both individual and adjudicated judgments

---

## 7. Current Status

| Milestone | Status |
|-----------|--------|
| Statistical methods defined | ✅ This document |
| Agreement calculation ready | ✅ Guidelines in workspace |
| Bootstrap CI method defined | ✅ 1000-2000 resamples |
| Human annotations collected | ❌ Not started |
| Statistical results computed | ❌ Not started |
