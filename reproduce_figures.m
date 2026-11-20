function ReproduceFigures(dataDir, outDir, fileNumbers)
%ReproduceFigures  Reproduce the model figures of the paper from the marker
%   output files (dsdNNNmark.h5) of the numerical simulations.
%
%   ReproduceFigures                       uses the defaults in USER SETTINGS
%   ReproduceFigures(dataDir)              reads dsdNNNmark.h5 files in dataDir
%   ReproduceFigures(dataDir, outDir)      writes the PNG figures to outDir
%   ReproduceFigures(dataDir, outDir, N)   plots output steps N only,
%                                       e.g. 11 or [5 11 20]
%
%   For every output step NNN the following figures are produced
%   (each can be switched on/off in Opt.Plot below):
%
%     Composition_NNN.png           material (composition) field
%     CompositionVelocity_NNN.png   material field + velocity arrows
%     Temperature_NNN.png           absolute temperature + isotherms
%                                   + velocity arrows
%     TemperatureAnomaly_NNN.png    temperature anomaly with respect to a
%                                   linear reference profile + labelled
%                                   isotherms + velocity arrows
%     ExtractedMelt_NNN.png         extracted melt
%
%   All figures show only the region Opt.PlotRegion (x = 1000-5000 km,
%   depth = 30-900 km), as in the paper.
%
%   INPUT FILES
%   dsdNNNmark.h5 (HDF5), NNN = output step, zero-padded to 3 digits:
%     attribute 'General' on '/' : [xmin xmax ymin ymax time nx ny]
%                                  (coordinates in m, time in yr)
%     /Comp  material ids on the nx-by-ny grid, run-length encoded:
%            -2 n m  -> n consecutive cells of material m
%            -1      -> one empty cell (plotted as material 0)
%            m >= 0  -> one cell of material m
%     /Tk    temperature [K]
%     /Vx    horizontal velocity (optional; arrows skipped if missing)
%     /Vy    vertical velocity   (optional; arrows skipped if missing)
%     /wt    extracted melt
%
%   NOTE ON VELOCITY ARROWS
%   Arrows are shown on a regular subset of grid nodes. Their length is
%   proportional to the velocity magnitude, except that arrows shorter
%   than Opt.Vel.minLengthFrac times the longest arrow are lengthened to
%   that minimum, so that the flow direction stays visible in slow regions.
%
%   REQUIREMENTS
%   - MATLAB R2020a or newer (uses exportgraphics).
%   - crameri.m (Scientific colour maps, F. Crameri, doi:10.5281/zenodo.1243862;
%     MATLAB function by C. Greene) on the MATLAB path, for the temperature
%     colour maps 'lajolla' and 'vik'.

%% ======================== USER SETTINGS ================================
here = fileparts(mfilename('fullpath'));

Opt.DataDir = fullfile(here, 'data');      % folder with dsdNNNmark.h5
Opt.OutDir  = fullfile(here, 'figures');   % folder for the PNG figures
Opt.Files   = [];                          % [] = all files in DataDir

% Figures to produce
Opt.Plot.Composition         = true;
Opt.Plot.CompositionVelocity = true;
Opt.Plot.Temperature         = true;
Opt.Plot.TemperatureAnomaly  = true;
Opt.Plot.ExtractedMelt       = true;

% Plotted region: [xmin xmax ymin ymax] in km
Opt.PlotRegion = [1000 5000 30 900];

% Output
Opt.Resolution     = 600;                  % dpi, temperature and melt maps
Opt.ResComposition = 600;                  % dpi, composition maps
Opt.FigurePosition     = [100 100 560 420];% pixels; fixed for reproducibility
Opt.FontSize           = 16;               % axis tick labels
Opt.TimeFontSize       = 24;               % time stamp in lower-right corner

% Composition
Opt.Comp.shading = 'interp';   % as in the paper; 'flat' avoids blended
                               % colours at material boundaries

% Absolute temperature
Opt.T.climC      = [1200 2000];        % colour limits [degC]
Opt.T.isothermsK = 1600:200:2300;      % isotherm levels [K]
Opt.T.cbarLabel  = 'Temperature [\circC]';

% Temperature anomaly
Opt.TA.refTopK     = 1600;             % reference profile at top    [K]
Opt.TA.refBottomK  = 2100;             % reference profile at bottom [K]
Opt.TA.clim        = [-200 200];       % colour limits [K = degC]
Opt.TA.isothermsC  = 1280:150:1880;    % labelled isotherms [degC]
Opt.TA.colorbar    = false;            % colour bar was drawn separately
Opt.TA.cbarLabel   = 'Temperature anomaly [\circC]';

% Extracted melt
Opt.Melt.dataset   = '/wt';
Opt.Melt.clim      = [];               % [] = automatic
Opt.Melt.cbarLabel = 'Extracted melt';

% Velocity arrows
Opt.Vel.nArrowsX      = 40;            % approx. number of arrows along x
Opt.Vel.minLengthFrac = 0.08;          % min arrow length / max arrow length
Opt.Vel.scale         = 0.7;           % quiver AutoScaleFactor
Opt.Vel.color         = [0.5 0.5 0.5];
Opt.Vel.lineWidth     = 0.9;
%% =======================================================================

if nargin >= 1 && ~isempty(dataDir),     Opt.DataDir = dataDir;     end
if nargin >= 2 && ~isempty(outDir),      Opt.OutDir  = outDir;      end
if nargin >= 3 && ~isempty(fileNumbers), Opt.Files   = fileNumbers; end

checkRequirements(Opt);

if ~exist(Opt.OutDir, 'dir'); mkdir(Opt.OutDir); end

if isempty(Opt.Files)
    Opt.Files = findOutputSteps(Opt.DataDir);
end
if isempty(Opt.Files)
    error('ReproduceFigures:noData', 'No dsdNNNmark.h5 files found in %s', Opt.DataDir);
end

% One invisible figure, reused for every plot
hf = figure('Visible', 'off', 'Units', 'pixels', 'Position', Opt.FigurePosition);
cleanup = onCleanup(@() close(hf));

for inum = Opt.Files(:).'
    fname = fullfile(Opt.DataDir, sprintf('dsd%03dmark.h5', inum));
    if ~exist(fname, 'file')
        warning('ReproduceFigures:missingFile', 'File not found, skipped: %s', fname);
        continue
    end
    fprintf('Plotting %s\n', fname);

    G   = readHeader(fname, Opt.PlotRegion(4));
    vel = [];
    if Opt.Plot.CompositionVelocity || Opt.Plot.Temperature || Opt.Plot.TemperatureAnomaly
        vel = readVelocity(fname, G);
    end
    tag = sprintf('%03d', inum);

    % ---- Composition (with and without velocity) ----------------------
    if Opt.Plot.Composition || Opt.Plot.CompositionVelocity
        C = decodeComposition(h5read(fname, '/Comp'), G.nx, G.nyFull);
        C = C(G.iy, :);
        if Opt.Plot.Composition
            plotComposition(hf, G, C, [], Opt);
            saveFigure(hf, Opt, ['Composition_' tag], Opt.ResComposition);
        end
        if Opt.Plot.CompositionVelocity
            plotComposition(hf, G, C, vel, Opt);
            saveFigure(hf, Opt, ['CompositionVelocity_' tag], Opt.ResComposition);
        end
    end

    % ---- Temperature ---------------------------------------------------
    if Opt.Plot.Temperature || Opt.Plot.TemperatureAnomaly
        TK = readField(fname, '/Tk', G);
        if Opt.Plot.Temperature
            plotTemperature(hf, G, TK, vel, Opt);
            saveFigure(hf, Opt, ['Temperature_' tag], Opt.Resolution);
        end
        if Opt.Plot.TemperatureAnomaly
            plotTemperatureAnomaly(hf, G, TK, vel, Opt);
            saveFigure(hf, Opt, ['TemperatureAnomaly_' tag], Opt.Resolution);
        end
    end

    % ---- Extracted melt ------------------------------------------------
    if Opt.Plot.ExtractedMelt
        M = readField(fname, Opt.Melt.dataset, G);
        plotExtractedMelt(hf, G, M, Opt);
        saveFigure(hf, Opt, ['ExtractedMelt_' tag], Opt.Resolution);
    end
end

fprintf('Figures written to %s\n', Opt.OutDir);
end


%% ========================= PLOTTING ====================================

function plotComposition(hf, G, C, vel, Opt)
clf(hf);
ax = axes(hf);
pcolor(ax, G.x, G.y, C);
shading(ax, Opt.Comp.shading);
colormap(ax, compositionColormap());
set(ax, 'CLim', [0 99]);
hold(ax, 'on');
addVelocity(ax, G, vel, Opt.Vel);
hold(ax, 'off');
finishAxes(ax, G, Opt, 'k');
end


function plotTemperature(hf, G, TK, vel, Opt)
clf(hf);
ax = axes(hf);
pcolor(ax, G.x, G.y, TK - 273.15);
shading(ax, 'interp');
set(ax, 'CLim', Opt.T.climC);
colormap(ax, flipud(crameri('lajolla', 256)));
cb = colorbar(ax, 'southoutside');
xlabel(cb, Opt.T.cbarLabel, 'FontSize', 30);
cb.FontSize = Opt.FontSize;
hold(ax, 'on');
% Isotherms drawn on the temperature in Kelvin (levels in Opt.T.isothermsK)
contour(ax, G.x, G.y, TK, Opt.T.isothermsK, 'k', 'LineWidth', 0.4, 'ShowText', 'off');
addVelocity(ax, G, vel, Opt.Vel);
hold(ax, 'off');
finishAxes(ax, G, Opt, 'k');
end


function plotTemperatureAnomaly(hf, G, TK, vel, Opt)
% Anomaly with respect to a reference profile that increases linearly
% with depth from Opt.TA.refTopK (top) to Opt.TA.refBottomK (bottom).
% The profile is defined over the full model depth, then cut like the data.
Tref = linspace(Opt.TA.refTopK, Opt.TA.refBottomK, G.nyFull).';
Tref = Tref(G.iy);
dT   = TK - Tref;

clf(hf);
ax = axes(hf);
pcolor(ax, G.x, G.y, dT);
shading(ax, 'interp');
set(ax, 'CLim', Opt.TA.clim);
colormap(ax, crameri('vik', 256));
if Opt.TA.colorbar
    cb = colorbar(ax, 'southoutside');
    xlabel(cb, Opt.TA.cbarLabel, 'FontSize', 30);
    cb.FontSize = Opt.FontSize;
    tv = cb.Ticks;
    ts = string(tv);
    ts(tv > 0) = "+" + ts(tv > 0);
    cb.TickLabels = ts;
end
hold(ax, 'on');
contour(ax, G.x, G.y, TK - 273.15, Opt.TA.isothermsC, 'k', 'LineWidth', 0.4, ...
    'ShowText', 'on', 'LabelSpacing', 1e3);
addVelocity(ax, G, vel, Opt.Vel);
hold(ax, 'off');
finishAxes(ax, G, Opt, 'w');
end


function plotExtractedMelt(hf, G, M, Opt)
clf(hf);
ax = axes(hf);
pcolor(ax, G.x, G.y, M);
shading(ax, 'interp');
colormap(ax, jet(256));
if ~isempty(Opt.Melt.clim)
    set(ax, 'CLim', Opt.Melt.clim);
end
cb = colorbar(ax, 'southoutside');
xlabel(cb, Opt.Melt.cbarLabel, 'FontSize', 14);
cb.FontSize = 12;
finishAxes(ax, G, Opt, 'k');
end


function addVelocity(ax, G, vel, V)
% Velocity arrows on a regular subset of nodes, with a minimum length.
if isempty(vel); return; end
step = max(1, round(G.nx / V.nArrowsX));
ix   = 1:step:G.nx;
iy   = 1:step:G.ny;
[X, Y] = meshgrid(G.x(ix), G.y(iy));
u = vel.vx(iy, ix);
v = vel.vy(iy, ix);

mag    = hypot(u, v);
maxMag = max(mag(:));
if maxMag > 0
    minMag = V.minLengthFrac * maxMag;
    short  = mag < minMag & mag > 0;
    u(short) = u(short) .* (minMag ./ mag(short));
    v(short) = v(short) .* (minMag ./ mag(short));
end

quiver(ax, X, Y, u, v, 'Color', V.color, 'AutoScale', 'on', ...
    'AutoScaleFactor', V.scale, 'LineWidth', V.lineWidth);
end


function finishAxes(ax, G, Opt, timeColor)
% Depth increases downwards; equal aspect ratio; time stamp in the corner.
axis(ax, 'ij', 'image');
set(ax, 'FontSize', Opt.FontSize, 'TickDir', 'out');
text(ax, 0.98, 0.03, sprintf('%3.2f Myr', G.timeMyr), 'Units', 'normalized', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', ...
    'FontSize', Opt.TimeFontSize, 'FontWeight', 'bold', 'Color', timeColor);
end


function saveFigure(hf, Opt, name, resolution)
% Restrict the view to Opt.PlotRegion and save as PNG.
axis(hf.CurrentAxes, Opt.PlotRegion);
exportgraphics(hf, fullfile(Opt.OutDir, [name '.png']), 'Resolution', resolution);
end


%% ========================= DATA INPUT ==================================

function G = readHeader(fname, maxDepth)
% Grid information. Rows deeper than maxDepth [km] are dropped; one node
% below maxDepth is kept so the plot reaches exactly maxDepth.
H = double(h5readatt(fname, '/', 'General'));
G.nx      = round(H(6));
G.nyFull  = round(H(7));
G.x       = linspace(H(1), H(2), G.nx) / 1e3;       % [km]
yFull     = linspace(H(3), H(4), G.nyFull) / 1e3;   % [km]
last      = find(yFull >= maxDepth, 1, 'first');
if isempty(last); last = G.nyFull; end
G.iy      = 1:last;                                 % rows kept
G.y       = yFull(G.iy);
G.ny      = numel(G.iy);
G.timeMyr = H(5) / 1e6;                             % [Myr]
end


function F = readField(fname, dataset, G)
F = double(h5read(fname, dataset));
F = reshape(F, G.nyFull, G.nx);
F = F(G.iy, :);
end


function vel = readVelocity(fname, G)
% Returns [] (and warns) if the velocity datasets are not in the file.
try
    vel.vx = readField(fname, '/Vx', G);
    vel.vy = readField(fname, '/Vy', G);
catch
    warning('ReproduceFigures:noVelocity', ...
        'Vx/Vy not found in %s: velocity arrows not drawn.', fname);
    vel = [];
end
end


function C = decodeComposition(raw, nx, ny)
% Decode the run-length encoded material field (see help text).
raw = double(raw(:));
n   = numel(raw);
C   = ones(ny, nx);
k   = 1;     % position in the encoded stream
ind = 1;     % linear index in the grid
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
    if mat == -1; mat = 0; end     % empty cell
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


function checkRequirements(Opt)
if exist('exportgraphics', 'file') == 0
    error('ReproduceFigures:matlabVersion', 'MATLAB R2020a or newer is required (exportgraphics).');
end
if (Opt.Plot.Temperature || Opt.Plot.TemperatureAnomaly) && exist('crameri', 'file') ~= 2
    error('ReproduceFigures:crameri', ...
        ['crameri.m not found. Download it (Scientific colour maps, ' ...
         'doi:10.5281/zenodo.1243862) and add it to the MATLAB path.']);
end
end


%% ========================= COLOUR MAP ==================================

function cmap = compositionColormap()
% Row k+1 is the colour of material id k (k = 0..99).
cmap = [ ...
    1       1       1       ; %  0 empty / sticky air
    0.6863  0.9333  0.9333  ; %  1
    0.3333  0.4196  0.1843  ; %  2
    0.3333  0.4196  0.1843  ; %  3
    0.3333  0.4196  0.1843  ; %  4
    0.50196 0.50196 0.50196 ; %  5 dry upper crust
    0.6996  0.7154  0.8181  ; %  6 wet upper crust
    0       0.50196 0       ; %  7 basalt
    0       0.84314 0       ; %  8 gabbro
    0.3725  0.6196  0.6275  ; %  9 lithospheric mantle
    0.9608  0.9608  0.8627  ; % 10 asthenosphere
    0.5882  0.8000  1.0000  ; % 11
    0.8000  0.8980  1.0000  ; % 12
    1       0       1       ; % 13 serpentinite
    0.49706 0.078431 0.15294; % 14
    1.0000  1.0000  0.9412  ; % 15 lower mantle
    1       1       0       ; % 16
    0.3803  0.50196 1       ; % 17
    0.31373 0.8941  0.247   ; % 18
    0.31373 0.8941  0.647   ; % 19
    0       0       0       ; % 20
    0       0       0       ; % 21
    1       0.5     0.31765 ; % 22
    1       1       0.31765 ; % 23
    1       0.90196 0.18824 ; % 24
    0.46667 0.46667 0.23529 ; % 25
    0.50196 0.50196 0       ; % 26
    0.72549 0.015686 0.78431; % 27
    0.92549 0.43922 0.99608 ; % 28 partially molten wet basalt
    1       0       0       ; % 29
    1       0       0       ; % 30
    0       0       0       ; % 31
    0       0       0       ; % 32
    0       0       0       ; % 33
    1.0000  0.2706  0       ; % 34 solid part of partially molten mantle
    0.58    0.45    0.35    ; % 35
    0.99216 0.38824 0.30196 ; % 36
    0.7194  0.1778  0.20196 ; % 37
    0.9525  0.26877 0.2295  ; % 38 partially molten wet andesitic crust
    0.9525  0.66877 0.2295  ; % 39
    zeros(11, 3)            ; % 40-50
    repmat([0 1 1], 49, 1)  ; % 51-99
    ];
end