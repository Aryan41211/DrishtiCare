# Task 10 — External Validation on Messidor-2: Status Assessment

**Date:** 2026-09-08
**Type:** Research / status assessment (no training code written, no dataset downloaded)
**Status:** ⛔ **BLOCKED on a human decision — license request required**

---

## 1. Local Copy Status

**No local copy of Messidor-2 exists anywhere in this workspace or the scratch temp directory.**

Evidence:
- Glob search for `**/*messidor*`, `**/*Messidor*`, `**/*messenger*` across `C:\projects\DrishtiCare` → **0 file hits**.
- Content grep for `(?i)messidor` → 24 hits, **all in Markdown docs/plans/context** (e.g. `docs/datasets.md`, `docs/validation/external-validation.md`, `archive/roadmap.md`, `context/tools-access.md`). **None reference an actual image file or archive on disk.**
- Full recursive scan of `C:\Users\aryan\AppData\Local\Temp\opencode` for any name matching `messidor|messenger` → **0 hits**.
- `data/` subtree contains only project artifacts: trained model `.mat` weights (`data/models/`), analysis outputs (`data/analysis/`), and APTOS/IDRiD-derived split PNGs (`data/splits_binary/`). No Messidor-2 images or archives are present.

**Conclusion: No local copy.** The task can proceed only via a fresh download, which requires the license/access request below.

---

## 2. License Terms & Exact Access / Request Steps

**Official access portal (current):** `https://www.adcis.net/en/third-party/messidor2/`
(ADCIS is the current data-management / distribution host. This page is the official redirect of the old `latim.univ-brest.fr` page.)

### License terms (quoted from the ADCIS Messidor-2 page)
> "Messidor-2 can be used, **free of charge, for research and educational purposes**. Copy, redistribution, and any unauthorized commercial use are prohibited. Any publication relying on this dataset must acknowledge the LaTIM laboratory and the Messidor program partners."

Required acknowledgment (must appear in any publication):
> "Kindly provided by the Messidor program partners (see https://www.adcis.net/en/third-party/messidor/)."

Required citations:
- Decencière et al., "Feedback on a publicly distributed database: the Messidor database," *Image Analysis & Stereology*, v. 33, n. 3, p. 231–234, aug. 2014. `http://dx.doi.org/10.5566/ias.1155`
- Abràmoff et al., "Automated analysis of retinal images for detection of referable diabetic retinopathy," *JAMA Ophthalmol*, vol. 131, no. 3, Mar. 2013, p. 351–357. `https://doi.org/10.1001/jamaophthalmol.2013.1743`

### Cost
**Free of charge** for research/education. No payment required.

### Download is NOT automatic — exact steps a researcher must take
1. Visit `https://www.adcis.net/en/third-party/messidor2/`.
2. Complete the **"Download form"** with personal information (email address, first/last name, professional interests, country, university/organization — fields per the historical Messidor procedure).
3. A member of the Messidor/ADCIS team **manually validates** the request (field-content check; ~25% of requests historically rejected for clearly incorrect fields).
4. A download link is sent **to the verified email address** (package is accessed via emailed link, not an anonymous direct URL).
5. Use of the data binds you to the license terms above (research-only, no redistribution, acknowledgment required).

**Contact for download problems:** database administrator `webmaster@adcis.net` (subject "Messidor-2"); or `bruno.lay@adcis.net` (ADCIS). To report publications / give feedback contact Mathieu Lamard (`mathieu.lamard@univ-brest.fr`), Etienne Decencière Ferrandière, or Bruno Laÿ.

**Key blocker:** access requires an **email + form + agreement** step performed *by a human*. Nothing can be fetched programmatically or anonymously.

---

## 3. Data Schema Summary

**Composition (official, per ADCIS):**
- **874 examinations, 1,748 images total** — each examination = 2 macula-centered fundus images (one per eye). Confirmed.
- **Messidor-Original:** 529 examinations → 1,058 images (PNG format).
- **Messidor-Extension:** 345 examinations → 690 images (JPG format), Topcon TRC NW6 non-mydriatic camera, 45° FOV, non-dilated, Brest University Hospital (Oct 2009 – Sep 2010).
- Ships with a **spreadsheet containing image pairing**.
- 4 images in *Messidor-Original* are typically excluded as ungradable → **1,744 usable** (per project `docs/datasets.md` and `docs/background/literature-verification.md`). Prevalence ≈ **14.6% referable (RDR)**.

### Labels — IMPORTANT correction to the task premise
The **official Messidor-2 download ships with NO DR-severity ground-truth annotations.** The ADCIS page explicitly states:
> "It does not contain annotations such as a diabetic retinopathy 'ground truth'. However, some third-parties proposed such annotations..."

The standard reference labels used by the literature (and referenced in this project, e.g. `docs/validation/external-validation.md` → "Krause et al. adjudicated grades") are **third-party**: Krause et al. 2018 (*Ophthalmology*) adjudicated a **referable / non-referable (RDR binary)** grade per image. This is a **binary** ground truth, NOT the 4-point severity scale the task brief mentions. (For context: "referable DR" = moderate NPDR or worse, or DME — the clinical referral threshold.)

### Applicability of existing project outputs (pRef, threshold 0.60)
**Directly applicable.** The project's screening output is already a **binary referable/non-referable** decision:
- `pRef` = raw P(referable), locked threshold **0.60** (`predictSingleFundus.m` default, `cascade_router.m` `def.pRefLocked`).
- Champion screening model: `day7_pretrained_resnet18_binary_stage2` @0.60 (sens 90.60% / spec 94.71% on APTOS validation).
- The task-4 closure locked the binary threshold at 0.60 and closed the APTOS test set.

Since Messidor-2's standard ground truth is referable/non-referable, the existing binary model + threshold map **1-to-1** onto it — external validation can be computed directly as sensitivity/specificity of `pRef ≥ 0.60` against Krause et al. RDR grades. No model/architecture change is needed for this task, only the (currently blocked) data + labels.

---

## 4. Recommendation

### ⛔ BLOCKED — license request needed (human decision required)

The task **cannot proceed to actual validation** until a human:

1. **Registers / agrees** via the ADCIS Messidor-2 download form:
   `https://www.adcis.net/en/third-party/messidor2/`
2. **Receives** the emailed link after manual approval, and
3. **Downloads** the dataset (~1,748 images; Messidor-Original 1,058 PNG + Messidor-Extension 690 JPG; approximate on-disk footprint on the order of a few GB — exact archive size is not published on the portal and is only known after the form/link is issued).

**Do NOT substitute another dataset (e.g. EyePACS) and label it as Messidor-2.** External validation for *comparison-against-published-Messidor-2-figures* has meaning only on the real Messidor-2 data. Proceeding without it would invalidate the comparison and contaminate the integrity of the task.

---

## 5. Explicit Note — Alternatives (separate from the Messidor-2 task)

This note is **independent** of the Messidor-2 work and does **not** satisfy the Messidor-2 external-validation requirement above:

- **EyePACS** is already used for pretraining in this project and is *not* a Messidor-2 substitute for external validation (overlap with training, different camera/histogram distribution).
- **IDRiD** is already used for internal test evaluation and is project-native, but is *not* Messidor-2.
- Other public DR datasets (e.g. DeepDRiD, MESSIDOR-Original/Universal Messidor) exist and could serve as *additional* generalization checks, but would be **separate deliverables** and must be requested separately. They are **not** Messidor-2.
