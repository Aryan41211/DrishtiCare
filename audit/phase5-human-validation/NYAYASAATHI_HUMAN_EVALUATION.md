# NyayaSaathi Human Evaluation — Phase 5

**Date:** 2026-11-25  
**Status:** Pilot prepared, no human annotations collected

---

## 1. Evaluation Design

| Item | Value |
|------|-------|
| Pilot queries | 50 (5 per category × 10 categories) |
| Main target | 500 queries |
| Relevance scale | 0-3 (0=irrelevant, 3=directly relevant) |
| N.E.I. option | Yes (Not Enough Information) |
| Difficulty levels | Easy, medium, hard |
| Language | English (all candidates) |
| Categories | 10 legal categories |

---

## 2. Annotation Form

For each query-reviewer pair, the following is recorded:
- Query text, category, subcategory, difficulty, language
- Case ID, problem description, searchable text
- Relevance grade (0-3) or N.E.I.
- Reviewer explanation (optional)
- Timestamp, reviewer ID, guideline version

---

## 3. Metrics to Compute (After Human Validation)

| Metric | Definition |
|--------|-----------|
| Recall@K | |relevant ∩ retrieved[:K]| / |relevant| |
| Precision@K | |relevant ∩ retrieved[:K]| / K |
| MRR | 1 / rank_of_first_relevant |
| nDCG@K | Graded DCG / IDGC using relevance grades 0-3 |
| MAP | Mean average precision across queries |
| Hit Rate@K | 1 if any relevant in top-K, else 0 |

**Category-specific metrics** will be computed for all 10 legal categories.

**Language-specific metrics** will be computed if multi-language queries are added.

---

## 4. Data Splits

| Split | Purpose | Size |
|-------|---------|------|
| Train | Development, tuning | ~60% |
| Validation | Selecting best configuration | ~20% |
| Test | Final reported metrics | ~20% |

Split by underlying document/case identity to prevent document leakage.

---

## 5. Current Status

| Milestone | Status |
|-----------|--------|
| Candidate queries generated | ✅ 1,160 |
| Pilot queries selected | ✅ 50 |
| Annotation guidelines created | ✅ v1.0 |
| Annotation interface built | ✅ Streamlit app |
| Primary reviewer annotation | ❌ Not started |
| Independent review | ❌ Not started |
| Agreement calculation | ❌ Not started |
| Main dataset annotation | ❌ Not started |
| Train/val/test split | ❌ Not created |
| Human-validated benchmark | ❌ Not created |
