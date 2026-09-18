fid = fopen('C:\projects\DrishtiCare\results\_probe_green.txt', 'w');
if fid < 0
    error('probe cannot open output file');
end
fprintf(fid, 'PROBE=OK\n');
fprintf(fid, 'MLV=%s\n', version);
fclose(fid);