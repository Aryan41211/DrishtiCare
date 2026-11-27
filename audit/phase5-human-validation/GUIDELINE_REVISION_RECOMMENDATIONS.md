# Guideline Revision Recommendations — Phase 5.1

**Date:** 2026-11-27  
**Guideline version under review:** 1.0  
**Status:** Proactive recommendations — no annotation data exists to identify reviewer confusion empirically

---

## 1. Important Caveat

No human annotations have been collected. Therefore, **no guideline ambiguities have been observed empirically**. The recommendations below are proactive — based on structural review of the guideline document and the annotation schema — not on observed reviewer confusion. Once pilot annotation begins, these recommendations should be validated or replaced with evidence-based findings.

---

## 2. Proactive Recommendations

### 2.1 NyayaSaathi — Legal Relevance

| Area | Current Guideline | Potential Ambiguity | Recommended Revision |
|------|-------------------|---------------------|----------------------|
| Grade 1 vs Grade 2 | "1 = Topically related but does not answer the query" vs "2 = Substantially relevant" | Reviewers may disagree on where "topically related" ends and "substantially relevant" begins | Add concrete examples for each grade with sample query-case pairs |
| Grade 2 vs Grade 3 | "2 = Substantially relevant" vs "3 = Directly relevant and materially supports" | "Materially supports" is subjective | Define "materially supports" with concrete criteria (e.g., "case provides actionable procedural steps the user can follow") |
| N.E.I. option | "Use when you cannot confidently judge relevance" | Reviewers may overuse N.E.I. to avoid difficult judgments | Add specific examples of when N.E.I. is appropriate vs. when a low grade should be assigned |
| Cross-category relevance | Not explicitly addressed | A case in a different category might still be relevant | Add explicit rule: "A case from a different category can be relevant if it provides procedural guidance for the query" |

### 2.2 Retrieval Intelligence Platform — RAG

| Area | Current Guideline | Potential Ambiguity | Recommended Revision |
|------|-------------------|---------------------|----------------------|
| Faithfulness | "Fully supported / Partially supported / Unsupported" | Unclear whether "fully supported" requires every sentence to be supported or just the main claim | Define at claim level: "Every factual claim in the answer must have corresponding support in the retrieved context" |
| Citation correctness | "Correct / Partially correct / Incorrect / Missing" | Unclear what makes a citation "partially correct" | Define: "Correct = citation points to source that fully supports the claim; Partially correct = citation points to related but not exact source; Incorrect = citation points to unrelated source or fabricates source" |
| Abstention | "Appropriate / Inappropriate / Not applicable" | Unclear who decides appropriateness | Define: "Appropriate = question is unanswerable from context and system correctly declines; Inappropriate = question is answerable but system declines, or question is unanswerable but system answers" |
| Claim-level review | "Claim text, supporting source ID, supporting text span, reviewer judgment" | Unclear what constitutes a "claim" | Define: "A claim is any factual assertion that can be verified against a source. Opinions, recommendations, and speculative statements are not claims." |

### 2.3 ML Pipeline Monitor — Drift Scenario Review

| Area | Current Guideline | Potential Ambiguity | Recommended Revision |
|------|-------------------|---------------------|----------------------|
| Realism rating | "1=unrealistic, 5=highly realistic" | No anchor points for intermediate values | Add anchor descriptions: "3 = plausible but simplified, 5 = matches real-world production drift patterns" |
| Validity rating | "1=invalid, 5=highly valid" | Unclear distinction between realism and validity | Define: "Realism = does this pattern occur in practice? Validity = is the scenario correctly constructed (drift type, magnitude, features internally consistent)?" |

### 2.4 EquiPilot AI — Financial Research

| Area | Current Guideline | Potential Ambiguity | Recommended Revision |
|------|-------------------|---------------------|----------------------|
| Metric match | "Match = true if computed value matches reference within tolerance" | Tolerance not defined per metric type | Add metric-specific tolerances: "Revenue growth: ±0.001; Margins: ±0.005; Ratios: ±0.01" |
| Currency handling | Not addressed | Multi-currency cases (GBP, USD) may confuse reviewers | Add rule: "Compare values in their native currency. Do not convert unless source document specifies conversion." |

---

## 3. Missing Annotation Options

| Project | Missing Option | Recommendation |
|---------|----------------|----------------|
| NyayaSaathi | "Case not available for review" | Add option when case_candidates reference is broken or document is inaccessible |
| RIP | "Context insufficient to judge" | Add option when retrieved context is too sparse to evaluate faithfulness |
| ML Pipeline Monitor | "Scenario generation error" | Add option when drift scenario appears malformed or corrupted |
| EquiPilot | "Source document unavailable" | Add option when source_document reference cannot be verified |

---

## 4. Inadequate Source Evidence

| Project | Issue | Recommendation |
|---------|-------|----------------|
| NyayaSaathi | Case candidates include only one case per query | Expand to include multiple candidate cases per query so reviewers can compare relative relevance |
| RIP | No source documents provided alongside questions | Include source document excerpts so reviewers can verify factual correctness independently |
| EquiPilot | No source documents included in workspace | Include actual financial statement excerpts so reviewers can verify computed values |

---

## 5. Guideline Versioning

**Current version:** 1.0  
**Recommended next version:** 1.1 (proactive clarifications only — no evidence-based changes yet)  
**Action:** Do not change guidelines silently. When revisions are made, increment version and notify all reviewers. Pilot annotations collected under v1.0 should be re-annotated under v1.1 if the changes affect their judgments.

---

## 6. Next Steps

1. **Launch pilot annotation** — Recruit 2-3 reviewers and begin annotation
2. **Collect pilot data** — Target: all reviewers annotate all 50 NyayaSaathi, 19 RAG, 11 ML Pipeline, and 20 Equipilot pilot examples
3. **Compute agreement** — Calculate Cohen's kappa, Krippendorff's alpha, exact agreement
4. **Identify real ambiguities** — Based on actual reviewer disagreements, not proactive speculation
5. **Revise guidelines** — Increment version based on evidence, not speculation
6. **Repeat pilot** — If guideline changes are substantial, re-run pilot with revised guidelines
