# Demo Script

## Duration
5-7 minutes

## Script

### Act 1: Problem (1 minute)
"India has 77 million diabetic adults. 18% have diabetic retinopathy. But there's only 1 ophthalmologist per 100,000 rural population. Most cases are detected too late."

### Act 2: Architecture (1 minute)
"Our system takes a raw fundus image and runs it through 4 stages: quality assessment, enhancement, classification, and explainability. The output is a clinical-grade report with Grad-CAM overlay."

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
"On our test set, we achieved X% sensitivity and Y% specificity for referable DR. This is honest — we're not claiming to beat the clinical target yet, but we have a clear path to get there."

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
