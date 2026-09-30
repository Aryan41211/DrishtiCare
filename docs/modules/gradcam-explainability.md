# Module: Grad-CAM Explainability

## Purpose
Generate heatmap overlays showing which regions drove the classification decision.

## Function

```matlab
scores = gradCAM(net, img, layerName)
```

## Parameters

| Parameter | Description | Recommended Value |
|-----------|-------------|-------------------|
| net | Trained network | Your ResNet-18 |
| img | Input image | 224x224x3 |
| layerName | Conv layer for gradients | 'conv5_3' or last conv layer |

## Implementation

```matlab
% Load trained model
load('dr_classifier.mat');

% Get layer name (check with: net.Layers)
layerName = 'conv5_3';

% Generate Grad-CAM
img = readimage(testDS, 1);
scores = gradCAM(net, img, layerName);

% Get predicted class
[predLabel, score] = classify(net, img);

% Overlay heatmap
figure;
imshow(img);
hold on;
imagesc(scores(:,:,double(predLabel)), 'AlphaData', 0.5);
colormap jet;
title(sprintf('Grade: %s (%.1f%%)', string(predLabel), score*100));
hold off;
```

## Tips

- If heatmap is scattered, try different layers
- Last convolutional layer usually works best
- Heatmap should highlight lesions (bright spots, dark areas)
- If heatmap is blank, check layer name is correct

## Batch Processing

```matlab
% Run on multiple images
for i = 1:10
    img = readimage(testDS, i);
    scores = gradCAM(net, img, layerName);
    % Save or display...
end
```

## Output for Pitch

Save 8-10 strong examples:
- Correct predictions
- Sensible heatmaps
- Clear lesion highlighting

These are the **most visually persuasive artifact** for judges.

## References
- Section 6.4 of 10-day roadmap
- PS requirement: "Grad-CAM explainability"
