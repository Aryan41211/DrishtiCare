# PHASE 3 BASELINE VALIDATION — EquiPilot AI

**Repository:** `C:\projects\Equipilot AI`
**Branch:** `main`
**Git SHA at validation:** `9187e99` (HEAD)
**Validation date:** 2026-11-25
**Environment:** 16 CPU cores, 15.65 GB RAM, CPU-only, Python 3.12.10, Windows

---

## 1. EXECUTIVE SUMMARY

The EquiPilot AI Phase 2.5 baseline was **partially reproducible** with several **critical architecture issues**:

- **`merge_results` node is orphaned** — Added to LangGraph but never connected via edges. Graph flow is `router → parallel_tools → synthesis → research → END`. The conditional routing functions are defined but NOT wired into the compiled graph.
- **No LLM API key** — SynthesisAgent falls back to placeholder report. No real citations generated. All evaluation results are based on placeholder output.
- **Financial analysis not integrated into graph** — `financial_analysis.py` has 13 functions with 39 passing tests, but no graph node calls them. The graph performs zero financial calculations.
- **Only 5 research evaluation cases** — Citation precision/coverage of 1.0000 based on 5 cases, not independently validated.
- **No agent efficiency metrics** — Per-agent latency, token consumption, retry count, failure rate not measured.

**Verdict:** The reported "5 operational graph agents" is misleading — `merge_results` is an orphan node. Citation metrics of 1.0000 are based on placeholder reports, not real LLM output.

---

## 2. REPRODUCIBILITY RESULTS

### 2.1 Test Status

| Metric | Value | Status |
|--------|-------|--------|
| Tests passed | 257 | ✅ |
| Tests failed | 3 | Pre-existing (environment-related) |
| Test failures | test_env_example_documents_backend_vars, test_env_example_documents_frontend_vars, test_submit_research_connection_error | Config/docs, connection error |

### 2.2 Agent Graph — Claims vs Reality

| Claim | Reported | Verified | Issue |
|-------|----------|----------|-------|
| Total agent classes | 5 | 4 real + 1 orphan | `merge_results` is not an agent |
| Compiled graph nodes | 5 | 5 nodes but 1 orphaned | `merge_results` has no incoming edges |
| Synthesis agent wired | Yes | Yes | Falls back to placeholder without LLM key |
| Report generation | Placeholder when LLM unavailable | Yes | No real citations generated |

### 2.3 Financial Validation

| Function | Tested | Result |
|----------|--------|--------|
| safe_divide | 5 tests | ✅ Pass |
| revenue_growth | 4 tests | ✅ Pass |
| gross_margin | 3 tests | ✅ Pass |
| operating_margin | 2 tests | ✅ Pass |
| net_margin | 1 test | ✅ Pass |
| ebitda_margin | 1 test | ✅ Pass |
| eps_growth | 2 tests | ✅ Pass |
| roe | 2 tests | ✅ Pass |
| roce | 2 tests | ✅ Pass |
| debt_to_equity | 2 tests | ✅ Pass |
| current_ratio | 1 test | ✅ Pass |
| free_cash_flow | 2 tests | ✅ Pass |
| pe_ratio | 2 tests | ✅ Pass |
| pb_ratio | 2 tests | ✅ Pass |
| ps_ratio | 1 test | ✅ Pass |
| ev_ebitda | 1 test | ✅ Pass |
| compute_all_financials | 3 tests | ✅ Pass |
| validate_financial_metrics | 4 tests | ✅ Pass |

All 39 financial analysis tests pass. However:
- Financial functions are NOT called by any graph node
- No independent reference calculations used for validation
- No edge cases tested (zero denominators, negative values, different currencies, restated figures)

### 2.4 Research Evaluation

| Metric | Value | Basis |
|--------|-------|-------|
| Evaluation cases | 5 | Insufficient for statistical significance |
| Citation precision | 1.0000 | Based on placeholder reports, not real LLM output |
| Citation coverage | 1.0000 | Same |
| Financial validation | 9/9 | Based on synthetic test data, not real market data |

---

## 3. CRITICAL ARCHITECTURE ISSUES

### Issue 1: `merge_results` Node Is Orphaned (CRITICAL)

In `graph.py`, the compiled graph has these edges:
```
router → parallel_tools → synthesis → research → END
```

`merge_results` is added as a node (line 84) but **no edge leads to it**. The conditional routing functions (`route_after_router`, `route_after_market_data`, `route_after_news`, `route_after_sentiment`) reference `merge_results` as a target but are **not used** in the graph compilation.

**Impact:** The claim of "5 operational graph agents" is misleading. Only 4 nodes are actually in the execution path.

### Issue 2: No LLM API Key (CRITICAL)

`OPENAI_API_KEY` is not configured. `SynthesisAgent.generate_report()` falls back to a placeholder report. All citations are empty. The reported citation precision/coverage of 1.0000 is based on placeholder output, not real LLM-generated citations.

**Impact:** All LLM-dependent metrics are meaningless without a real LLM provider.

### Issue 3: Financial Analysis Not Integrated Into Graph (HIGH)

`financial_analysis.py` has 13 pure calculation functions with 39 passing unit tests, but:
- No graph node calls any financial function
- The `synthesis_node` doesn't compute financial metrics
- The `research_node` doesn't incorporate financial data
- No financial data flows through the graph state

**Impact:** The system cannot produce financial analysis in research reports despite having the functions implemented.

### Issue 4: Only 5 Research Evaluation Cases (HIGH)

5 cases are insufficient to establish quality. Citation precision/coverage of 1.0000 cannot be trusted with such a small sample. No independent validation.

### Issue 5: No Agent Efficiency Metrics (MEDIUM)

Not measured:
- Per-agent latency
- Token consumption
- API cost
- Retry count
- Failed execution rate
- Cache hit rate

### Issue 6: No Financial Edge Case Testing (MEDIUM)

Not tested:
- Zero denominators
- Negative values
- Different currencies
- Different reporting periods
- Restated figures
- Stale financial information

---

## 4. LIMITATIONS RECORDED

1. **No OPENAI_API_KEY** — LLM synthesis not measurable, falls back to placeholder
2. **No financial backtest** — Prohibited per master prompt
3. **yfinance rate-limited** — Live market data testing not possible
4. **Only 5 evaluation cases** — Insufficient for statistical significance
5. **No human review** — Subjective criteria not validated
6. **`merge_results` orphaned** — Graph architecture issue
7. **Financial functions not integrated** — Not called by any graph node
8. **No agent efficiency metrics** — Not measured

---

## 6. BASELINE VERDICT

| Aspect | Status |
|--------|--------|
| Graph compilation | ✅ Compiles successfully |
| All 5 nodes in execution path | ❌ `merge_results` is orphaned |
| LLM-based synthesis measurable | ❌ No API key |
| Financial analysis in graph | ❌ Not integrated |
| Citation metrics independently validated | ❌ 5 cases, placeholder output |
| Research evaluation statistically significant | ❌ Only 5 cases |
| Results defensible in interview | ⚠️ PARTIAL — Financial unit tests pass, but graph and LLM issues remain |

**DO NOT claim "5 operational graph agents" or "citation precision 1.0000" without fixing the graph architecture and expanding the evaluation dataset.**

---

## 7. IMMEDIATE NEXT STEPS FOR PHASE 3

1. **Fix graph architecture** — Connect `merge_results` node via conditional edges, or remove it if not needed
2. **Integrate financial analysis** — Add financial calculation node to the graph
3. **Expand research evaluation** — 100+ company/report cases across sectors
4. **Add agent efficiency metrics** — Per-agent latency, tokens, cost, retry count, failure rate
5. **Test financial edge cases** — Zero denominators, negative values, different currencies, restated figures
6. **Test failure handling** — Node failure, retry behavior, recovery

---

## 8. REPRODUCTION COMMANDS

```bash
# Run test suite
cd "C:\projects\Equipilot AI"
pytest tests -q -p no:cacheprovider

# Run financial analysis tests
pytest tests/test_financial_analysis.py -q

# Run report evaluator tests
pytest tests/test_report_evaluator.py -q

# Test graph compilation
python -c "from backend.graphs.graph import create_first_graph; g = create_first_graph(); print('Graph compiled:', g is not None)"
```
