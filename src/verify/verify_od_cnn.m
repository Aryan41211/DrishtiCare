cd('C:\projects\DrishtiCare'); addpath(genpath('src'));
origDir = 'data/idrid/A. Segmentation/1. Original Images/a. Training Set';
odMaskDir = 'data/idrid/A. Segmentation/2. All Segmentation Groundtruths/a. Training Set/5. Optic Disc';
imgFiles = dir(fullfile(origDir,'*.jpg'));
fprintf('%-11s %-10s %-28s %-28s\n','Image','', 'Classical err_px','CNN err_px');
errC=[]; errN=[]; cok=0; nok=0; cumC=[]; cumN=[];
for i=1:10
    imgFile=imgFiles(i).name;
    numStr=regexp(imgFile,'IDRiD_(\d+)\.jpg','tokens','once');
    n2=str2double(numStr{1}); id3=sprintf('IDRiD_%03d',n2);
    m=imread(fullfile(odMaskDir,sprintf('IDRiD_%02d_OD.tif',n2)))>0;
    st=regionprops(m,'Centroid','Area'); [~,k]=max([st.Area]); gt=st(k).Centroid;
    est=estimateOpticDisc(fullfile(origDir,imgFile));
    eC=NaN; if ~isempty(est), eC=norm(est(1:2)-gt); cok=cok+1; cumC(end+1)=eC; end
    I=imread(fullfile(origDir,imgFile));
    [cxN,cyN]=locateOpticDiscCnn(I);
    eN=NaN; if ~isempty(cxN), eN=norm([cxN cyN]-gt); nok=nok+1; cumN(end+1)=eN; end
    g=double(I(:,:,2));
    briC=NaN; if ~isempty(est), rr=60; briC=mean(g(max(1,round(est(2))-rr):min(size(g,1),round(est(2))+rr), max(1,round(est(1))-rr):min(size(g,2),round(est(1))+rr)),'all'); end
    briN=NaN; if ~isempty(cxN), rr=60; briN=mean(g(max(1,round(cyN)-rr):min(size(g,1),round(cyN)+rr), max(1,round(cxN)-rr):min(size(g,2),round(cxN)+rr)),'all'); end
    fprintf('%-11s %-10s %-28s %-28s  briC=%.0f briN=%.0f\n', id3,'', ...
        sprintf('%-4s (%.0fpx)', (eC<=300)+"", eC), sprintf('%-4s (%.0fpx)', (eN<=300)+"", eN), briC, briN);
    errC(end+1)=eC; errN(end+1)=eN;
end
fprintf('\nClassical: nLocated=%d within300=%d meanErr=%.0fpx\n', cok, sum(errC<=300 & ~isnan(errC)), mean(cumC));
fprintf('CNN      : nLocated=%d within300=%d meanErr=%.0fpx\n', nok, sum(errN<=300 & ~isnan(errN)), mean(cumN));