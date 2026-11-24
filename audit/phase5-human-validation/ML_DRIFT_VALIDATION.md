# ML Drift Validation — Phase 5

**Date:** 2026-11-25  
**Status:** Scenarios prepared, no human review collected

---

## 1. Evaluation Design

| Item | Value |
|------|-------|
| Drift scenarios | 11 |
| Drift types | 11 types (see below) |
| Review dimensions | Realism (1-5), validity (1-5) |
| Ground truth type | Controlled (synthetic) |

---

## 2. Drift Scenarios

| ID | Drift Type | Dataset | Magnitude | Onset |
|----|-----------|---------|-----------|-------|
| drift-001 | no_drift | iris | 0.0 | 0.0 |
| drift-002 | mild_drift | iris | 0.3 | 0.5 |
| drift-003 | moderate_drift | breast_cancer | 0.7 | 0.5 |
| drift-004 | severe_drift | wine | 1.5 | 0.5 |
| drift-005 | scale_change | iris | 3.0 | 0.5 |
| drift-006 | covariate_shift | digits | 2.0 | 0.5 |
| drift-007 | feature_level_drift | iris | 1.0 | 0.5 |
| drift-008 | class_imbalance_shift | iris | 0.3 | 0.5 |
| drift-009 | gradual_drift | iris | 1.5 | 0.0 (transition 1.0) |
| drift-010 | concept_drift | iris | 1.0 | 0.5 |
| drift-011 | recurring_drift | iris | 1.0 | 0.25 |

---

## 3. Reviewer Tasks

Reviewers inspect each scenario and rate:
- **Realism (1-5):** Does this drift pattern resemble real-world data shifts?
- **Validity (1-5):** Is the scenario correctly constructed?

Reviewers also provide explanations for low ratings.

---

## 4. Metrics to Compute

| Metric | Definition |
|--------|-----------|
| Precision | True positives / (true positives + false positives) |
| Recall | True positives / (true positives + false negatives) |
| F1 | 2 × precision × recall / (precision + recall) |
| FPR | False positives / (false positives + true negatives) |
| FNR | False negatives / (false negatives + true positives) |
| Detection delay | Samples between drift onset and detection |
| Alert stability | Consistency of alerts across repeated runs |

---

## 5. Evaluation Protocol

1. **Threshold tuning:** Tune drift detection thresholds on validation scenarios
2. **Unseen evaluation:** Test final performance on reserved unseen scenarios
3. **Multiple random seeds:** Run each scenario with multiple seeds
4. **Reviewer inspection:** Reviewers validate scenario realism before final evaluation

---

## 6. Current Status

| Milestone | Status |
|-----------|--------|
| Drift scenarios generated | ✅ 11 |
| Drift types covered | ✅ 11 types |
| Annotation guidelines created | ✅ v1.0 |
| Annotation interface built | ✅ Streamlit app |
| Primary reviewer review | ❌ Not started |
| Independent review | ❌ Not started |
| Agreement calculation | ❌ Not started |
| Threshold tuning | ❌ Not started |
| Unseen evaluation | ❌ Not started |

**Known quality problem:** All scenarios are synthetic. Reviewers must inspect realism before final evaluation.
