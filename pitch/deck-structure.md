# Pitch Deck Structure

## 6-Slide Deck

### Slide 1: Problem (1 min)
- 77 million diabetic adults in India
- 18% DR prevalence
- 1 ophthalmologist per 100,000 rural population
- Most cases detected too late

**Visual:** Map of India with DR prevalence overlay

### Slide 2: Architecture (1 min)
- System diagram: Quality → Enhancement → Classification → Grad-CAM → Report
- Key features: Explainable, MATLAB-based, PS-compliant

**Visual:** Pipeline block diagram

### Slide 3: Demo (2-3 min)
- Live or recorded demo
- Show actual image going through pipeline
- End on Grad-CAM output (most visually persuasive)

**Visual:** Screen recording or live demo

### Slide 4: Results (1 min)
- Your real numbers:
  - Sensitivity: __% (target >90%)
  - Specificity: __% (target >85%)
- Honest framing: "Here's what we achieved, here's what's needed next"

**Visual:** Confusion matrix or metrics table

### Slide 5: Simulink Insight (1 min)
- Throughput bottleneck graph
- What it implies for district-level resource planning
- "At 100k patients/year, we need X ophthalmologists"

**Visual:** Queue backlog graph

### Slide 6: Roadmap (1 min)
- What's needed next:
  - More training data (EyePACS)
  - Lesion-level segmentation
  - Clinical validation
  - Regulatory approval
- Clear path from prototype to product

**Visual:** Timeline or roadmap diagram

## Timing

| Section | Time |
|---------|------|
| Problem | 1 min |
| Architecture | 1 min |
| Demo | 2-3 min |
| Results | 1 min |
| Simulink | 1 min |
| Roadmap | 1 min |
| **Total** | **7-8 min** |

## Key Messages

1. **Problem is real** — 77M diabetics, 18% DR, no doctors
2. **We built something** — Working pipeline, not just slides
3. **We're honest** — Real numbers, not fabricated
4. **We have a plan** — Clear roadmap to clinical validation

## References
- Section 8 of 10-day roadmap
