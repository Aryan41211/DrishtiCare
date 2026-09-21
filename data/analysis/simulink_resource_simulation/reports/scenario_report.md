# Scenario Report - District Screening Simulation

**ENGINEERING / RESOURCE-PLANNING SIMULATION - NOT clinical validation.**

All threshold-specific sensitivity/specificity values are **measured** from
the locked 733-val PRef scores. Capacity/volume values are assumptions.

| id | scenario | vol/yr | t | sens | spec | referrals/yr | ref/day | cap/day | util% | specialists req. | backlog | status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| A | Baseline (t=0.60, 100k/yr) | 100000 | 0.60 | 0.9060 | 0.9471 | 38406 | 153.6 | 60 | 100.0 | 7.68 | 23406 | Specialist capacity exceeded |
| B | Lower threshold (t=0.50) | 100000 | 0.50 | 0.9228 | 0.9425 | 39324 | 157.3 | 60 | 100.0 | 7.86 | 24324 | Specialist capacity exceeded |
| C | Higher threshold (t=0.70) | 100000 | 0.70 | 0.8859 | 0.9517 | 37358 | 149.4 | 60 | 100.0 | 7.47 | 22358 | Specialist capacity exceeded |
| D50 | Volume scaling 50k/yr | 50000 | 0.60 | 0.9060 | 0.9471 | 19203 | 76.8 | 60 | 100.0 | 3.84 | 4203 | Specialist capacity exceeded |
| D100 | Volume scaling 100k/yr | 100000 | 0.60 | 0.9060 | 0.9471 | 38406 | 153.6 | 60 | 100.0 | 7.68 | 23406 | Specialist capacity exceeded |
| D150 | Volume scaling 150k/yr | 150000 | 0.60 | 0.9060 | 0.9471 | 57610 | 230.4 | 60 | 100.0 | 11.52 | 42610 | Specialist capacity exceeded |
| D200 | Volume scaling 200k/yr | 200000 | 0.60 | 0.9060 | 0.9471 | 76813 | 307.2 | 60 | 100.0 | 15.36 | 61813 | Specialist capacity exceeded |
| E60 | Capacity 60/day | 100000 | 0.60 | 0.9060 | 0.9471 | 38406 | 153.6 | 60 | 100.0 | 7.68 | 23406 | Specialist capacity exceeded |
| E120 | Capacity 120/day | 100000 | 0.60 | 0.9060 | 0.9471 | 38406 | 153.6 | 120 | 100.0 | 7.68 | 8406 | Specialist capacity exceeded |
| E180 | Capacity 180/day | 100000 | 0.60 | 0.9060 | 0.9471 | 38406 | 153.6 | 180 | 85.3 | 7.68 | 0 | Review capacity sufficient |

## Key readings

- **Threshold effect (A/B/C):** lower threshold increases referrals (higher
  sensitivity, lower specificity); higher threshold reduces referrals.
- **Volume effect (D):** referral demand scales ~linearly with volume.
- **Capacity effect (E):** at 60/day demand (153.6/day) the queue clears only
  when capacity exceeds demand; the 180/day scenario is sufficient under
  these assumptions.

Specialists required is computed as referrals/day divided by the assumed
20 cases/specialist/day. It is an engineering estimate, not a staffing plan.
