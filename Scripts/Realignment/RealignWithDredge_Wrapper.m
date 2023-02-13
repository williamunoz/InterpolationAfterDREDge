clear all;
close all;
restoredefaultpath;

scriptsDir = 'C:\Publish_Human_Layers\'; %Change to the directory where repository is
addpath(genpath([scriptsDir 'Scripts/Realignment/']));
addpath(genpath('Kilosort-2.5/'));%Change to the directory where Kilosort2.5 is
%% Requirements
%basePath folder should contain .dat file named the same as containing
%folder
%basePath should contain chanMap.mat
%e.g. if basePath = 'c:/data/Subject01/';
%then this folder should contain:
%  Subject01.dat
%  chanMap.mat

%%
basepath = 'Data'; %Set to base folder contatining .dat file, and dredge.csv file
config_version = 'Dredge';

dredgeParams.Fname             = 'dredge.csv'; %set to file containing dredge realignment
dredgeParams.fs                = 250; %Sampling rate of dredge file in Hz
dredgeParams.BatchSamplesNT    = 128; %dredge will be applied at a rate of 30000/BatchSamplesNT; for reference: NT = 64 for ~500Hz,...
                                      %NT = 128 for ~250Hz, NT = 320 for ~100 Hz, NT = 576 for ~50 Hz, NT =
                                      %1088 for ~25Hz, NT = 65600 for ~0.5Hz
dredgeParams.outName           = ['manualDREDgeKS_NT' num2str(dredgeParams.BatchSamplesNT)];

%%
RealignRecordingUsingDredgeAndKilosort2point5(basepath,config_version,dredgeParams)

basepath = fullfile(basepath,dredgeParams.outName);
MakeDriftMapUsingKS25(basepath,config_version)







