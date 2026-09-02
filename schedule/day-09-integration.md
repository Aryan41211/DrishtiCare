# Day 9 — Integration (Sep 10)

## Focus
Integration + auto-report mockup

## Deliverables
- End-to-end demo flow working
- Auto-generated report mockup

## Checklist

### Morning
- [ ] Wire all modules together
- [ ] Test end-to-end pipeline
- [ ] Fix integration issues

### Afternoon
- [ ] Build report generation
- [ ] Test report output
- [ ] Verify report is readable

### Evening
- [ ] Full demo run-through
- [ ] Record backup video
- [ ] Prepare for Day 10 (pitch)

## End-to-End Pipeline

```matlab
function report = runPipeline(imagePath)
    % 1. Load image
    img = imread(imagePath);
    
    % 2. Quality assessment
    quality = assessImageQuality(img);
    if ~quality.pass
        report.status = 'rejected';
        report.reason = quality.reason;
        return;
    end
    
    % 3. Enhancement
    enhanced = enhanceImage(img);
    
    % 4. Classification
    [predLabel, scores] = classify(drClassifier, enhanced);
    
    % 5. Grad-CAM
    gradMap = gradCAM(drClassifier, enhanced, 'conv5_3');
    
    % 6. Generate report
    report.status = 'complete';
    report.grade = predLabel;
    report.confidence = max(scores);
    report.isReferable = double(predLabel) >= 2;
    report.gradCAM = gradMap;
    report.originalImage = img;
    report.enhancedImage = enhanced;
end
```

## Report Mockup

```matlab
function generateReport(report, outputPath)
    figure('Position', [100 100 800 600]);
    
    % Original image
    subplot(2,2,1);
    imshow(report.originalImage);
    title('Original');
    
    % Enhanced image
    subplot(2,2,2);
    imshow(report.enhancedImage);
    title('Enhanced');
    
    % Grad-CAM overlay
    subplot(2,2,3);
    imshow(report.originalImage);
    hold on;
    imagesc(report.gradCAM(:,:,double(report.grade)), 'AlphaData', 0.5);
    colormap jet;
    title('Grad-CAM');
    hold off;
    
    % Results text
    subplot(2,2,4);
    axis off;
    text(0.1, 0.8, sprintf('Grade: %s', string(report.grade)), 'FontSize', 16);
    text(0.1, 0.6, sprintf('Confidence: %.1f%%', report.confidence*100), 'FontSize', 14);
    text(0.1, 0.4, sprintf('Referable: %s', string(report.isReferable)), 'FontSize', 14);
    if report.isReferable
        text(0.1, 0.2, 'ACTION: Refer to specialist', 'FontSize', 12, 'Color', 'red');
    else
        text(0.1, 0.2, 'ACTION: Annual screening', 'FontSize', 12, 'Color', 'green');
    end
    
    saveas(gcf, outputPath);
end
```

## End of Day Check
- [ ] End-to-end pipeline working
- [ ] Report generation working
- [ ] Demo run-through successful
- [ ] Backup video recorded
- [ ] Ready for Day 10 (pitch)
