# PHASE 3 BASELINE VALIDATION — NyayaSaathi

**Repository:** `C:\projects\NyaySaathi` (note: directory name is `NyaySaathi`, not `NyayaSaathi`)
**Branch:** `main`
**Git SHA at validation:** `bb1570d` (HEAD)
**Validation date:** 2026-11-25
**Environment:** 16 CPU cores, 15.65 GB RAM, CPU-only, Python 3.12.10, Windows

---

## 1. EXECUTIVE SUMMARY

The Phase 2.5 baseline for NyayaSaathi was **partially reproducible** but has **critical data integrity failures** in the human-validated evaluation dataset. Auto-generated (category-proxy) labels reproduce exactly, but human-validated metrics show significant discrepancies with reported values. The human-validated dataset suffers from sequential block assignment of relevance labels, case ID reuse across categories, and references to deduplicated-out cases.

**Verdict:** The human-validated Recall@5 of 0.0200 cannot be treated as a reliable baseline. The dataset must be rebuilt before any quality claims can be made.

---

## 2. REPRODUCIBILITY RESULTS

### 2.1 Auto-Generated Labels (Category Proxy) — FULLY REPRODUCIBLE

| System | Reported R@5 | Reproduced R@5 | Match? | Reported P@5 | Reproduced P@5 |
|--------|-------------|----------------|--------|-------------|----------------|
| TF-IDF | 0.1027 | 0.1027 | YES | 0.4819 | 0.4819 |
| BM25 | 0.1618 | 0.1618 | YES | 0.7552 | 0.7552 |
| MiniLM (384d) | 0.1768 | 0.1768 | YES | 0.8328 | 0.8328 |
| MPNet (768d) | 0.1867 | 0.1867 | YES | 0.8698 | 0.8698 |
| E5-base (768d) | 0.1836 | 0.1836 | YES | 0.8595 | 0.8595 |
| BGE-base (768d) | 0.1819 | 0.1819 | YES | 0.8483 | 0.8483 |
| Hybrid (weighted) | 0.1870 | 0.1870 | YES | 0.8698 | 0.8698 |

All auto-generated results match exactly. These were computed using `experiment_phase2_benchmark.py` on the deduplicated corpus (232 cases) with 232 auto-generated queries.

**However:** Auto-generated labels are **category-matching proxies** — a case is "relevant" if it shares the same category as the query's source case. This is NOT a true relevance judgment. MRR = 1.0000 for all dense models is expected and not discriminative.

### 2.2 Human-Validated Labels — PARTIALLY REPRODUCIBLE

| System | Reported R@5 | Reproduced R@5 | Match? | Reported P@5 | Reproduced P@5 |
|--------|-------------|----------------|--------|-------------|----------------|
| MPNet (raw query) | 0.0120 | 0.0178 | NO | 0.0120 | 0.0178 |
| MPNet (normalized) | 0.0160 | Not tested in benchmark | N/A | 0.0160 | N/A |
| E5-base (768d) | 0.0200 | 0.0200 | YES | 0.0200 | 0.0200 |
| BGE-base (768d) | 0.0120 | 0.0200 | NO | 0.0120 | 0.0200 |
| BM25 | 0.0200 | 0.0133 | NO | 0.0200 | 0.0133 |

Only **E5-base matches exactly**. BM25, BGE-base, and MPNet (raw) do not reproduce. The discrepancies indicate the reported numbers were computed on a different mapping, dataset version, or query set than what is currently in the repository.

**Dataset size discrepancy:** Multiple documents report 50 human-validated queries, but `human_validated.json` contains **90 queries** (`n_queries: 90`).

---

## 3. CRITICAL DATA INTEGRITY ISSUES

### Issue 1: Sequential Block Assignment of Relevance Labels (CRITICAL)

The `relevant_case_ids` in `human_validated.json` are sequential blocks, not actual human relevance judgments:

| Query ID | Category | Subcategory | Relevant Case IDs |
|----------|----------|-------------|-------------------|
| human-land-001 | Land and Property | Land Boundary Dispute | 0, 1, 2, 3, 4 |
| human-land-002 | Land and Property | Illegal Land Occupation | 76, 77, 78, 79, 80 |
| human-govt-003 | Govt Scheme | Certificate Delay | 1, 2, 3, 4, 5 |
| human-land-006 | Land and Property | Illegal Construction | 1, 2, 3, 4, 5 |
| human-police-004 | Police Complaints | FIR Registration Refusal | 56, 57, 58, 59, 60 |

**Case 1 is marked relevant for THREE different queries in different categories** (Land Boundary Dispute, Certificate Delay, Illegal Construction). This is impossible for genuine human relevance annotation.

**Impact:** The human-validated labels are synthetic sequential assignments, not human judgments. All human-validated metrics (Recall@5 = 0.0200) are meaningless.

### Issue 2: Case IDs Reference Deduplicated-Out Cases (CRITICAL)

`human_validated.json` references indices into `expanded_cases.json` (500 cases). The evaluation corpus is deduplicated to 232 unique cases. **123 of 336 unique relevant IDs (37%) are beyond index 231** — they reference cases removed during deduplication.

The mapping script in `experiment_phase2_benchmark.py` attempts to map expanded indices to deduped indices, but any expanded index whose content was deduped away is simply dropped. This means:
- Queries lose relevant cases silently
- Different queries lose different numbers of relevant cases
- The effective number of relevant cases per query is unknown and inconsistent

### Issue 3: Case ID Reuse Across Categories (CRITICAL)

**110 case IDs are referenced by multiple queries** across different categories. Example:
- Case ID "1" is relevant for `human-land-001` (Land Boundary), `human-govt-003` (Certificate Delay), and `human-land-006` (Illegal Construction)

A single legal case cannot be equally relevant to a land boundary dispute, a government certificate delay, and an illegal construction case simultaneously.

### Issue 4: `load_dataset()` Incompatible with File Format (HIGH)

`evaluation/__init__.py` `load_dataset()` expects a flat JSON list, but `human_validated.json` uses a wrapper object `{"queries": [...]}`. Calling `load_dataset()` on this file will iterate over dictionary keys ("label_source", "n_queries", etc.) and crash. The benchmark script uses a custom `load_human_validated_dataset()` instead, but the general-purpose loader is broken.

### Issue 5: Inconsistent Query Counts Across Documents (MEDIUM)

| Document | Reported Query Count | Actual in File |
|----------|---------------------|----------------|
| NYAYSAATHI_EVALUATION_RESULTS.json | 50 | 90 |
| NYAYSAATHI_PHASE2_AUDIT.md | 50 | 90 |
| Phase 2 benchmark script output | 90 | 90 |
| human_validated.json | n_queries: 90 | 90 |

### Issue 6: No Train/Dev/Test Split (HIGH)

All 90 queries are used for evaluation with no held-out test set. No train/dev/test split exists. Hyperparameters (fusion weights, model selection) cannot be validated without leakage.

### Issue 7: Auto-Generated Labels Are Not Discriminative (MEDIUM)

With category-proxy labels, MRR = 1.0000 for all dense models because the first retrieved case is usually in the same category. This metric provides zero signal for model comparison.

### Issue 8: Corpus Is Synthetic, Not Real Legal Documents (MEDIUM)

The 500-case expanded corpus is a synthetic/template-based expansion of 201 seed cases. After dedup: 232 unique cases. This is too small for production-scale legal retrieval evaluation.

---

## 4. METRIC CALCULATION VERIFICATION

### Recall@5 Formula

`recall@k = |relevant ∩ retrieved[:k]| / |relevant|`

This is correctly implemented in `evaluation/__init__.py`:
```python
def recall_at_k(ranked_relevant, k, n_relevant):
    if n_relevant == 0:
        return 0.0
    return float(sum(ranked_relevant[:k]) / n_relevant)
```

The formula is correct, but the `n_relevant` denominator is based on the flawed relevance labels described above.

### nDCG@5 Formula

Uses binary relevance (1 if in relevant_case_ids, 0 otherwise) despite `relevance_grades` being available in the dataset. Grades are stored but not used in nDCG calculation.

### Precision@5 Formula

`precision@k = |relevant ∩ retrieved[:k]| / k`

Correctly implemented.

---

## 5. LIMITATIONS RECORDED

1. **Human-validated labels are not genuine** — sequential block assignment, cross-category reuse, and deduped-out references make them invalid
2. **Auto-generated labels are category proxies** — not true relevance, MRR is not discriminative
3. **No train/dev/test split** — evaluation leakage risk
4. **Small corpus** — 232 unique cases after dedup, synthetic data
5. **No confidence intervals** — single run per configuration
6. **No statistical significance testing** — cannot compare models reliably
7. **Inconsistent query counts** across documentation (50 vs 90)
8. **`load_dataset()` incompatible** with human_validated.json format
9. **No cross-validation** — results may not generalize

---

## 6. BASELINE VERDICT

| Aspect | Status |
|--------|--------|
| Auto-generated label reproducibility | ✅ Fully reproducible |
| Human-validated label reproducibility | ❌ Partially reproducible (only E5-base matches) |
| Human-validated data integrity | ❌ FAILED — sequential blocks, cross-category reuse, deduped-out references |
| Metric formula correctness | ✅ Formulas correctly implemented |
| Evaluation methodology soundness | ❌ NOT SOUND — no train/dev/test split, proxy labels, small corpus |
| Results defensible in interview | ❌ NO — human-validated metrics cannot be trusted |

**DO NOT proceed to optimization until the human-validated evaluation dataset is rebuilt with genuine human annotations.**

---

## 7. IMMEDIATE NEXT STEPS FOR PHASE 3

1. **Rebuild the human-validated dataset** with genuine relevance judgments (not sequential blocks)
2. **Ensure all relevant_case_ids map to valid deduped corpus indices**
3. **Create train/dev/test splits** to prevent evaluation leakage
4. **Expand the corpus** with more legal documents if available
5. **Re-run baseline** on the corrected dataset before any optimization
6. **Add confidence intervals and statistical comparisons** to all benchmarks

---

## 8. REPRODUCTION COMMANDS

```bash
# Reproduce auto-generated baseline
cd C:\projects\NyaySaathi\backend
python experiment_phase2_benchmark.py

# Output: experiment_results/phase2_benchmark.json

# Reproduce model comparison (500-case expanded corpus, NOT deduplicated)
python experiment_model_comparison.py --corpus dataset/expanded_cases.json

# Output: experiment_results/model_comparison.json

# Run test suite
python manage.py test
```

**Note:** `experiment_model_comparison.py` loads `expanded_cases.json` (500 cases with duplicates), NOT the deduplicated corpus used by `experiment_phase2_benchmark.py` (232 cases). This explains why the same model produces different R@5 values across scripts.
