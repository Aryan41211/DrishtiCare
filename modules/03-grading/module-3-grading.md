# Module 3 — DR Severity Grading

## Architecture: Dual-Branch Fusion

### Branch A — Deep Classifier

**Architecture:** EfficientNet-B4 (primary), pretrained ImageNet → EyePACS → APTOS

**Research context:**
- Well-designed CNNs with attention still compete with ViT on small datasets (arXiv 2608.28207, Aug 2026)
- Consider RETFound as pretrained backbone (1.6M unlabeled retinal images, Nature 2023)
- AADR-AI: CNN-Transformer ensemble achieved 96.7% accuracy (Nature Sci Rep, 2025)
- STMFNet: Spatial texture multi-scale fusion achieved 98.10% accuracy (Frontiers in Medicine, 2026)

**Output head:** Ordinal binary decomposition
```matlab
% NOT plain 5-way softmax
% 4 sigmoid outputs: P(grade>=1), P(grade>=2), P(grade>=3), P(grade>=4)
% P(grade>=2) is the direct referable-DR probability

layers = [
    imageInputLayer([224 224 3])
    % ... backbone layers ...
    globalAveragePooling2dLayer
    fullyConnectedLayer(4)
    sigmoidLayer  % 4 independent sigmoids
];
```

**Why ordinal, not softmax:**
- ICDR grades are ordinal — mistaking 0 for 4 is worse than 2 for 3
- P(grade≥2) is directly the referable-DR probability
- Respects the ordering structure of the clinical scale

**Class imbalance handling:**
- APTOS skews heavily toward grade 0 (1,805/3,662)
- Grades 1 and 3 are comparatively rare
- Use class-balanced sampling or focal loss
- Always report per-class metrics

### Branch B — Lesion-Feature Model

**Input:** Structured feature vector from Module 2
```
[ma_count, he_count_per_quad, ex_area, ex_dist_fovea, se_present, vessel_features]
```

**Model:** Gradient-boosted trees or SVM
```matlab
mdl = fitcensemble(X_features, Y_grade, 'Method', 'Bag', ...
    'NumLearningCycles', 100);
```

**Interpretable by construction** — can be checked directly against written ICDR criteria.

### Fusion

```matlab
% Option 1: Logistic regression over concatenated outputs
fusedInput = [branchA_scores(:); branchB_grade];
finalGrade = predict(fusionModel, fusedInput);

% Option 2: Rule-based consistency check
if branchA_grade == branchB_grade
    finalGrade = branchA_grade;
elseif abs(branchA_grade - branchB_grade) > 1
    flag_for_review = true;
    finalGrade = max(branchA_grade, branchB_grade); % Conservative
end
```

## Calibration Layer

**Constrained Temperature Scaling** — focus calibration on the referable boundary

```matlab
% Standard temperature scaling
% Find T that minimizes NLL on validation set
T = fminbnd(@(t) nll(softmax(logits/t), labels), 0.1, 10);

% Constrained: only calibrate where decision boundaries lie
% For referable DR: focus on predictions where P(grade>=2) is near 0.5
criticalMask = abs(calibratedScores - 0.5) < 0.2;
T_constrained = fminbnd(@(t) nll(softmax(logits(criticalMask)/t), ...
    labels(criticalMask)), 0.1, 10);
```

**Metrics to report:**
- Expected Calibration Error (ECE) — target: <0.05
- Brier score — target: <0.15
- Reliability diagram before/after calibration

## Threshold Selection

After calibration, choose operating threshold on ROC curve:
- Target: ≥90% sensitivity AND ≥85% specificity for referable DR (≥2)
- Report bootstrap 95% confidence intervals
- Point estimate of 91% on small test set is NOT evidence of clearing 90% bar

```matlab
% Bootstrap CIs
for b = 1:1000
    idx = randperm(n, n);
    [sens(b), spec(b)] = compute_sens_spec(yTrue(idx), yPred(idx), threshold);
end
ci_sens = prctile(sens, [2.5 97.5]);
ci_spec = prctile(spec, [2.5 97.5]);
```

## Test-Time Augmentation (Free Accuracy)

```matlab
% Average predictions over augmented versions
augmentations = [original, fliplr, rot90, rot180, rot270];
scores = zeros(numAugmentations, numClasses);
for i = 1:numAugmentations
    [~, scores(i,:)] = classify(net, augmentations{i});
end
finalScores = mean(scores, 1);
```

## Selective Prediction / Abstention

```matlab
% Define abstention band
uncertain = calibratedScores > 0.35 & calibratedScores < 0.92;
abstain = calibratedScores < 0.35;

% Report accuracy vs coverage curve
coverages = 0.8:0.05:1.0;
for c = coverages
    threshold = prctile(calibratedScores, (1-c)*100);
    mask = calibratedScores >= threshold;
    accuracy(c) = sum(yPred(mask) == yTrue(mask)) / sum(mask);
end
```

## ICDR Grading Standards

| Grade | Description | ETDRS Levels | 1-Year PDR Risk | Follow-up |
|-------|-------------|--------------|-----------------|-----------|
| 0 | No apparent retinopathy | Level 10 | <1% | Annual screening |
| 1 | Mild NPDR | Level 20 | <1% | Annual screening |
| 2 | Moderate NPDR | Levels 35, 43, 47 | ~5% | 6-12 month follow-up |
| 3 | Severe NPDR | Level 53 | ~15-20% | 3-6 month follow-up; consider referral |
| 4 | PDR | Levels 60-85 | Immediate vision threat | Urgent referral; laser/anti-VEGF treatment |

**ICDR was developed** via international consensus (2002, modified Delphi with 14 experts from 11 countries) from ETDRS and WESDR data. Deliberately simplified for global clinical use.

## Lesion-Level vs Global Grading

**Global (image-level) grading:**
- Train classifier on whole image → output grade
- Simpler annotation; limited to specific grading scheme
- Requires retraining for each new grading standard

**Feature-based (lesion-level) grading:**
- Detect individual lesions: MA, HE, EX, SE, IRMA, NV
- Grade from detected features using rule-based system
- **Advantage:** Adaptable to any grading scheme without retraining (ICDR, UK NSC, ETDRS)
- DAPHNE system (2021): QWK 0.85 on Kenya dataset; 92% sensitivity for referable DR
- More annotation-intensive for training
