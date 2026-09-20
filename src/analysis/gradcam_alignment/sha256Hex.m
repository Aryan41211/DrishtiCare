function h = sha256Hex(p)
%SHA256HEX SHA-256 over a binary file -> uppercase hex string.
    if exist(p,'file')~=2
        h = 'MISSING';
        return;
    end
    % Use system call to PowerShell for reliable SHA256
    cmd = sprintf('powershell -Command "Get-FileHash -Algorithm SHA256 ''%s'' | Select-Object -ExpandProperty Hash"', p);
    [status, result] = system(cmd);
    if status == 0
        h = upper(strtrim(result));
    else
        h = 'ERROR';
    end
end