# RESUME-READY BULLETS — Phase 4

**Prioritized by: genuine algorithmic improvements, strong evaluation quality, statistically supported results, performance improvements, production reliability, scale under documented conditions.**

---

## NyayaSaathi — Legal Retrieval

- **Built annotation system for legal retrieval evaluation** — Designed schema with graded relevance (0-3), train/validation/test splits, inter-annotator agreement (Cohen's kappa, Krippendorff's alpha); generated 1,160 candidate queries across 10 legal categories awaiting human annotation
- **Built retrieval evaluation pipeline** — Compared TF-IDF, BM25, MiniLM, MPNet, E5-base, BGE-base with 95% bootstrap confidence intervals on 1,160 queries; documented null results (no statistically significant improvement from normalization/multi-query/hybrid)
- **Identified invalid evaluation data** — Proved human-validated Recall@5 of 0.0200 was based on synthetic sequential block labels, not genuine human judgments; 37% of case IDs referenced deduplicated-out cases
- **CPU-only production environment** — All benchmarks on 16-core CPU, 15.65 GB RAM; latency p50/p95/p99 measured for all retrieval systems

---

## Retrieval Intelligence Platform — RAG

- **Built end-to-end RAG evaluation pipeline** — First end-to-end evaluation with real 36-document FAISS corpus, 19 diverse question types (simple, multi-hop, unanswerable, ambiguous, misleading, conflicting)
- **Exposed invalid context precision metric** — Demonstrated Phase 3 context precision of 1.0000 was trivial (1 context/query); real retrieval shows 0.39-0.57
- **Compared retrieval methods** — BM25 (p50=0.21ms), Dense MiniLM (p50=4.67ms), Hybrid RRF (p50=5.87ms) with context precision, faithfulness, answer relevancy metrics
- **Provider-independent architecture** — RAG evaluation works without LLM API key; clearly marks placeholder output as simulated

---

## ML Pipeline Monitor — MLOps

- **Fixed SVM ROC-AUC computation bug** — Resolved silent `except Exception: pass` that zeroed all SVM ROC-AUC values (0.0000 → 0.972-0.997 across datasets)
- **Extended benchmarking to 13 datasets** — Added imbalanced (90/10), noisy (20% label noise), high-dimensional (100 features), temporal drift, and missing values datasets
- **Added calibration metrics** — Brier score and Expected Calibration Error (ECE) for binary classification models
- **Implemented 7 drift detection methods** — PSI, KS, JS, Wasserstein, ADWIN, Page-Hinkley, CUSUM on 10 drift scenarios; KS Test achieves F1=1.0, FPR=0.0
- **Added nested cross-validation** — For hyperparameter validation on wine dataset
- **310 tests passing, 80.65% coverage** — All existing tests continue to pass

---

## EquiPilot AI — Agentic Research

- **Fixed orphaned LangGraph node** — Connected `merge_results` node into compiled graph execution path (`research → merge_results → END`); all 5 nodes now execute end-to-end, verified with live execution
- **Financial validation with edge cases** — 4 reference cases with 15/15 financial metrics matching independent reference values; 11/11 edge case tests pass (zero denominators, None inputs, negative values)
- **Citation metrics benchmark** — 5 test cases with citation precision 0.8000, coverage 0.6333, unsupported claim rate 0.3667
- **Agent performance benchmark** — 5 test queries measuring latency, success rate, node execution; documented yfinance rate-limiting limitations
- **329 tests passing** — All existing tests pass after graph fix

---

## Cross-Project Engineering

- **Statistical validation framework** — Bootstrap 95% confidence intervals (1000-2000 resamples, seed=42) for all per-query metrics
- **Experiment management** — Machine-readable experiment results with dataset version, model version, configuration, random seed, hardware, execution duration, raw metrics, confidence intervals
- **No fabricated results** — All null results, failed experiments, and limitations explicitly documented; no evaluation samples removed or manipulated
