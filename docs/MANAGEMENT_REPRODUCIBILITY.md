# Management-scenario reproducibility

All management scenarios reported in the manuscript were generated using the
same NetLogo model implementation, with scenario-specific settings supplied
programmatically from R through `nlrx`.

The public-release model is available at:

`model/management/IASExpansion_ManagementModel.nlogo`

The scenario design is documented in
`metadata/management_scenario_matrix.csv`, while the exact random seeds and
run-level metadata from the archived simulation experiment are provided in the
associated Zenodo Dataset.

## Scenario design

The experiment comprised one baseline scenario and nine targeted-management
scenarios obtained by crossing three treatment intensities with three
treatment-zone widths (100, 200 and 400 m).

| Publication label | NetLogo treatment | Frequency |
|---|---|---|
| Low intensity | `cut` | `once` |
| Intermediate intensity | `cut+revegetation` | `annual` |
| High intensity (eradication) | `eradication` | `once` |

The baseline scenario included recurrent agricultural suppression but no
additional targeted management.

All targeted management started in 2025 (`management-start-tick = 17`).

The relationship between scenario identifiers, NetLogo treatment settings and
publication terminology is documented in
`metadata/terminology_mapping.csv`.

## Simulation design

Each of the 10 scenarios was evaluated using 50 stochastic replicates. The same
set of 50 random seeds was reused across scenarios, allowing scenario outcomes
to be compared under matched stochastic initialisation.

This resulted in:

- 10 scenarios
- 50 stochastic replicates per scenario
- 500 NetLogo runs
- two raster outputs per run (2035 and 2045)
- 1,000 ASC raster outputs in total

Raster outputs were exported at tick 27 (2035) and tick 37 (2045).

The exact seeds, run identifiers and raster-to-scenario correspondence are
archived in the associated Zenodo Dataset:

- `management/simulation_seeds.csv`
- `management/ASC_manifest.csv`
- `management/run_metadata.txt`

## Model version and execution snapshot

The NetLogo model distributed in this software repository was editorially
cleaned after the archived simulation run. Changes were limited to removal of
development comments, revision of the NetLogo Info tab, and standardisation of
the biotic-resistance input filename. No executable model logic, parameter
values or scenario settings were changed.

For exact computational provenance, the byte-identical NetLogo file used to
generate the archived management outputs is preserved in the associated Zenodo
Dataset at:

`management/runtime_snapshot/IASExpansion_ManagementModel.nlogo`

The MD5 checksum recorded in `management/run_metadata.txt` corresponds to this
execution snapshot. Because the public-release model contains editorial
documentation changes, its file checksum is not expected to match the archived
execution snapshot.

The public-release model refers to the biotic-resistance raster as
`resistance_bio_10m.asc`. This raster is byte-identical to
`resistance_0_1_def.asc`, the filename referenced by the execution snapshot.

## Execution

The management experiment can be reproduced with:

`scripts_final_analysis/run_management_scenarios.R`

The script defines the 10-row scenario matrix, applies the common set of random
seeds through `nlrx`, executes the NetLogo model, and validates the expected
500 runs and 1,000 raster outputs.

The archived simulation run used NetLogo 6.4.0 and `nlrx` 0.4.6. Additional
software and runtime information is provided in
`metadata/software_versions.csv` and
`management/run_metadata.txt`.

## Spatial post-processing

The management rasters are post-processed with:

`scripts_final_analysis/analyse_management_scenarios.R`

For each raster, occupied cells are converted to binary occupancy and invasion
clusters are identified using 8-neighbour connectivity. Two spatial metrics
reported in the manuscript are then calculated:

1. number of invasion clusters; and
2. mean cluster size, expressed as the mean number of occupied cells per
   cluster.

The resulting replicate-level and scenario-level tables are archived as:

- `management/scenario_outputs_summary/results_analysis_figure6.csv`
- `management/scenario_outputs_summary/summary_figure6.csv`

The final plotting script used to generate Figure 6 is:

`scripts_final_analysis/plot_management_scenarios.R`