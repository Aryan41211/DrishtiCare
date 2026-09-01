# Module 5 — Simulink Workflow Simulation

## Purpose

Model the telemedicine screening pipeline as a discrete-event queueing system. Optimize resource allocation for district-level programmes serving 100,000+ patients annually.

## System Parameters (From PS)

```
100,000 patients/year
÷ ~250 working days = 400 patients/day district-wide
÷ ~20 PHCs = 20 patients/PHC/day
× 1-4 images per patient = 20-80 images/PHC/day
```

## Queueing Model Architecture

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ Poisson      │───▶│ Quality Gate │───▶│ AI Inference │───▶│ Decision     │
│ Arrivals     │    │ (reject rate │    │ Queue        │    │ Splitter     │
│ per PHC      │    │  20-40%)     │    │              │    │              │
└──────────────┘    └──────────────┘    └──────────────┘    └──────┬───────┘
                                                                    │
                     ┌──────────────────────────────────────────────┘
                     ▼
         ┌───────────────────────┐
         │  Three output queues: │
         │  • Clear (auto)       │
         │  • Referable (review) │
         │  • Uncertain (review) │
         └───────────┬───────────┘
                     │
         ┌───────────┼───────────┐
         ▼           ▼           ▼
    ┌─────────┐ ┌─────────┐ ┌─────────┐
    │Auto-Clear│ │Reviewer │ │Urgent   │
    │(no review)│ │Queue    │ │Review   │
    └─────────┘ └─────────┘ └─────────┘
```

## Simulink Components

### 1. Arrival Process
- Poisson arrivals with time-of-day profile (morning peak)
- Seasonal variation (harvest season → less screening)
- Parameter: λ (arrival rate per PHC per hour)

### 2. Quality Gate
- Probability of rejection: 20-40% (non-mydriatic field conditions)
- Recapture loop with retry limit (max 2 retries)
- Rejection adds latency + load

### 3. AI Inference Queue
- Inference latency varies by hardware:
  - Laptop GPU: ~2 seconds/image
  - CPU-only: ~10 seconds/image
  - Jetson edge: ~5 seconds/image
- Queue discipline: FCFS or Priority (urgent cases first)

### 4. Decision Splitter
- Clear: ~50-60% of graded images
- Referable: ~25-30%
- Uncertain: ~10-15%

### 5. Reviewer Queue
- Only referable + uncertain cases need human review
- Grader capacity: 30 seconds/case, 6 productive hours/day
- **Sanity anchor:** 1 grader handles ~700 cases/day

## Key Finding 1: Edge Inference Collapses Bandwidth

```
Scenario A: Upload all images for cloud review
  400 images/day × 20 PHCs = 8,000 images/day
  × ~500 KB/image = ~4 GB/day uplink

Scenario B: Edge inference, upload only referable
  8,000 × 30% referable = 2,400 images/day
  = ~1.2 GB/day uplink (70% reduction)
```

**Sweep:** Plot uplink demand vs referable percentage

## Key Finding 2: Threshold-Staffing Pareto

```matlab
% Sweep referable-DR threshold
thresholds = 0.3:0.05:0.8;
for t = thresholds
    referable_pct = sum(calibratedScores >= t & grade >= 2) / n;
    reviewer_load = totalImages * referable_pct;
    graders_needed = reviewer_load / 700; % cases per grader per day
    turnaround_days = reviewer_load / (graders_needed * 700);
end

% Plot Pareto frontier
plot(thresholds, graders_needed, '-o')
xlabel('Sensitivity threshold')
ylabel('Graders needed per district')
title('Clinical Operating Point = Resource Budget')
```

**This is the insight to lead with:** pushing sensitivity from 90% to 95% increases referral rate → reviewer workload → staffing requirement. The Module 3 threshold and the Module 5 staffing requirement are the same variable viewed from two ends.

## Simulink Implementation

### Option A: SimEvents (if licensed)
- Entity Generator: Poisson arrivals
- Queue blocks: Quality gate, inference, reviewer
- Server blocks: AI inference, human review
- Sink blocks: Auto-clear, referral output

### Option B: Plain Simulink + Stateflow
- Stateflow chart for queue logic
- Discrete-event approximation with manual counters
- More work but no extra license needed

## Output Metrics

| Metric | What to Report |
|--------|---------------|
| Mean turnaround time | Days from capture to result |
| Reviewer utilization | % of productive time used |
| Graders needed per district | Staffing requirement |
| Cost per screened patient | Total cost / total screened |
| Throughput at capacity | Max patients/day with current resources |
| Loss to follow-up impact | Referral no-show rate effect |
