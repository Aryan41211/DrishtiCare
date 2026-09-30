# Day 8 — Simulink Workflow Model (Sep 9)

## Focus
Simulink workflow model

## Deliverables
- Basic Simulink block model
- Queue/bottleneck output graph
- Throughput analysis for 100k+ patients/year

## Checklist

### Morning
- [ ] Open Simulink, create new model
- [ ] Add image arrival block (Poisson process)
- [ ] Add AI processing block (fixed delay)

### Afternoon
- [ ] Add human review queue block
- [ ] Configure parameters (arrival rate, processing time, capacity)
- [ ] Run simulation

### Evening
- [ ] Generate queue backlog graph
- [ ] Identify bottleneck
- [ ] Document assumptions

## Simulink Model Design

```
[Poisson Generator] → [AI Processing] → [Human Review Queue] → [Output]
     (images/hr)        (fixed delay)      (capacity/day)
```

## Assumptions (clearly labeled)

| Parameter | Value | Source |
|-----------|-------|--------|
| Image arrival rate | 10 images/hour | Assumed |
| AI processing time | 2 seconds/image | Measured from Day 6 |
| Human review capacity | 50 images/day | Assumed |
| Operating hours | 8 hours/day | Assumed |

## MATLAB/Simulink Approach

```matlab
% If Simulink is complex, use MATLAB script
arrivalRate = 10; % images/hour
processingTime = 2; % seconds/image
reviewCapacity = 50; % images/day
operatingHours = 8; % hours/day

% Simulate over 1 year (250 working days)
days = 250;
queueBacklog = zeros(days, 1);
queue = 0;

for day = 1:days
    arrivals = arrivalRate * operatingHours;
    processed = min(queue + arrivals, floor(operatingHours * 3600 / processingTime));
    reviewed = min(processed, reviewCapacity);
    queue = processed - reviewed;
    queueBacklog(day) = queue;
end

% Plot results
figure;
plot(1:days, queueBacklog);
xlabel('Day');
ylabel('Queue Length');
title('Screening Throughput Over 1 Year');
saveas(gcf, 'simulink_throughput.png');
```

## End of Day Check
- [ ] Simulink model built (or MATLAB script)
- [ ] Simulation ran successfully
- [ ] Throughput graph generated
- [ ] Bottleneck identified
- [ ] Ready for Day 9 (integration)
