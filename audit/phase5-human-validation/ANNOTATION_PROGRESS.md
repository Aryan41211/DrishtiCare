# Annotation Progress — Phase 5

**Date:** 2026-11-25  
**Workspace:** `C:\ML-Datasets\Phase5-Human-Annotation\`  
**Status:** Infrastructure ready, zero human annotations collected yet

---

## 1. Current Status

No human annotations have been collected. The annotation infrastructure is built and ready for the annotation coordinator to begin.

| Project | Pilot Examples | Main Examples | Human-Annotated | Double-Reviewed | Adjudicated |
|---------|---------------|---------------|-----------------|-----------------|-------------|
| NyayaSaathi | 50 | 500 (target) | 0 | 0 | 0 |
| RIP | 19 | 300 (target) | 0 | 0 | 0 |
| ML Pipeline Monitor | 11 | 11 (all scenarios) | 0 | 0 | 0 |
| EquiPilot AI | 20 | 100 (target) | 0 | 0 | 0 |

---

## 2. Pilot Status

| Project | Pilot Prepared | Primary Reviewer | Independent Reviewers | Agreement Calculated |
|---------|---------------|------------------|----------------------|---------------------|
| NyayaSaathi | ✅ 50 queries | Not started | Not started | Not started |
| RIP | ✅ 19 questions | Not started | Not started | Not started |
| ML Pipeline Monitor | ✅ 11 scenarios | Not started | Not started | Not started |
| EquiPilot AI | ✅ 20 cases | Not started | Not started | Not started |

---

## 3. Main Dataset Status

| Project | Main Prepared | Primary Reviewer | Independent Reviewers | Frozen Test Set |
|---------|--------------|------------------|----------------------|-----------------|
| NyayaSaathi | ❌ Not expanded | Not started | Not started | Not created |
| RIP | ❌ Not expanded | Not started | Not started | Not created |
| ML Pipeline Monitor | ⚠️ All 11 scenarios ready | Not started | Not started | Not created |
| EquiPilot AI | ❌ Not expanded | Not started | Not started | Not created |

---

## 4. How to Begin

1. Launch the annotation interface:
   ```
   streamlit run C:\ML-Datasets\Phase5-Human-Annotation\interface\annotation_app\app.py
   ```
2. Select a reviewer ID (e.g., `reviewer_01`)
3. Select a project and task (Pilot or Main)
4. Annotate examples, save judgments
5. Export results when complete

See `REVIEWER_INSTRUCTIONS.md` in the workspace for detailed steps.

---

## 6. Data Files

| File | Location | Records |
|------|----------|---------|
| `candidate_queries.csv` | `nyayasaathi/` | 1,160 |
| `pilot_queries.jsonl` | `nyayasaathi/` | 50 |
| `candidate_documents.jsonl` | `nyayasaathi/` | 500 |
| `evaluation_questions.jsonl` | `rag/` | 19 |
| `drift_scenarios.jsonl` | `ml_pipeline/` | 11 |
| `research_cases.jsonl` | `equipilot/` | 20 |
