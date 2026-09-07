% verify_fuseEvidence.m
addpath(genpath('C:\projects\DrishtiCare\src'));
% A referable + B referable -> agree
[ag,dis,d] = fuseEvidence(struct('grade',3,'pRefCal',0.95,'confident',true), struct('pRefB',0.8,'available',true));
assert(ag && ~dis && strcmp(d.routeOverride,''));
% A referable + B non -> discrepancy REVIEW
[ag,dis,d] = fuseEvidence(struct('grade',3,'pRefCal',0.95,'confident',true), struct('pRefB',0.2,'available',true));
assert(~ag && dis && strcmp(d.routeOverride,'REVIEW'));
% both non, confident -> agree
[ag,dis,d] = fuseEvidence(struct('grade',0,'pRefCal',0.01,'confident',true), struct('pRefB',0.1,'available',true));
assert(ag && ~dis);
% both non, NOT confident -> discrepancy REVIEW
[ag,dis,d] = fuseEvidence(struct('grade',1,'pRefCal',0.45,'confident',false), struct('pRefB',0.2,'available',true));
assert(~ag && dis && strcmp(d.routeOverride,'REVIEW'));
% B unavailable -> no conflict
[ag,dis,d] = fuseEvidence(struct('grade',3,'pRefCal',0.95,'confident',true), struct('pRefB',NaN,'available',false));
assert(~ag && ~dis && strcmp(d.routeOverride,''));
% A non-referable but B referable -> discrepancy REVIEW
[ag,dis,d] = fuseEvidence(struct('grade',0,'pRefCal',0.01,'confident',true), struct('pRefB',0.9,'available',true));
assert(~ag && dis && strcmp(d.routeOverride,'REVIEW'));
fprintf('fuseEvidence: 6/6 assertions pass\n');