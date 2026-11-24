# REPRODUCTION GUIDE — Phase 3

**Date:** 2026-11-25  
**Environment:** 16 CPU cores, 15.65 GB RAM, CPU-only, Python 3.12.10, Windows

---

## HOW TO REPRODUCE ALL RESULTS

Each repository contains its own benchmark scripts and result files. Run commands from the repository root unless specified otherwise.

---

## 1. NYAYASAATHI — Legal Retrieval

**Repository:** `C:\projects\NyaySaathi`

### Reproduce Auto-Generated Baseline

```bash
cd C:\projects\NyaySaathi\backend
python experiment_phase2_benchmark.py
```

**Output:** `experiment_results/phase2_benchmark.json`

**Expected results:**
- MPNet Recall@5 = 0.1867 (auto-generated labels, 232 queries)
- All dense models MRR = 1.0000 (category-proxy labels, not discriminative)

### Reproduce Phase 3 Improvement Experiments

```bash
cd C:\projects\NyaySaathi\backend
python experiment_phase3_improvements.py
```

**Output:** `experiment_results/phase3_improvements.json`

**Tests:**
- Query normalization on all 4 embedding models
- Multi-query retrieval (RRF fusion) on all 4 models
- Hybrid BM25+MPNet (RRF and weighted fusion)
- Evaluated on 232 auto-generated + 90 human-validated queries
- 95% bootstrap confidence intervals included

### Run Test Suite

```bash
cd C:\projects\NyaySaathi\backend
python manage.py test
```

**Expected:** 3 tests pass

---

## 2. RETRIEVAL INTELLIGENCE PLATFORM — RAG

**Repository:** `C:\projects\Retrieval Intelligence Platform`

### Reproduce Phase 2 Offline Evaluation

```bash
cd "C:\projects\Retrieval Intelligence Platform\scripts"
python rip_phase2_evaluation.py
```

**Output:** `experiment_results/rip_phase2_evaluation.json`

**Expected results:**
- Faithfulness = 0.7894, Answer Relevancy = 0.7316
- Context Precision = 1.0000 (trivial — 1 context per query)
- 60 samples, all successful

### Reproduce Phase 3 End-to-End RAG Evaluation

```bash
cd "C:\projects\Retrieval Intelligence Platform\scripts"
python rip_phase3_e2e_rag_eval.py
```

**Output:** `experiment_results/rip_phase3_e2e_rag_eval.json`

**What it does:**
- Builds FAISS index from 31 synthetic documents
- Evaluates Dense (MiniLM), BM25, and Hybrid (RRF) retrieval
- Measures context precision, faithfulness, answer relevancy per method
- Reports p50/p95/p99 latency per method

### Run Test Suite

```bash
cd "C:\projects\Retrieval Intelligence Platform\backend"
python -m pytest tests -q -p no:cacheprovider
```

**Expected:** 547 passed, 4 failed (pre-existing: integration tests need DB, config drift)

---

## 3. ML PIPELINE MONITOR — MLOps

**Repository:** `C:\projects\ML-pipeline-monitor`

### Reproduce Algorithm Benchmark

```bash
cd C:\projects\ML-pipeline-monitor
python scripts/mlpm_algorithm_benchmark.py
```

**Output:** `experiment_results/mlpm_algorithm_benchmark.json`

### Reproduce Drift Benchmark

```bash
cd C:\projects\ML-pipeline-monitor
python scripts/mlpm_drift_benchmark.py
```

**Output:** `experiment_results/mlpm_drift_benchmark.json`

### Reproduce Phase 3 Improvements

```bash
cd C:\projects\ML-pipeline-monitor
python scripts/mlpm_phase3_improvements.py
```

**Output:** `experiment_results/mlpm_phase3_improvements.json`

**What it does:**
- Classification benchmarks on 6 datasets (iris, breast_cancer, wine, digits, imbalanced_90_10, noisy_20pct)
- Regression benchmarks on 3 datasets (diabetes, california_housing, noisy_regression)
- SVM ROC-AUC bug fix verification
- Calibration metrics (Brier score, ECE)
- Drift detection on 10 scenarios (including gradual and concept drift)
- Nested cross-validation on wine dataset

### Run Test Suite

```bash
cd C:\projects\ML-pipeline-monitor
pytest tests/unit tests/integration -q -p no:cacheprovider
```

**Expected:** 310 passed, coverage 80.65%

---

## 4. EQUIPIPIT AI — Agentic Research

**Repository:** `C:\projects\Equipilot AI`

### Verify Graph Fix

```bash
cd "C:\projects\Equipilot AI"
python -c "from backend.graphs.graph import create_first_graph; g = create_first_graph(); print('Graph compiled:', g is not None); print('Nodes:', list(g.nodes.keys()))"
```

**Expected:** All 6 nodes (`__start__`, `router`, `parallel_tools`, `synthesis`, `research`, `merge_results`)

### Run Test Suite

```bash
cd "C:\projects\Equipilot AI"
pytest tests -q -p no:cacheprovider
```

**Expected:** 329 passed, 3 failed (pre-existing environment-related: deploy config docs, frontend connection)

---

## 5. MASTER DELIVERABLES

All master deliverables are in `C:\projects\DrishtiCare\audit\phase3-elite-engineering\`:

| File | Purpose |
|------|---------|
| MASTER_PHASE3_REPORT.md | Executive summary and cross-project findings |
| MASTER_BENCHMARK_COMPARISON.csv | Before/after metric comparison table |
| MASTER_EXPERIMENT_INDEX.json | Machine-readable experiment index |
| STATISTICAL_VALIDATION.md | Confidence interval methodology and results |
| RESUME_READY_BULLETS.md | Resume-ready achievement statements |
| INTERVIEW_DEFENSE_GUIDE.md | Interview defense talking points |
| UNVERIFIED_METRICS.md | Metrics that cannot be independently verified |
| FAILED_EXPERIMENTS.md | Null results and failed experiments |
| REPRODUCTION_GUIDE.md | This file |
| FINAL_PROJECT_SCORECARD.md | Per-project completion scorecard |

Per-project baseline validation reports:
- PHASE3_BASELINE_VALIDATION.md (NyayaSaathi)
- RIP_PHASE3_BASELINE_VALIDATION.md (RIP)
- MLPM_PHASE3_BASELINE_VALIDATION.md (MLPM)
- EQUIPILOT_PHASE3_BASELINE_VALIDATION.md (EquiPilot AI)

---

## 6. DATASET INFORMATION

### NyayaSaathi
- Corpus: `backend/dataset/expanded_cases.json` (500 cases → 232 unique after dedup)
- Evaluation: 232 auto-generated queries + 90 human-validated queries
- Human-validated labels: INVALID (sequential blocks, cross-category reuse) — see PHASE3_BASELINE_VALIDATION.md

### RIP
- Corpus: 31 synthetic documents (ingested at runtime by rip_phase3_e2e_rag_eval.py)
- Evaluation: 19 queries (8 simple, 3 multi-hop, 3 unanswerable, 2 ambiguous, 2 misleading, 1 conflicting)
- Original eval: 60 queries in `backend/evaluation/core/eval_dataset.jsonl`

### MLPM
- Datasets: iris (150), breast_cancer (569), wine (178), digits (1797), synthetic_clf (2000), synthetic_reg (2000), imbalanced_90_10 (2000), noisy_20pct (2000), diabetes (442), california_housing (20640)
- All from scikit-learn (BSD license) or synthetically generated

### EquiPilot AI
- No dataset — financial analysis functions tested with synthetic unit test data
- Graph execution tested with live invocation (yfinance/NewsAPI rate-limited, no credits)

---

## 7. RANDOM SEEDS

All experiments use `random_seed = 42` for reproducibility. Bootstrap confidence intervals use `seed = 42` with 2000 resamples.

---

## 8. GIT STATE

All changes are committed to `main` branch in each repository. No branches created or switched. No force pushes. Commits pending explicit push approval.

| Repository | Last Commit SHA | Status |
|------------|----------------|--------|
| NyayaSaathi | e34ad6e | Committed |
| RIP | 96a0001 | Committed |
| MLPM | 852acb4 | Committed |
| EquiPilot AI | c7b7d39 | Committed |
| DrishtiCare (audit) | — | Committed |
