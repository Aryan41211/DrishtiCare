# REPRODUCTION GUIDE — Phase 4

**Date:** 2026-11-25  
**Environment:** 16 CPU cores, 15.65 GB RAM, CPU-only, Python 3.12.10, Windows

---

## HOW TO REPRODUCE ALL RESULTS

Each repository contains its own benchmark scripts and result files. Run commands from the repository root unless specified otherwise.

---

## 1. NYAYASAATHI — Legal Retrieval

**Repository:** `C:\projects\NyaySaathi`

### Generate Candidate Queries

```bash
cd C:\projects\NyaySaathi\scripts\phase4
python annotation_system.py generate-candidates \
  --output ../../backend/evaluation/phase4/annotations/candidate_queries.jsonl \
  --n-per-category 50
```

**Output:** `backend/evaluation/phase4/annotations/candidate_queries.jsonl` (1,160 queries)

### Run Retrieval Evaluation

```bash
cd C:\projects\NyaySaathi\scripts\phase4
python retrieval_evaluation.py
```

**Output:** `backend/evaluation/phase4/retrieval_results.json`

**Expected results (auto-generated labels):**
- E5-base R@5 = 0.9968, BGE-base R@5 = 0.9968
- BM25 R@5 = 1.0000
- All on category-proxy labels (NOT human-validated)

### Run Test Suite

```bash
cd C:\projects\NyaySaathi\backend
python manage.py test
```

**Expected:** 3 tests pass

### Import Human Annotations (when available)

```bash
cd C:\projects\NyaySaathi\scripts\phase4
python annotation_system.py import-annotations \
  --input annotated_queries.jsonl \
  --output ../../backend/evaluation/phase4/annotations/validated_dataset.jsonl

python annotation_system.py create-splits \
  --input ../../backend/evaluation/phase4/annotations/validated_dataset.jsonl \
  --output-dir ../../backend/evaluation/phase4/splits/
```

---

## 2. RETRIEVAL INTELLIGENCE PLATFORM — RAG

**Repository:** `C:\projects\Retrieval Intelligence Platform`

### Run Phase 4 End-to-End RAG Evaluation

```bash
cd "C:\projects\Retrieval Intelligence Platform\scripts\phase4"
python rag_evaluation_pipeline.py
```

**Output:** `experiment_results/phase4/rag_evaluation_results.json`

**Expected results:**
- Dense: Faithfulness=1.0000, ContextPrecision=0.5684, p50=4.67ms
- BM25: Faithfulness=1.0000, ContextPrecision=0.3895, p50=0.21ms
- Hybrid: Faithfulness=1.0000, ContextPrecision=0.4947, p50=5.87ms

### Run Test Suite

```bash
cd "C:\projects\Retrieval Intelligence Platform\backend"
python -m pytest tests -q -p no:cacheprovider
```

**Expected:** 547 passed, 4 failed (pre-existing: integration tests need DB, config drift)

---

## 3. ML PIPELINE MONITOR — MLOps

**Repository:** `C:\projects\ML-pipeline-monitor`

### Run Phase 4 Advanced Benchmarking

```bash
cd C:\projects\ML-pipeline-monitor
python scripts/phase4/mlpm_phase4_benchmark.py
```

**Output:** `experiment_results/phase4/mlpm_phase4_results.json`

**Expected results:**
- KS Test drift F1=1.0, FPR=0.0
- SVM ROC-AUC correctly computed (0.972-0.997)
- Wine accuracy 1.0000 (easy dataset)
- Noisy 20% accuracy 0.71-0.89

### CSV Outputs

- `experiment_results/phase4/PHASE4_MODEL_BENCHMARK.csv`
- `experiment_results/phase4/PHASE4_DRIFT_BENCHMARK.csv`

### Run Test Suite

```bash
cd C:\projects\ML-pipeline-monitor
pytest tests/unit tests/integration -q -p no:cacheprovider
```

**Expected:** 310 passed, coverage 80.65%

---

## 4. EQUIPIPIT AI — Agentic Research

**Repository:** `C:\projects\Equipilot AI`

### Run Financial Validation Benchmark

```bash
cd "C:\projects\Equipilot AI\scripts\phase4"
python financial_validation_benchmark.py
```

**Output:** `experiment_results/phase4/financial_validation_results.json`

**Expected results:**
- All 4 reference cases pass (15/15 metrics each)
- All 11 edge case tests pass

### Run Citation Metrics Benchmark

```bash
cd "C:\projects\Equipilot AI\scripts\phase4"
python citation_metrics_benchmark.py
```

**Output:** `experiment_results/phase4/citation_and_performance_results.json`

**Expected results:**
- Citation precision: 0.8000 mean
- Citation coverage: 0.6333 mean
- Agent success: 2/5 (yfinance rate-limited)

### Run Test Suite

```bash
cd "C:\projects\Equipilot AI"
pytest tests -q -p no:cacheprovider
```

**Expected:** 329 passed, 3 failed (pre-existing: deploy config docs, frontend connection)

---

## 5. MASTER DELIVERABLES

All master deliverables are in `C:\projects\DrishtiCare\audit\phase4-benchmark-breakthrough\`:

| File | Purpose |
|------|---------|
| MASTER_PHASE4_REPORT.md | Executive summary and cross-project findings |
| MASTER_METRICS_COMPARISON.csv | Before/after metric comparison table |
| MASTER_EXPERIMENT_INDEX.json | Machine-readable experiment index |
| STATISTICAL_SIGNIFICANCE_REPORT.md | Confidence interval methodology and results |
| RESUME_READY_BULLETS.md | Resume-ready achievement statements |
| INTERVIEW_DEFENSE_GUIDE.md | Interview defense talking points |
| FAILED_EXPERIMENTS.md | Null results and failed experiments |
| DATASET_PROVENANCE.md | Dataset sources and licensing |
| REPRODUCTION_GUIDE.md | This file |
| NEXT_RESEARCH_ROADMAP.md | Next steps for each project |

---

## 6. RANDOM SEEDS

All experiments use `random_seed = 42`. Bootstrap confidence intervals use `seed = 42` with 1000-2000 resamples.

---

## 7. GIT STATE

All changes are committed to `main` branch in each repository. No branches created or switched. Commits pending explicit push approval.

| Repository | Last Commit SHA |
|------------|-----------------|
| NyayaSaathi | 4ef4923 |
| RIP | 142313d |
| MLPM | 0f13abb |
| EquiPilot AI | 5087a7a |
| DrishtiCare (audit) | — |
