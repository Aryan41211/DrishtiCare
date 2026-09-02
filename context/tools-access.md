# Tools and Access

## Required Software

| Tool | Purpose | Required? |
|------|---------|-----------|
| MATLAB Desktop or Online | Primary development environment | Yes |
| Image Processing Toolbox | CLAHE, filtering, morphological ops | Yes |
| Deep Learning Toolbox | Transfer learning, gradCAM | Yes |
| Computer Vision Toolbox | Image augmentation | Yes |
| Simulink | Workflow throughput model | Yes |
| Statistics and Machine Learning Toolbox | Evaluation metrics | Yes |

## Getting MATLAB Access

1. **Check campus license first** — Log in at mathworks.com with VPKBIET college email
2. **If unavailable** — Use MATLAB free trial or MATLAB Online (browser-based, no install)
3. **Fallback** — Train classifier in Python/Colab, export to ONNX, import in MATLAB

## Dataset

### Primary: APTOS 2019
- **Size:** ~3,600 labeled fundus images
- **Labels:** DR severity 0-4
- **Source:** Kaggle competition
- **Why:** Manageable size for 10-day build

### Stretch/Reference (if time allows)
- **IDRiD** — Useful for citing broader validation
- **Messidor-2** — External validation reference

## Python/Colab Fallback

If MATLAB training is too slow:
1. Train classifier in PyTorch on Google Colab (free GPU)
2. Export model to ONNX format
3. Import ONNX model in MATLAB Deep Learning Toolbox
4. Use MATLAB for quality assessment, Grad-CAM, Simulink (all PS-required)
