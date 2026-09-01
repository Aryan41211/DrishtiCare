# Data Gaps — The Three Missing Pieces

## Gap 1: Lesion-Annotation Cliff

Only ~54 training images have pixel-level lesion masks (IDRiD segmentation subset). Workarounds: patch-based training, heavy augmentation, e-ophtha, pseudo-labeling on APTOS.

## Gap 2: No Quality Labels Anywhere

None of the 4 PS datasets label quality. Use EyeQ (28,792 images with Good/Usable/Reject) + handcrafted measures.

## Gap 3: No Neovascularization Annotations

No dataset annotates NV. Use surrogate features (vessel tortuosity, fractal dimension, peripapillary density). Route suspected PDR to urgent human review.
