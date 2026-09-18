msgs = checkcode('C:\projects\DrishtiCare\src\reporting\generateDrishtiReport.m', '-string');
try
    msgs = checkcode('C:\projects\DrishtiCare\src\reporting\generateDrishtiReport.m', '-string');
catch e
    msgs = evalin('base', '{}');
    fid = fopen('C:\projects\DrishtiCare\results\_cc_err.txt','w');
    fprintf(fid, '%s: %s\n', e.identifier, e.message);
    fclose(fid);
end
fid = fopen('C:\projects\DrishtiCare\results\_cc_dump.txt','w');
if isempty(msgs)
    fprintf(fid, 'CLEAN NO MESSAGES\n');
else
    for k=1:numel(msgs)
        fprintf(fid, '%s\n', msgs{k});
    end
end
fclose(fid);
