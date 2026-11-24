# Reproduction Guide — Phase 5

**Date:** 2026-11-25  
**Environment:** 16 CPU cores, 15.65 GB RAM, CPU-only, Python 3.12.10, Windows

---

## 1. Workspace Location

**Central annotation workspace:** `C:\ML-Datasets\Phase5-Human-Annotation\`

**Master deliverables:** `C:\projects\DrishtiCare\audit\phase5-human-validation\`

**Note:** Annotation data lives outside Git repositories. No large datasets, model weights, or private annotation records are committed to Git.

---

## 2. Workspace Structure

```
Phase5-Human-Annotation/
├── README.md
├── DATASET_MANIFEST.md
├── ANNOTATION_GUIDELINES.md
├── REVIEWER_INSTRUCTIONS.md
├── schemas/
│   ├── legal_annotation.schema.json
│   ├── rag_annotation.schema.json
│   ├── financial_annotation.schema.json
│   └── drift_scenario.schema.json
├── nyayasaathi/
│   ├── candidate_queries.csv     # 1,160 candidate queries
│   ├── pilot_queries.jsonl       # 50 pilot queries
│   ├── candidate_documents.jsonl # 500 legal cases
│   ├── annotations/              # Raw reviewer judgments
│   ├── adjudication/             # Resolved disagreements
│   └── exports/                  # Frozen evaluation datasets
├── rag/
│   ├── evaluation_questions.jsonl # 19 questions
│   ├── annotations/
│   ├── adjudication/
│   └── exports/
├── ml_pipeline/
│   ├── drift_scenarios.jsonl      # 11 scenarios
│   ├── scenario_reviews/
│   └── benchmark_results/
├── equipilot/
│   ├── research_cases.jsonl       # 20 cases
│   ├── source_documents/
│   ├── annotations/
│   ├── adjudication/
│   └── exports/
├── interface/annotation_app/
│   ├── app.py                     # Streamlit annotation interface
│   └── requirements.txt           # streamlit>=1.28.0
└── reports/
    ├── annotation_progress.json
    ├── agreement_report.json
    └── data_quality_report.json
```

---

## 3. Launching the Annotation Interface

```bash
# Install dependencies
pip install -r C:\ML-Datasets\Phase5-Human-Annotation\interface\annotation_app\requirements.txt

# Launch the interface
streamlit run C:\ML-Datasets\Phase5-Human-Annotation\interface\annotation_app\app.py
```

The interface opens at `http://localhost:8501`.

---

## 4. How to Annotate One Example

1. **Enter reviewer ID:** Use an anonymous ID (e.g., `reviewer_01`)
2. **Select project:** Choose from NyayaSaathi, RIP, ML Pipeline Monitor, EquiPilot AI
3. **Select task:** Pilot (agreement analysis) or Main evaluation
4. **Read the example:** Query/question, context, source documents
5. **Select judgment:** Use the provided dropdowns/radio buttons for the relevant scale
6. **Add explanation (optional):** Brief reasoning for the judgment
7. **Save judgment:** Click "Save Judgment" — stored with UUID, timestamp, reviewer ID
8. **Navigate:** Use Previous/Next to move between examples

---

## 5. Saving Judgments

Each judgment is appended to `annotations/reviewer_XX.jsonl` as a JSONL record. Raw annotations are **never overwritten**. If a reviewer changes their mind, a new revision record is added to `revision_history`.

---

## 6. Exporting Results

1. Click "Export My Annotations" in the interface
2. Export is saved to `exports/{reviewer_id}_export.jsonl`
3. Download the file using the download button

Each reviewer's raw judgments are exported separately.

---

## 7. Inspecting Progress

- Interface shows completion percentage per project
- `reports/annotation_progress.json` shows aggregate progress
- `reports/agreement_report.json` shows inter-annotator agreement (after pilot)
- `reports/data_quality_report.json` shows data quality metrics

---

## 8. Data Integrity Verification

To verify no annotation was fabricated:

1. Check that every record has a unique `annotation_id` (UUID)
2. Check that `reviewer_id` matches an actual reviewer
3. Check that `annotation_timestamp` is a valid ISO datetime
4. Check that `annotation_guideline_version` matches the current guidelines version
5. Check that `review_status` is one of: pending, reviewed, adjudicated, excluded
6. Verify no `annotation_id` appears twice in a reviewer's file (unless it's a revision)

---

## 9. Dataset Files

| File | Location | Records |
|------|----------|---------|
| `candidate_queries.csv` | `nyayasaathi/` | 1,160 |
| `pilot_queries.jsonl` | `nyayasaathi/` | 50 |
| `candidate_documents.jsonl` | `nyayasaathi/` | 500 |
| `evaluation_questions.jsonl` | `rag/` | 19 |
| `drift_scenarios.jsonl` | `ml_pipeline/` | 11 |
| `research_cases.jsonl` | `equipilot/` | 20 |

---

## 10. SHA-256 Verification

SHA-256 hashes will be recorded for every dataset version upon export. To verify a file's integrity:

```bash
python -c "import hashlib; print(hashlib.sha256(open('FILEPATH','rb').read()).hexdigest())"
```

Compare against the recorded hash in the dataset manifest.

---

## 11. Git State

All Phase 5 deliverables are in `C:\projects\DrishtiCare\audit\phase5-human-validation\`. Annotation data is in `C:\ML-Datasets\Phase5-Human-Annotation\` (outside Git).

No push without explicit approval.
