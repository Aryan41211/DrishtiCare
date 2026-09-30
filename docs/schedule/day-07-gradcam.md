# Day 7 — Grad-CAM Explainability (Sep 8)

## Focus
Grad-CAM explainability

## Deliverables
- `gradCAM()` implemented producing heatmap overlays
- At least 10 test images with overlays saved

## Checklist

### Morning
- [ ] Write Grad-CAM script
- [ ] Test on single image
- [ ] Verify heatmap highlights meaningful regions

### Afternoon
- [ ] Run on batch of 10+ test images
- [ ] Save outputs with labels
- [ ] Identify best examples for pitch

### Evening
- [ ] Create side-by-side comparisons
- [ ] Select 5-8 best examples for demo
- [ ] Prepare for Day 8 (Simulink)

## MATLAB Implementation

```matlab
% Load trained network
load('dr_classifier.mat');

% Get convolutional layer name
layerName = 'conv5_3'; % Check with net.Layers

% Run Grad-CAM on test images
figure;
for i = 1:10
    img = readimage(testDS, i);
    trueLabel = testDS.Labels(i);
    
    % Generate Grad-CAM
    scores = gradCAM(net, img, layerName);
    
    % Get predicted class
    [predLabel, score] = classify(net, img);
    
    % Overlay heatmap
    subplot(2, 5, i);
    imshow(img);
    hold on;
    imagesc(scores(:,:,double(predLabel)), 'AlphaData', 0.5);
    colormap jet;
    title(sprintf('Pred: %s (%.1f%%)\nTrue: %s', ...
        string(predLabel), score*100, string(trueLabel)));
    hold off;
end
sgtitle('Grad-CAM Explanations');
saveas(gcf, 'gradcam_results.png');
```

## Grad-CAM Tips

- If heatmap is scattered, try different layers
- `conv5_3` or last conv layer usually works best
- Heatmap should highlight lesions (bright spots, dark areas)
- If heatmap is blank, check if layer name is correct

## End of Day Check
- [ ] Grad-CAM working
- [ ] 10+ images with overlays saved
- [ ] Heatmaps look sensible
- [ ] Best examples selected for pitch
- [ ] Ready for Day 8 (Simulink)
