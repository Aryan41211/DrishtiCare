# Module 4 — Explainability

## Purpose

Generate clinically meaningful explanations that enable ophthalmologist validation in under 30 seconds.

## Research Context

**Key findings from literature:**
- Grad-CAM effective but has limitations — heatmaps can be noisy, inconsistent across layers (Springer 2024)
- Incorporating prior knowledge and sophisticated gradient computation improves reliability
- HSQ-VLM (Telang 2026): Spatially-constrained quadrant segmentation achieved 99.6% hemorrhage sensitivity, 96.4% MA sensitivity
- Khokhar et al. (2026): CNN-Transformer ensembles + VLM-generated textual rationales using Grad-CAM++

## Grad-CAM Generation

```matlab
% MATLAB built-in (Deep Learning Toolbox)
% Note: Use dlnetwork objects created via trainnet (newer API)

layerName = 'last_conv_layer'; % Choose final convolutional layer
gradMap = gradCAM(net, image, layerName);

% Also available:
% occlusionSensitivity(net, image)
% imageLIME(net, image)
```

## Grad-CAM Quantification (The Differentiator)

**Everyone will produce Grad-CAM heatmaps. This is what sets you apart:**

```matlab
% 1. Fraction of saliency mass inside annotated lesions
totalSaliency = sum(gradMap(:));
lesionSaliency = sum(gradMap(lesionMask > 0));
fractionInLesions = lesionSaliency / totalSaliency;

% 2. Pointing game: does saliency peak land within a true lesion?
[peakY, peakX] = find(gradMap == max(gradMap(:)));
pointingGame = lesionMask(peakY, peakX) > 0;

% 3. IoU against lesion masks
predictedRegion = gradMap > prctile(gradMap(:), 90); % Top 10%
iou = sum(predictedRegion & lesionMask) / sum(predictedRegion | lesionMask);

% 4. MACE (Mean Absolute Coordinate Error)
% From HSQ-VLM paper: measures localization precision
% Target: <5 pixels in macular zone
```

**Converts:** "The heatmap looks plausible" → "N% of saliency mass falls on clinician-annotated lesions"

## Concept-Based Explanations (TCAV/ACE)

**TCAV (Testing with Concept Activation Vectors):**
- Measures model sensitivity to high-level concepts (e.g., "microaneurysms", "hemorrhages")
- Requires user-defined concepts and counterexamples
- Trains a linear classifier to separate images with/without a concept
- **TCAVQ score:** relative importance of each concept across all prediction classes

**ACE (Automatic Concept-based Explanations):**
- Extends TCAV with automated concept discovery
- Segments images at multiple resolutions → clusters in activation space → TCAV scoring
- No manual concept labeling needed

**For DR specifically:** Concept-based explanations can map to clinical entities (MA, HE, EX, SE, NV) — making model decisions interpretable to ophthalmologists.

## Lesion-Level Evidence Report

```matlab
function report = generate_evidence_report(image, grade, confidence, lesions, quadrantCounts)
    report = struct();
    report.grade = grade;
    report.confidence = confidence;

    % 4-2-1 rule evaluation
    report.hemorrhage_counts = quadrantCounts;
    report.rule_4_satisfied = all(quadrantCounts > 20);
    report.rule_2_satisfied = sum(quadrantCounts > 0) >= 2; % Simplified
    report.level_3_criteria = evaluate_421rule(quadrantCounts);

    % Lesion summary
    report.microaneurysms = lesions.ma_count;
    report.hemorrhages = lesions.he_count;
    report.hard_exudates = lesions.ex_area;
    report.soft_exudates = lesions.se_present;
    report.exudate_distance_fovea = lesions.ex_dist_fovea;

    % DME grading
    report.dme_grade = assign_dme(lesions.ex_dist_fovea, lesions.ex_area);

    % Recommended action
    if grade >= 3
        report.action = 'Urgent referral — within 1 week';
    elseif grade >= 2
        report.action = 'Referral — within 4 weeks';
    elseif grade == 1
        report.action = 'Annual screening';
    else
        report.action = 'No retinopathy — annual screening';
    end
end
```

## Report Template (One Page)

```
┌─────────────────────────────────────────────────────────┐
│  DrishtiCare DR Screening Report                        │
│  Patient ID: XXXXXX | Date: YYYY-MM-DD                  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  [Original Image]    [Lesion Overlay]    [Grad-CAM]     │
│                                                         │
├─────────────────────────────────────────────────────────┤
│  GRADE: 3 — Severe NPDR                                │
│  Confidence: 0.89 (calibrated)                          │
│                                                         │
│  LESION EVIDENCE:                                       │
│  • Hemorrhages: 24/21/8/5 per quadrant                 │
│    → 4-2-1 haemorrhage criterion: SATISFIED (2 quads)  │
│  • Microaneurysms: 47 detected                         │
│  • Hard exudates: 1.2 DD from fovea — DME grade 1      │
│  • Soft exudates: present                              │
│                                                         │
│  ATTENTION OVERLAY:                                     │
│  • 73% of saliency mass on annotated lesions           │
│  • Pointing game: PASS (peak on lesion)                │
│  • IoU vs lesion masks: 0.42                           │
│                                                         │
│  RECOMMENDED ACTION: Refer within 4 weeks              │
│  FOLLOW-UP: 3 months post-treatment                    │
├─────────────────────────────────────────────────────────┤
│  System: DrishtiCare v1.0 | Model: Ensemble-EffB4+RN50 │
│  Quality: Gradeable | Enhancement: Applied              │
└─────────────────────────────────────────────────────────┘
```

## 30-Second Review Validation

**Empirical validation:**
1. Find 2-3 ophthalmologists (local eye hospital)
2. Give them 20 generated reports
3. Time each review with stopwatch
4. Collect Likert rating of clinical usefulness

**Claim:** "Ophthalmologist median review time: X seconds (IQR: Y-Z)"

Even a tiny study like this produces a measured number for a claim the PS makes explicitly.

## Quantification Metrics to Report

| Metric | What It Measures | Target |
|--------|-----------------|--------|
| Saliency-in-lesion fraction | How much attention falls on real lesions | >60% |
| Pointing game accuracy | Does peak attention land on a lesion? | >70% |
| IoU vs lesion masks | Spatial overlap between attention and lesions | >0.3 |
| MACE | Localization precision in pixels | <10 px |
| Clinician Likert rating | Perceived clinical usefulness | >4/5 |
| TCAVQ score | Concept importance for each grade | Report per concept |
| Faithfulness | Does explanation reflect actual model decision? | Report |
| Consistency | Do similar inputs produce similar explanations? | Report |

## Explainability Methods Comparison

| Method | Type | Pros | Cons |
|--------|------|------|------|
| Grad-CAM | Visual heatmap | Easy to implement, fast | Noisy, inconsistent |
| Grad-CAM++ | Visual heatmap | Better multi-object localization | Still visual only |
| TCAV | Concept-based | Maps to clinical entities | Requires concept definitions |
| ACE | Concept-based | Automated concept discovery | High computational cost |
| LIME | Local explanation | Model-agnostic | Slow, unstable |
| LRP | Pixel-level decomposition | Fine-grained | Complex implementation |
| VLM rationales | Textual explanation | Clinician-friendly | Requires VLM integration |

## Clinical Explanation Format

Reports should read like clinical reasoning:
> *"Grade 3 — Severe NPDR. Hemorrhages: 24/21/8/5 per quadrant — satisfies 4-2-1 in 2 quadrants. Microaneurysms: 47. Hard exudates 1.2 disc diameters from fovea — DME grade 1. Confidence 0.89. Recommend referral within 4 weeks."*

This is what makes 30-second ophthalmologist review possible — expressed in the criteria they already carry.
