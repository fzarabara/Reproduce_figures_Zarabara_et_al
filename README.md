# Model figures – Zarabara et al. (Earth and Planetary Science Letters)

MATLAB scripts to reproduce the model figures of:

> Zarabara, F., Faccenda, M., Yang, J., Faccenna, C. *Interaction between subducting slabs and an anomalous lower mantle as source of intraplate volcanism.* Earth and Planetary Science Letters (under review).

The numerical models were run with the 2D petrological-thermomechanical code I2VIS (Gerya and Yuen, 2003). I2VIS is not open source; it is developed and maintained by T. Gerya (ETH Zurich) and is available from him upon request. This repository contains only the scripts that read the model output and plot the figures.

## Contents

| File | What it does |
|---|---|
| `CreateFigures.m` | Composition, composition with velocity, absolute temperature, temperature anomaly and extracted melt maps for each output step |
| `CreateVolumeFigure.m` | Volume of newly formed volcanic material as a function of distance and time, with the trench position |

Each script describes its input, method and settings in its help text (`help CreateFigures`, `help CreateVolumeFigure`).

## Requirements

- MATLAB R2020a or newer
- `crameri.m` (Scientific colour maps; Crameri, 2018, doi:[10.5281/zenodo.1243862](https://doi.org/10.5281/zenodo.1243862)) on the MATLAB path

## Model output

The model output files (`dsdNNNmark.h5`) are archived separately on Zenodo: doi:[DATA DOI]. Download them and place each model in its own folder:

```
data/
  test23/   dsdNNNmark.h5 files of model [MODEL ID]
  test51/   dsdNNNmark.h5 files of model [MODEL ID]
CreateFigures.m
CreateVolumeFigure.m
```

## Usage

```matlab
% Maps (composition, temperature, temperature anomaly, extracted melt)
CreateFigures('data/test23', 'figures', 11)

% Volume of volcanic material vs distance and time
CreateVolumeFigure('data/test51', 'figures')
```

The figures are written as PNG files to `figures/`.

## Paper figures

| Paper figure | Script | Model | Output step(s) |
|---|---|---|---|
| Fig. [X] | `CreateFigures.m` | [MODEL ID] | [N] |
| Fig. [X] | `CreateVolumeFigure.m` | [MODEL ID] | 6–67 |

## License

MIT (see `LICENSE`).

## Citation

If you use these scripts, please cite the paper above and this repository (see `CITATION.cff` or the Zenodo record).
