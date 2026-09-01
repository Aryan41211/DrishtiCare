# Module 0 — Out-of-Distribution Detection

## Purpose

Catch fundus images from unseen camera types or different populations before they reach the classifier. Prevents confident-but-wrong predictions on unfamiliar data.

## Research Context

**Key findings from literature:**
- Mahalanobis OOD (UNSURE/MICCAI 2023, Best Paper): Multi-branch detection at different network depths
- Mahalanobis++ (Müller & Hein, 2025): Feature normalization for better separation
- X-Mahalanobis (NeurIPS 2025): Transformer feature mixing for reliable detection
- Energy-Based OOD (Liu et al., NeurIPS 2020): 18.03% reduction in FPR vs softmax confidence
- Medical imaging OOD is diverse: artifacts, different camera systems, different populations

## Architecture

```
Enhanced Image → Feature Extraction → Mahalanobis Distance → Threshold → In-distribution / OOD
                         ↓
              Energy Score (secondary detector)
```

## Method: Multi-Branch Mahalanobis Distance

1. Extract deep features from **multiple network depths** (not just penultimate)
2. Compute class-conditional Gaussian statistics on training features
3. For new image: compute Mahalanobis distance at each depth
4. Combine distances (weighted average or max)
5. If combined distance > threshold → OOD → route to human review

**Why multi-branch:**
- Different anomalies manifest at different feature levels
- Shallow features: camera artifacts, illumination issues
- Deep features: semantic anomalies, unusual pathologies
- Best Paper at UNSURE/MICCAI 2023 demonstrated this approach

## Implementation

```matlab
% During training: fit class-conditional Gaussians at multiple depths
layers = {'conv3', 'conv4', 'conv5', 'penultimate'};
features = cell(length(layers), 1);
for i = 1:length(layers)
    features{i} = activations(net, XTrain, layers{i});
end

% Fit Gaussians per layer
mu = cell(length(layers), numClasses);
sigma = cell(length(layers), numClasses);
for i = 1:length(layers)
    for c = 1:numClasses
        mu{i,c} = mean(features{i}(:, yTrain == c), 2);
        sigma{i,c} = cov(features{i}(:, yTrain == c)');
    end
end

% During inference: compute distance at each depth
distances = zeros(length(layers), numClasses);
for i = 1:length(layers)
    feat = activations(net, image, layers{i});
    for c = 1:numClasses
        distances(i,c) = (feat-mu{i,c})' * inv(sigma{i,c}) * (feat-mu{i,c});
    end
end

% Combine distances (weighted by layer importance)
weights = [0.1, 0.2, 0.3, 0.4]; % Deeper layers weighted more
minDistPerLayer = min(distances, [], 2);
combinedDist = weights * minDistPerLayer;
isOOD = combinedDist > threshold;
```

## Secondary Detector: Energy Score

```matlab
% Energy score: E(x) = -log Σ_k exp(f_k(x))
% Low energy for in-distribution, high energy for OOD
logits = forward(net, image, 'OutputMode', 'logits');
energy = -log(sum(exp(logits)));

% Can also use as trainable cost function
% Liu et al. (NeurIPS 2020): 18.03% reduction in FPR vs softmax confidence
```

**Advantages over softmax:**
- Not susceptible to overconfidence
- Works with any pre-trained classifier
- Parameter-free scoring function

## Why Mahalanobis Over Alternatives

| Method | Pros | Cons |
|--------|------|------|
| Mahalanobis | Parameter-free after fitting, works with limited OOD | Assumes Gaussian distribution |
| Energy Score | Works with any classifier, parameter-free | Requires temperature tuning for optimal |
| ODIN | Good separation | Requires input perturbation |
| Softmax Confidence | Simple | Overconfident on OOD |
| Mahalanobis++ | Better separation via normalization | More complex implementation |

## Threshold Selection

- Choose threshold to achieve 95% TPR on in-distribution validation set
- Report OOD detection AUROC on held-out OOD dataset
- Available OOD sources: different camera types, non-retinal images

```matlab
% Threshold calibration
% Sweep thresholds to find 95% TPR point
thresholds = linspace(0, max(combinedDist), 100);
for i = 1:length(thresholds)
    tpr(i) = sum(combinedDist(inDist) <= thresholds(i)) / sum(inDist);
    fpr(i) = sum(combinedDist(~inDist) <= thresholds(i)) / sum(~inDist);
end
% Find threshold where TPR >= 0.95
idx = find(tpr >= 0.95, 1);
optimalThreshold = thresholds(idx);
```

## Synthetic OOD Generation

For calibration when real OOD data is unavailable:
- Generate pseudo-Outliers for training OOD detectors (Springer 2025)
- Methods: random noise, adversarial examples, style transfer from non-retinal domains
- Use for threshold calibration only, not for final evaluation

## Routing

- **In-distribution:** Proceed to cascade router
- **OOD:** Route to human review with reason code "unfamiliar image type — cannot guarantee accuracy"

## Cost

- Near-zero at inference (single forward pass + distance computation)
- Amortized by skipping Branch B on OOD cases
- Multi-branch adds minimal overhead (~10% vs single-branch)
