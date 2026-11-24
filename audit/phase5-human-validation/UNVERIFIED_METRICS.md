# Unverified Metrics — Phase 5

**Date:** 2026-11-25  
**Status:** All human-validated metrics are unverified — no annotations collected yet

---

## 1. Metrics That Cannot Be Claimed Until Human Annotation

| Project | Metric | Current Status | Why Unverified |
|---------|--------|---------------|----------------|
| NyayaSaathi | Human-validated Recall@5 | 0.0200 (invalid) | Based on synthetic sequential block labels, not human judgments |
| NyayaSaathi | Human-validated nDCG@10 | Not computed | No human relevance grades exist |
| RIP | Human-validated faithfulness | 1.0000 (circular) | answer = ground_truth fallback, no LLM generation |
| RIP | Human-validated citation precision | 0.0000 | No citations generated in placeholder mode |
| ML Pipeline Monitor | Human-validated drift F1 | 1.0000 (synthetic) | All scenarios synthetic, thresholds not tuned on validation data |
| EquiPilot AI | Human-validated citation precision | 0.8000 (synthetic) | 5 synthetic test cases, no real LLM output |
| EquiPilot AI | Human-validated financial correctness | 100% (synthetic) | 4 synthetic reference cases, no real market data |

---

## 2. Metrics That Require Human Annotation

| Project | Metric | Required Action |
|---------|--------|----------------|
| NyayaSaathi | Recall@5, Precision@5, MRR, nDCG@10 | Human annotators must label 500+ queries with relevance grades 0-3 |
| RIP | Faithfulness, answer relevancy, citation precision/coverage | Human reviewers must evaluate generated answers against retrieved context |
| ML Pipeline Monitor | Drift F1, FPR, detection delay | Reviewers must validate scenario realism; unseen scenarios for final test |
| EquiPilot AI | Citation precision, unsupported claim rate, financial correctness | Human reviewers must verify financial calculations and citation support |

---

## 3. Metrics That Require LLM API Key

| Project | Metric | Blocker |
|---------|--------|---------|
| RIP | Faithfulness (real generation), answer relevancy | No OPENAI_API_KEY configured |
| EquiPilot AI | Report quality, citation generation | No OPENAI_API_KEY configured |

---

## 4. Verification Path

To make these metrics defensible:

1. **Recruit human reviewers** (2-3 with relevant expertise)
2. **Run pilot annotation** (30-50 examples per project)
3. **Calculate inter-annotator agreement** (target kappa ≥ 0.60)
4. **Revise guidelines** based on pilot disagreements
5. **Expand to main dataset** (500 NyayaSaathi, 300 RAG, 100+ Equipilot)
6. **Adjudicate disagreements**
7. **Freeze train/val/test datasets**
8. **Run system benchmarks on frozen test sets**
9. **Report human-validated metrics with 95% confidence intervals**
