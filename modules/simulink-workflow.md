# Module: Simulink Workflow Model

## Purpose
Model screening throughput and identify bottlenecks at scale.

## Model Design

```
[Poisson Generator] → [AI Processing] → [Human Review Queue] → [Output]
     (images/hr)        (fixed delay)      (capacity/day)
```

## Parameters

| Parameter | Value | Source |
|-----------|-------|--------|
| Image arrival rate | 10 images/hour | Assumed |
| AI processing time | 2 seconds/image | Measured |
| Human review capacity | 50 images/day | Assumed |
| Operating hours | 8 hours/day | Assumed |

## MATLAB Implementation (if Simulink too complex)

```matlab
arrivalRate = 10;
processingTime = 2;
reviewCapacity = 50;
operatingHours = 8;

days = 250; % 1 year
queueBacklog = zeros(days, 1);
queue = 0;

for day = 1:days
    arrivals = arrivalRate * operatingHours;
    processed = min(queue + arrivals, floor(operatingHours * 3600 / processingTime));
    reviewed = min(processed, reviewCapacity);
    queue = processed - reviewed;
    queueBacklog(day) = queue;
end

figure;
plot(1:days, queueBacklog);
xlabel('Day');
ylabel('Queue Length');
title('Screening Throughput Over 1 Year');
```

## Key Insight

The graph shows where the system breaks down:
- If queue grows indefinitely → bottleneck at human review
- If queue stabilizes → system can handle the load
- At 100k patients/year → need X ophthalmologists

## Assumptions (clearly labeled)

All numbers are **assumed**, not measured. Clearly state this in the pitch.

## References
- Section 6.5 of 10-day roadmap
- PS requirement: "Simulink workflow simulation"
