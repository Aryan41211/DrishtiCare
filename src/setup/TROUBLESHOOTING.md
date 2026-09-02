# Day 1 Troubleshooting Guide

## Common Issues and Solutions

---

### Issue 1: MATLAB Campus License Not Working

**Symptoms:** Can't log in, license error, "Invalid credentials"

**Solutions:**
1. Use college email (not personal Gmail)
2. Go to: https://www.mathworks.com/login
3. Click "Academic - Sign In"
4. Enter college email and password

**If campus license fails:**
1. Go to: https://www.mathworks.com/campaigns/products/trials.html
2. Sign up for free trial (30 days)
3. Download MATLAB Desktop OR use MATLAB Online

**Fallback:**
- MATLAB Online (browser): https://www.mathworks.com/products/matlab-online.html
- No installation needed, works on any computer

---

### Issue 2: Missing Toolboxes

**Symptoms:** `[FAIL]` message for specific toolbox

**Solutions:**
1. Note which toolbox is missing
2. Check if it's available separately:
   ```matlab
   ver
   ```
3. Ask team lead if purchase is possible

**Fallback per toolbox:**
| Missing Toolbox | Workaround |
|-----------------|------------|
| Image Processing | Use basic MATLAB image functions |
| Computer Vision | Manual augmentation code |
| Deep Learning | Use Python/PyTorch, export ONNX |
| Statistics | Manual metric calculations |
| Simulink | MATLAB script with assumed numbers |

---

### Issue 3: No GPU Detected

**Symptoms:** `[WARN] No GPU detected`

**Impact:** Training will be 10-50x slower

**Solutions:**
1. **Best:** Use Google Colab (free GPU)
   - Go to: https://colab.research.google.com
   - Runtime > Change runtime type > GPU
   - Train in PyTorch, export to ONNX

2. **Alternative:** Train on a teammate's gaming laptop
3. **Last resort:** Use CPU (will take hours, not minutes)

---

### Issue 4: Dataset Not Found

**Symptoms:** `[FAIL] Dataset not found`

**Solutions:**
1. Check if downloaded:
   ```
   data/aptos2019/
   ├── train_images/    (should have 3,662 files)
   ├── test_images/     (should have 1,928 files)
   ├── train.csv
   └── test.csv
   ```

2. If missing, download from Kaggle:
   - Go to: https://www.kaggle.com/c/aptos2019-blindness-detection/data
   - Click "Download All" (requires free Kaggle account)
   - Extract to `data/aptos2019/`

3. If Kaggle blocked, use alternative download:
   ```bash
   pip install kaggle
   kaggle competitions download -c aptos2019-blindness-detection
   ```

---

### Issue 5: Images Not Displaying

**Symptoms:** Black screen, error on `imshow`, figures don't appear

**Solutions:**
1. Check MATLAB graphics:
   ```matlab
   figure;
   imshow(zeros(100,100));
   ```
   If this works, issue is with image loading.

2. Check image file:
   ```matlab
   info = imfinfo('path/to/image.png');
   disp(info);
   ```

3. Try different display method:
   ```matlab
   img = imread('path/to/image.png');
   image(img);
   ```

---

### Issue 6: Git/GitHub Access Problems

**Symptoms:** Can't push, clone, or access repo

**Solutions:**
1. Check Git is installed:
   ```bash
   git --version
   ```

2. Clone the repo:
   ```bash
   git clone <repo-url>
   ```

3. If permission denied:
   - Ask repo owner to add your GitHub username
   - Or use HTTPS instead of SSH

4. If behind proxy:
   ```bash
   git config --global http.proxy http://proxy:port
   ```

---

### Issue 7: Slow Performance

**Symptoms:** MATLAB freezing, long load times

**Solutions:**
1. Close other applications
2. Reduce MATLAB cache:
   ```matlab
   prefdir  % Shows cache location
   ```
3. Work with smaller image subset first
4. Use MATLAB Online (runs on cloud servers)

---

## Emergency Contacts

| Issue Type | Contact |
|------------|---------|
| MATLAB License | MathWorks Support: 508-647-7000 |
| GitHub Access | Team Lead: _______________ |
| Dataset Issues | Kaggle Forum or Team Lead |
| Hardware Issues | College IT Lab |

---

## If All Else Fails

**Plan B:** Switch to Python + Google Colab

1. Install Python: https://python.org
2. Install Jupyter: `pip install jupyter`
3. Use Colab for GPU training
4. Export model to ONNX
5. Import ONNX to MATLAB

**This is a valid fallback, not a failure.**
The judges care about the result, not the tool.

---

## Escalation Path

1. **Self-fix** (5 min) → Try solutions above
2. **Ask teammate** (10 min) → Pair debugging
3. **Ask team lead** (15 min) → Decision needed
4. **Escalate to mentor** (30 min) → Critical blocker
5. **Switch to fallback** (1 hour) → Alternative approach

**Remember:** Day 1 is for setup. It's okay if things don't work perfectly.
The goal is to identify issues early and have solutions ready.
