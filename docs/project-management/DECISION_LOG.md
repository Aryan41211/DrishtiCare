# DrishtiCare — Decision Log

This file records important decisions so future work does not reopen settled questions.

## D001 — Freeze champion models

**Decision:** Keep Day-7 pretrained ResNet-18 5-class and binary models as champions.

**Reason:** They are integrity-anchored and extensively audited.

**Status:** LOCKED.

---

## D002 — Keep referral threshold at 0.60

**Decision:** Do not retune.

**Reason:** Provenance-pinned and used throughout the hardened inference contract.

**Status:** LOCKED.

---

## D003 — Keep enhancement out of production inference

**Decision:** Raw input remains the production path.

**Reason:** A/B evaluation showed substantial degradation with enhancement.

**Status:** CLOSED.

---

## D004 — Exclude vessel features from production

**Decision:** Do not feed vessel segmentation features into Branch B.

**Reason:** Adding them reduced AUC.

**Status:** CLOSED.

---

## D005 — Do not claim Grad-CAM lesion localization

**Decision:** Grad-CAM is model attention evidence only.

**Reason:** Quantified IDRiD lesion alignment was weak.

**Status:** LOCKED.

---

## D006 — Keep external validation as future work

**Decision:** Do not invent Messidor-2 or Sin-NP results.

**Reason:** Data access is currently blocked.

**Status:** OPEN.

---

## D007 — Prioritize packaging over another model

**Decision:** Dashboard, report, demo, deck, video and defensibility take priority.

**Reason:** Current ML is frozen and the next competition gate is submission packaging.

**Status:** ACTIVE.

---

## D008 — Preserve negative findings

**Decision:** Do not hide weak fovea localization, vessel segmentation, MA recall, explainability alignment, or external-validation gaps.

**Reason:** These are important evidence and improve technical credibility when presented accurately.

**Status:** LOCKED.

---

## D009 — Treat Simulink output as engineering simulation

**Decision:** Do not present implied specialist capacity as a real staffing recommendation.

**Reason:** It depends on simulation assumptions.

**Status:** LOCKED.

---

## D010 — Every metric needs provenance

**Decision:** If a value cannot be traced to an artifact/source, label it unverified.

**Reason:** Avoid accidental overclaiming.

**Status:** LOCKED.
