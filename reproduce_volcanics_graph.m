function CreateVolumeFigure(dataDir, outDir, fileNumbers)
%CREATEVOLUMEFIGURE  Reproduce the paper figure of the volume of newly
%   formed volcanic material as a function of distance and time, with the
%   trench position, from the marker output files (dsdNNNmark.h5).
%
%   CreateVolumeFigure                       uses the defaults in USER SETTINGS
%   CreateVolumeFigure(dataDir)              reads dsdNNNmark.h5 files in dataDir
%   CreateVolumeFigure(dataDir, outDir)      writes the PNG figure to outDir
%   CreateVolumeFigure(dataDir, outDir, N)   uses output steps N, e.g. 6:67
%
%   Output: volume_vs_time_vs_space_<ModelName>_volcanic.png
%           (without "_volcanic" if Opt.DepthCutoff > 45 km)
%
%   METHOD
%   For every output step:
%   1. Cells are "new volcanic material" if they hold material
%      Opt.VolcanicIds (16 or 19) now but did not hold that same material
%      in the previous output step, and lie above Opt.DepthCutoff.
%      For the first step, the previous state is read from the file
%      before it (step N(1)-1); if that file is missing, all volcanic
%      material present at the first step counts as new.
%   2. For each column, (1 - wt) is summed over these cells, clipped to
%      [Opt.SumThreshold, Opt.WeightUpperBound], and multiplied by the
%      cell area, giving a volume per unit length along strike.
%   3. Trench position: the column with the most cells of materials
%      Opt.TrenchIds (2, 3, 4), shifted by Opt.TrenchOffset.
%   The volumes are then averaged in bins of Opt.BinX (distance) by
%   Opt.BinT (time); each bin is the mean of its non-zero values.
%
%   INPUT FILES
%   Same files and format as CreateFigures.m (see its help text):
%     attribute 'General' on '/' : [xmin xmax ymin ymax time nx ny]
%     /Comp  material ids, run-length encoded
%     /wt    extracted melt
%   All files must use the same grid.
%
%   REQUIREMENTS
%   - MATLAB R2020a or newer (uses exportgraphics).
%   - crameri.m (Scientific colour maps, F. Crameri, doi:10.5281/zenodo.1243862;
%     MATLAB function by C. Greene) on the MATLAB path, for 'batlowW'.

%% ======================== USER SETTINGS ================================
here = fileparts(mfilename('fullpath'));

Opt.DataDir   = fullfile(here, 'data');    % folder with dsdNNNmark.h5
Opt.OutDir    = fullfile(here, 'figures'); % folder for the PNG figure
Opt.Files     = 6:67;                      % output steps; [] = all files
Opt.ModelName = 'test51';                  % used in the file name

% Datasets
Opt.CompDataset   = '/Comp';
Opt.WeightDataset = '/wt';

% Volume calculation
Opt.VolcanicIds      = [16 19];  % material ids of volcanic material
Opt.DepthCutoff      = 40;       % only cells above this depth [km]
Opt.SumThreshold     = 0;        % column sums below this are set to 0
Opt.WeightUpperBound = 4;        % column sums are clipped to this value

% Trench position
Opt.TrenchIds    = [2 3 4];      % material ids used to locate the trench
Opt.TrenchOffset = 20;           % shift added to the trench position [km]

% Binning and plot
Opt.XLim     = [1500 3500];      % distance range [km]
Opt.BinX     = 26;               % bin width in distance [km]
Opt.BinT     = 0.2;              % bin width in time [Myr]
Opt.CLim     = [0 1];            % colour limits [km^3 km^-1]
Opt.FontSize = 20;               % all text scales with this

% Output
Opt.Resolution     = 600;                   % dpi
Opt.FigurePosition = [100 100 1000 700];    % pixels; fixed for reproducibility
%% =======================================================================

if nargin >= 1 && ~isempty(dataDir), Opt.DataDir = dataDir; end
if nargin >= 2 && ~isempty(outDir),  Opt.OutDir  = outDir;  end
if nargin >= 3,                      Opt.Files   = fileNumbers; end

checkRequirements();

if ~exist(Opt.OutDir, 'dir'); mkdir(Opt.OutDir); end

if isempty(Opt.Files)
    Opt.Files = findOutputSteps(Opt.DataDir);
end
if isempty(Opt.Files)
    error('CreateVolumeFigure:noData', 'No dsdNNNmark.h5 files found in %s', Opt.DataDir);
end
Opt.Files = Opt.Files(:).';

% ---- Grid (from the first file) ---------------------------------------
G = readHeader(stepFile(Opt.DataDir, Opt.Files(1)));

% ---- Volumes and trench position for every step ------------------------
nSteps = numel(Opt.Files);
time   = zeros(nSteps, 1);
trench = zeros(nSteps, 1);
volume = zeros(nSteps, G.nx);

prevFile = stepFile(Opt.DataDir, Opt.Files(1) - 1);
if Opt.Files(1) > 1 && exist(prevFile, 'file')
    Cprev = readComposition(prevFile, Opt.CompDataset, G);
else
    Cprev = zeros(G.ny, G.nx);
end

aboveCutoff = G.y(:) <= Opt.DepthCutoff;

for k = 1:nSteps
    fname = stepFile(Opt.DataDir, Opt.Files(k));
    if ~exist(fname, 'file')
        error('CreateVolumeFigure:missingFile', 'File not found: %s', fname);
    end
    fprintf('Reading %s\n', fname);

    H       = double(h5readatt(fname, '/', 'General'));
    time(k) = H(5) / 1e6;                                   % [Myr]
    C       = readComposition(fname, Opt.CompDataset, G);
    wt      = reshape(double(h5read(fname, Opt.WeightDataset)), G.ny, G.nx);

    % New volcanic material above the depth cut-off
    isNew = false(G.ny, G.nx);
    for id = Opt.VolcanicIds
        isNew = isNew | (C == id & Cprev ~= id);
    end
    isNew = isNew & aboveCutoff;

    w = 1 - wt;
    w(~isNew) = 0;
    colSum = sum(w, 1);
    colSum(colSum < Opt.SumThreshold)     = 0;
    colSum(colSum > Opt.WeightUpperBound) = Opt.WeightUpperBound;
    volume(k, :) = colSum * G.cellArea;

    % Trench: column with the most cells of the trench materials
    [~, it]   = max(sum(ismember(C, Opt.TrenchIds), 1));
    trench(k) = G.x(it) + Opt.TrenchOffset;

    Cprev = C;
end

% ---- Bin in distance and time ------------------------------------------
xEdges   = Opt.XLim(1):Opt.BinX:Opt.XLim(2);
tEdges   = min(time):Opt.BinT:max(time);
xCenters = xEdges(1:end-1) + Opt.BinX / 2;
tCenters = tEdges(1:end-1) + Opt.BinT / 2;
binned   = zeros(numel(tCenters), numel(xCenters));

for it = 1:numel(tCenters)
    tMask = time >= tEdges(it) & time < tEdges(it+1);
    for ix = 1:numel(xCenters)
        xMask = G.x >= xEdges(ix) & G.x < xEdges(ix+1);
        sub   = volume(tMask, xMask);
        sub   = sub(sub > 0);
        if ~isempty(sub)
            binned(it, ix) = mean(sub);
        end
    end
end

% ---- Figure ------------------------------------------------------------
fs = Opt.FontSize;
hf = figure('Visible', 'off', 'Units', 'pixels', 'Position', Opt.FigurePosition);
cleanup = onCleanup(@() close(hf));
ax = axes(hf);

imagesc(ax, xCenters, tCenters, binned);
set(ax, 'YDir', 'normal');
hold(ax, 'on');
hTrench = plot(ax, trench, time, 'k-', 'LineWidth', 1.0);
hold(ax, 'off');
xlim(ax, Opt.XLim);
colormap(ax, flipud(crameri('batlowW', 256)));
set(ax, 'CLim', Opt.CLim);

cb = colorbar(ax);
ylabel(cb, 'Volume [km^3 km^{-1}]', 'FontSize', fs);
cb.FontSize = fs - 2;

ax.FontSize = fs;
% Narrower, raised axes so the large labels fit; shorter colour bar
p = ax.Position;
ax.Position = [p(1), p(2) + 0.08, p(3) * 0.85, p(4) - 0.08];
p = cb.Position;
h = p(4) * 0.7;
cb.Position = [p(1), p(2) + (p(4) - h) / 2, p(3), h];

xlabel(ax, 'Distance [km]', 'FontSize', fs);
ylabel(ax, 'Time [Myr]', 'FontSize', fs);
lgd = legend(ax, hTrench, {'Trench'}, 'Location', 'southeast');
lgd.FontSize = fs - 2;

if Opt.DepthCutoff <= 45
    name = sprintf('volume_vs_time_vs_space_%s_volcanic.png', Opt.ModelName);
else
    name = sprintf('volume_vs_time_vs_space_%s.png', Opt.ModelName);
end
drawnow;
exportgraphics(hf, fullfile(Opt.OutDir, name), 'Resolution', Opt.Resolution);
fprintf('Figure written to %s\n', fullfile(Opt.OutDir, name));
end


%% ========================= DATA INPUT ==================================

function fname = stepFile(dataDir, n)
fname = fullfile(dataDir, sprintf('dsd%03dmark.h5', n));
end


function G = readHeader(fname)
H = double(h5readatt(fname, '/', 'General'));
G.nx = round(H(6));
G.ny = round(H(7));
G.x  = linspace(H(1), H(2), G.nx) / 1e3;      % [km]
G.y  = linspace(H(3), H(4), G.ny) / 1e3;      % [km]
dx   = (H(2) - H(1)) / (G.nx - 1) / 1e3;      % [km]
% NOTE: as in the computation used for the paper, the vertical spacing is
% divided by (nx - 1). The true vertical spacing is
% (H(4) - H(3)) / (G.ny - 1) / 1e3.
dy   = (H(4) - H(3)) / (G.nx - 1) / 1e3;      % [km]
G.cellArea = dx * dy;                         % [km^2]
end


function C = readComposition(fname, dataset, G)
C = decodeComposition(h5read(fname, dataset), G.nx, G.ny);
end


function C = decodeComposition(raw, nx, ny)
% Decode the run-length encoded material field (see CreateFigures.m).
raw = double(raw(:));
n   = numel(raw);
C   = ones(ny, nx);
k   = 1;
ind = 1;
while k <= n
    if raw(k) == -2
        count = raw(k+1);
        mat   = raw(k+2);
        k     = k + 3;
    else
        count = 1;
        mat   = raw(k);
        k     = k + 1;
    end
    if mat == -1; mat = 0; end
    C(ind:ind+count-1) = mat;
    ind = ind + count;
end
end


function steps = findOutputSteps(dataDir)
d = dir(fullfile(dataDir, 'dsd*mark.h5'));
tok = regexp({d.name}, '^dsd(\d+)mark\.h5$', 'tokens', 'once');
tok = tok(~cellfun(@isempty, tok));
steps = sort(cellfun(@(t) str2double(t{1}), tok));
end


function checkRequirements()
if exist('exportgraphics', 'file') == 0
    error('CreateVolumeFigure:matlabVersion', 'MATLAB R2020a or newer is required (exportgraphics).');
end
if exist('crameri', 'file') ~= 2
    error('CreateVolumeFigure:crameri', ...
        ['crameri.m not found. Download it (Scientific colour maps, ' ...
         'doi:10.5281/zenodo.1243862) and add it to the MATLAB path.']);
end
end