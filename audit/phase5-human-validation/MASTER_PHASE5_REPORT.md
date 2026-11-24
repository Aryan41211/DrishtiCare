# MASTER PHASE 5 REPORT — Human-Validated Benchmark Program

**Date:** 2026-11-25  
**Scope:** 4 repositories, human-validated evaluation infrastructure  
**Annotation workspace:** `C:\ML-Datasets\Phase5-Human-Annotation\`  
**Status:** Phase 5 infrastructure complete — annotation interface built, datasets prepared, pilots ready  
**Environment:** 16 CPU cores, 15.65 GB RAM, CPU-only

---

## 1. EXECUTIVE SUMMARY

Phase 5 establishes the human-validated benchmark infrastructure required to produce defensible, research-grade evaluation results across all four projects. No human annotations have been collected yet — this phase prepares the infrastructure and pilot datasets so the annotation coordinator (project owner) can collect genuine human judgments.

### Key Principle

**No annotations are fabricated.** All judgments must come from actual human reviewers. The annotation agent prepares the process; it does not impersonate human reviewers.

---

## 2. CENTRAL ANNOTATION WORKSPACE

**Location:** `C:\ML-Datasets\Phase5-Human-Annotation\`

### 2.1 Directory Structure

| Directory | Purpose |
|-----------|---------|
| `README.md` | Workspace overview and rules |
| `DATASET_MANIFEST.md` | Inventory of all datasets with provenance |
| `ANNOTATION_GUIDELINES.md` | Project-wide annotation rules |
| `REVIEWER_INSTRUCTIONS.md` | How reviewers use the interface |
| `schemas/` | JSON schemas for each annotation type |
| `nyayasaathi/` | Legal retrieval annotation (1,160 candidates, 50 pilot) |
| `rag/` | RAG answer evaluation (19 questions) |
| `ml_pipeline/` | Drift scenario review (11 scenarios) |
| `equipilot/` | Financial research validation (20 cases) |
| `interface/annotation_app/` | Streamlit annotation interface |
| `reports/` | Progress, agreement, and data quality reports |

### 2.2 Data Integrity Rules

1. Raw annotations are **never overwritten or deleted**
2. Revisions create new records (revision history preserved)
3. Excluded examples record reason, reviewer, and date
4. No annotation is ever deleted
5. SHA-256 hashes recorded for every dataset version

---

## 3. PROJECT-BY-PROJECT STATUS

### 3.1 NyayaSaathi — Legal Retrieval

| Item | Value |
|------|-------|
| Candidate queries | 1,160 |
| Pilot queries | 50 (5 per category × 10 categories) |
| Difficulty mix | 20 easy, 20 medium, 10 hard |
| Legal corpus | 500 cases (232 unique after dedup) |
| Relevance scale | 0-3 (0=irrelevant, 3=directly relevant) |
| N.E.I. option | Yes |

**Pilot target:** 50 queries, all reviewers annotate for agreement analysis  
**Main target:** 500 queries, 20–30% double-reviewed  
**Annotation file:** `nyayasaathi/pilot_queries.jsonl`

**Known quality problem:** Candidate queries are auto-generated from problem descriptions; not human-written. Human annotation is required.

---

### 3.2 Retrieval Intelligence Platform — RAG

| Item | Value |
|------|-------|
| Evaluation questions | 19 |
| Question types | 8 simple factual, 3 multi-hop, 3 unanswerable, 2 ambiguous, 2 misleading, 1 conflicting |
| Document corpus | 36 synthetic documents |
| Review dimensions | Factual correctness, faithfulness, citation correctness, completeness, abstention, contradiction |
| Claim-level review | Yes (claim text, source ID, text span, judgment) |

**Pilot target:** 19 questions, all reviewers annotate  
**Main target:** 300 questions (to be expanded)  
**Annotation file:** `rag/evaluation_questions.jsonl`

**Known quality problem:** Questions are hand-written but not human-reviewed for answer correctness. No LLM API key — generation evaluation pending.

---

### 3.3 ML Pipeline Monitor — Drift Detection

| Item | Value |
|------|-------|
| Drift scenarios | 11 |
| Drift types | no_drift, mild, moderate, severe, scale_change, covariate_shift, feature_level, class_imbalance, gradual, concept, recurring |
| Review dimensions | Realism (1-5), validity (1-5) |

**Pilot target:** 11 scenarios, all reviewers review  
**Main target:** Unseen drift configurations reserved for final evaluation  
**Annotation file:** `ml_pipeline/drift_scenarios.jsonl`

**Known quality problem:** All scenarios are synthetic. Reviewers must inspect realism and validity before final evaluation.

---

### 3.4 EquiPilot AI — Financial Research

| Item | Value |
|------|-------|
| Research cases | 20 |
| Sectors | 18 distinct sectors |
| Financial conditions | 9 distinct conditions |
| Market caps | 9 large, 8 mid, 3 small |
| Financial metrics | 15 metrics per case (revenue growth, margins, ROE, ROCE, debt-to-equity, current ratio, FCF, valuation) |

**Pilot target:** 20 cases, financial expert review  
**Main target:** 100+ cases (to be expanded)  
**Annotation file:** `equipilot/research_cases.jsonl`

**Known quality problem:** All financial data is synthetic. No real market data. No LLM API key.

---

## 4. ANNOTATION INTERFACE

**Location:** `interface/annotation_app/app.py`  
**Launch:** `streamlit run interface/annotation_app/app.py`  
**Requirements:** `streamlit>=1.28.0` (Streamlit 1.56.0 available)

### 4.1 Features

- Anonymous reviewer identification (no passwords or personal data)
- Project and task selection
- Per-project annotation forms with validation
- Save and resume (revisions preserved, never overwritten)
- Progress tracking per reviewer
- Export to CSV and JSONL per reviewer

### 4.2 Annotation Record Schema

Every annotation record contains:
- `annotation_id` — unique UUID
- `example_id` — identifier of the example
- `reviewer_id` — anonymous reviewer identifier
- `annotation_timestamp` — ISO datetime
- `annotation_guideline_version` — guideline version used
- `judgment` — the actual rating/score
- `reviewer_explanation` — optional explanation
- `source_reference` — source document reference
- `review_status` — pending/reviewed/adjudicated/excluded
- `revision_history` — previous versions (never overwritten)

---

## 5. PILOT AND QUALITY CONTROL

For each project:
1. Prepare annotation guidelines (done — `ANNOTATION_GUIDELINES.md`)
2. Generate 30–50 example pilot (done — pilot datasets created)
3. Primary reviewer annotates pilot
4. Independent reviews by other reviewers
5. Calculate agreement (Cohen's kappa, Krippendorff's alpha)
6. Identify confusing instructions
7. Revise guidelines and version them
8. Repeat pilot if necessary
9. Only then expand to main dataset

---

## 6. AGREEMENT ANALYSIS

When two or more reviewers annotate the same examples:
- **Exact agreement:** percentage of identical judgments
- **Weighted Cohen's kappa:** for two reviewers on ordinal scales
- **Krippendorff's alpha:** for multiple reviewers
- **Category-specific disagreement:** which categories have lowest agreement
- **Score distribution:** how grades are distributed
- **Adjudication rate:** percentage requiring third-party resolution

Target: Cohen's kappa ≥ 0.60 (substantial agreement) for pilot

---

## 7. FINAL REPORTS (TO BE POPULATED AFTER ANNOTATION)

| File | Location | Status |
|------|----------|--------|
| `MASTER_PHASE5_REPORT.md` | `audit/phase5-human-validation/` | This file |
| `ANNOTATION_GUIDELINES.md` | workspace root | Created |
| `REVIEWER_INSTRUCTIONS.md` | workspace root | Created |
| `ANNOTATION_PROGRESS.md` | `audit/phase5-human-validation/` | Template created |
| `DATASET_MANIFEST.md` | workspace root | Created |
| `INTER_ANNOTATOR_AGREEMENT.md` | `audit/phase5-human-validation/` | Template created |
| `NYAYASAATHI_HUMAN_EVALUATION.md` | `audit/phase5-human-validation/` | Template created |
| `RAG_HUMAN_EVALUATION.md` | `audit/phase5-human-validation/` | Template created |
| `ML_DRIFT_VALIDATION.md` | `audit/phase5-human-validation/` | Template created |
| `EQUIPILOT_HUMAN_EVALUATION.md` | `audit/phase5-human-validation/` | Template created |
| `STATISTICAL_VALIDATION.md` | `audit/phase5-human-validation/` | Template created |
| `RESUME_READY_BULLETS.md` | `audit/phase5-human-validation/` | Template created |
| `UNVERIFIED_METRICS.md` | `audit/phase5-human-validation/` | Template created |
| `REPRODUCTION_GUIDE.md` | `audit/phase5-human-validation/` | Template created |

---

## 8. GIT SAFETY

- All changes on `main` branches only
- No branch creation or switching
- No force push or history rewriting
- Conventional commits
- **No push without explicit approval**
- No secrets, large datasets, model weights, or private annotation records in Git
- Annotation data lives in `C:\ML-Datasets\Phase5-Human-Annotation\` (outside Git)

---

## 9. NEXT STEPS FOR THE ANNOTATION COORDINATOR

1. Launch the interface: `streamlit run C:\ML-Datasets\Phase5-Human-Annotation\interface\annotation_app\app.py`
2. Select a reviewer ID and begin pilot annotation
3. Have 2–3 reviewers independently annotate the pilot sets
4. Calculate inter-annotator agreement
5. Revise guidelines based on disagreements
6. Expand to main dataset (500 NyayaSaathi, 300 RAG, 100+ Equipilot)
7. Adjudicate disagreements
8. Freeze train/val/test datasets
9. Run system benchmarks on frozen test sets
10. Document final human-validated metrics

---

## 10. VERIFICATION THAT NO ANNOTATION WAS FABRICATED

Every annotation record contains:
- `annotation_id` — unique UUID
- `reviewer_id` — who made the judgment
- `annotation_timestamp` — when it was made
- `annotation_guideline_version` — which guidelines were used
- `review_status` — current status

Raw judgments can be audited against these fields. No annotation is ever deleted or silently modified. The coordination is performed by the project owner; the agent only prepares the infrastructure.
