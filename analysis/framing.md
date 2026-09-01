# Framing — How to Present This Project

## Lead With the Deployment Gap, Not the Algorithm

The PS's own framing is that accurate DR classifiers already exist and **still** are not deployed in rural India — because they are opaque, fail on real-world image quality, and are not validated with clinical rigour.

### The Pitch

> "We are not proposing a better classifier. We are proposing the validated, explainable, resource-modelled system that lets an existing-quality classifier actually be trusted and deployed in a primary health centre."

### Why This Works

1. **Matches the PS motivation line by line** — you're answering what they asked
2. **Makes unglamorous work the core contribution** — quality gating, calibration, ablations, queueing simulation become the main story
3. **Protects you if accuracy is slightly below SOTA** — accuracy was never the claim

## The Three Pillars

### Pillar 1: Trust (Explainability + Calibration)
- "Here's what the model sees, in clinical language"
- Grad-CAM heatmaps quantified against ground truth
- Calibrated confidence with explicit abstention
- Lesion evidence in ICDR criteria format

### Pillar 2: Rigour (Validation + Ablation)
- "Here's proof it works, not just on our test set"
- External validation on Messidor-2
- Ablation study showing integrated pipeline > any single technique
- Bootstrap confidence intervals, not just point estimates

### Pillar 3: Deployability (Quality + Resource Model)
- "Here's how it actually runs in a district programme"
- Closed-loop quality gating with recapture feedback
- Simulink threshold-staffing Pareto analysis
- Edge inference bandwidth analysis

## The Demo Narrative

1. **Feed a bad image** → show it bounce back with reason code
2. **Feed a normal image** → show it clear without Branch B (cascade)
3. **Feed a referable DR image** → show dual evidence path, both branches, agreement
4. **Show the report** → Grad-CAM + lesion evidence + 4-2-1 rule + confidence
5. **Show the Simulink model** → threshold sweep → staffing implication

## What NOT to Say

- Don't claim SOTA accuracy — claim validated methodology
- Don't claim clinical deployment — claim retrospective validation
- Don't claim NV detection — claim surrogate features with honest limitations
- Don't claim "sub-pixel MA detection" — claim FROC-evaluated detection at pixel scale
