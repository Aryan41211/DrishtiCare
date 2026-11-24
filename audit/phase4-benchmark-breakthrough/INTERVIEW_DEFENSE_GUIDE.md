# INTERVIEW DEFENSE GUIDE — Phase 4

Use this guide to defend Phase 4 work in interviews. Every claim is backed by reproducible evidence.

---

## GENERAL DEFENSE PRINCIPLES

1. **Never claim a metric you can't reproduce** — All baselines were independently reproduced or limitations documented
2. **Never hide null results** — All experiments with no significant improvement are documented in FAILED_EXPERIMENTS.md
3. **Always report confidence intervals** — All per-query metrics include 95% bootstrap CIs
4. **Never change methodology to get higher numbers** — Evaluation methodology was kept constant across all comparisons
5. **Document limitations explicitly** — Every project's limitations are in its baseline validation report

---

## NYAYASAATHI

### Q: "Your human-validated Recall@5 is only 0.0200. Is that real?"

**A:** No, and we proved it isn't. The human-validated dataset used synthetic sequential block labels — cases 0-4 marked relevant for land disputes, government certificates, AND construction queries simultaneously. 37% of case IDs reference cases removed during deduplication. We built an annotation system with 1,160 candidate queries awaiting genuine human annotation. No query is marked "human-validated" until a person has reviewed it.

### Q: "Did query normalization improve retrieval?"

**A:** No statistically significant improvement. We tested normalization on MiniLM, MPNet, E5-base, and BGE-base — all 95% bootstrap CIs overlap with baseline. The root cause is invalid label data, not the algorithm.

---

## RETRIEVAL INTELLIGENCE PLATFORM

### Q: "Your context precision was 1.0000. Is that real?"

**A:** No. It was trivially satisfied because each query had exactly 1 context chunk written to match the question. We built an end-to-end RAG evaluation with a real 36-document corpus — context precision is now 0.39-0.57, which is representative of actual system behavior.

### Q: "Was your faithfulness measurement circular?"

**A:** Yes, and we acknowledged it. The evaluation script used `answer = ground_truth` fallback, so faithfulness measured whether the reference answer matched the context, not whether the model's output was grounded. No LLM generation was tested. We clearly mark this as a limitation.

---

## ML PIPELINE MONITOR

### Q: "Your SVM ROC-AUC was 0.0000. Was the model broken?"

**A:** No — it was a bug in the evaluation code. A silent `except Exception: pass` swallowed all ROC-AUC computation errors. We fixed it, and SVM now correctly computes ROC-AUC (0.972-0.997 across datasets). This is a genuine bug fix, not a model improvement.

### Q: "Is 0.9907 accuracy on wine production-grade?"

**A:** No — wine has 178 samples, 13 features, 3 classes. Multiple models achieve 1.0000. We tested on 13 diverse datasets including imbalanced, noisy, and high-dimensional data. Noisy 20% label noise reduces accuracy to 0.71-0.89.

---

## EQUIPILOT AI

### Q: "Are all 5 agents actually in the graph?"

**A:** Initially no — `merge_results` was an orphan node. We fixed it (`research → merge_results → END`). All 5 nodes now execute end-to-end, verified with live execution.

### Q: "Can you measure LLM quality without an API key?"

**A:** No. We clearly mark this as a limitation. The SynthesisAgent falls back to placeholder output without OPENAI_API_KEY. We built provider-independent architecture but cannot measure real generation quality.

---

## RED FLAGS TO AVOID

- ❌ "Recall@5 = 0.0200 is acceptable because labels are sparse" — The labels are invalid, not just sparse
- ❌ "Context precision = 1.0000 proves retrieval works" — It was trivially satisfied by construction
- ❌ "SVM ROC-AUC = 0.0000 means the model is bad" — It was a bug, not a model property
- ❌ "5 operational agents" — merge_results was orphaned until fixed
- ❌ "0.9907 is production-grade accuracy" — It's on an easy 178-sample dataset
