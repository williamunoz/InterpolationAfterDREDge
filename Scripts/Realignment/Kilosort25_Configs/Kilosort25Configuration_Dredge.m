function ops = Kilosort25Configuration_Dredge(dredgeParams)


%% RH edits  CODE
rootpath = pwd;
[~,ed] = fileparts(pwd);
ops.chanMap             = fullfile(rootpath,'chanMap.mat'); % make this file using createChannelMapFile.m
load(fullfile(rootpath,'chanMap.mat'))
ops.NchanTOT            = length(connected); % total number of channels
ops.Nchan = sum(~connected); % number of active channels

templatemultiplier = 9;
ops.Nchan              = sum(connected>1e-6); % number of active channels
ops.Nfilt              =   max(ops.Nchan*templatemultiplier - mod(ops.Nchan*templatemultiplier,32),16); % number of filters to use (2-4 times more than Nchan, should be a multiple of 32)
% binary file
ops.fbinary             = [ed  '.dat']; % will be created for 'openEphys'
ops.ForceMaxRAMforDat   = 15000000000;
% sample rate
ops.fs                  = 30000;        % sampling rate
ops.parfor              = 0; % whether to use parfor to accelerate some parts of the algorithm

ops.trange = [0 Inf]; % time range to sort
fname = fullfile(rootpath,'PreprocessedData.dat');
ops.fproc = fname;
%%
if ~isempty(dredgeParams)
    ops.dredge = dredgeParams;
    ops.dredge.dredgeSamples = ops.fs/dredgeParams.fs;
    ops.dredge.outDir = fullfile(rootpath,dredgeParams.outName);
    ops.dredge.outDat = fullfile(ops.dredge.outDir,[ops.dredge.outName '.dat']);
end

%%
% frequency for high pass filtering (150)
ops.fshigh = 150;

% minimum firing rate on a "good" channel (0 to skip)
ops.minfr_goodchannels = 0;

% threshold on projections (like in Kilosort1, can be different for last pass like [10 4])
ops.Th = [10 4];

% how important is the amplitude penalty (like in Kilosort1, 0 means not used, 10 is average, 50 is a lot)
ops.lam = 10;

% splitting a cluster at the end requires at least this much isolation for each sub-cluster (max = 1)
ops.AUCsplit = 0.9;

% minimum spike rate (Hz), if a cluster falls below this for too long it gets removed
ops.minFR = 1/25;

% number of samples to average over (annealed from first to second value)
ops.momentum = [20 400];

% spatial constant in um for computing residual variance of spike
ops.sigmaMask = 30;

% threshold crossings for pre-clustering (in PCA projection space)
ops.ThPre = 8;

% type of data shifting (0 = none, 1 = rigid, 2 = nonrigid)
ops.nblocks = 1;

ops.smoothValue = 32; %Needs to be changed for use iin datashift2_RH align_block2_RH functions
ops.sig = 30;       
%% danger, changing these settings can lead to fatal errors
% options for determining PCs
ops.spkTh           = -6;      % spike threshold in standard deviations (-6)
ops.reorder         = 1;       % whether to reorder batches for drift correction.
ops.nskip           = 25;  % how many batches to skip for determining spike PCs

ops.GPU                 = 1; % has to be 1, no CPU version yet, sorry
% ops.Nfilt               = 1024; % max number of clusters


ops.nfilt_factor        = 4; % max number of clusters per good channel (even temporary ones)
ops.ntbuff              = 64;    % samples of symmetrical buffer for whitening and spike detection
ops.NT                  = 64*1024 + ops.ntbuff; % must be multiple of 32 + ntbuff. This is the batch size (try decreasing if out of memory).
ops.whiteningRange      = 32; % number of channels to use for whitening each channel
ops.nSkipCov            = 25; % compute whitening matrix from every N-th batch
ops.scaleproc           = 200;   % int16 scaling of whitened data
ops.nPCs                = 3; % how many PCs to project the spikes into
ops.useRAM              = 0; % not yet available