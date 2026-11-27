# Main Campaign Readiness — Phase 5.1

**Date:** 2026-11-27  
**Workspace:** `C:\ML-Datasets\Phase5-Human-Annotation\`  
**Status:** NOT READY — no human annotations collected

---

## 1. Readiness Assessment

The pilot annotation campaign has **not started**. Therefore, the dataset is **not ready** for freeze, and the main annotation campaign cannot begin.

| Readiness Criterion | Status | Evidence |
|---------------------|--------|----------|
| Annotation interface built | PASS | Streamlit app at `interface/annotation_app/app.py`, Streamlit 1.56.0 available |
| Annotation schemas defined | PASS | 4 JSON schemas in `schemas/` |
| Annotation guidelines written | PASS | `ANNOTATION_GUIDELINES.md` v1.0 |
| Reviewer instructions written | PASS | `REVIEWER_INSTRUCTIONS.md` |
| Pilot datasets prepared | PASS | 50 NyayaSaathi, 19 RAG, 11 ML Pipeline, 20 Equipilot |
| Human annotations collected | FAIL | 0 annotations across all projects |
| Reviewers participated | FAIL | 0 reviewers |
| Inter-annotator agreement computed | FAIL | No data to compute |
| Adjudication process tested | FAIL | No disagreements to adjudicate |
| Guidelines validated with real data | FAIL | No reviewer confusion observed |

**Overall: NOT READY** — The pilot has not been executed. No human judgments exist.

---

## 2. What Must Be Fixed Before Main Campaign

### 2.1 Immediate Blocker: No Reviewers Have Started

| Issue | Detail | Resolution |
|-------|--------|------------|
| No reviewer has launched the interface | All annotation directories empty | Recruit 2-3 reviewers and have them run `streamlit run interface/annotation_app/app.py` |
| No pilot annotations submitted | 0 of 100 pilot examples annotated | Each reviewer must annotate all pilot examples independently |
| No agreement data | Cannot compute kappa/alpha | After pilot, compute agreement and check kappa ≥ 0.60 |

### 2.2 Pre-Main-Campaign Checklist

Before expanding to the main dataset, the following must be complete:

1. **Pilot annotation complete:** All reviewers have annotated all pilot examples
   - NyayaSaathi: 50 queries × all reviewers
   - RIP: 19 questions × all reviewers
   - ML Pipeline Monitor: 11 scenarios × all reviewers
   - EquiPilot AI: 20 cases × all reviewers

2. **Inter-annotator agreement computed:** Cohen's kappa ≥ 0.60 for each project

3. **Guideline issues resolved:** Any confusing instructions identified during pilot have been addressed and guidelines versioned (v1.1+)

4. **Adjudication process tested:** At least one disagreement has been identified, discussed, and resolved by an adjudicator

5. **Main dataset defined:** The full set of examples for main annotation is selected and locked

---

## 3. Recommended Main Campaign Plan

Once pilot is complete and guidelines are stable:

### Phase 5.1 — Pilot (Current State: NOT STARTED)
- 50 NyayaSaathi queries
- 19 RAG questions
- 11 ML Pipeline scenarios
- 20 Equipilot cases
- All reviewers annotate all pilot examples

### Phase 5.2 — Main Annotation
- NyayaSaathi: Expand to 500 queries (train/val/test split)
- RIP: Expand to 300 questions
- ML Pipeline Monitor: Expand drift scenarios with unseen configurations
- Equipilot AI: Expand to 100+ research cases

### Phase 5.3 — Adjudication and Freeze
- Resolve all disagreements
- Freeze train/validation/test splits
- Prevent document leakage (split by document/case identity)
- Preserve test set from any model tuning

### Phase 5.4 — Human-Validated Benchmark
- Run system benchmarks on frozen human-validated test sets
- Report human-validated metrics with 95% confidence intervals
- Document all limitations

---

## 4. Split Rules (When Ready)

When the main campaign is ready, follow these rules:

| Split | Purpose | Size |
|-------|---------|------|
| Train | Development, tuning | ~60% |
| Validation | Selecting best configuration | ~20% |
| Test | Final reported metrics | ~20% |

**Split by document/case identity** to prevent document leakage. No case should appear in more than one split.

**Never:** Tune hyperparameters on the test set. Never change the test set after inspecting benchmark results.

---

## 5. Blocker Summary

| Blocker | Severity | Resolution Required |
|---------|----------|---------------------|
| No human annotations collected | Critical | Recruit reviewers, launch interface, complete pilot annotation |
| No inter-annotator agreement data | Critical | Complete pilot, compute kappa/alpha |
| No adjudication process tested | High | Complete at least one disagreement resolution cycle |
| Guidelines not validated with real data | High | Complete pilot, identify and fix confusing instructions |

**None of these blockers are technical.** The interface, schemas, data files, and guidelines are all ready. The only requirement is for human reviewers to begin annotation.
