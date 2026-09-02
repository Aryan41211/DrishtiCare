# Goals for Internal Round (Sep 12)

## Primary Deliverable

A working end-to-end demo:

```
Raw fundus image → Quality check → DR severity grade (0-4) → Grad-CAM overlay → Simple report
```

## Specific Deliverables

### 1. Working Demo Pipeline
- Raw fundus image in
- Quality check (pass/reject with reason)
- DR severity grade (0-4) out
- Grad-CAM explainability overlay
- Simple report with grade + confidence

### 2. Simulink Throughput Model
- Basic block model showing screening throughput
- Bottleneck identification at scale
- Queue-length-over-time graph for 100k+ patients/year

### 3. Honest Results
- Real accuracy/sensitivity/specificity numbers on APTOS test set
- Not fabricated numbers matching the PS target
- Honest framing of limitations

### 4. Roadmap Slide
- Clear argument for how prototype evolves toward clinical validation
- What's needed next (more data, clinical trials, regulatory)

## What We Are NOT Delivering

- Full segmentation of all structures (MA, HE, EX, SE, NV)
- Exact >90% sensitivity / >85% specificity (we report honest numbers)
- Real-world deployment or hardware integration
- Multi-dataset validation (APTOS + IDRiD + Messidor)

## Success Criteria

| Criteria | How We Know |
|----------|-------------|
| Pipeline works | Image goes through all stages, report comes out |
| Numbers are real | Same numbers reproduced on different test splits |
| Grad-CAM is sensible | Heatmaps highlight lesions, not random regions |
| Simulink shows bottleneck | Graph shows queue grows at high volume |
| Demo is rehearsed | Full run-through without crashes |
