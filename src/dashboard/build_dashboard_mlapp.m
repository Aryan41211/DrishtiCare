% build_dashboard_mlapp.m
% T12: package DRScreeningDashboard.m as a real .mlapp App Designer file.
%
% The dashboard class (matlab.apps.AppBase) is authored as a plain .m so it
% is human-reviewable and diffable in git. App Designer is installed on this
% machine but cannot run headlessly to emit a .mlapp, so:
%   1. verify the class instantiates headlessly (run src/dashboard/verify_dashboard.m)
%   2. open the class in App Designer so the user can save it as
%      'DRScreeningDashboard.mlapp' (File > Save As), placed in src/dashboard/
%
% Both paths produce the SAME behaviour; the .mlapp is a packaging convenience
% only. The .m class remains the source of truth.
addpath(genpath(fullfile(pwd, 'src')));

if ~matlab.desktop.isdesktop
    warning('No desktop here, so App Designer cannot open. On a desktop run:');
    fprintf('  >> appdesigner(''%s'')\n', fullfile(pwd, 'src', 'dashboard', 'DRScreeningDashboard.m'));
    return;
end

a = DRScreeningDashboard();
fprintf('Dashboard OK: %s\n', a.UIFigure.Name);
a.delete();

fprintf('\nNow: Type\n  >> appdesigner\nFile > Open -> src/dashboard/DRScreeningDashboard.m\n');
fprintf('File > Save As -> src/dashboard/DRScreeningDashboard.mlapp\n');
open(fullfile(pwd, 'src', 'dashboard', 'DRScreeningDashboard.m'));