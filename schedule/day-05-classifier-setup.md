# Day 5 — Classifier Setup (Sep 6)

## Focus
Classifier setup — transfer learning start

## Deliverables
- Pretrained CNN selected (ResNet-18 or ResNet-50)
- Training pipeline set up in MATLAB or Python

## Checklist

### Morning
- [ ] Choose pretrained model (ResNet-18 recommended for speed)
- [ ] Set up training pipeline
- [ ] Configure data augmentation

### Afternoon
- [ ] Split APTOS into train/validation (80/20)
- [ ] Set up folder-per-class datastore
- [ ] Configure training options

### Evening
- [ ] Start training (or plan to start Day 6)
- [ ] Verify training starts without errors
- [ ] Monitor first few iterations

## MATLAB Setup

```matlab
% Load pretrained ResNet-18
net = resnet18;
lgraph = layerGraph(net);

% Replace final layer for 5 classes
numClasses = 5;
lgraph = replaceLayer(lgraph, 'fc1000', ...
    fullyConnectedLayer(numClasses, 'Name', 'fc_dr'));
lgraph = replaceLayer(lgraph, 'ClassificationLayer_predictions', ...
    classificationLayer('Name', 'output'));

% Data augmentation
augmenter = imageDataAugmenter(...
    'RandRotation', [-20, 20], ...
    'RandXReflection', true, ...
    'RandBrightness', [0.8 1.2], ...
    'RandXTranslation', [-10 10], ...
    'RandYTranslation', [-10 10]);

% Training options
options = trainingOptions('adam', ...
    'MaxEpochs', 10, ...
    'MiniBatchSize', 32, ...
    'ValidationData', valDS, ...
    'ValidationFrequency', 50, ...
    'Plots', 'training-progress', ...
    'ExecutionEnvironment', 'auto');
```

## Python Fallback (if MATLAB too slow)

```python
import torch
import torchvision.models as models
import torchvision.transforms as transforms

# Load pretrained ResNet-18
model = models.resnet18(pretrained=True)
model.fc = torch.nn.Linear(512, 5)  # 5 DR classes

# Train on Colab with free GPU
# Export to ONNX after training
torch.onnx.export(model, dummy_input, "dr_classifier.onnx")
```

## End of Day Check
- [ ] Model architecture ready
- [ ] Data pipeline configured
- [ ] Training started or ready to start
- [ ] Ready for Day 6 (training + results)
