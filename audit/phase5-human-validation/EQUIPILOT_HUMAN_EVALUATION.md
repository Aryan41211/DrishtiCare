# EquiPilot Human Evaluation — Phase 5

**Date:** 2026-11-25  
**Status:** Pilot prepared, no human annotations collected

---

## 1. Evaluation Design

| Item | Value |
|------|-------|
| Research cases | 20 |
| Sectors | 18 distinct sectors |
| Financial conditions | 9 distinct conditions |
| Market caps | 9 large, 8 mid, 3 small |
| Financial metrics per case | 15 (revenue growth, margins, ROE, ROCE, debt-to-equity, current ratio, FCF, valuation) |

---

## 2. Financial Correctness Validation

For each metric, reviewers independently verify:
- Revenue growth
- Gross margin
- Operating margin
- Net margin
- EBITDA margin
- EPS growth
- ROE
- ROCE
- Debt-to-equity
- Current ratio
- Operating cash flow
- Free cash flow
- Valuation metrics (P/E, P/B, P/S, EV/EBITDA)

Only score metrics that are available and applicable for the reporting period.

Preserve calculation formulas and reference figures.

---

## 3. Citation and Research Annotation

For each factual claim, reviewers identify:
- Claim text
- Supporting source ID
- Page or section reference
- Whether source supports the claim
- Whether claim accurately represents source
- Whether information is stale or incomplete

Scores:
- Supported
- Partially supported
- Unsupported
- Contradicted
- Not verifiable

---

## 4. Reviewer Expertise

Financial statement verification should be performed by people capable of interpreting financial statements. Reviewer qualifications relevant to each task are recorded (e.g., "financial statement analysis: yes") without collecting unnecessary personal information.

**Do not:**
- Ask reviewers to predict stock returns
- Ask for investment recommendations
- Fabricate financial values

---

## 5. Metrics to Compute

| Metric | Definition |
|--------|-----------|
| Financial calculation correctness | Fraction of computed metrics matching reference |
| Citation precision | Fraction of citations backed by source |
| Citation coverage | Fraction of claims with citation |
| Claim-level support rate | Fraction of claims supported by source |
| Unsupported claim rate | Fraction of claims without support |
| Source freshness rate | Fraction of sources with recent timestamps |
| Report completeness rate | Fraction of expected sections present |

---

## 6. Current Status

| Milestone | Status |
|-----------|--------|
| Research cases prepared | ✅ 20 |
| Financial reference values computed | ✅ 4 cases verified |
| Citation test cases created | ✅ 5 cases |
| Annotation guidelines created | ✅ v1.0 |
| Annotation interface built | ✅ Streamlit app |
| Primary reviewer annotation | ❌ Not started |
| Independent review | ❌ Not started |
| Agreement calculation | ❌ Not started |
| Main dataset expansion | ❌ Not started (target: 100+) |
| Human-validated benchmark | ❌ Not created |

**Known quality problems:**
- All financial data is synthetic
- No real company financial statements
- No LLM API key — generation evaluation pending
- yfinance rate-limited — live market data testing not possible
