# MATLAB Toolbox Guide

## Required Toolboxes (from PS)

| Toolbox | What It Does in This Project |
|---------|------------------------------|
| **Image Processing Toolbox** | `adapthisteq` (CLAHE), `imnlmfilt` (denoising), morphological operations, thresholding |
| **Computer Vision Toolbox** | Feature extraction, Hough transform (OD detection), connected components |
| **Deep Learning Toolbox** | `trainnet`, `dlnetwork`, `gradCAM`, `occlusionSensitivity`, `imageLIME` |
| **Medical Imaging Toolbox** | DICOM handling, specialized filters (check what adds value for 2D fundus) |
| **Statistics & ML Toolbox** | Temperature scaling, isotonic regression, gradient-boosted trees, SVM, calibration metrics |
| **Simulink** | Workflow simulation, queueing model |
| **SimEvents** (separate license) | Discrete-event simulation for queueing — check campus license |

## License Verification

Run in MATLAB:
```matlab
ver  % Lists all installed toolboxes
license('test', 'Image_Toolbox')
license('test', 'Computer_Vision_Toolbox')
license('test', 'Deep_Learning_Toolbox')
license('test', 'Statistics_Toolbox')
license('test', 'Simulink')
```

## Key Functions by Module

### Module 1 — Quality & Enhancement
```matlab
adapthisteq(green_channel)          % CLAHE
imnlmfilt(img)                      % Non-local means denoising
medfilt2(img, [N N])                % Median filtering
imgradientxy(img)                   % Tenengrad gradient
std2(img)                           % Focus measure
entropy(img)                        % Illumination measure
```

### Module 2 — Segmentation
```matlab
imfindcircles(img, [R1 R2], 'ObjectPolarity', 'bright')  % OD detection
bwmorph(vessels, 'thin')            % Vessel thinning
bwboundaries(mask)                  % Contour extraction
regionprops(mask, 'all')            % Region properties
imopen / imclose                   % Morphological operations
```

### Module 3 — Grading
```matlab
trainnet(layers, XTrain, YTrain, lossFcn, options)  % New API (preferred)
dlnetwork(layerGraph)                                % For gradCAM
classify(net, XTest)                                 % Inference
fitcensemble(X, Y, 'Method', 'Bag')                 % Gradient-boosted trees
```

### Module 4 — Explainability
```matlab
gradCAM(net, image, layerName)       % Grad-CAM heatmap
occlusionSensitivity(net, image)     % Occlusion sensitivity
imageLIME(net, image)                % LIME explanation
```

### Module 5 — Calibration
```matlab
fitctree(X, Y)                       % For temperature scaling
kfoldLoss(crossvalmdl)               % Cross-validation loss
confusionmat(yTrue, yPred)           % Confusion matrix
```

## API Notes

- Newer MATLAB versions recommend `trainnet` over `trainNetwork`
- `dlnetwork` objects work with `gradCAM`, not older `DAGNetwork`
- Verify exact syntax against your installed release
- `importNetworkFromONNX` available for external pretrained weights

## GPU Requirements

- Training: GPU strongly recommended (CUDA-capable)
- Inference: CPU works but slower
- Confirm GPU availability: `gpuDeviceCount` in MATLAB

## Simulink Notes

- SimEvents is **separately licensed** — check campus license
- Without SimEvents: use Stateflow + discrete blocks to approximate queueing
- Base Simulink is sufficient for time-based simulation
