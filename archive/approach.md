# Approach

This is the strategy layer — *how* to win this statement, as distinct from [ARCHITECTURE.md](./ARCHITECTURE.md), which covers *what* to build.

## Verdict

**Conditional go.** The performance bar this statement sets (>90% sensitivity, >85% specificity for referable DR) is comfortably below what published literature already achieves — Gulshan et al. 2016 hit 96.1%/93.9% on Messidor-2, Ting et al. 2017 hit 90.5%/91.6%, and the FDA-cleared IDx-DR hit 87.2%/90.7% in a prospective trial. You are not being asked to advance the state of the art. You are being asked to **integrate, explain, and validate** — a fundamentally more achievable engineering problem under a hackathon deadline than raw model accuracy would be.

**Take it only if the team has all three:**
1. Someone who has trained a CNN end-to-end and can debug a training run that silently isn't learning
2. Real willingness to work in MATLAB/Simulink, not just tolerate it
3. Discipline to descope — five modules, ~11 sub-tasks; attempting all at equal depth is the failure mode that kills teams on this statement

**The asymmetry in your favor:** most student teams are Python-native and will either avoid this statement or quietly build it in Python and fail the toolchain expectation. Commit to MATLAB properly and the effective competition thins out fast, regardless of how popular "diabetic retinopathy detection" is as a topic.

---

## The Hidden Grading Criterion

The expected-solution paragraph ends with a line most teams skim past:

> "...validation against published benchmarks showing the integrated pipeline outperforms any single technique approach."

This is asking for an **ablation study** — proof that the assembled pipeline beats each of its parts alone. It's cheap to produce (the same experiment run 4–5 times with pieces switched off), it's explicitly requested, and the large majority of teams will not do it because it feels like bookkeeping rather than building.

**Design the whole project backwards from this one table.** If the final report shows the CNN alone hits a certain sensitivity, the lesion-feature model alone hits something lower, the fusion beats both, and adding the quality gate improves it further on the low-quality subgroup — that directly and literally answers the hardest-to-fake requirement in the statement. Everything in [ARCHITECTURE.md](./ARCHITECTURE.md) and [VALIDATION.md](./VALIDATION.md) exists in service of filling that table honestly.

---

## Design Philosophy: Two Branches That Agree

The architecture (see [ARCHITECTURE.md](./ARCHITECTURE.md)) is built around one decision: run a deep classifier (accurate, opaque) and a lesion-feature model (interpretable by construction) independently, then fuse them. This single choice buys three things at once:

- **Accuracy** — the deep branch carries the heavy lifting on raw sensitivity/specificity
- **Explainability** — the lesion-feature branch is checkable directly against the written ICDR criteria, and can flag disagreement with the deep branch as a safety signal
- **The ablation table** — the two branches alone are the baselines; the fusion is the headline result. The architecture and the required experiment are the same object.

This is why the architecture isn't just "a CNN plus some extra features" — the split is what makes the validation story possible at all.

---

## What Separates a Winning Submission — Ranked by Return on Effort

1. **Quantified explainability** — Grad-CAM saliency measured against IDRiD lesion masks (pointing-game score, IoU), not just heatmaps that look plausible. Highest impact, lowest competition — very few student teams do this.
2. **The ablation study** — explicitly requested (see above), cheap to produce, widely skipped.
3. **External validation on Messidor-2** with zero training contamination, placed beside published figures from the same dataset — see [VALIDATION.md](./VALIDATION.md) for the comparison table.
4. **The Simulink threshold-vs-staffing Pareto analysis** — the insight that the clinical operating point (sensitivity/specificity threshold) and the district staffing budget are the same variable viewed from two ends. Nothing else in the statement is this easy to answer this well.
5. **Closed-loop quality gating with actionable recapture reason codes** — the module that makes the system deployable by a health worker rather than merely accurate in a notebook.
6. **Calibration plus abstention** as an explicit clinical safety mechanism, not just a metrics checkbox.
7. **Real clinician feedback**, however small the sample, on the 30-second review claim. Thirty minutes of an ophthalmologist's time converts an assertion into evidence.
8. **Honest, specific limitations slide** — microaneurysm sensitivity, absent NV annotations, retrospective-only validation, single-field imaging. Clinician judges weight intellectual honesty heavily, and a limitations slide that shows genuine understanding of your own failure modes is disproportionately persuasive.

---

## Submission Framing

**Lead with the deployment gap, not the algorithm.** The statement's own framing is that accurate DR classifiers already exist and *still* aren't deployed in rural India — because they're opaque, fail on real-world image quality, and aren't validated with clinical rigor. The pitch should therefore be:

> *We are not proposing a better classifier. We are proposing the validated, explainable, resource-modeled system that lets an existing-quality classifier actually be trusted and deployed in a primary health centre.*

This framing does three things:
- Matches the statement's stated motivation almost line for line
- Turns the "unglamorous" work — quality gating, calibration, ablations, queueing simulation — into the **core contribution** rather than supporting cast
- Protects the team if raw accuracy lands slightly below the best published numbers, because accuracy was never the claim being made

---

## Validation Approach (summary — full detail in VALIDATION.md)

- Train on EyePACS + APTOS; internal validation split from APTOS for model selection, threshold choice, and calibration; test on IDRiD; external-validate on **Messidor-2, touched only once, at the very end**
- Report sensitivity/specificity/AUC with **bootstrap 95% confidence intervals**, not point estimates — a single 91% sensitivity on a small test set is not evidence of clearing a 90% bar; the interval is what tells you whether you actually cleared it
- Stratify results by image-quality tier — if the quality module earns its place, performance on the low-quality subgroup should visibly improve when it's enabled
- Place final numbers beside Gulshan 2016, Ting 2017, and Abràmoff/IDx-DR 2016 on the same datasets, and be honest where the pipeline falls short — a team reporting slightly-below-benchmark numbers with correct methodology and clear confidence intervals is more credible than one claiming near-perfect scores on a leaky split, and experienced judges can tell the difference instantly

---

## Descoping Discipline

When time runs short, cut in this order (deprioritize, don't abandon — state clearly in the report what was cut and why):

1. Neovascularization pixel-level segmentation → surrogate features only (already the honest design, see [ARCHITECTURE.md](./ARCHITECTURE.md))
2. IRMA and venous beading → mention as future work, don't attempt detection
3. Web dashboard wrapper → MATLAB App Designer alone is sufficient if time is tight
4. Real clinician validation study → substitute with a clearly-labeled internal team review if no ophthalmologist can be reached in time, and say so explicitly rather than implying it was clinician-validated

Depth on grading + explainability + Simulink beats breadth across all five modules attempted shallowly. A modest, complete submission with a real ablation table scores better than an ambitious, half-finished one.
