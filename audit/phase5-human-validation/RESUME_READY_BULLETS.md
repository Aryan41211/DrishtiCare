# Resume-Ready Bullets — Phase 5

**Prioritized by: genuine human-validated evaluation, statistically supported results, research-grade methodology**

---

## Annotation Infrastructure

- **Built human-validated annotation infrastructure** for 4 AI projects (NyayaSaathi legal retrieval, RIP RAG, ML Pipeline Monitor drift detection, EquiPilot AI financial research)
- **Designed annotation schema** with graded relevance (0-3), reviewer identification, revision history, adjudication tracking, and data integrity rules
- **Built Streamlit annotation interface** supporting anonymous reviewer ID, project selection, per-project forms, save/resume, progress tracking, and JSONL/CSV export
- **Established non-negotiable rules:** No fabricated annotations, no model-prediction-as-ground-truth, preserve individual judgments, no overwriting raw annotations, blinded review

---

## NyayaSaathi — Legal Retrieval

- **Generated 1,160 candidate retrieval queries** across 10 legal categories with graded relevance schema
- **Selected 50 pilot queries** (5 per category, mixed difficulty: 20 easy / 20 medium / 10 hard)
- **Prepared 500-case legal corpus** (232 unique after deduplication) for annotation
- **Defined relevance scale:** 0=irrelevant, 1=topically related, 2=substantially relevant, 3=directly relevant, plus N.E.I. option

---

## Retrieval Intelligence Platform — RAG

- **Prepared 19 diverse evaluation questions** covering simple factual, multi-hop, unanswerable, ambiguous, misleading-premise, and conflicting-evidence types
- **Defined 6 review dimensions:** factual correctness, faithfulness, citation correctness, completeness, abstention, contradiction
- **Established claim-level review** with source ID, text span, and reviewer judgment per claim

---

## ML Pipeline Monitor — Drift Detection

- **Generated 11 drift scenarios** covering no_drift, mild, moderate, severe, scale_change, covariate_shift, feature_level, class_imbalance, gradual, concept, and recurring drift
- **Defined reviewer rating dimensions:** realism (1-5) and validity (1-5) for scenario quality assessment
- **Reserved unseen scenarios** for final evaluation (threshold tuning separate from final testing)

---

## EquiPilot AI — Financial Research

- **Prepared 20 research cases** across 18 sectors, 9 financial conditions, 3 market cap sizes
- **Defined 15 financial metrics** for validation: revenue growth, margins, ROE, ROCE, debt-to-equity, current ratio, FCF, valuation multiples
- **Established citation and research annotation** with claim-level source verification

---

## Cross-Project Methodology

- **Pilot-first approach:** 30-50 examples per project, all reviewers, agreement analysis before main expansion
- **Inter-annotator agreement:** Weighted Cohen's kappa (target ≥ 0.60) and Krippendorff's alpha
- **Adjudication process:** Disagreements resolved by third reviewer, both original judgments preserved
- **Data integrity:** SHA-256 hashes, revision history, exclusion logging, no silent removal of difficult samples
