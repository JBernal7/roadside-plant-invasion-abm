# A spatially explicit agent-based model of roadside plant invasion

Research software and reproducibility materials associated with the manuscript:

**A spatially explicit agent-based model of roadside plant invasion to inform management decisions along Mediterranean mountain roads**

Associated manuscript authors: Jessica Bernal-Borrego, Claudio A. Bracho-Estévanez, María Suárez-Muñoz, and Pablo González-Moreno.

## Software authorship and contributions

**Software creator:** Jessica Bernal-Borrego.

Claudio A. Bracho-Estévanez contributed to the methodological and computational implementation of the management scenarios and their execution. Pablo González-Moreno contributed conceptual and methodological supervision of model development.

## Repository contents

1. `model/user/` — reusable NetLogo implementation based on the retained Test 4 formulation.
2. `model/calibration/` — historical NetLogo calibration models corresponding to Tests 1–4.
3. `model/management/` — baseline and zone-specific v22 management models for the 100-, 200-, and 400-m treatment zones.
    - `original_v22/` preserves the historical management models unchanged.
    - `portable_v22/` contains path-adjusted copies with relative treatment-zone paths for reproducible execution; no model-process logic was altered.
4. `config/behaviorsearch/` — BehaviorSearch configurations used for calibration.
5. `scripts/final_analysis/` — final candidate-level calibration diagnostics and management-scenario post-processing scripts.
6. `scripts/supporting_original/` — original working scripts retained for computational provenance.
7. `metadata/` — scenario configuration, terminology mapping, and software-version information.

Large spatial inputs, calibration outputs, verification outputs, and management simulation rasters are archived separately in the associated Zenodo Dataset.

## Data dependency

Download the associated Zenodo Dataset and place its `abm_prep/` directory at the repository root. NetLogo models use relative paths of the form:

`abm_prep/...`

The associated dataset DOI is:

**[DATASET DOI TO BE INSERTED]**

## Calibration

Each calibration test comprised five independent BehaviorSearch searches. Each search evaluated 160 candidate parameterisations, with seven stochastic replicates per candidate, yielding 800 candidate parameterisations and 5,600 stochastic NetLogo model runs per test.

Candidate fitness was defined as the median incremental normalised root-mean-square error (NRMSEΔ) across the seven stochastic replicates.

Post-optimisation stochastic verification (`VerifYn`) was executed directly in NetLogo for the best-performing parameterisation from each test. Verification outputs are archived in the associated Zenodo Dataset.

For the final practical-identifiability analysis, the near-optimal ensemble was defined at candidate level as the top 5% of the 800 candidate parameterisations per test (`n = 40`), ranked by candidate-level median NRMSEΔ.

## Management scenarios

Management was evaluated across three treatment-zone widths: 100, 200, and 400 m.

The final manuscript describes the management treatments as an ordered treatment-intensity gradient:

- **Low intensity** — one cutting intervention in 2025.
- **Intermediate intensity** — annual cutting plus revegetation from 2025 onwards.
- **High intensity (eradication)** — complete stand removal in 2025 plus revegetation.

Historical filenames and raw simulation folders retain the labels used during the original computational workflow:

- `lowintensity` → Low intensity
- `highintensity` → Intermediate intensity
- `erradication` → High intensity (eradication)

The mapping is documented in `metadata/terminology_mapping.csv` and `metadata/scenario_configuration.csv`.

The historical v22 experiment used one zone-specific model for each treatment-zone width:

- `management1` — 100 m
- `management2` — 200 m
- `management3` — 400 m

Treatment type and recurrence were changed directly in the corresponding model before each simulation batch. Separate source-code snapshots were therefore not retained for all nine treatment-intensity × treatment-zone combinations.

Each final management scenario was evaluated using **10 independent stochastic replicates**. Raw simulation outputs and the summary table underlying the management figures are archived in the associated Zenodo Dataset.

## Historical resistance-layer filename

The archived v22 management models refer to:

`abm_prep/resistance_0_1_def.asc`

This is a historical filename for the same resistance raster distributed as:

`abm_prep/resistance_bio_10m.asc`

Both files are retained as byte-identical copies to preserve compatibility with the original management models.

## Spatial-data provenance

Spatial-data provenance and third-party attribution are documented in the associated Zenodo Dataset.

The distributed model inputs include author-generated data and derivatives of openly licensed or publicly reusable sources, including SIPNA/REDIAM, DERA, and NASA SRTM data.

No Google Street View imagery is redistributed.

## Citation

The archived software release is available at:

**[SOFTWARE DOI TO BE INSERTED]**

Citation metadata are provided in `CITATION.cff`.

## Licence

The software is distributed under the **MIT License**.

The associated dataset has separate licensing and attribution information in its Zenodo record.
