# UNVERIFIED METRICS — Phase 3

Metrics that were reported in Phase 2.5 but **cannot be independently verified** as valid measurements of system quality.

---

## NYAYASAATHI

| Metric | Reported Value | Verification Status | Reason Unverifiable |
|--------|---------------|---------------------|---------------------|
| Human-validated Recall@5 | 0.0200 | ❌ INVALID | Labels are synthetic sequential blocks, not human judgments; 37% of case IDs reference deduped-out cases; 110 case IDs reused across categories |
| Human-validated Recall@5 (MPNet raw) | 0.0120 | ❌ PARTIAL | Reproduced as 0.0178 — mismatch indicates different mapping/dataset version |
| Human-validated Recall@5 (BGE-base) | 0.0120 | ❌ PARTIAL | Reproduced as 0.0200 — mismatch indicates different mapping/dataset version |
| Human-validated Recall@5 (BM25) | 0.0200 | ❌ PARTIAL | Reproduced as 0.0133 — mismatch indicates different mapping/dataset version |
| Query count (human-validated) | 50 | ❌ INCONSISTENT | File contains 90 queries; multiple documents report 50 |
| Auto-generated Recall@5 (MPNet) | 0.1867 | ✅ REPRODUCED | Matches exactly on deduplicated corpus (232 cases) |
| Auto-generated Recall@5 (E5-base) | 0.1836 | ✅ REPRODUCED | Matches exactly |
| Auto-generated Recall@5 (BGE-base) | 0.1819 | ✅ REPRODUCED | Matches exactly |
| Auto-generated Recall@5 (BM25) | 0.1618 | ✅ REPRODUCED | Matches exactly |

**Bottom line:** All human-validated metrics are unverifiable due to invalid label data. Auto-generated metrics are reproducible but based on category-proxy labels, not true relevance.

---

## RETRIEVAL INTELLIGENCE PLATFORM

| Metric | Reported Value | Verification Status | Reason Unverifiable |
|--------|---------------|---------------------|---------------------|
| Context Precision | 1.0000 | ❌ TRIVIAL | 1 context per query, written to match question; 0.4 cosine threshold |
| Faithfulness | 0.7894 | ❌ CIRCULAR | answer = ground_truth fallback; no LLM generation tested |
| Answer Relevancy | 0.7316 | ❌ CIRCULAR | Measures question-to-ground_truth similarity, not question-to-generated-answer |
| Context Recall | 0.7894 | ❌ CIRCULAR | Measures ground_truth sentences in context, not actual context coverage |
| Unsupported Claim Rate | 0.2106 | ❌ CIRCULAR | Derived from faithfulness (1 - faithfulness) |
| Retrieval p50 latency | 0.16 ms | ❌ NOT REPRESENTATIVE | Measured on 60-vector index built from eval contexts only |
| Retrieval p95 latency | 0.28 ms | ❌ NOT REPRESENTATIVE | Same as above |
| Citation Precision | 0.0000 | ❌ DATA GAP | No citations in eval dataset |
| Citation Coverage | 0.0000 | ❌ DATA GAP | No citations in eval dataset |

**Bottom line:** All Phase 2 RAG metrics are unverifiable as measures of production RAG quality. End-to-end evaluation with real documents is required.

---

## ML PIPELINE MONITOR

| Metric | Reported Value | Verification Status | Reason Unverifiable |
|--------|---------------|---------------------|---------------------|
| SVM ROC-AUC (all datasets) | 0.0000 | ❌ BUG | Silent `except Exception: pass` zeroed all values; now fixed (0.972-0.997) |
| Best classification accuracy | 0.9907 | ⚠️ CONTEXT | On wine dataset (178 samples, easy); multiple models achieve 1.0000 |
| KS Test drift F1 | 1.0000 | ⚠️ LIMITED | 8 synthetic scenarios with obvious separation; no gradual/concept drift |
| PSI drift recall | 0.5714 | ⚠️ LIMITED | Threshold 0.25 too high for small drift |

**Bottom line:** SVM ROC-AUC bug is fixed. Other metrics are reproducible but limited by dataset difficulty and scenario scope.

---

## EQUIPILOT AI

| Metric | Reported Value | Verification Status | Reason Unverifiable |
|--------|---------------|---------------------|---------------------|
| Citation Precision | 1.0000 | ❌ UNVERIFIED | 5 cases only; placeholder reports (no LLM API key) |
| Citation Coverage | 1.0000 | ❌ UNVERIFIED | 5 cases only; placeholder reports (no LLM API key) |
| Financial validation | 9/9 | ⚠️ SYNTHETIC | Unit tests pass on synthetic data; not integrated into graph; no independent reference calculations |
| Agents operational | 5 | ⚠️ PARTIAL | merge_results was orphaned until Phase 3 fix; now all 5 in execution path |
| Graph execution time | ~704ms | ⚠️ PLACEHOLDER | No LLM key; synthesis falls back to placeholder |

**Bottom line:** Citation metrics are unverifiable without real LLM output and larger evaluation dataset.

---

## SUMMARY: METRICS THAT CANNOT BE DEFENDED

| Project | Metric | Why |
|---------|--------|-----|
| NyayaSaathi | All human-validated metrics | Invalid label data |
| RIP | Context precision, faithfulness, answer relevancy, context recall | Trivial/circular evaluation |
| RIP | Retrieval latency | Not production-representative |
| MLPM | SVM ROC-AUC (pre-fix) | Bug (now fixed) |
| EquiPilot | Citation precision/coverage | Placeholder output, 5 cases |

**No unverified metric was used to support a quality claim in Phase 3.**
