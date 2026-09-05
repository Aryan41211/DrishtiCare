# DrishtiCare Day 5 — Classifier Setup

## 1. Overview

Day 5 implements the **Classifier Setup** — preparation of data and model architecture for DR severity classification. The module uses ResNet-18 (untrained weights due to missing support package) with staged fine-tuning and prepares the APTOS dataset with stratified train/validation split.

**IMPORTANT: This is an ENGINEERING classifier setup, NOT a clinical diagnostic system. The model must be validated before clinical use.**

## 2. Module Files

| File | Purpose |
|------|---------|
| `defaultTrainingConfig.m` | Centralized configuration (single source of truth) |
| `prepareData.m` | Split APTOS dataset into train/validation datastores |
| `setupClassifier.m` | Load ResNet-18 architecture and replace final layers |
| `trainClassifier.m` | Training pipeline with staged fine-tuning |
| `run_day5.m` | Master script (verify/setup/train modes) |

## 3. Centralized Configuration

### 3.1 defaultTrainingConfig.m

All Day 5 parameters are centralized in `defaultTrainingConfig.m`:

```matlab
config = defaultTrainingConfig();
config.experimentId = 'day5_resnet18_baseline';
config.model.name = 'resnet18';
config.model.usePretrained = false;  % Set true when support package installed
config.split.splitRatio = 0.8;
config.input.imageSize = [224, 224, 3];
config.classes.numClasses = 5;
config.classes.names = {'NoDR', 'Mild', 'Moderate', 'Severe', 'Proliferative'};
config.classes.referable = [2, 3, 4];
```

### 3.2 Staged Fine-Tuning

**Stage 1:** Backbone frozen, train head only
- `freezeBackbone = true`, `freezeLayers = 60`
- `maxEpochs = 10`, `learningRate = 1e-3`

**Stage 2:** Backbone unfrozen, low-LR fine-tuning
- `freezeBackbone = false`
- `maxEpochs = 20`, `learningRate = 1e-5`

## 4. Data Preparation

### 4.1 Stratified Split

**Method:**
- 80/20 train/validation split
- Stratified by DR class to maintain class distribution
- Random seed = 42 for reproducibility

**Class Distribution:**
| Class | Description | Train | Val | Total |
|-------|-------------|-------|-----|-------|
| 0 | No DR | 1,444 | 361 | 1,805 |
| 1 | Mild | 296 | 74 | 370 |
| 2 | Moderate | 799 | 200 | 999 |
| 3 | Severe | 154 | 39 | 193 |
| 4 | Proliferative | 236 | 59 | 295 |

### 4.2 Test Set Protection

- Test directory (`data/aptos2019/test_images`) verified
- 1,928 test images excluded from split
- Overlap check prevents data contamination

### 4.3 Folder-per-Class Structure

```
data/splits/
├── train/
│   ├── class_0/    (1,444 images)
│   ├── class_1/    (296 images)
│   ├── class_2/    (799 images)
│   ├── class_3/    (154 images)
│   └── class_4/    (236 images)
└── val/
    ├── class_0/    (361 images)
    ├── class_1/    (74 images)
    ├── class_2/    (200 images)
    ├── class_3/    (39 images)
    └── class_4/    (59 images)
```

### 4.4 Class Weights

**Computed for imbalanced data:**
```
NoDR:          0.216
Mild:          1.052
Moderate:      0.390
Severe:        2.022
Proliferative: 1.320
```

**Formula:** `weight = totalSamples / (numClasses * classSamples)`

## 5. Classifier Architecture

### 5.1 Model Selection

**Primary: ResNet-18**
- Input: 224×224×3 RGB images
- Feature size: 512
- Layers: 71
- Connections: 78

**Note:** Due to missing support package, using untrained architecture with random weights. This is equivalent to training from scratch but with ResNet-18 architecture.

### 5.2 Final Layer Replacement

**Original ResNet-18:**
```
fc1000 (FullyConnected, 512 → 1000)
ClassificationLayer_predictions
```

**Modified for DR Classification:**
```
fc_dr (FullyConnected, 512 → 5)
output (ClassificationOutput)
```

### 5.3 Architecture Summary

```
Input (224×224×3)
    ↓
Conv1 + BN + ReLU + MaxPool
    ↓
Layer1 (BasicBlock × 2)
    ↓
Layer2 (BasicBlock × 2)
    ↓
Layer3 (BasicBlock × 2)
    ↓
Layer4 (BasicBlock × 2)
    ↓
Global Average Pooling
    ↓
fc_dr (512 → 5)
    ↓
Softmax
    ↓
Classification Output
```

## 6. Data Augmentation

**Configuration:**
```matlab
augmenter = imageDataAugmenter(...
    'RandRotation', [-15, 15], ...
    'RandXReflection', true, ...
    'RandBrightness', [0.9 1.1], ...
    'RandContrast', [0.9 1.1], ...
    'RandXTranslation', [-10 10], ...
    'RandYTranslation', [-10 10], ...
    'RandXShear', [-5 5], ...
    'RandYShear', [-5 5]);
```

**Purpose:** Increase training data diversity and reduce overfitting.

## 7. Training Configuration

**Stage 1 (Backbone Frozen):**
- Optimizer: Adam
- Initial learning rate: 1e-3
- Max epochs: 10
- Mini-batch size: 32

**Stage 2 (Backbone Unfrozen):**
- Optimizer: Adam
- Initial learning rate: 1e-5
- Max epochs: 20
- Mini-batch size: 16

**Common:**
- Learning rate schedule: Piecewise decay
- Drop period: 5 epochs
- Drop factor: 0.5
- Validation patience: 5 (early stopping)
- Execution: Auto (CPU/GPU detection)

## 8. Usage

### Verify Setup (No Training)
```matlab
cd('C:\projects\DrishtiCare')
addpath('src', 'src/setup', 'src/quality', 'src/enhancement', 'src/grading');

run_day5('verify');
```

**Tests run:**
1. Data preparation (split, no leakage)
2. Classifier setup (architecture, layer replacement)
3. Forward pass (dlnetwork predict, NaN/Inf check)

### Setup Data and Classifier
```matlab
run_day5('setup');
```

### Start Training
```matlab
run_day5('train');
```

## 9. Output Structure

### Setup Info
```matlab
setupInfo = struct(...
    'date',          '04-Sep-2026', ...
    'model',         'resnet18', ...
    'pretrained',    false, ...
    'inputSize',     [224, 224, 3], ...
    'numClasses',    5, ...
    'featureSize',   512, ...
    'frozenLayers',  60, ...
    'layerCount',    71);
```

### Trained Model
```matlab
% Saved to data/models/day5_resnet18_baseline_stage1.mat
% or day5_resnet18_baseline_stage2.mat
trainedNet = ...
info = struct(...
    'TrainingAccuracy', [...], ...
    'ValidationAccuracy', [...], ...
    'TrainingLoss', [...], ...
    'ValidationLoss', [...]);
```

## 10. Pipeline Integration

```
Input Retinal Image
        ↓
Quality Assessment (Day 3)
        ↓
PASS / WARNING / FAIL
        ↓
Enhancement (Day 4)
        ↓
Classifier (Day 5)
        ↓
DR Severity Prediction (0-4)
```

## 11. Limitations

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| **Untrained weights** | May need more epochs to converge | Use pretrained weights when support package installed |
| **CPU-only training** | Slow convergence | Use GPU or Google Colab |
| **Class imbalance** | Bias toward majority class | Class weights, oversampling |
| **Single dataset** | May not generalize | Multi-site validation |
| **Fixed image size** | May lose detail at 224×224 | Multi-scale analysis |

## 12. Important Notes

### What This IS
- An engineering classifier setup for DR severity prediction
- A transfer learning pipeline with data augmentation
- A prototype system for research and development

### What This IS NOT
- A clinical diagnostic system
- A replacement for ophthalmologist review
- A validated medical device
- A system that claims clinical accuracy

### Required Future Work
1. **Install support package** for pretrained ResNet-18 weights
2. **Train classifier** and evaluate on validation set
3. **Hyperparameter tuning** for better performance
4. **Ensemble methods** for improved accuracy
5. **Clinical validation** with ophthalmologist review

## References

- APTOS 2019 dataset: https://www.kaggle.com/c/aptos2019-blindness-detection
- ResNet-18: Deep Residual Learning for Image Recognition
- Transfer Learning: MATLAB Deep Learning Toolbox
- SIH 26038 problem statement
