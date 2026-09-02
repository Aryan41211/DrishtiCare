# Day 6 — Classifier Training (Sep 7)

## Focus
Classifier training + first results

## Deliverables
- First trained DR severity classifier (0-4)
- Initial accuracy/sensitivity/specificity numbers recorded honestly

## Checklist

### Morning
- [ ] Continue training (if started Day 5)
- [ ] Monitor training progress
- [ ] Check for overfitting

### Afternoon
- [ ] Evaluate on validation set
- [ ] Compute accuracy, sensitivity, specificity
- [ ] Record numbers honestly

### Evening
- [ ] Save trained model
- [ ] Document results
- [ ] Identify best/worst cases

## Evaluation Code

```matlab
% Load trained model
load('dr_classifier.mat');

% Evaluate on test set
[predictedLabels, scores] = classify(net, testDS);
trueLabels = testDS.Labels;

% Overall accuracy
accuracy = sum(predictedLabels == trueLabels) / numel(trueLabels);
fprintf('Accuracy: %.2f%%\n', accuracy * 100);

% Binary: referable (>=2) vs non-referable (<2)
isReferable = trueLabels >= 2;
predReferable = predictedLabels >= 2;

% Sensitivity (true positive rate)
sensitivity = sum(predReferable & isReferable) / sum(isReferable);
fprintf('Sensitivity: %.2f%%\n', sensitivity * 100);

% Specificity (true negative rate)
specificity = sum(~predReferable & ~isReferable) / sum(~isReferable);
fprintf('Specificity: %.2f%%\n', specificity * 100);

% Confusion matrix
figure;
confusionchart(trueLabels, predictedLabels);
title('DR Severity Classification');
```

## Honest Reporting

| Metric | Your Number | PS Target | Literature |
|--------|------------|-----------|------------|
| Accuracy | __% | - | - |
| Sensitivity (≥2) | __% | >90% | 96.1% |
| Specificity (≥2) | __% | >85% | 93.9% |

**Remember:** Honest numbers + improvement plan > suspiciously perfect metrics

## End of Day Check
- [ ] Model trained
- [ ] Numbers recorded
- [ ] Model saved
- [ ] Ready for Day 7 (Grad-CAM)
