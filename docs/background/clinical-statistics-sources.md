# Clinical Statistics — Source Verification

Provenance record for the three impact statistics used in the pitch deck and background docs.
Every figure below was read from the cited source, not from a search snippet alone. Where a
source could not be rendered and the number came from an index snippet, that is stated explicitly.

Scope note: this file covers the three claims assigned for verification. The `ORNATE 2023`
blindness-cost figure in `clinical-background.md` was **not** in scope and remains unverified.

---

## Claim 1 — "77 million Indians have diabetes"

**Status: VERIFIED, but SUPERSEDED.** The number is real and traceable, but it is the 2019
IDF estimate and has been revised twice since. Do not present it as current.

| Field | Value |
|-------|-------|
| Repo claim | 77 million Indians have diabetes |
| Verified figure | **77.0 million** adults aged 20–79 with diabetes (India, 2019) |
| Source organisation | International Diabetes Federation (IDF) |
| Year of statistic | 2019 (IDF Diabetes Atlas, 9th edition) |
| Exact locator | IDF Diabetes Atlas, 9th ed. Brussels: IDF; 2019. Methods paper: Saeedi P, et al. *Diabetes Res Clin Pract* 2019. PMID 31518657. Tabulated in: Pradeepa R, Mohan V. *Indian J Ophthalmol* 2021;69(11):2932–2938. doi:10.4103/ijo.IJO_1627_21 — https://pmc.ncbi.nlm.nih.gov/articles/PMC8725109/ |
| What the source says (quoted) | "the top three countries with the highest number of individuals with diabetes are China (116.4 million), **India (77.0 million)**, and the United States of America (31.0 million)" — Pradeepa & Mohan 2021, Table 1 gives "Number of people (million) **77.0**" for 2019, footnoted "*Source IDF Diabetes Atlas 2019*" |
| Match quality | **Exact** (for 2019) |

### Superseding and competing estimates

| Edition / study | India figure | Year | Locator |
|---|---|---|---|
| IDF Diabetes Atlas 9th ed | 77.0 million | 2019 | doi:10.4103/ijo.IJO_1627_21 (tabulated) |
| IDF Diabetes Atlas 10th ed | **74.2 million** | 2021 | Sun H, et al. *Diabetes Res Clin Pract* 2021;183:109119. doi:10.1016/j.diabres.2021.109119 — Table 5: "\| 2 \| India \| 74.2 \| 2 \| India \| 124.9 \|" |
| IDF Diabetes Atlas 11th ed | **90 million [89–91]** | 2024 | Genitsaridi I, et al. *Lancet Diabetes Endocrinol* 2026;14(2):149–156. PMID 41412135. doi:10.1016/S2213-8587(25)00299-2 |
| ICMR-INDIAB-17 (national survey) | **101 million** (projected) | 2021 | Anjana RM, et al. *Lancet Diabetes Endocrinol* 2023. doi:10.1016/S2213-8587(23)00119-5 — "we estimated that in 2021, 101 million people had diabetes" |

**Verification caveat on the 11th-edition figure.** The paper's existence, authorship, journal,
volume and pages are confirmed via Europe PMC (PMID 41412135). The India value "90 million
[89–91]" was read from the search index of the authors' accepted manuscript in the University of
Edinburgh research repository; the PDF body could not be rendered as text, so this specific number
was **not** confirmed against a readable page. Treat as provisional until checked against the
printed table.

### Definitional mismatches to state whenever this number is used

- **Age band:** 20–79 years only. Excludes type 1 diabetes in children and all adults aged ≥80.
- **All diabetes, not diagnosed diabetes:** IDF models *diagnosed + undiagnosed*. India-specific
  undiagnosed fraction was 57.0% (43.9 million) in 2019. A pitch saying "77 million Indians have
  diabetes" is therefore correct; saying "77 million are *diagnosed*" would be wrong by ~44 million.
- **Modelled, not counted:** these are regression estimates from population-based surveys, not a
  registry census. The IDF authors state laboratory-based prevalence "will likely overestimate the
  prevalence of clinically-defined diabetes."
- **ICMR-INDIAB disagrees with IDF, and is higher** (101 million vs 74.2 million for a similar
  year). ICMR-INDIAB used OGTT in a 113,043-person national cross-sectional study; IDF applied its
  own quality scoring and modelling. The two are **not** interchangeable. If the deck needs one
  number, say which body produced it.

---

## Claim 2 — "Diabetic retinopathy affects ~18% of the Indian diabetic population"

**Status: CLOSE MATCH, with a material age-band restriction.** "18%" is defensible **only** as
"among Indians with diabetes aged 50 and over". It is not defensible for the diabetic population
as a whole, where the same meta-analysis gives 14.9%.

| Field | Value |
|-------|-------|
| Repo claim | ~18% DR prevalence in the Indian diabetic population |
| Verified figure | **18.1%** (95% CI 14.8–21.4) among persons with diabetes **aged ≥50 years** |
| Source organisation | Public Health Foundation of India / Indian Institute of Public Health (systematic review) |
| Year of statistic | 2016 (studies pooled 1999–2014) |
| Exact locator | Jotheeswaran AT, Lovakanth N, Nadiga S, Anchala R, Murthy GVS, Gilbert CE. *Indian J Endocrinol Metab* 2016;20(Suppl 1):S51–S58. doi:10.4103/2230-8210.179774. PMID 27144137 — https://pmc.ncbi.nlm.nih.gov/articles/PMC4847450/ |
| What the source says (quoted) | "In the meta-analysis, **14.9%** (95% confidence interval [CI] 10.7–19.0%) of known diabetics aged ≥30 years and **18.1%** (95% CI 14.8–21.4) among those aged ≥50 years had DR." Also: "About 14.9% ... of the diabetics aged 30 years and above had DR compared with 16.7% ... of those aged 40 years and above, and 18.09% ... of those aged 50 years and above" |
| Match quality | **Close** — number matches, population does not |

### Age-band breakdown from the same source (this is the part that matters)

| Population | DR prevalence |
|---|---|
| Diabetics aged ≥30 years | **14.9%** (95% CI 10.7–19.0) |
| Diabetics aged ≥40 years | 16.7% (95% CI 14.2–19.2) |
| Diabetics aged ≥50 years | **18.1%** (95% CI 14.8–21.4) |

### Independent cross-checks — the sources disagree

| Source | Population | Figure | Year | Locator |
|---|---|---|---|---|
| Vashist P, et al. National Survey 2015–19 (MoHFW/NPCB-funded) | Persons with diabetes aged ≥50, 21 districts, n=63,000 enumerated / 5,986 examined | **16.9%** any DR (95% CI 15.9–17.9); STDR 3.6% | 2015–19 | *Indian J Ophthalmol* 2021;69(11):3087–3094. doi:10.4103/ijo.IJO_1310_21. PMID 34708747 — https://pmc.ncbi.nlm.nih.gov/articles/PMC8725073/ |
| Brar AS, et al. Systematic review + meta-analysis | People with **type 2** diabetes, 10 population-based studies | **16.10%** overall (95% CI 13.16–19.04); urban 17.44%, rural 14.00%; population prevalence 1.63% | to Apr 2021 | *Indian J Ophthalmol* 2022. doi:10.4103/ijo.ijo_2206_21 — https://pmc.ncbi.nlm.nih.gov/articles/PMC9359280/ |

**Verification caveat on the Brar row.** DOI, journal and PMC id are confirmed. The figures above
come from the article's abstract as indexed; the full text (PMC9359280) was **not** directly
fetched, so treat the CIs as provisional.

**A 14.8% vs 14.9% discrepancy that is not a real disagreement.** Vashist et al. 2021 cites the
≥30-year figure as 14.8%. That is not an error on their part: Jotheeswaran's own Discussion gives
"14.8% in persons aged 30 years and older" while its abstract and Results give 14.9%. Both carry
the same CI (10.7–19.0). We quote 14.9% because that is the abstract figure. Not material.

**Where they disagree, and why.** The two national-survey-grade estimates for the *same* ≥50-year
age band are 18.1% (Jotheeswaran meta-analysis) and 16.9% (Vashist national survey) — a 1.2
percentage-point gap. Vashist et al. explain the direction of bias: "studies relying on self-report
of DM had reported a higher prevalence of DR. This might be because persons self-reporting
diabetes are usually in a more advanced stage of the disease with higher chances of complications."

Jotheeswaran et al. identify a bias running the **other** way, and concede the denominator is soft:
"In this case, the denominator, number of persons with diabetes, is imprecise: Prevalence estimated
in these studies may be underestimated." Their reason is measurement: most included studies
screened with a **glucometer**, which they note "is recommended as a monitoring tool but not as a
screening device" and "is unlikely to achieve 100% sensitivity and specificity". One South Indian
validation they cite found glucometer FBG sensitivity/specificity of just **62.8%/62.9%** (WHO
FPG ≥110 mg/dl cut-off) and **58.3%/58.6%** (ADA ≥100 mg/dl cut-off). Their stated conclusion is
that "the proportion of diabetics with DR is underestimated in the Indian population".

**So the two biases partly cancel, which is why we present a range rather than a number.** The
honest reading is that ~17% is a reasonable central estimate for age ≥50, that 18% is defensible
as an upper-central figure, and that no source supports 18% for all ages.

**Statistical caveat that limits how precise any of this can be.** Jotheeswaran's pooled estimate
has high statistical heterogeneity — "Heterogeneity around this estimate ranged from I2 = 79–87%"
— drawn from only **seven** studies (1999–2014, n=8,315 persons with diabetes), five of them urban
and three in Tamil Nadu. They could not run meta-regression (fewer than 10 studies). The pooled
point estimate should not be quoted to a decimal place as though it were precise.

**Conclusion: 18% is the top of the defensible range, not the centre of it.** A safer deck line is
*"roughly 1 in 6 to 1 in 5 Indians with diabetes have diabetic retinopathy (16.9%–18.1%,
age ≥50)"*.

### Other definitional mismatches to avoid

- **"Among diabetics" ≠ "in the population."** Jotheeswaran and Brar give the *population*
  prevalence of DR as a distinct, much smaller quantity (Brar: 1.63%, 95% CI 0.94–2.32). Quoting
  18% as a population prevalence would overstate the burden by an order of magnitude.
- **"All diabetics" vs "type 2 diabetics".** Brar's 16.10% is restricted to type 2 diabetes.
- **Facility-based figures are much higher and are not comparable.** The All India Ophthalmological
  Society screening study reported 21.7% in diabetes clinics/camps (>80% urban, non-random
  sampling). The SPEED programme (Rajalakshmi et al., *Indian J Ophthalmol* 2020;68(Suppl 1):S21–6,
  doi:10.4103/ijo.IJO_21_19) found DR in "one-third" and sight-threatening DR in "one-fifth" of
  people with type 2 diabetes "presenting at 14 eye-care facilities". These are clinic samples
  selected for disease, are biased upward, and are not comparable with population-based figures —
  do not average them together.
- **Mild NPDR dominates.** In the Vashist national survey, of all DR: 83.1% R0, 11.8% mild (R1),
  2.6% observable background (R2), 1.9% referable (R3), 0.6% proliferative (R4). If the deck needs
  a referable-DR number, the national figure is ~1.9%, not 18%.

---

## Claim 3 — "~1 ophthalmologist per 100,000 people"

**Status: NOT SUPPORTED as a current figure, and CONTRADICTED for the national level.** The
best current authoritative survey puts India at **1 per 65,221** — i.e. roughly 54% *more*
ophthalmologists per person than the repo claim. Using 1:100,000 would **understate** the
workforce gap in a deck whose argument depends on scarcity. The "rural" qualifier is separately
unsupported.

| Field | Value |
|-------|-------|
| Repo claim | ~1 ophthalmologist per 100,000 people (rural population) |
| Verified figure | **1 : 65,221** (≈15 per million) — ophthalmologists, national, secondary/tertiary level |
| Source organisation | AIIMS New Delhi (Dr Rajendra Prasad Centre for Ophthalmic Sciences); National Programme for Control of Blindness & VI, MoHFW (data on India Vision Atlas) |
| Year of statistic | Data collected January 2020 – September 2021; published 2025 |
| Exact locator | Vashist P, Manna S, Gupta V, Gupta N, Saxena R, Agrawal S, et al. "Human resources and infrastructure for ophthalmic services in India: Results from the National Survey." *Indian J Ophthalmol* 2025;73(11):1679–1686. doi:10.4103/IJO.IJO_2816_24. PMID 41148023 — https://pmc.ncbi.nlm.nih.gov/articles/PMC12659840/ |
| What the source says (quoted) | "The **ophthalmologist population ratio in the country was found to be 1:65,221**. The number of ophthalmologists per million population was 15 for the country, ranging from the highest of 127 in Puducherry to the lowest two in Ladakh." Abstract: "The number of ophthalmologists and optometrists in the entire country at secondary/tertiary level was 20,944, and 17,849, respectively (ratio: 0.85). On average, there were 15 ophthalmologists and 74 eye beds per million population." |
| Match quality | **Not supported** (national level contradicted; rural qualifier unsupported) |

Supporting numbers from the same survey: 7,901 of 8,790 eye institutes responded (89.9%);
20,944 ophthalmologists (15,373 full-time, 5,571 part-time) against a 2021 population of
1,40,37,82,395; optometrist:ophthalmologist ratio 0.85 against a Vision 2020 norm of 3.0; the
survey states 20,944 "falls short of the 25,000 required to eliminate the burden of avoidable
blindness in the country by 2030".

### Why "rural" is not supportable from this source

The survey is **national and institutional, not rural**. Its stated inclusion criterion excludes
precisely the rural primary-level facilities: "The inclusion criteria were eyecare institutes that
had at least one ophthalmologist (either full-time or part-time) on roll. Hence, vision centers
manned by PMOAs were excluded." It reports *geographic* maldistribution — "better ratios in the
Southern and Western states, compared to Northern, Eastern, and Northeastern states" — but
publishes **no rural-specific ophthalmologist density**.

A rural/urban split ("urban 1 per 10,000; rural 1 per 250,000") circulates in teleophthalmology
review literature. It was **not** adopted here: the same source's own text gives "about 15 per
million" nationally, which is inconsistent with a 1-per-10,000 urban figure, and its underlying
citation could not be traced to a primary workforce survey. Do not cite it.

### Where "~1 per 100,000" most likely came from — two candidates, both problematic

1. **A Vision 2020 planning *target*, mistaken for a measurement.** The Vision 2020 / IAPB human
   resource development framework sets the regional target for Asia as "Ophthalmologist 1 per
   100,000 population" (IAPB/WHO HRDWG, *Global Human Resource Development Assessment for
   Comprehensive Eye Care*, 2006). This is a benchmark, not an Indian count. Given that DrishtiCare
   is framed against a Vision-2020-style target, this is the most likely provenance of the error.
2. **A genuinely old measurement.** Murthy GVS, Gupta SK, Bachani D, Tewari HK, John N. "Human
   resources and infrastructure for eye care in India: current status." *Natl Med J India*
   2004;17(3):128–134. PMID 15253398 — survey April 2002–March 2003: "it is estimated that there
   are 9478 practising ophthalmologists and 59 828 dedicated eye beds in India." Against India's
   population of roughly 1.06 billion at the time, 9,478 is on the order of 1 per 110,000 — the
   right order of magnitude for the repo's number, and about 20 years out of date. *(The per-capita
   ratio here is our arithmetic; the paper does not state it.)*

### Contradiction worth surfacing in the deck

For DrishtiCare's actual use case — automated vitreoretinal grading — the binding constraint is
worse than general ophthalmology. The Vashist national DR survey states: "There is an acute
shortage of retina specialists in India, that is, **1 per 1.26 million population**" (attributed to
WHO, *Strengthening diagnosis and treatment of diabetic retinopathy in the South-East Asia
Region*, 2020). General ophthalmology at 1:65,221 understates the specialist bottleneck by
roughly 19×.

---

## Claims policy

1. **Label, never invent** (per D010). A value that cannot be traced to a named source is tagged
   unverified. Where a repo claim cannot be matched, the original number stays visible and is
   marked NOT SUPPORTED alongside the best defensible alternative — it is never silently swapped.
2. **Every number carries four things**: figure, source organisation, year, and an exact locator
   (DOI, PMID or URL). A claim missing any of the four is not citable.
3. **Name the age band and the diagnosis definition.** Most of the damage in this file comes from
   population drift, not from wrong numbers: 18% is right for ≥50-year-olds and wrong for all
   diabetics; 77 million is all diabetes and not diagnosed diabetes; 1:65,221 counts
   ophthalmologists and not retina specialists.
4. **Prefer the newest national survey over a pooled meta-analysis** where both exist, and say so
   when they disagree. Brar 2022 and Vashist 2021 are the current best estimates for DR
   prevalence; Jotheeswaran 2016 is older and its authors flag their own denominator weakness.
5. **State the year in the sentence, not only in a footnote.** IDF's India estimate has moved
   77.0 → 74.2 → 90 million across three editions in seven years. An undated "77 million" will age
   badly and will eventually be wrong on its face.
6. **Prefer primary and government sources.** IDF, ICMR, MoHFW/NPCB and peer-reviewed
   PubMed-indexed studies only. News coverage, blog posts and advocacy pages were used to *locate*
   primary sources, never as the citation itself.
7. **Do not average incompatible estimates.** Report the range and name each source.
