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

Each statistic below carries a status tag, the verified figure, the source, and the year. Full
provenance, exact quotes and locators are in
[`clinical-statistics-sources.md`](clinical-statistics-sources.md). Per D010, the originally drafted
number is kept visible even where it is not supported.

### Diabetic population

- **Original claim (as drafted):** "77 million Indians have diabetes"
- **Status: VERIFIED BUT SUPERSEDED — do not present as current**
- **Verified figure:** 77.0 million adults aged 20–79 (2019). The figure is real and traceable to the
  IDF Diabetes Atlas 9th edition, but it has been revised twice since:
  - **74.2 million** — IDF Diabetes Atlas 10th ed., 2021 (Sun et al., *Diabetes Res Clin Pract*
    2021;183:109119, doi:10.1016/j.diabres.2021.109119)
  - **90 million [89–91]** — IDF Diabetes Atlas 11th ed., 2024 (Genitsaridi et al., *Lancet
    Diabetes Endocrinol* 2026;14(2):149–156, doi:10.1016/S2213-8587(25)00299-2)
  - **101 million** — ICMR-INDIAB-17 national survey projection for 2021 (Anjana et al., *Lancet
    Diabetes Endocrinol* 2023, doi:10.1016/S2213-8587(23)00119-5). Higher than IDF; the two use
    different methods and are **not** interchangeable — name the body whenever quoting either.
- **Definitional caveat:** all diabetes (diagnosed **and** undiagnosed), ages 20–79 only, modelled
  estimate rather than a count. In 2019 an estimated 57% (43.9 million) of Indian adults with
  diabetes were undiagnosed. Never restate this as "diagnosed".
- **Recommended deck line:** *"An estimated 74 million Indian adults aged 20–79 had diabetes in
  2021 (IDF); India's own national survey puts the 2021 figure nearer 101 million (ICMR-INDIAB)."*

### Diabetic retinopathy prevalence

- **Original claim (as drafted):** "Diabetic retinopathy affects ~18% of the Indian diabetic population"
- **Status: CLOSE MATCH — number right, population wrong**
- **Verified figure:** 18.1% (95% CI 14.8–21.4) among persons with diabetes **aged ≥50 years**
  (Jotheeswaran et al., *Indian J Endocrinol Metab* 2016;20(Suppl 1):S51–S58,
  doi:10.4103/2230-8210.179774). The same meta-analysis gives **14.9%** (95% CI 10.7–19.0) for
  diabetics aged ≥30 — so "~18% of the Indian diabetic population" overstates the all-ages figure.
- **Cross-checks disagree:** the MoHFW/NPCB National Survey 2015–19 (Vashist et al., *Indian J
  Ophthalmol* 2021;69(11):3087–3094, doi:10.4103/ijo.IJO_1310_21) found **16.9%** (95% CI
  15.9–17.9) in the same ≥50 age band; Brar et al. 2022 (doi:10.4103/ijo.ijo_2206_21) pooled
  **16.10%** among people with type 2 diabetes. 18% is the top of the defensible range, not its
  centre.
- **Definitional caveats:** "among diabetics" is not "in the population" — population prevalence of
  DR is ~1.63%. Clinic-based studies report 21.7% and above (SPEED found DR in about one-third of
  type 2 diabetes patients attending 14 eye facilities) and are biased upward; do not average them
  with population-based figures. If a *referable* DR number is needed, the national figure is
  ~1.9% (R3) plus 0.6% (R4), with sight-threatening DR at 3.6%.
- **The bias may run upward, not downward.** Jotheeswaran et al. conclude that "the proportion of
  diabetics with DR is underestimated in the Indian population", because most pooled studies
  screened diabetes with a glucometer (validated sensitivity/specificity as low as 58%/59%) and
  therefore misclassified who counted in the denominator. Note also that the pooled estimate has
  high heterogeneity (I² = 79–87%) across only seven studies, five of them urban.
- **Recommended deck line:** *"Roughly 1 in 6 to 1 in 5 Indians with diabetes aged 50+ have
  diabetic retinopathy (16.9%–18.1%) — and the true rate is likely higher, since screening has
  largely missed people who never knew they had diabetes."*

### Ophthalmology workforce

- **Original claim (as drafted):** "Only 1 ophthalmologist per 100,000 rural population"
- **Status: NOT SUPPORTED — contradicted at national level, and the rural qualifier is unsourced**
- **Verified figure:** **1 : 65,221**, i.e. ~15 ophthalmologists per million population, nationally
  (Vashist et al., "Human resources and infrastructure for ophthalmic services in India: Results
  from the National Survey," *Indian J Ophthalmol* 2025;73(11):1679–1686,
  doi:10.4103/IJO.IJO_2816_24; 20,944 ophthalmologists; data collected 2020–21). India actually has
  ~54% *more* ophthalmologists per person than the drafted claim, so quoting 1:100,000 would
  **understate** the scarcity argument this project depends on.
- **Why "rural" fails:** that survey is national and institutional, and its inclusion criteria
  explicitly **exclude** the rural primary-level vision centres staffed by para-medical ophthalmic
  assistants. It reports geographic maldistribution (better in South/West, worst in North/East/NE;
  1.53 per million in Ladakh — 2 ophthalmologists in the entire UT — vs 127.21 in Puducherry) but
  publishes no rural-specific density. A "rural 1 per 250,000" figure circulates in
  teleophthalmology literature but is internally inconsistent and could not be traced to a primary
  survey — **do not cite it**.
- **Likely origin of the error:** "1 ophthalmologist per 100,000" is the Vision 2020 / IAPB
  *planning target* for Asia, not an Indian measurement. A genuinely old measurement is in the same
  range: 9,478 practising ophthalmologists in 2002–03 (Murthy et al., *Natl Med J India*
  2004;17(3):128–134, PMID 15253398), roughly 1 per 110,000.
- **Stronger framing available:** for automated *vitreoretinal* grading the real bottleneck is
  retina specialists, at **1 per 1.26 million** population (WHO, cited in Vashist et al. 2021).
- **Recommended deck line:** *"India has 15 ophthalmologists per million people — about one for
  every 65,000 — and only one retina specialist per 1.26 million."*

### Other figures in this section

- **Cost:** Diabetes-related blindness costs India **INR 400 billion annually** (ORNATE 2023)
  — **UNVERIFIED, OUT OF SCOPE.** Not covered by the source verification pass; still needs a source.
- **Prevention:** 95% of severe vision loss can be prevented with early detection
  — **UNVERIFIED.** Widely repeated but not sourced in this repo.

## Clinical Vocabulary for Reports

Reports should read like clinical reasoning:
> *"Grade 3 — Severe NPDR. Hemorrhages: 24/21/8/5 per quadrant — satisfies 4-2-1 in 2 quadrants. Microaneurysms: 47. Hard exudates 1.2 disc diameters from fovea — DME grade 1. Confidence 0.89. Recommend referral within 4 weeks."*

This is what makes 30-second ophthalmologist review possible — expressed in the criteria they already carry.
