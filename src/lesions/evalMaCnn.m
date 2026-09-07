function evalMaCnn()
%EVALMACNN Compute corrected held-out metrics from trained MA CNN
projRoot = 'C:\projects\DrishtiCare'; cd(projRoot);
addpath(fullfile(projRoot,'src','lesions'));
out = fullfile(projRoot,'data','analysis','day8','ma_cnn');
S = load(fullfile(out,'ma_dataset.mat'));
N = load(fullfile(out,'ma_cnn_net.mat'));
vl = find(S.split=='val');
lbl = S.labels(vl);
ds = augmentedImageDatastore([48 48 3], S.patches(:,:,:,vl), lbl, 'OutputSizeMode','resize');
[Y, sc] = classify(N.net, ds);
acc = mean(Y==lbl);
scMA = sc(:,1);   % column1 = MA (Classes=['MA','BG'])
[~,ord] = sort(scMA,'descend');
[X,Yc,T,AUC] = perfcurve(double(lbl=='MA'), scMA, 1);
prec = cumsum(double(lbl(ord)=='MA'))./ (1:numel(vl))';
rec  = cumsum(double(lbl(ord)=='MA'))./sum(lbl=='MA');
fprintf('acc=%.3f AUC=%.3f\n', acc, AUC);
fprintf('prec@recall>=0.5 = %.3f\n', max(prec(rec>=0.5)));
fprintf('rec@prec>=0.5 = %.3f\n', max(rec(prec>=0.5)));
% operating point at threshold 0.75 on MA prob
tr = 0.75;
rAt = mean(scMA(lbl=='MA')>=tr);
fAt = mean(scMA(lbl=='BG')>=tr);
fprintf('thr=%.2f: MA recall=%.3f  BG-FP-rate=%.3f\n', tr, rAt, fAt);
save(fullfile(out,'ma_cnn_metrics.mat'),'acc','AUC','X','Y','T','-v7.3');
end