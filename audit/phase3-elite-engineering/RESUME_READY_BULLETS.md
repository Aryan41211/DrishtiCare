# RESUME-READY BULLETS — Phase 3 Elite Engineering

**Prioritized by: genuine algorithmic improvements, strong evaluation quality, statistically supported results, performance improvements, production reliability, scale under documented conditions.**

---

## NyayaSaathi — Legal Retrieval

- **Independent baseline audit of legal retrieval system** — Reproduced Phase 2.5 metrics (MPNet Recall@5 = 0.1867 on auto-generated labels) and identified critical data integrity failures in the human-validated evaluation dataset (sequential block label assignment, 37% deduped-out case references, cross-category case ID reuse)
- **Comprehensive retrieval benchmarking framework** — Built and executed experiments comparing TF-IDF, BM25, MiniLM, MPNet, E5-base, BGE-base, query normalization, multi-query retrieval (RRF), and hybrid BM25+dense fusion with 95% bootstrap confidence intervals on 232 auto-generated and 90 human-validated queries
- **Documented null results with evidence** — Demonstrated that normalization, multi-query, and hybrid fusion produced no statistically significant improvement on human-validated labels (all 95% CIs overlap), preventing false quality claims
- **Root-cause analysis of low human Recall@5 (0.0200)** — Traced to invalid label data (synthetic sequential assignments, not human judgments), not algorithmic limitations
- **CPU-only production environment** — All benchmarks executed on 16-core CPU, 15.65 GB RAM, no GPU; latency p50/p95/p99 measured for all retrieval systems

## Retrieval Intelligence Platform — RAG

- **End-to-end RAG evaluation pipeline** — Built first end-to-end RAG evaluation with real 31-document corpus, ingesting documents into FAISS and evaluating BM25, dense, and hybrid retrieval with per-stage latency tracking
- **Exposed invalid context precision metric** — Demonstrated that reported context precision of 1.0000 was trivial (1 context per query, 0.4 cosine threshold); real retrieval shows 0.37-0.56 context precision
- **Circular evaluation detection** — Identified that faithfulness measured ground_truth vs context (answer = ground_truth fallback), not generated answer vs context; no LLM generation was being tested
- **Realistic retrieval latency measurement** — Replaced 0.16ms (60-vector trivial index) with end-to-end latency on real corpus: BM25 p50 = 0.18ms, Dense p50 = 4.59ms
- **Diverse evaluation dataset** — 19 queries across simple factual, multi-hop, unanswerable, ambiguous, misleading-premise, and conflicting-source categories

## ML Pipeline Monitor — MLOps

- **Fixed SVM ROC-AUC computation bug** — Resolved silent `except Exception: pass` that zeroed all SVM ROC-AUC values (0.0000 → 0.972-0.997 across datasets)
- **Extended benchmarking to imbalanced and noisy datasets** — Added imbalanced classification (90/10 split), noisy classification (20% label noise), and noisy regression datasets; wine 0.9907 accuracy confirmed on easy 178-sample dataset
- **Added calibration metrics** — Brier score and Expected Calibration Error (ECE) for binary classification models
- **Nested cross-validation** — Implemented nested CV for hyperparameter validation on wine dataset (Random Forest, XGBoost, SVM, Logistic Regression)
- **Extended drift detection scenarios** — Added gradual drift and concept drift to existing 8 scenarios (now 10); PSI threshold 0.25 confirmed to miss small drift (Recall = 0.5714)
- **310 tests passing, 80.65% coverage** — All existing tests continue to pass after changes

## EquiPilot AI — Agentic Research

- **Fixed orphaned LangGraph node** — Connected `merge_results` node into compiled graph execution path (`research → merge_results → END`); all 5 nodes now execute end-to-end, verified with live graph execution (status: success)
- **Graph architecture audit** — Verified all 5 agent classes (router, parallel_tools/market_data, news, sentiment, synthesis) are wired into compiled graph; conditional routing functions now connected
- **Financial analysis validation** — 39/39 unit tests pass for 13 financial calculation functions (revenue growth, margins, ROE, ROCE, debt-to-equity, current ratio, FCF, valuation multiples)
- **329 tests passing** — All existing tests pass after graph fix; 3 pre-existing environment-related failures unchanged

## Cross-Project Engineering

- **Statistical validation framework** — Bootstrap 95% confidence intervals (2000 resamples, seed=42) for all per-query metrics; identical evaluation examples across all model comparisons
- **Experiment management** — Machine-readable experiment results with dataset version, model version, configuration, random seed, hardware, execution duration, raw metrics, and confidence intervals
- **No fabricated results** — All null results, failed experiments, and limitations explicitly documented; no evaluation samples removed or manipulated
