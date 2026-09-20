function ok = diaryOn(filename)
%DIARYON Start diary to file, return success
%   ok = diaryOn(filename) - returns true if diary started successfully
    try
        diary(filename);
        ok = true;
    catch
        ok = false;
    end
end