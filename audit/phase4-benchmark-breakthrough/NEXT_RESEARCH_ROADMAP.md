# NEXT RESEARCH ROADMAP — Phase 4 and Beyond

**Date:** 2026-11-25  
**Scope:** All four repositories

---

## 1. NYAYASAATHI — Immediate Next Steps

### Priority 1: Human Annotation (Required Before Quality Claims)

| Task | Effort | Impact |
|------|--------|--------|
| Recruit 2+ annotators with legal knowledge | High | Critical — without this, no quality claims are defensible |
| Annotate 200+ candidate queries from candidate_queries.jsonl | High | Critical — target 200+ human-validated queries |
| Compute inter-annotator agreement (Cohen's kappa, Krippendorff's alpha) | Medium | Important — target κ ≥ 0.60 |
| Create train/validation/test splits (stratified by category) | Medium | Important — prevents evaluation leakage |
| Re-run retrieval benchmarks on held-out test split | Medium | Critical — real quality numbers |

### Priority 2: Corpus Expansion

| Task | Effort | Impact |
|------|--------|--------|
| Source real legal documents from public sources (government websites, legal aid organizations) | High | Critical — current corpus is synthetic |
| Expand toward 5,000-10,000 distinct legal documents | High | Important — current corpus is 232 unique cases |
| Add language metadata (Hindi, Marathi, Hinglish) | Medium | Important — current data is English-only |
| Add document versioning and source provenance | Medium | Important — currently missing |

### Priority 3: Advanced Retrieval Experiments

| Task | Effort | Impact |
|------|--------|--------|
| Cross-encoder reranking | Medium | May improve precision on human-validated data |
| Parent-document retrieval | Medium | May improve context relevance |
| Hard-negative mining | Medium | Important — addresses semantic similarity ≠ legal relevance |
| Legal terminology normalization | Medium | May improve Hinglish/Hindi query handling |

---

## 2. RETRIEVAL INTELLIGENCE PLATFORM — Immediate Next Steps

### Priority 1: Real Document Corpus (Required Before Quality Claims)

| Task | Effort | Impact |
|------|--------|--------|
| Ingest real documents into FAISS vector store | High | Critical — data/raw and data/vectorstore are empty |
| Target 100+ distinct documents | Medium | Important — current corpus is 36 synthetic documents |
| Add document versioning and source tracking | Medium | Important — currently missing |

### Priority 2: Real LLM Generation

| Task | Effort | Impact |
|------|--------|--------|
| Configure OPENAI_API_KEY (with explicit approval) | Medium | Critical — generation not measurable without it |
| Execute real generation benchmarks | High | Critical — placeholder answers make faithfulness trivially 1.0 |
| Measure token consumption, API cost, latency | Medium | Important — for production cost modeling |

### Priority 3: Expanded Evaluation Dataset

| Task | Effort | Impact |
|------|--------|--------|
| Expand to 300-500 reviewed questions | High | Important — current dataset is 19 questions |
| Add multi-hop, unanswerable, ambiguous, misleading questions | Medium | Important — already started in Phase 4 |
| Add questions with conflicting source documents | Medium | Important — tests contradiction detection |
| Human review of factual correctness | High | Critical — automated metrics cannot establish ground truth |

### Priority 4: Performance Engineering

| Task | Effort | Impact |
|------|--------|--------|
| Load tests at C=1, 10, 25, 50, 100 concurrent users | Medium | Important — current latency measured on single query |
| Separate retrieval vs generation latency | Medium | Important — currently combined |
| Measure CPU, RAM, connection pool utilization | Medium | Important — for production capacity planning |

---

## 3. ML PIPELINE MONITOR — Immediate Next Steps

### Priority 1: Real-World Datasets

| Task | Effort | Impact |
|------|--------|--------|
| Source real-world datasets with proper licensing | High | Critical — all current datasets are synthetic or scikit-learn |
| Add imbalanced classification with real class imbalance | Medium | Important — current imbalanced dataset is synthetic |
| Add time-series datasets with chronological splits | Medium | Important — current temporal dataset is synthetic |

### Priority 2: Advanced Drift Detection

| Task | Effort | Impact |
|------|--------|--------|
| Tune drift thresholds on validation scenarios, test on unseen | Medium | Critical — thresholds not yet tuned |
| Add concept drift detection with label feedback | Medium | Important — current concept drift doesn't use labels |
| Add multivariate drift detection methods | Medium | Important — current methods are univariate |

### Priority 3: Calibration and Reliability

| Task | Effort | Impact |
|------|--------|--------|
| Add multi-class calibration metrics (ECE for >2 classes) | Medium | Important — currently binary only |
| Add reliability diagram visualization | Low | Nice-to-have |
| Expand reliability testing beyond 6 cases | Medium | Important — add database failures, worker interruption, retries |

---

## 4. EQUIPIPIT AI — Immediate Next Steps

### Priority 1: LLM Integration

| Task | Effort | Impact |
|------|--------|--------|
| Configure OPENAI_API_KEY (with explicit approval) | Medium | Critical — generation not measurable without it |
| Execute real generation benchmarks | High | Critical — placeholder answers make all LLM metrics invalid |
| Measure token consumption, API cost, retry count | Medium | Important — for production cost modeling |

### Priority 2: Research Evaluation Dataset

| Task | Effort | Impact |
|------|--------|--------|
| Expand to 100-200 company/report evaluation cases | High | Critical — current dataset is 5 cases |
| Add multiple sectors, reporting periods, company sizes | Medium | Important — current coverage is limited |
| Human review of subjective research quality | High | Critical — automated metrics cannot establish quality |

### Priority 3: Financial Integration

| Task | Effort | Impact |
|------|--------|--------|
| Integrate financial analysis functions into graph nodes | Medium | Important — functions exist but aren't called by graph |
| Add real market data ingestion (with rate-limit handling) | Medium | Important — yfinance rate-limited |
| Add financial edge case handling (zero denominators, negative values) | Low | Done in Phase 4 |

### Priority 4: Agent Efficiency

| Task | Effort | Impact |
|------|--------|--------|
| Measure per-agent latency, token consumption, API cost | Medium | Important — not yet measured |
| Add agent-specific caching | Low | Nice-to-have |
| Add retry and failure recovery | Medium | Important — current error handling is basic |

---

## 5. CROSS-PROJECT PRIORITIES

| Priority | Task | Effort | Impact |
|----------|------|--------|--------|
| 1 | Human annotation for NyayaSaathi and RIP | High | Critical — without this, no quality claims |
| 2 | Real document corpus for RIP | High | Critical — without this, no production RAG |
| 3 | LLM API key for EquiPilot AI and RIP | Medium | Critical — generation not measurable |
| 4 | Real-world datasets for MLPM | Medium | Important — all data is synthetic |
| 5 | Statistical significance testing (paired tests) | Low | Important — currently only bootstrap CIs |
| 6 | Multiple random seeds | Low | Nice-to-have — currently single seed |

---

## 6. SUCCESS CRITERIA

| Project | Current | Target | Status |
|---------|---------|--------|--------|
| NyayaSaathi — Human-validated Recall@5 | Invalid (0.0200 based on fake labels) | >0.70 on human-validated test set | Not started |
| RIP — Context Precision | 1.0000 (trivial) | 0.85+ on real corpus | Phase 4: 0.57 |
| RIP — Faithfulness | 1.0000 (circular) | 0.90+ with real LLM | Blocked (no API key) |
| MLPM — Drift Detection F1 | 1.0000 (8 scenarios) | 0.90+ on 10+ scenarios | Phase 4: 1.0000 (KS) |
| EquiPilot — Citation Precision | 1.0000 (5 cases, placeholder) | 0.95+ with real LLM | Phase 4: 0.8000 |
| EquiPilot — Graph nodes in execution | 4 of 5 | 5 of 5 | Phase 4: ✅ Fixed |
