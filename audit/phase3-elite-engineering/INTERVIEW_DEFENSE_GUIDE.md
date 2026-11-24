# INTERVIEW DEFENSE GUIDE — Phase 3

Use this guide to defend Phase 3 work in interviews. Every claim is backed by reproducible evidence.

---

## NYAYASAATHI — Legal Retrieval

### Q: "Your human-validated Recall@5 is only 0.0200. How do you explain this?"

**A:** That number is not trustworthy, and we proved it. During Phase 3, we independently reproduced the baseline and found the human-validated dataset (`human_validated.json`) uses synthetic sequential case ID blocks — cases 0-4 are marked relevant for land disputes, government certificate delays, AND illegal construction queries simultaneously. 37% of referenced case IDs point to cases removed during deduplication. 110 case IDs are reused across different categories. The labels are not genuine human relevance judgments.

**Evidence:** `PHASE3_BASELINE_VALIDATION.md`, `experiment_results/phase3_improvements.json`

### Q: "Did you try to improve it?"

**A:** Yes. We benchmarked TF-IDF, BM25, MiniLM, MPNet, E5-base, BGE-base, query normalization, multi-query retrieval (RRF), and hybrid BM25+dense fusion. None produced statistically significant improvement on human-validated labels — all 95% bootstrap CIs overlap. The root cause is invalid label data, not the algorithm.

**Evidence:** `backend/experiment_phase3_improvements.py`, `experiment_results/phase3_improvements.json`

### Q: "What's your plan to fix it?"

**A:** Rebuild the human-validated dataset with genuine legal expert annotations — query text, category, language, difficulty, relevant document IDs, relevance grades (0-3), annotator ID, annotation date, adjudication status. Create train/dev/test splits to prevent evaluation leakage. Only then can quality claims be defensible.

---

## RETRIEVAL INTELLIGENCE PLATFORM — RAG

### Q: "You report context precision of 1.0000. Is that real?"

**A:** No, and we demonstrated it's not. Context precision was trivially 1.0 because each query had exactly 1 context chunk written to match the question, evaluated with a 0.4 cosine similarity threshold. We built an end-to-end RAG evaluation with a real 31-document corpus and found context precision of 0.37-0.56 with actual retrieval — much more representative.

**Evidence:** `RIP_PHASE3_BASELINE_VALIDATION.md`, `experiment_results/rip_phase3_e2e_rag_eval.json`

### Q: "Your faithfulness is 0.7894. How was it measured?"

**A:** It wasn't measured on generated answers. The evaluation script used `answer = obj.get("answer", obj["ground_truth"])` — since no `answer` field existed, it always used `ground_truth`. So faithfulness measured whether the reference answer matched the context, not whether the model's output was grounded. No LLM generation was tested.

**Evidence:** `scripts/rip_phase2_evaluation.py` line 46, `offline_evaluator.py`

### Q: "Your retrieval latency is 0.16ms. Is that production-realistic?"

**A:** No. That was measured on a 60-vector FAISS index built only from the 60 eval contexts. We measured end-to-end latency on a real 31-document corpus: BM25 p50 = 0.18ms, Dense p50 = 4.59ms. The 0.16ms figure cannot be extrapolated to production.

---

## ML PIPELINE MONITOR — MLOps

### Q: "You claim 0.9907 best accuracy. Is that production-grade?"

**A:** No — that's on the wine dataset (178 samples, 13 features, 3 classes), which is an easy dataset. Multiple models achieve 1.0000 accuracy on it with proper evaluation. We also fixed a bug where SVM ROC-AUC was silently zeroed (0.0000 → 0.972-0.997) due to `except Exception: pass` swallowing all errors.

**Evidence:** `MLPM_PHASE3_BASELINE_VALIDATION.md`, `experiment_results/mlpm_phase3_improvements.json`, `src/ml_pipeline_monitor/ml/pipeline.py`

### Q: "What about drift detection? You claim F1=1.0 for KS."

**A:** That's on 8 synthetic drift scenarios with obvious separation (no drift vs. mean shifts of 0.3-2.0). We added gradual drift and concept drift scenarios. PSI with threshold 0.25 misses small drift (Recall = 0.5714). The thresholds weren't tuned on validation data and tested on unseen scenarios.

---

## EQUIPILOT AI — Agentic Research

### Q: "You claim 5 operational agents. Are they all in the graph?"

**A:** Initially no — `merge_results` was an orphan node added to the graph but never connected via edges. We fixed it (`research → merge_results → END`). All 5 nodes now execute end-to-end, verified with live execution.

**Evidence:** `backend/graphs/graph.py`, test execution output showing all nodes completing

### Q: "Your citation precision is 1.0000. Is that validated?"

**A:** No — based on 5 cases with placeholder reports (no LLM API key configured). The SynthesisAgent falls back to placeholder output when no API key is available, so no real citations were generated. We did not claim 100% accuracy beyond those 5 cases.

---

## GENERAL DEFENSE PRINCIPLES

1. **Never claim a metric you can't reproduce** — All baselines were independently reproduced or limitations documented
2. **Never hide null results** — All experiments with no significant improvement are documented in `FAILED_EXPERIMENTS.md`
3. **Always report confidence intervals** — All per-query metrics include 95% bootstrap CIs
4. **Never change methodology to get higher numbers** — Evaluation methodology was kept constant across all comparisons
5. **Document limitations explicitly** — Every project's limitations are in its baseline validation report

---

## RED FLAGS TO AVOID

- ❌ "Recall@5 = 0.0200 is acceptable because labels are sparse" — The labels are invalid, not just sparse
- ❌ "Context precision = 1.0000 proves retrieval works" — It was trivially satisfied by construction
- ❌ "0.16ms retrieval latency is production-ready" — Measured on a 60-vector index
- ❌ "SVM ROC-AUC = 0.0000 means the model is bad" — It was a bug, not a model property
- ❌ "5 operational agents" — merge_results was orphaned until fixed
