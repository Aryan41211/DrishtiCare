# Day 3 — Image Quality Assessment (Sep 4)

## Focus
Image quality assessment module

## Deliverables
- MATLAB function: input raw fundus → output usable/reject + reason
- Blur detection, illumination check, FOV check

## Checklist

### Morning
- [ ] Write `assessImageQuality(img)` function
- [ ] Implement blur detection (Laplacian variance)
- [ ] Implement illumination check (histogram-based)

### Afternoon
- [ ] Implement FOV check (circular mask coverage)
- [ ] Test on 10-15 sample images
- [ ] Verify pass/fail decisions make sense

### Evening
- [ ] Document function signature
- [ ] Save sample outputs
- [ ] Prepare handoff to enhancement team

## MATLAB Implementation

```matlab
function result = assessImageQuality(img)
    % Check blur
    gray = rgb2gray(img);
    laplacian = fspecial('laplacian');
    filtered = imfilter(double(gray), laplacian);
    blurScore = var(filtered(:));
    result.blur = blurScore > 100; % Threshold to tune
    
    % Check brightness
    brightness = mean(gray(:));
    result.brightness = brightness > 40 && brightness < 220;
    
    % Check FOV
    gray3 = double(rgb2gray(img));
    mask = gray3 > 20; % Simple threshold
    result.fov = sum(mask(:)) / numel(mask) > 0.3;
    
    % Overall decision
    result.pass = result.blur && result.brightness && result.fov;
    
    % Reason if rejected
    if ~result.pass
        if ~result.blur, result.reason = 'reject: low contrast/blurry';
        elseif ~result.brightness, result.reason = 'reject: poor illumination';
        else, result.reason = 'reject: small field of view';
        end
    else
        result.reason = 'pass';
    end
end
```

## End of Day Check
- [ ] `assessImageQuality()` working
- [ ] Tested on 10+ images
- [ ] Pass/fail decisions reasonable
- [ ] Ready for Day 4 (enhancement)
