# Demo Script

## Duration
5-7 minutes

## Script

### Act 1: Problem (1 minute)
"India has 77 million diabetic adults. 18% have diabetic retinopathy. But there's only 1 ophthalmologist per 100,000 rural population. Most cases are detected too late."

### Act 2: Architecture (1 minute)
"Our system takes a raw fundus image and runs it through 6 stages: quality assessment, enhancement, classification (ResNet-18 pretrained on EyePACS), a lesion-feature cross-check branch, calibration, and explainability. The output is a clinical-grade report with Grad-CAM overlay and a confidence-gated referral decision."

### Act 3: Live Demo (2-3 minutes)
"Let me show you how it works."

1. Load a sample image
2. Run quality check → show pass/reject
3. Run enhancement → show before/after
4. Run classification → show grade and confidence
5. Run Grad-CAM → show heatmap overlay
6. Generate report → show final output

"Notice how the Grad-CAM highlights the lesion regions that drove the classification decision. This is what makes our system explainable."

### Act 4: Results (1 minute)
"Our champion 5-class grader (ResNet-18, EyePACS-pretrained, class-balanced) on 733 held-out validation images: 82.81% accuracy, QWK 0.8914, and for referable DR (Moderate or worse) sensitivity 90.60% with specificity 94.71% at the locked 0.60 threshold. Temperature calibration cuts calibration error by ~2× (ECE 0.045→0.030). This is honest — we're not claiming to beat the clinical standard yet, but the numbers are measured on a locked split."

### Act 4b: Ablation (30-45 s, if slides allow)
"Three isolated levers measured on the same split: pretraining is decisive (QWK 0.6887 → 0.8914), class balancing alone does not help a scratch model (QWK −0.079), and enhancement hurts grading (QWK −0.24). We report what hurts too — that's what makes the ablation credible."

### Act 5: Simulink (1 minute)
"Our Simulink model shows that at 100,000 patients per year, the bottleneck is ophthalmologist review capacity. This means we can automate 80% of screening and only send borderline cases to specialists."

### Act 6: Roadmap (1 minute)
"Next steps: train on larger datasets, add lesion-level segmentation, clinical validation, and regulatory approval. We have a clear path from prototype to product."

## Backup Plan

If live demo fails:
1. Switch to screen-recorded video
2. Say: "Let me show you a recording of the pipeline"
3. Play the backup video
4. Continue with results

## Tips

- Speak slowly and clearly
- Make eye contact with judges
- Don't rush the demo
- If something fails, stay calm and switch to backup
- Practice 2+ times before the real thing

## References
- Section 8 of 10-day roadmap
