clear all;
close all;
restoredefaultpath;

scriptsDir = 'C:\InterpolationAfterDREDge\'; %Change to the directory where repository is
addpath(genpath([scriptsDir 'Scripts/AP/']));
addpath(genpath('Kilosort-2.5/'));%Change to the directory where Kilosort2.5 is
%% Requirements
%basePath folder should contain .dat file named the same as containing
%folder
%basePath should contain chanMap.mat
%e.g. if basePath = 'c:/data/Subject01/';
%then this folder should contain:
%  rawData.imec0.ap.bin
%  dredge.csv    (in microns)

%%
basepath  = 'Data'; %Set to base folder containing .dat file, and dredge.csv file
raw_fname = 'raw.imec0.ap.bin'; %Set to .bin file containing raw data (unpruned)

config_version = 'Dredge';

dredgeParams.Fname             = 'dredge.csv'; %set to file containing dredge realignment
dredgeParams.fs                = 250; %Sampling rate of dredge file in Hz
dredgeParams.BatchSamplesNT    = 128; %dredge will be applied at a rate of 30000/BatchSamplesNT; for reference: NT = 64 for ~500Hz,...
                                      %NT = 128 for ~250Hz, NT = 320 for ~100 Hz, NT = 576 for ~50 Hz, NT =
                                      %1088 for ~25Hz, NT = 65600 for ~0.5Hz
dredgeParams.outName           = ['manualDREDgeKS_NT' num2str(dredgeParams.BatchSamplesNT)];

recordingParams.raw_fname = fullfile(basepath, raw_fname);
recordingParams.sampfreq = 30000;     %sampling rate in Hz of raw file
recordingParams.stable_time = [1 100]; %Timewindow in seconds for analysis
recordingParams.channels = 0:383;      
recordingParams.hasTriggerChannel = 1; %1 if there is a trigger channel in raw file, 0 otherwise
recordingParams.outputDirectory = basepath;
recordingParams.outfname = 'Data.dat';  %Output filename should be same as directoryname

% This should be the Kilosort channel map which is different from the channel map used by DREDge
ChannelMapUsed = fullfile(scriptsDir,'Scripts','Realignment','Kilosort25_Configs','ShortChannelMap.mat');
copyfile(ChannelMapUsed,fullfile(basepath,'chanMap.mat'));

%%
PruneRecording(recordingParams);

%%
RealignRecordingUsingDredgeAndKilosort2point5(basepath,config_version,dredgeParams)

basepath = fullfile(basepath,dredgeParams.outName);
MakeDriftMapUsingKS25(basepath,config_version)




