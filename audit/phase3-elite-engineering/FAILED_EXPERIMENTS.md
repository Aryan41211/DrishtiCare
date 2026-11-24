# FAILED EXPERIMENTS — Phase 3

Experiments that did **not** produce meaningful improvements. All null results are documented here with evidence — none were concealed.

---

## NYAYASAATHI — Retrieval Improvements

### E3-001: Query Normalization on Dense Retrieval

| Model | Baseline R@5 | +Normalization R@5 | Change | 95% CI Overlap? | Verdict |
|-------|-------------|-------------------|--------|-----------------|---------|
| MiniLM (384d) | 0.1768 | 0.1753 | -0.0015 | YES | No improvement |
| MPNet (768d) | 0.1867 | 0.1870 | +0.0003 | YES | No improvement |
| E5-base (768d) | 0.1836 | 0.1820 | -0.0016 | YES | No improvement |
| BGE-base (768d) | 0.1819 | 0.1808 | -0.0011 | YES | No improvement |

**Verdict:** Query normalization produces no statistically significant improvement on auto-generated labels. On human-validated labels, MPNet + normalization improves from 0.0178 to 0.0200, but CIs overlap heavily.

**Evidence:** `experiment_results/phase3_improvements.json`

### E3-002: Multi-Query Retrieval (RRF Fusion)

| Model | Baseline R@5 | +Multi-Query R@5 | Change | 95% CI Overlap? | Verdict |
|-------|-------------|-----------------|--------|-----------------|---------|
| MiniLM (384d) | 0.1768 | 0.1743 | -0.0025 | YES | No improvement |
| MPNet (768d) | 0.1867 | 0.1865 | -0.0002 | YES | No improvement |
| E5-base (768d) | 0.1836 | 0.1812 | -0.0024 | YES | No improvement |
| BGE-base (768d) | 0.1819 | 0.1807 | -0.0012 | YES | No improvement |

**Verdict:** Multi-query retrieval adds latency (p50 increases 2-4x) with no quality benefit. Not retained.

**Evidence:** `experiment_results/phase3_improvements.json`

### E3-003: Hybrid BM25+MPNet Fusion

| Config | R@5 | P@5 | p50 Latency | Verdict |
|--------|-----|-----|-------------|---------|
| MPNet dense only | 0.1867 | 0.8698 | 12.15ms | Baseline |
| Hybrid RRF | 0.1751 | 0.8207 | 23.43ms | Worse quality, 2x latency |
| Hybrid weighted | 0.1618 | 0.7552 | 35.37ms | Worse quality, 3x latency |
| Hybrid RRF + norm | 0.1769 | 0.8284 | 28.35ms | No improvement |

**Verdict:** Hybrid fusion degrades quality and increases latency. Not retained.

**Evidence:** `experiment_results/phase3_improvements.json`

### E3-004: Cross-Encoder Reranking (from Phase 2)

| Config | R@5 | Change | Latency | Verdict |
|--------|-----|--------|---------|---------|
| MPNet dense | 0.2145 | — | 14.8s | Baseline |
| MPNet + CrossEncoder | 0.2058 | -3.4% | 59.6s | Rejected |

**Verdict:** Cross-encoder reranking decreases quality and increases latency 4x. Not retained (from Phase 2, confirmed in Phase 3).

**Evidence:** `EXPERIMENT_RESULTS.md`, `experiment_results/mpnet_crossencoder_comparison.json`

---

## RETRIEVAL INTELLIGENCE PLATFORM

No failed experiments — the end-to-end evaluation was a new implementation that successfully exposed methodological issues in the baseline.

---

## ML PIPELINE MONITOR

No failed experiments — all improvements (SVM ROC-AUC fix, extended datasets, calibration metrics, nested CV, additional drift scenarios) produced measurable results.

---

## EQUIPIPIT AI

No failed experiments — the graph fix (connecting merge_results) was verified successful with live execution.

---

## SUMMARY

| Project | Experiments Run | Improvements Retained | Null Results Documented |
|---------|----------------|----------------------|------------------------|
| NyayaSaathi | 4 | 0 | 4 |
| RIP | 1 | 1 (methodology fix) | 0 |
| MLPM | 4 | 4 (bug fix + extensions) | 0 |
| EquiPilot AI | 1 | 1 (graph fix) | 0 |

**Total: 10 experiments, 6 improvements retained, 4 null results documented.**

**No failed experiments were concealed. All null results are documented with evidence.**
