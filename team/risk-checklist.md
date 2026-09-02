# Risk Checklist

## Critical Risks

### 1. MATLAB Access Delay
- **Impact:** Blocks ALL work
- **Mitigation:** Resolve on Day 1. Check campus license first, trial/online as fallback
- **Owner:** Everyone

### 2. Team Unfamiliar with MATLAB
- **Impact:** Slower development, more bugs
- **Mitigation:** Train classifier in Python/Colab, import via ONNX. Use MATLAB for quality, Grad-CAM, Simulink only
- **Owner:** ML/Classifier Lead

### 3. Live Demo Failure
- **Impact:** Catastrophic on pitch day
- **Mitigation:** Always have backup screen-recorded video ready BEFORE Sep 12
- **Owner:** Integration Lead

### 4. Overpromising Accuracy
- **Impact:** Loses judge credibility
- **Mitigation:** Report real numbers honestly. Honest + improvement plan > suspiciously perfect metrics
- **Owner:** Pitch Lead

## Technical Risks

### 5. APTOS Training Too Slow
- **Impact:** Delayed classifier results
- **Mitigation:** Use Google Colab free GPU. Train in PyTorch, export ONNX, import MATLAB
- **Owner:** ML/Classifier Lead

### 6. Grad-CAM Produces Nonsensical Heatmaps
- **Impact:** Weak demo artifact
- **Mitigation:** Try different layers, use Grad-CAM++, save best examples
- **Owner:** ML/Classifier Lead

### 7. Simulink Model Too Complex
- **Impact:** Day 8 overrun
- **Mitigation:** Keep intentionally simple. Reasonable assumed numbers, clearly labeled
- **Owner:** Simulink Lead

## Schedule Risks

### 8. Day 1-2 Overrun
- **Impact:** Cascading delays
- **Mitigation:** Hard cutoff at end of Day 2. Whatever isn't done, skip to Day 3
- **Owner:** Team

### 9. Integration Issues Day 9
- **Impact:** Demo not working
- **Mitigation:** Start integration early if possible. Have working components isolated
- **Owner:** Integration Lead

## Contingency Plans

| If This Happens | Do This |
|----------------|---------|
| MATLAB not available | Use Python + ONNX import |
| Training too slow | Use smaller model (ResNet-18 not 50) |
| Grad-CAM broken | Use LIME or simple occlusion sensitivity |
| Simulink fails | Use MATLAB script with assumed numbers |
| Demo crashes | Switch to backup video |
