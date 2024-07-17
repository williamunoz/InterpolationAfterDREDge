function rez = applyDredge(rez)
%% Adapted from Kilosort2.5 function datashift2.m
%% by Richard Hardstone (2022_11_30)

%%
outDir = rez.ops.dredge.outDir;
if ~exist(outDir,'dir')
    mkdir(outDir);
end

%%
if  getOr(rez.ops, 'nblocks', 1)==0
    rez.iorig = 1:rez.temp.Nbatch;
    return;
end

ops = rez.ops;

% The min and max of the y and x ranges of the channels
ymin = min(rez.yc);
ymax = max(rez.yc);
xmin = min(rez.xc);
xmax = max(rez.xc);

% Determine the average vertical spacing between channels.
% Usually all the vertical spacings are the same, i.e. on Neuropixels probes.
dmin = median(diff(unique(rez.yc)));
fprintf('pitch is %d um\n', dmin)
rez.ops.yup = ymin:dmin/2:ymax; % centers of the upsampled y positions

% Determine the template spacings along the x dimension
xrange = xmax - xmin;
npt = floor(xrange/16); % this would come out as 16um for Neuropixels probes, which aligns with the geometry.
rez.ops.xup = linspace(xmin, xmax, npt+1); % centers of the upsampled x positions

spkTh = 8; % same as the usual "template amplitude", but for the generic templates

% Extract all the spikes across the recording that are captured by the
% generic templates. Very few real spikes are missed in this way.
[st3, rez] = standalone_detector(rez, spkTh);

%%
close all
figure(194);
set(gcf, 'Color', 'w')
% raster plot of all spikes at their original depths
st_shift = st3(:,2); %+ imin(batch_id)' * dd;
for j = spkTh:100
    % for each amplitude bin, plot all the spikes of that size in the
    % same shade of gray
    ix = st3(:, 3)==j; % the amplitudes are rounded to integers
    plot(st3(ix, 1)/ops.fs, st_shift(ix), '.', 'color', [1 1 1] * max(0, 1-j/40)) % the marker color here has been carefully tuned
    hold on
end
axis tight

figDir = fullfile(outDir,'DriftMapFigures');
if ~exist(figDir,'dir')
    mkdir(figDir);
end
xlabel('time (sec)')
ylabel('spike position (um)')
title('Drift map')
print('-dpng',fullfile(figDir, 'DriftMap_BeforeRealignment.png'))
saveas(194,fullfile(figDir, 'DriftMap_BeforeRealignment.fig'))
drawnow;


%%
hread = csvread(rez.ops.dredge.Fname);
hread = resample(hread,rez.ops.dredge.dredgeSamples , rez.ops.dredge.BatchSamplesNT);
hread = median(hread) - hread;
rez.ops.NT  = rez.ops.dredge.BatchSamplesNT;

Nbatches = length(hread); %ceil(ops.sampsToRead / rez.ops.dredge.BatchSamplesNT);
rez.temp.Nbatch = Nbatches;
sig = rez.ops.sig;

dprev = gpuArray.zeros(ops.ntbuff,ops.Nchan, 'single');
copyfile(rez.ops.fbinary,rez.ops.dredge.outDat)

copyfile('chanMap.mat' ,  fullfile(outDir,'chanMap.mat'));

for ibatch = 1:Nbatches
    fprintf('Realigning %.1f percent complete\n',100*ibatch/Nbatches);
    dprev = shift_batch_on_disk2_dredge(rez, ibatch, hread(ibatch, :), [], sig, dprev);
end
