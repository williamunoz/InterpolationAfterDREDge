%function [cleanDataLFP] = GetLFP_Realignment_Params(PtID,TTLchan,nFFT,fs_scale,smoothBetweenBlocks,lowPassFreq,doCMR);
% Realignment and zaplined LFP from Neuropixels data.
% written by R. Hardstone & W. Munoz.   rhardstone@gmail.com
% Version 1.0. This version used for figures in Windolf et. al (Nature Methods, 2024)
%
% STEPS:
% 1. Load data
% 2. Pruning data
% 3. Check For and remove Bad Channels
% 4. LP filter at 500 Hz
% 5. Downsample to 1250 Hz 
% 6a. Pick Line Noise Frequencies 
% 6b. Zapline: remove 60 Hz noise and other Line Noise Frequencies 
% 7. Optional: Common Median Reference
% 8: Center dredge signal
% 9. Shift using adapted kilosort shifter
% 10: Zapline: Remove pulse artifact
% 11: Plot results of zapline 
% 13: Save data

%Files required:
%   lf .bin file
%   chanMap.mat 
%   DepthMicrons.csv
% Set location of these files in lines 50-56
%% Set paths...
clear all
close all
clc
restoredefaultpath;

scriptsDir = 'C:\InterpolationAfterDREDge\Scripts\';
addpath(genpath([scriptsDir 'ExternalPackages\Kilosort-2.5\']));
addpath(genpath([scriptsDir 'LFP\']));
addpath(genpath([scriptsDir 'ExternalPackages\zapline-plus-main']));  % download from https://github.com/MariusKlug/zapline-plus

%% Set params...
PtID = 'Example_DataID';
TTLchan = 0;                %boolean: whether lfp binary file contains a TTL channel. TTL channel assumed to be the last channel
nFFT = 2^13;                %2^13 seems to work well for 1250 Hz
fs_scale = 2;               %Downsample factor (e.g. 2 to downsample from 2500 to 1250 Hz)
smoothBetweenBlocks = 2;    %number of samples between blocks to smooth (see shift_LFP_data)
lowPassFreq = 500;          %Anti-aliasing filter
doCMR = false;              %Boolean to decide whether to do common median referencing in Step 7
stable_time = [50 140];     %Time selected in recording
lfpFS = 2500;               %sampling rate of lfp
numNPchans = 384;           % number of non-TTL Neuropixel channels


%% Set location of files and  directory/filenames to save
patientFiles.rawlfp         = ['F:\Example\Example.imec0.lf.bin'];
patientFiles.chanMap        = ['F:\Example\chanMap.mat'];
patientFiles.dredge         = ['F:\Example\DepthMicrons.csv'];
patientFiles.saveDirectory  = ['F:\Example\LFP\'];
patientFiles.figfolder      = ['F:\Example\FIGS\'];
patientFiles.saveName       = ['F:\' PtID '\LFP\' PtID '.RealignedLFP.lfp'];
patientFiles.saveNameMat    = ['F:\' PtID '\LFP\' PtID '.RealignedLFP.mat'];


if ~exist(patientFiles.saveDirectory,'dir')
    mkdir(patientFiles.saveDirectory);
end
if ~exist(patientFiles.figfolder,'dir')
    mkdir(patientFiles.figfolder);
end


load(patientFiles.sessionInfo );
num_of_raw_channels_in_rawlfp = numNPchans+TTLchan;

goodChans = [1:384];                    % remove any flat  channels from this list
noiseFreqs  = [60];                     % e.g. [60 72.3]  % select any sharp line noise components (sometimes lights will produce this noise at non-line noise frequencies)
pulseFreqs = []; %E.g. [1.07 2.14 3.05 4.12 5.19]; % frequencies where pulse artifact is strongest.  should be selected in Step 6a
if isempty(pulseFreqs)
    disp('Need to set Pulse artifact frequencies in Step 6a');
end

%% Step 1: load all data
load(patientFiles.chanMap  ,'xcoords','ycoords');
shifts = csvread(patientFiles.dredge);

temp_rawLF = memmapfile(patientFiles.rawlfp ,'Format', 'int16'); %LFP
rawLF_memmap = memmapfile(patientFiles.rawlfp , 'Format',{'int16', [num_of_raw_channels_in_rawlfp, length(temp_rawLF.Data)/num_of_raw_channels_in_rawlfp], 'data'});
rawLFData = rawLF_memmap.Data.data;
lfpdata = double(rawLFData);
clear rawLF* temp_rawLF REST* 

%% Step2: Prune data
LFP_timestamp = [1:length(lfpdata)]/lfpFS; %%
samples_LFP = find(LFP_timestamp>stable_time(1) & LFP_timestamp<=stable_time(2));
lfpdata = lfpdata(1:sessionInfo.nChannels,samples_LFP);

%% Step3: Check For and remove Bad Channels
figure
plot(std(lfpdata,[],2));
title('Step3: Check For Bad Channels')

figure
plot(std(lfpdata(goodChans,:),[],2));
title('Step3: Check For Bad Channels')

if isempty(goodChans)
     error('Step 3: goodChans cannot be empty')
end

lfpdata = lfpdata(goodChans,:);
xcoords = xcoords(goodChans,1);
ycoords = ycoords(goodChans,1);

%% Step 4: LP filter at 500 Hz
filterOrder = 3;
[lpb,lpa] = butter(filterOrder,(lowPassFreq*2)/lfpFS,'low');
LP_lfpdata  = filtfilt(lpb,lpa,lfpdata')';

%% Step 5: Downsample to 1250 Hz
ds_fs = lfpFS / fs_scale;
lfpdataDS = downsample(LP_lfpdata',fs_scale);
clear LP_lfpdata lfpdata

%% Step 6a: Pick pulse frequencies and Line Noise Frequencies
nF = (nFFT / 2) + 1;
ps_lfpData_DS = zeros(length(goodChans),nF);
for i = 1:length(goodChans)
    [ps_lfpData_DS(i,:),f] = pwelch(lfpdataDS(:,i),hamming(nFFT),[],nFFT,ds_fs);
end

figure
plot(f,mean(log10(ps_lfpData_DS)))
title('Step 6a: Pick line noise and pulse frequencies');

%% Step 6b: Zapline to remove noise Frequencies
[lineNoiseRemovedSignal, lineNoiseRemovedSignal_zaplineConfig, lineNoiseRemovedSignal_analyticsResults, lineNoiseRemovedSignal_plothandles] = clean_data_with_zapline_plus_With_NFFT(lfpdataDS, ds_fs, ...
    'noisefreqs',noiseFreqs,...
    'nfft',nFFT,...
    'plotResults',0);

nF = (nFFT / 2) + 1;
ps_lineNoiseRemovedSignal = zeros(length(goodChans),nF);
for i = 1:length(goodChans)
    [ps_lineNoiseRemovedSignal(i,:),f] = pwelch(lineNoiseRemovedSignal(:,i),hamming(nFFT),[],nFFT,ds_fs);
end

figure
plot(f,mean(log10(ps_lineNoiseRemovedSignal)));
hold on
plot(f,mean(log10(ps_lfpData_DS)));
legend({'Post ' num2str(noiseFreqs) 'Hz removal', 'Before Zapline'});
xlim([0 100]);

tmp = ['NoiseZL_LFPSpec_nFFT' num2str(nFFT) '_NL' num2str(noiseFreqs)];
tmp = strrep(tmp,' ','_');

saveas(gcf,[patientFiles.figfolder PtID '_' tmp '.fig']);


%% Step 7 Common median reference
if doCMR
    lineNoiseRemovedSignal = lineNoiseRemovedSignal - repmat(median(lineNoiseRemovedSignal,2),[1 size(lineNoiseRemovedSignal,2)]);
    nF = (nFFT / 2) + 1;
    ps_lineNoiseRemovedSignal = zeros(length(goodChans),nF);
    for i = 1:length(goodChans)
        [ps_lineNoiseRemovedSignal_CMR(i,:),f] = pwelch(lineNoiseRemovedSignal(:,i),hamming(nFFT),[],nFFT,ds_fs);
    end

    figure;
    plot(f,mean(log10(ps_lineNoiseRemovedSignal)));
    hold on
    plot(f,mean(log10(ps_lineNoiseRemovedSignal_CMR)));
    legend({'Before CMR', 'After CMR'});

    tmp = ['CMR_LFPSpec_nFFT' num2str(nFFT) '_NL' num2str(noiseFreqs)];
    tmp = strrep(tmp,' ','_');
    saveas(gcf,[patientFiles.figfolder PtID '_' tmp '.fig']);
    close all;
end

%% Step 8: Center dredge signal
shifts = median(shifts) - shifts; %Make sure that centering of dredge signal has been done in same way as for the AP realignment (applyDredge.m, line 72: hread = median(hread) - hread;) 

%% Step 9: Realign using Kilosort Kriging
sigmaMask = 60;
[shiftedLFP] = shift_LFP_data(lineNoiseRemovedSignal', ds_fs, shifts, shiftsFS,  xcoords, ycoords, smoothBetweenBlocks,sigmaMask);

%% Step 10: Remove Pulse artifact using zapline
clear lineNoiseRemovedSignal* lfpdataDS
pChans = 1:length(padded_goodChans);

[cleanData, cleanData_zaplineConfig, cleanData_analyticsResults, cleanData_plothandles] = clean_data_with_zapline_plus_With_NFFT(shiftedLFP(pChans,:),ds_fs, ...
    'noisefreqs',pulseFreqs,...
    'detectionWinsize',1.15, ...
    'nfft', nFFT, ...   
    'plotResults',0);

%% Step 11: Plot results of zapline 
clear ps*
nF = (nFFT / 2) + 1;
ps_lfpData_DS = zeros(length(pChans),nF);
ps_cleanData = zeros(length(pChans),nF);

for i = 1:length(pChans)
    [ps_lfpData_DS(i,:),f] = pwelch(shiftedLFP(i,:),hamming(nFFT),[],nFFT,ds_fs);
    [ps_cleanData(i,:),f] = pwelch(cleanData(i,:),hamming(nFFT),[],nFFT,ds_fs);
end

nchans = size(pChans,1);
figure;
clear h
h(1) = subplot(3,1,1);
plot(f,mean(log10(ps_lfpData_DS)))
hold on
plot(f,mean(log10(ps_cleanData)))
h(2) = subplot(3,1,2);
imagesc(f,nchans,log10(ps_lfpData_DS))
h(3) = subplot(3,1,3);
imagesc(f,nchans,log10(ps_cleanData))
linkaxes(h,'x');
xlim([1 25]);
title('Step 12: Plot results of zapline');

tmp = ['PulseZL_LFPSpec_nFFT' num2str(nFFT) '_NL' num2str(pulseFreqs)];
tmp = strrep(tmp,' ','_');
saveas(gcf,[patientFiles.figfolder PtID '_' tmp '.fig']);

close all

%% Step 12: Save data

save(patientFiles.saveNameMat,'-v7.3','*coords','shifts','noiseFreqs','pulseFreqs','cleanData','stable_time','cleanDataFS','patientFiles');

