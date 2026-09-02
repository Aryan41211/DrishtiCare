# Module: Segmentation (Simplified Scope)

## Purpose
Localize optic disc and basic vessel segmentation.

## Scope for Internal Round

Full segmentation (MA, HE, EX, SE, NV) is **not realistic in 10 days**. Implement only:

1. **Optic Disc Localization** — Brightest large circular region
2. **Basic Vessel Segmentation** — Morphological top-hat filtering

Everything else is **roadmap item**.

## Optic Disc Localization

```matlab
function [center, radius] = localizeOpticDisc(img)
    % Convert to grayscale
    gray = rgb2gray(img);
    
    % Threshold bright regions
    bright = gray > 200;
    
    % Find largest connected component
    stats = regionprops(bright, 'Area', 'Centroid', 'EquivDiameter');
    [~, idx] = max([stats.Area]);
    
    center = stats(idx).Centroid;
    radius = stats(idx).EquivDiameter / 2;
end
```

## Basic Vessel Segmentation

```matlab
function vesselMask = segmentVessels(img)
    % Extract green channel
    green = img(:,:,2);
    
    % Top-hat filtering
    se = strel('disk', 15);
    tophat = imtophat(green, se);
    
    % Threshold
    vesselMask = tophat > 30;
    
    % Clean up
    vesselMask = bwareaopen(vesselMask, 50);
end
```

## What NOT to Implement Now

| Structure | Why Skip |
|-----------|----------|
| Microaneurysms | Too small, needs specialized model |
| Hemorrhages | Overlaps with MA, complex |
| Hard exudates | Needs distance-to-fovea calculation |
| Soft exudates | Rare, hard to detect |
| Neovascularization | No public dataset available |

## Roadmap Items

These are **future work**, not internal round deliverables.

## References
- Section 6.2 of 10-day roadmap
- PS requirement mentions full segmentation, but realistic scope is limited
