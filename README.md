# Model figures – Zarabara et al. (Earth and Planetary Science Letters)

MATLAB scripts to reproduce the model figures of:

> Zarabara, F., Faccenda, M., Yang, J., Faccenna, C. *Interaction between subducting slabs and an anomalous lower mantle as source of intraplate volcanism.* Earth and Planetary Science Letters (under review).

The numerical models were run with the 2D petrological-thermomechanical code I2VIS (Gerya and Yuen, 2003). I2VIS is not open source; it is developed and maintained by T. Gerya (ETH Zurich) and is available from him upon request. This repository contains only the scripts that read the model output and plot the figures.

## Contents

| File | What it does |
|---|---|
| `reproduce_figures.m` | Composition, composition with velocity, absolute temperature, temperature anomaly and extracted melt maps for each output step |
| `reproduce_volcanics_graph.m` | Volume of newly formed volcanic material as a function of distance and time, with the trench position |

Each script describes its input, method and settings in its help text (`help reproduce_figures`, `help reproduce_volcanics_graph`).

## Requirements

- MATLAB R2020a or newer
- `crameri.m` (Scientific colour maps; Crameri, 2018, doi:[10.5281/zenodo.1243862](https://doi.org/10.5281/zenodo.1243862)) on the MATLAB path

## Model output

The model output files (`dsdNNNmark.h5`) are archived on Zenodo: doi:[DATA DOI]. Download the zip files and unzip them next to the scripts:

```
reproduce_figures.m
reproduce_volcanics_graph.m
Figure_3a/              2-4 output files each
Figure_3b/
Figure_4ab/
Figure_4de/
Figure_5a/
Figure_5d/
Volcanics_evolution_1/  50 output files each
Volcanics_evolution_2/
```

## Usage

```matlab
reproduce_figures                 % all Figure_* folders
reproduce_figures('Figure_3a')    % one folder only

reproduce_volcanics_graph         % all Volcanics_evolution_* folders
reproduce_volcanics_graph('Volcanics_evolution_1')
```

The maps of each `Figure_*` folder are written to `figures/<folder name>/`, and the volcanism plots to `figures/volume_vs_time_vs_space_<folder name>.png`. In each `Volcanics_evolution_*` folder, the first output file only provides the initial state; the volumes are computed from the second file onwards.

## Paper figures

| Folder | Paper figure | Model |
|---|---|---|
| `Figure_3a` | Fig. 3a | [MODEL ID] |
| `Figure_3b` | Fig. 3b | [MODEL ID] |
| `Figure_4ab` | Fig. 4a–b | [MODEL ID] |
| `Figure_4de` | Fig. 4d–e | [MODEL ID] |
| `Figure_5a` | Fig. 5a | [MODEL ID] |
| `Figure_5d` | Fig. 5d | [MODEL ID] |
| `Volcanics_evolution_1` | Fig. [X] | [MODEL ID] |
| `Volcanics_evolution_2` | Fig. [X] | [MODEL ID] |

## License

MIT (see `LICENSE`).

## Citation

If you use these scripts, please cite the paper above and this repository (see `CITATION.cff` or the Zenodo record).
