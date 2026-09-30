# A spatially explicit agent-based model of roadside plant invasion

Research software and reproducibility materials associated with the manuscript:

**A spatially explicit agent-based model of roadside plant invasion to inform management decisions along Mediterranean mountain roads**

Associated manuscript authors: Jessica Bernal-Borrego, Claudio A. Bracho-Estévanez, María Suárez-Muñoz, and Pablo González-Moreno.

## Software authorship and contributions

**Software creator:** Jessica Bernal-Borrego.

Claudio A. Bracho-Estévanez contributed to the methodological and computational implementation of the management scenarios and their execution. Pablo González-Moreno contributed conceptual and methodological supervision of model development.

## Repository contents

1. `model/user/` — interactive user-facing NetLogo implementation for simulating management scenarios, defining treatment areas interactively or from predefined spatial polygons, modifying selected model and treatment settings, visualising invasion dynamics, and exporting simulation outputs.
2. `model/calibration/` — NetLogo calibration models corresponding to Tests 1–4.
3. `model/management/` — NetLogo implementation used for the management-scenario experiment.
4. `config/behaviorsearch/` — BehaviorSearch configurations used for calibration.
5. `scripts_final_analysis/` — scripts used for candidate-level calibration diagnostics, management-scenario execution, spatial post-processing and final figures.
6. `metadata/` — scenario configuration, terminology mapping and software-version information.
7. `docs/` — additional reproducibility documentation.

Large spatial inputs, calibration and verification outputs, and management-scenario rasters are archived separately in the associated Zenodo Dataset.

## Data dependency

Download the associated Zenodo Dataset and place its `abm_prep/` directory at the repository root. NetLogo models use relative paths of the form:

`abm_prep/...`

The associated dataset DOI is:

**[10.5281/zenodo.22833035](https://doi.org/10.5281/zenodo.22833035)**

## Calibration

Each calibration test comprised five independent BehaviorSearch searches. Each search evaluated 160 candidate parameterisations, with seven stochastic replicates per candidate, yielding 800 candidate parameterisations and 5,600 stochastic NetLogo model runs per test.

Candidate fitness was defined as the median incremental normalised root-mean-square error (NRMSEΔ) across the seven stochastic replicates.

Post-optimisation stochastic verification (`VerifYn`) was executed directly in NetLogo for the best-performing parameterisation from each test. Verification outputs are archived in the associated Zenodo Dataset.

For the final practical-identifiability analysis, the near-optimal ensemble was defined at candidate level as the top 5% of the 800 candidate parameterisations per test (`n = 40`), ranked by candidate-level median NRMSEΔ.

## Management scenarios

All management scenarios reported in the manuscript were generated using the same NetLogo model implementation, with scenario-specific settings supplied programmatically from R through `nlrx`. The experiment comprised one baseline scenario and nine targeted-management scenarios.

Targeted scenarios crossed three treatment intensities:

- **Low intensity** — one cutting intervention in 2025.
- **Intermediate intensity** — annual cutting plus revegetation from 2025 onwards.
- **High intensity (eradication)** — complete removal of existing stands in 2025 plus revegetation.

Each treatment intensity was evaluated within treatment zones of 100, 200 and 400 m.

The baseline scenario included recurrent agricultural suppression but no additional targeted management.

Each scenario was evaluated using 50 stochastic replicates. The same set of 50 random seeds was applied across all 10 scenarios, yielding 500 NetLogo runs. Outputs were exported for 2035 and 2045, producing 1,000 management-scenario rasters.

The exact experimental design is documented in `metadata/management_scenario_matrix.csv`, while `metadata/terminology_mapping.csv` maps scenario identifiers and NetLogo treatment settings to publication terminology.

The model distributed in `model/management/IASExpansion_ManagementModel.nlogo` is the public-release version of the management model. Following the archived simulation run, development comments and the NetLogo Info tab were editorially revised for clarity and consistency with the manuscript and data-provenance documentation. The biotic-resistance input filename was also standardised to the canonical dataset filename. These changes do not alter executable model logic, parameter values, scenario settings or numerical spatial inputs.

For exact computational provenance, the byte-identical NetLogo file used to generate the archived management outputs is preserved in the associated Zenodo Dataset at:

`management/runtime_snapshot/IASExpansion_ManagementModel.nlogo`

The MD5 checksum recorded in `management/run_metadata.txt` refers to this execution snapshot rather than to the editorially cleaned public-release file.

Detailed execution and post-processing instructions are provided in:

`docs/MANAGEMENT_REPRODUCIBILITY.md`

Raw simulation rasters, random seeds, run metadata, the ASC manifest and derived management-scenario tables are archived in the associated Zenodo Dataset.

## Spatial-data provenance

Spatial-data provenance and third-party attribution are documented in the associated Zenodo Dataset.

The distributed model inputs include author-generated data and derivatives of openly licensed or publicly reusable sources, including SIPNA/REDIAM, DERA, and NASA SRTM data.

No Google Street View imagery is redistributed.

## Citation

The archived software release is available at:

**[10.5281/zenodo.22833451](https://doi.org/10.5281/zenodo.22833451)**

Citation metadata are provided in `CITATION.cff`.

## Licence

The software is distributed under the **MIT License**.

The associated dataset has separate licensing and attribution information in its Zenodo record.

## Funding

This research was carried out within the DesFutur project, funded by Fundación Biodiversidad (MITECO) under the European Union NextGenerationEU/PRTR framework, and the DYNAMO project (PID2023-152653OA-C22), funded by MCIN/AEI/10.13039/501100011033.

Pablo González-Moreno was also supported by grant RYC2021-033138-I, funded by MCIN/AEI/10.13039/501100011033 and the European Union NextGenerationEU/PRTR.
