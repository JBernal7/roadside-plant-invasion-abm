# Management-scenario reproducibility

Publication terminology uses an ordered treatment-intensity gradient.

| Publication label | Raw/legacy label | NetLogo treatment | Frequency |
|---|---|---|---|
| Low intensity | `lowintensity` | `cut` | `once` |
| Intermediate intensity | `highintensity` | `cut+revegetation` | `annual` |
| High intensity (eradication) | `erradication` | `erradication` | `once` |

All targeted management starts in 2025 (`management-start-tick = 17`). Treatment-zone widths are 100, 200 and 400 m.

Historical v22 models are zone-specific: management1 = 100 m, management2 = 200 m, management3 = 400 m. Treatment settings were manually changed before each simulation batch, so a saved model may show only one treatment as its current default. The full factorial design is documented in `metadata/scenario_configuration.csv`.

Raw output labels are preserved so existing scripts remain functional.