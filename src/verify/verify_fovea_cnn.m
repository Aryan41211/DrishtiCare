cd('C:\projects\DrishtiCare'); addpath(genpath('src'));
origDir = 'data/idrid/A. Segmentation/1. Original Images/a. Training Set';
foveaCsv = 'data/idrid/C. Localization/2. Groundtruths/2. Fovea Center Location/IDRiD_Fovea_Center_Training Set_Markups.csv';

% ---- parse fovea GT CSV ----
fid = fopen(foveaCsv,'r'); fgetl(fid);
gt = nan(54,2);
while ~feof(fid)
    t = fgetl(fid); if isempty(t), continue; end
    p = strsplit(strtrim(t), ','); if isempty(p{1}), continue; end
    tok = regexp(p{1},'IDRiD_(\d+)','tokens','once'); if isempty(tok), continue; end
    n2 = str2double(tok{1});
    if n2>=1 && n2<=54, gt(n2,:)=[str2double(p{2}) str2double(p{3})]; end
end
fclose(fid);

imgFiles = dir(fullfile(origDir,'*.jpg'));
fprintf('%-11s %-22s\n','Image','Fovea err_px');
errF=[]; fok=0; w150=0; w300=0; cumF=[];
for i=1:10
    imgFile=imgFiles(i).name;
    numStr=regexp(imgFile,'IDRiD_(\d+)\.jpg','tokens','once');
    n2=str2double(numStr{1}); id3=sprintf('IDRiD_%03d',n2);
    g = gt(n2,:);
    I=imread(fullfile(origDir,imgFile));
    [cxN,cyN]=locateFoveaCnn(I);
    eN=NaN;
    if ~isempty(cxN)
        eN=norm([cxN cyN]-g); fok=fok+1; cumF(end+1)=eN;
        if eN<=150, w150=w150+1; end
        if eN<=300, w300=w300+1; end
        fprintf('%-11s  located (%.0fpx)\n', id3, eN);
    else
        fprintf('%-11s  NOT located (P<gate)\n', id3);
    end
    errF(end+1)=eN; %#ok<SAGROW>
end
fprintf('\nFovea CNN: nLocated=%d within150=%d within300=%d meanErr=%.0fpx (accepted only)\n', ...
    fok, w150, w300, mean(cumF));
