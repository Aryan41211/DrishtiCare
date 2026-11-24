# RAG Human Evaluation — Phase 5

**Date:** 2026-11-25  
**Status:** Pilot prepared, no human annotations collected

---

## 1. Evaluation Design

| Item | Value |
|------|-------|
| Evaluation questions | 19 |
| Question types | 8 simple factual, 3 multi-hop, 3 unanswerable, 2 ambiguous, 2 misleading, 1 conflicting |
| Document corpus | 36 synthetic documents |
| Review dimensions | 6 (see below) |

---

## 2. Review Dimensions

Each answer is evaluated on six independent dimensions:

| Dimension | Scale | Definition |
|-----------|-------|------------|
| Factual correctness | Correct / Partially correct / Incorrect | All factual claims match source |
| Faithfulness | Fully / Partially / Unsupported | Answer supported by retrieved context |
| Citation correctness | Correct / Partially / Incorrect / Missing | Citations point to supporting sources |
| Completeness | Complete / Partially / Incomplete | Answer addresses all parts of question |
| Abstention | Appropriate / Inappropriate / N/A | Correctly declined to answer unanswerable |
| Contradiction | No contradiction / Contains contradiction | Internal consistency |

---

## 3. Claim-Level Review

Each factual claim is reviewed individually:
- Claim text
- Supporting source ID
- Supporting text span or page
- Reviewer judgment (supports / does not support)
- Explanation

---

## 4. Metrics to Compute

| Metric | Definition |
|--------|-----------|
| Faithfulness rate | Fraction of answers fully supported |
| Answer correctness rate | Fraction of answers correct |
| Citation precision | Fraction of citations backed by source |
| Citation coverage | Fraction of answer sentences with citation |
| Unsupported claim rate | Fraction of claims without support |
| Correct abstention rate | Fraction of unanswerable questions correctly declined |
| Answer completeness rate | Fraction of answers fully addressing question |

---

## 5. Current Status

| Milestone | Status |
|-----------|--------|
| Evaluation questions prepared | ✅ 19 |
| Question types classified | ✅ 6 types |
| Annotation guidelines created | ✅ v1.0 |
| Annotation interface built | ✅ Streamlit app |
| Primary reviewer annotation | ❌ Not started |
| Independent review | ❌ Not started |
| Agreement calculation | ❌ Not started |
| Main dataset expansion | ❌ Not started (target: 300) |
| Human-validated benchmark | ❌ Not created |

**Generation dependency:** No LLM API key configured. Generation evaluation pending until provider is configured and approved.
