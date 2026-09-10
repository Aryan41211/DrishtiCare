# DrishtiCare Hardening — Phase 23: Performance Envelope

Date: 2026-09-10. **4/4 PASS** (one self-contradictory check fixed).

## Envelope (two clearly-labelled operating points — no conflation)
| Operating point | n | median | mean | throughput | note |
|---|---|---|---|---|---|
| FULL demo path (quality+OOD+2 nets+calib+fusion+router+gradcam+narrative) | 10 | 11.03 s/img | 15.16 s/img | ~0.09 img/s | Phase-12 measured profile; includes inspector-style explanation; NOT a screening throughput claim |
| Model screening (dashboard measure) | 1 | 0.1028 s/img | 0.1028 s/img | ~9.73 img/s | Pure model path only; must NOT be conflated with the full demo path |

## Stationarity
- mean/median skew = 1.37 (≤3): slow inspector paths do not dominate the
  profile; the median is a stable summary of the full-demo operating point.

## Memory probe (one full inference, in-process)
- `MemUsedMATLAB` growth ≈ 2.63 GB. **Labeled honestly**: this includes the
  retained result in workspace and engine-allocator growth — a conservative
  *upper bound*, NOT a clean peak-RSS measurement. Not cited as steady-state
  memory anywhere.

## Artifacts
- `src/phase23_performance_envelope.m`
- `data/analysis/day10/phase23/phase23_performance_envelope.mat`
  (fields: `envelope` 2×1 struct, `memProbe`, `auditRes`)