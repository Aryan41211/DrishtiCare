# Clinical Background — Diabetic Retinopathy

## ICDR Severity Scale

| Level | Name | ETDRS Levels | Defining Findings | 1-Year PDR Risk | Follow-up |
|-------|------|--------------|-------------------|-----------------|-----------|
| 0 | No apparent retinopathy | Level 10 | No abnormalities | <1% | Annual screening |
| 1 | Mild NPDR | Level 20 | Microaneurysms only | <1% | Annual screening |
| 2 | Moderate NPDR | Levels 35, 43, 47 | Between mild and severe | ~5% | 6-12 month follow-up |
| 3 | Severe NPDR | Level 53 | **4-2-1 rule** (see below) | ~15-20% | 3-6 month follow-up; consider referral |
| 4 | Proliferative DR (PDR) | Levels 60-85 | Neovascularization and/or vitreous/preretinal hemorrhage | Immediate vision threat | Urgent referral; laser/anti-VEGF treatment |

**Referable DR = Level ≥2.** This is the binary endpoint for >90%/>85% targets.

**ICDR was developed** via international consensus (2002, modified Delphi with 14 experts from 11 countries) from ETDRS and WESDR data. Deliberately simplified for global clinical use.

## The 4-2-1 Rule (Level 3 Criteria)

A case satisfies Level 3 if ANY of:
- >20 intraretinal hemorrhages in **each of 4 quadrants**
- Definite venous beading in **≥2 quadrants**
- Prominent IRMA in **≥1 quadrant**

With NO proliferative signs.

**Quadrant-based and countable** — if your pipeline counts hemorrhages per quadrant, you can state in plain language why a case is Level 3.

## Lesion Detection Difficulty

| Lesion | Difficulty | Notes |
|--------|-----------|-------|
| Hard exudates (EX) | Easiest | Bright, sharp margins, high contrast |
| Soft exudates (SE) | Moderate | Bright, fuzzy margins |
| Hemorrhages (HE) | Moderate | Dark, irregular; dot/blot/flame subtypes |
| Microaneurysms (MA) | Hard | Few pixels, low contrast, confused with noise |
| IRMA / venous beading | Hard | Unannotated in public data |
| Neovascularization (NV) | Hardest | No public pixel-annotated dataset exists |

**Key finding (Krause 2018):** Most common cause of disagreement between adjudicated consensus and ophthalmologist grading was a **missed microaneurysm** — directly justifying why MA detection matters.

**Key finding (HSQ-VLM, Telang 2026):** Spatially-constrained quadrant segmentation achieved 99.6% hemorrhage sensitivity, 96.4% MA sensitivity — demonstrating that lesion-level detection is achievable with modern methods.

## Diabetic Macular Edema (DME)

- Retinal thickening at the macula
- Graded 0-2 by proximity of hard exudates to fovea (proxy on 2D photos)
- Second independent referral trigger
- Cheap to compute once you have EX segmentation + fovea localization
- IDRiD provides DME grades 0-2

## Referable DR Triggers

Referral is triggered by EITHER:
1. DR Level ≥2, OR
2. Presence of DME (even at lower retinopathy grade)

## Global Disease Burden

- **India:** 77 million diabetic adults, 18% DR prevalence
- **Cost:** Diabetes-related blindness costs India **INR 400 billion annually** (ORNATE 2023)
- **Workforce:** Only 1 ophthalmologist per 100,000 rural population
- **Prevention:** 95% of severe vision loss can be prevented with early detection

## Clinical Vocabulary for Reports

Reports should read like clinical reasoning:
> *"Grade 3 — Severe NPDR. Hemorrhages: 24/21/8/5 per quadrant — satisfies 4-2-1 in 2 quadrants. Microaneurysms: 47. Hard exudates 1.2 disc diameters from fovea — DME grade 1. Confidence 0.89. Recommend referral within 4 weeks."*

This is what makes 30-second ophthalmologist review possible — expressed in the criteria they already carry.
