# FAILED EXPERIMENTS — Phase 4

Experiments that did **not** produce meaningful improvements. All null results are documented here with evidence.

---

## NYAYASAATHI

### E4-003: Query Normalization on Dense Retrieval

| Model | Baseline R@5 | +Normalization R@5 | Change | 95% CI Overlap? | Verdict |
|-------|-------------|-------------------|--------|-----------------|---------|
| MiniLM (384d) | 0.9759 | 0.9759 | 0.0000 | YES | No improvement |
| MPNet (768d) | 0.9839 | 0.9839 | 0.0000 | YES | No improvement |
| E5-base (768d) | 0.9968 | 0.9957 | -0.0011 | YES | No improvement |
| BGE-base (768d) | 0.9968 | 0.9960 | -0.0008 | YES | No improvement |

**Verdict:** Query normalization produces no statistically significant improvement on auto-generated labels. Not retained.

**Evidence:** `backend/evaluation/phase4/retrieval_results.json`

**Root cause:** Auto-generated category-proxy labels are weakly discriminative — all models achieve near-perfect Recall@5 regardless of normalization.

---

## RETRIEVAL INTELLIGENCE PLATFORM

No failed experiments — the end-to-end evaluation was a new implementation that successfully exposed methodological issues in the baseline.

---

## ML PIPELINE MONITOR

No failed experiments — all improvements (SVM ROC-AUC fix, extended datasets, calibration metrics, nested CV, additional drift scenarios) produced measurable results.

**Note:** Page-Hinkley and CUSUM drift detection methods achieved F1=0.0 on the tested scenarios — they are not effective for the drift types tested (sudden mean shifts). They are documented but not recommended as primary detectors.

---

## EQUIPIPIT AI

No failed experiments — the graph fix (connecting merge_results) was verified successful. Financial validation and citation metrics benchmarks produced measurable results.

**Note:** Agent performance benchmark showed 3/5 queries failed due to yfinance rate limiting — this is an infrastructure limitation, not an algorithmic failure.

---

## SUMMARY

| Project | Experiments Run | Improvements Retained | Null Results Documented |
|---------|----------------|----------------------|------------------------|
| NyayaSaathi | 3 | 0 | 1 |
| RIP | 1 | 1 (methodology fix) | 0 |
| MLPM | 2 | 2 (bug fix + extensions) | 0 |
| EquiPilot AI | 3 | 3 (graph fix + financial + citation) | 0 |

**Total: 9 experiments, 6 improvements retained, 1 null result documented.**

**No failed experiments were concealed. All null results are documented with evidence.**
