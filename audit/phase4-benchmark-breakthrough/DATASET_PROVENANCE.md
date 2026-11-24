# DATASET PROVENANCE — Phase 4

**Date:** 2026-11-25  
**Scope:** All datasets used across all four repositories

---

## 1. NYAYASAATHI — Legal Dataset

| Dataset | Source | License | Samples | Features | Notes |
|---------|--------|---------|---------|----------|-------|
| expanded_cases.json | Synthetic (template expansion of 201 seed cases) | Internal | 500 (232 unique after dedup) | category, subcategory, problem_description, workflow_steps, required_documents, authorities | All cases synthetic; language metadata missing ("Unknown" for all) |
| human_eval_queries.jsonl | Claimed human-validated | Internal | 6 | query_text, relevant_case_ids, relevance_grades | Labels are synthetic sequential blocks; NOT genuine human judgments |
| candidate_queries.jsonl | Generated from corpus | Internal | 1,160 | query_text, category, subcategory, difficulty | Candidates awaiting human annotation; NOT validated |

**Provenance issues:**
- No real legal documents from public sources
- All cases are synthetic/template-based
- No document versioning
- No source provenance beyond synthetic generation
- No language diversity (all English)

---

## 2. RETRIEVAL INTELLIGENCE PLATFORM — RAG Dataset

| Dataset | Source | License | Samples | Features | Notes |
|---------|--------|---------|---------|----------|-------|
| eval_dataset.jsonl | Synthetic (hand-written Q&A pairs) | Internal | 60 | question, ground_truth, contexts | No real documents; contexts written to match questions |
| Phase 4 corpus (36 docs) | Synthetic (hand-written) | Internal | 36 | text, category, source | Covers ML, retrieval, RAG, database, embeddings |
| Phase 4 queries (19) | Synthetic (hand-written) | Internal | 19 | question, category, difficulty, type | Covers simple, multi-hop, unanswerable, ambiguous, misleading, conflicting |

**Provenance issues:**
- No real documents ingested (data/raw and data/vectorstore empty in Phase 3)
- Phase 4 corpus is synthetic, not real documents
- No document versioning or source provenance
- All questions hand-written, not from real users

---

## 3. ML PIPELINE MONITOR — ML Datasets

| Dataset | Source | License | Samples | Features | Notes |
|---------|--------|---------|---------|----------|-------|
| iris | scikit-learn | BSD | 150 | 4 | Balanced 3-class |
| breast_cancer | scikit-learn | BSD | 569 | 30 | Balanced 2-class |
| wine | scikit-learn | BSD | 178 | 13 | Easy 3-class |
| digits | scikit-learn | BSD | 1797 | 64 | Multi-class 10 |
| imbalanced_90_10 | Synthetic (sklearn make_classification) | BSD | 2000 | 20 | 90/10 class split |
| noisy_20pct | Synthetic (sklearn make_classification) | BSD | 2000 | 20 | 20% label noise |
| high_dimensional_100f | Synthetic (sklearn make_classification) | BSD | 1000 | 100 | 20 informative features |
| temporal_drift | Synthetic (sklearn make_classification + shift) | BSD | 2000 | 10 | Concept drift over time |
| missing_values | Synthetic (sklearn make_classification + NaN) | BSD | 1000 | 15 | 5% random missing values |
| diabetes | scikit-learn | BSD | 442 | 10 | Regression |
| california_housing | scikit-learn | BSD | 20640 | 8 | Regression |
| noisy_regression | Synthetic (sklearn make_regression) | BSD | 2000 | 20 | High noise |
| high_dimensional_50f | Synthetic (sklearn make_regression) | BSD | 1000 | 50 | Regression |

**Provenance:**
- All scikit-learn datasets: BSD license, well-documented
- Synthetic datasets: Generated with sklearn.make_classification/make_regression, seed=42
- No real-world production data
- No dataset versioning beyond random seed

---

## 4. EQUIPIPIT AI — Financial Data

| Dataset | Source | License | Samples | Notes |
|---------|--------|---------|---------|-------|
| Reference cases (fin-001 to fin-004) | Synthetic (hand-computed) | Internal | 4 | TechCorp, DistressedCo, StartupCo, UtilityCo |
| Citation test cases (cite-001 to cite-005) | Synthetic (hand-written) | Internal | 5 | Citation precision/coverage test cases |
| Financial analysis unit tests | Synthetic | Internal | 39 tests | 13 functions tested |

**Provenance issues:**
- All financial data is synthetic — no real market data
- No real company financial statements
- No independent reference calculations (expected values hand-computed)
- No currency normalization, reporting period validation, or stale-data detection

---

## 5. DATA LIMITATIONS SUMMARY

| Project | Primary Limitation | Impact |
|---------|-------------------|--------|
| NyayaSaathi | No human-validated data; synthetic corpus | Cannot claim defensible retrieval quality |
| RIP | No real documents; no LLM API key | Cannot claim production RAG quality |
| MLPM | All synthetic/scikit-learn data; no real-world data | Cannot claim production ML performance |
| EquiPilot AI | No LLM API key; synthetic financial data; no real market data | Cannot claim production research quality |

**Bottom line:** All datasets are synthetic or from standard ML libraries. No real-world production data is used in any benchmark. Human annotation is required before quality claims can be defensible.
