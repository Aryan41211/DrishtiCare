# Module: DR Severity Grading

## Purpose
Classify fundus images into ICDR grades 0-4.

## Approach
- Transfer learning (not from scratch)
- Pretrained ResNet-18 or ResNet-50
- Train on APTOS 2019

## Model Architecture

```
Input (224x224x3) → ResNet-18 (pretrained) → FC(512→5) → Softmax → Grade (0-4)
```

## Training Configuration

| Parameter | Value |
|-----------|-------|
| Model | ResNet-18 (recommended for speed) |
| Dataset | APTOS 2019 |
| Split | 80/20 train/validation |
| Batch size | 32 |
| Epochs | 10-20 |
| Learning rate | 0.001 (default Adam) |
| Augmentation | Rotation, flip, brightness, translation |

## Evaluation Metrics

### Binary: Referable vs Non-Referable
- **Referable:** Grade ≥ 2
- **Non-referable:** Grade < 2

```matlab
isReferable = trueLabels >= 2;
predReferable = predictedLabels >= 2;

sensitivity = sum(predReferable & isReferable) / sum(isReferable);
specificity = sum(~predReferable & ~isReferable) / sum(~isReferable);
```

### Multi-class: Grade 0-4
- Overall accuracy
- Per-class recall
- Confusion matrix

## Honest Reporting

| Metric | Target | Report Your Number |
|--------|--------|-------------------|
| Sensitivity (≥2) | >90% | __% |
| Specificity (≥2) | >85% | __% |
| Accuracy (5-class) | - | __% |

## Common Issues

| Issue | Solution |
|-------|----------|
| Training too slow | Use ResNet-18, not 50. Or use Python/Colab |
| Overfitting | Add more augmentation, reduce epochs |
| Class imbalance | Use class weights or oversampling |
| Low accuracy | Check data quality, try different model |

## References
- Section 6.3 of 10-day roadmap
- PS requirement: ">90% sensitivity, >85% specificity"
