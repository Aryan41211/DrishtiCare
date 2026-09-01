# Deployment Plan — From Prototype to Production

## Target Environment

Primary Health Centres (PHCs) in rural India with dedicated fundus cameras, variable internet, health worker operation, remote ophthalmologist review.

## Architecture Options

### Option A: Edge Inference (Recommended)
Fundus Camera → Laptop/Jetson → Local AI → Only referable uploaded → Ophthalmologist review
- 70-90% bandwidth reduction
- Works offline

### Option B: Cloud Inference
Fundus Camera → Upload all → Cloud AI → Results back → Ophthalmologist review
- Requires reliable internet
- Centralized updates

### Option C: Hybrid (Pragmatic)
Local lightweight model (quality + triage) → Clear auto-approved → Borderline/referable uploaded → Cloud full analysis

## Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| Camera | Portable fundus camera | Kowa VX-10α |
| Compute | Laptop (CPU) | Jetson Orin Nano |
| Network | Intermittent 3G | 4G broadband |

## Regulatory Context

- Software as Medical Device (SaMD) in India
- CDSCO regulation, IEC 62304, ISO 13485
- IDx-DR FDA clearance (2018) as precedent
