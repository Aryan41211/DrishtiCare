# Dataset Manifest — Phase 5 Human Validation

**Date:** 2026-11-25  
**Workspace:** `C:\ML-Datasets\Phase5-Human-Annotation\`

---

## 1. NyayaSaathi — Legal Retrieval

| File | Source | Records | Label Status | SHA-256 | Notes |
|------|--------|---------|--------------|---------|-------|
| `candidate_queries.csv` | Phase 4 generation | 1,160 | Candidate (not human-validated) | TBD | Auto-generated from problem descriptions |
| `pilot_queries.jsonl` | Subset of candidates | 50 | Candidate (ready for annotation) | TBD | 5 per category, mixed difficulty |
| `candidate_documents.jsonl` | Phase 4 corpus | 500 | Reference documents | TBD | 232 unique after dedup |

**Known quality problems:**
- Candidate queries auto-generated, not human-written
- Some query variants are near-duplicates
- No human relevance judgments exist yet

---

## 2. Retrieval Intelligence Platform — RAG

| File | Source | Records | Label Status | SHA-256 | Notes |
|------|--------|---------|--------------|---------|-------|
| `evaluation_questions.jsonl` | Phase 4 generation | 19 | Candidate (not human-validated) | TBD | Hand-written questions |

**Known quality problems:**
- Questions not human-reviewed for answer correctness
- No real document corpus (36 synthetic documents)
- Phase 3 evaluation used circular answer=ground_truth

---

## 3. ML Pipeline Monitor — Drift Detection

| File | Source | Records | Label Status | SHA-256 | Notes |
|------|--------|---------|--------------|---------|-------|
| `drift_scenarios.jsonl` | Phase 4 generation | 11 | Controlled ground truth (synthetic) | TBD | All scenarios synthetic |

**Known quality problems:**
- All scenarios synthetic
- Thresholds not tuned on validation data

---

## 4. EquiPilot AI — Financial Research

| File | Source | Records | Label Status | SHA-256 | Notes |
|------|--------|---------|--------------|---------|-------|
| `research_cases.jsonl` | Phase 4 generation | 20 | Synthetic reference values | TBD | All data synthetic |

**Known quality problems:**
- No real company financial statements
- Only 4 reference cases with independent verification
- No LLM API key for generation testing

---

## 5. Schema Files

| Schema | Location | Version |
|--------|----------|---------|
| `legal_annotation.schema.json` | `schemas/` | 1.0 |
| `rag_annotation.schema.json` | `schemas/` | 1.0 |
| `financial_annotation.schema.json` | `schemas/` | 1.0 |
| `drift_scenario.schema.json` | `schemas/` | 1.0 |

---

## 6. Data Integrity

- SHA-256 hashes will be recorded for every dataset version upon export
- Raw annotations stored in `annotations/reviewer_XX.jsonl` (one file per reviewer)
- Adjudicated results stored in `adjudication/`
- Frozen datasets exported to `exports/`
