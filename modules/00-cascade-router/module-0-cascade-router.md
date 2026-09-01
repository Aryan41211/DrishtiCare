# Module 0 — Cascade Router

## Purpose

Route images to the appropriate processing path based on ensemble confidence. Saves compute by skipping Branch B on clear cases.

## Research Context

**Key findings from literature:**
- 2-model cascades provide significant cost savings; 3-model only marginally better (OpenReview, 2023)
- Confidence-Gated Training (arXiv 2509.17885, 2026): Conditionally propagates gradients from deeper exits only when preceding exits fail
- CalexNet (arXiv 2509.08318, 2026): 31.58% FLOP reduction for 1% accuracy tradeoff
- T-RECX (2023): Mitigates "overthinking" problem with early-view features
- Design rule: Choose models with large computational cost differences

## Confidence Bands

| Band | Condition | Action | Expected % |
|------|-----------|--------|-----------|
| Clear | conf > 0.92 | Commit to Branch A grade, skip Branch B | ~50-60% |
| Need Review | 0.35 < conf < 0.92 | Run Branch B → evidence agreement → commit or flag | ~30-40% |
| Abstain | conf < 0.35 | Route to human review immediately | ~5-10% |

## Architecture

```
Image → Quality Gate → Branch A (Ensemble) → Confidence Score
                            ↓
                    ┌─────────────────────────────────────────┐
                    │                                         │
                    ▼                                         ▼
            conf > 0.92                               0.35 < conf < 0.92
            │                                              │
            ▼                                              ▼
    Commit Grade A                                  Run Branch B
    (skip Branch B)                                │
                                                   ▼
                                          Evidence Agreement
                                                   │
                                          ┌────────┴────────┐
                                          │                  │
                                          ▼                  ▼
                                    Agree → Commit    Disagree → Flag
```

## Implementation

```matlab
% Branch A ensemble inference
[~, scoresA] = classify(netEnsemble, image);
prob_grades = mean(scoresA, 1); % Average across 3 backbones

% Apply calibrated confidence (post temperature scaling)
conf_referable = calibratedScores(grade >= 2);

% Route
if conf_referable > 0.92
    grade = branchA_grade;
    source = 'clear';
elseif conf_referable > 0.35
    % Run Branch B
    [gradeB, evidence] = branchB_inference(image);
    [grade, agreed] = evidence_agreement(branchA_grade, gradeB, evidence);
    source = 'fused';
else
    grade = 'abstain';
    source = 'human_review';
end
```

## Evidence Agreement Logic

```matlab
function [finalGrade, agreed] = evidence_agreement(gradeA, gradeB, evidence)
    if gradeA == gradeB
        finalGrade = gradeA;
        agreed = true;
    elseif abs(gradeA - gradeB) == 1
        % Adjacent grades — use higher (conservative)
        finalGrade = max(gradeA, gradeB);
        agreed = false; % Flag for review
    else
        % Disagree by 2+ — abstain
        finalGrade = 'abstain';
        agreed = false;
    end
end
```

## Ensemble Diversity

Three backbones with different architectures:
- **EfficientNet-B4** — best accuracy-speed tradeoff
- **ResNet-50** — different architecture = different failure modes
- **Inception-v3** — captures different scales

Ensemble disagreement is a free uncertainty signal. If all 3 agree → confident. If 2 disagree → uncertain → run Branch B.

## Early Exit Optimization

**Confidence-Gated Training (CGT):**
- Conditionally propagates gradients from deeper exits only when preceding exits fail
- Encourages shallow classifiers to act as primary decision points
- Reduces average inference cost while improving overall accuracy

**CalexNet-style cascade alignment:**
- Each branch's training matches inference distribution
- Class Precision Margin (CPM) calibration for threshold selection
- Drop-in replacement for any frozen-backbone early-exit cascade

## Threshold Calibration

- Tune thresholds on validation split
- Optimize for: minimize Branch B calls while maintaining >90% sensitivity
- Report: % images in each band, accuracy per band, Branch B utilization rate

```matlab
% Threshold optimization
% Sweep thresholds to find optimal operating point
thresholds_high = linspace(0.8, 0.99, 20);
thresholds_low = linspace(0.1, 0.5, 20);

for i = 1:length(thresholds_high)
    for j = 1:length(thresholds_low)
        % Simulate routing
        clear_pct = sum(conf > thresholds_high(i)) / n;
        review_pct = sum(conf > thresholds_low(j) & conf <= thresholds_high(i)) / n;
        abstain_pct = sum(conf <= thresholds_low(j)) / n;
        
        % Compute accuracy on clear cases
        clear_acc = mean(yPred(conf > thresholds_high(i)) == yTrue(conf > thresholds_high(i)));
        
        % Record metrics
        metrics(i,j) = struct('clear', clear_pct, 'review', review_pct, ...
            'abstain', abstain_pct, 'clear_acc', clear_acc);
    end
end
```

## Cost-Accuracy Tradeoff

**Practical breakeven:** Cascade with 50% cost reduction pays for itself after 2,000 inputs

**Design principles:**
- Use models from the Pareto front of accuracy-compute tradeoff
- Priority is high sensitivity (miss rate = 0% for referable cases)
- Accept more false positives to ensure safety
- 2-model cascades optimal for most medical imaging applications

## Metrics to Report

| Metric | Target |
|--------|--------|
| Clear band % | ~50-60% |
| Clear band accuracy | >95% |
| Review band % | ~30-40% |
| Abstain band % | ~5-10% |
| Branch B utilization | ~30-40% |
| Overall sensitivity | >90% |
| Overall specificity | >85% |
| Compute savings | ~40% |
