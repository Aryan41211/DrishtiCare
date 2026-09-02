# Day 1 Quick Start Guide

## Run These Scripts in Order

### Step 1: Verify Environment
```matlab
cd src/setup
verify_environment
```
**What it checks:** MATLAB version, toolboxes, GPU, memory
**Expected:** All green [PASS] marks, or clear [FAIL] messages

### Step 2: Inspect Dataset
```matlab
cd src/setup
inspect_dataset
```
**What it does:** Loads APTOS CSV, shows class distribution, displays 10 sample images
**Expected:** See 10 fundus images, class distribution table

### Step 3: Confirm Everything Works
- [ ] `verify_environment` ran without errors
- [ ] `inspect_dataset` displayed images
- [ ] You can see the 5 DR severity classes
- [ ] No critical [FAIL] messages

## If Something Fails

| Problem | Solution |
|---------|----------|
| Missing toolbox | Note which one. Use Python fallback for that module |
| No GPU | Use Google Colab for training (Days 5-6) |
| Dataset not found | Check path. Re-download from Kaggle if needed |
| Images not loading | Check file permissions, try different image |

## Team Coordination

1. **Run both scripts** on your machine
2. **Screenshot** the output (especially any errors)
3. **Share** in team chat/channel
4. **Report** any [FAIL] or [WARN] messages

## What's Next?

After verification:
1. **Assign roles** - See `team/roles.md`
2. **Review roadmap** - Read `roadmap-10day.md` together
3. **Plan tomorrow** - Day 2 is data exploration
