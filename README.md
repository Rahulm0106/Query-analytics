# Query Analytics Workloads — CSP 571 Team Project

Team sprint on UCI ML Repository dataset **#493 — Query Analytics Workloads Dataset**: 260,000 synthetic spatial queries (range + radius) over Chicago crime data. One person at a time, handoff-style.

| Day | Person | Phase | Status |
| --- | --- | --- | --- |
| 1 | Rahul Sanjay Mandviya | Data engineering & preprocessing | **Complete** |
| 2 | Manthan Sarjuse | EDA & visualization | Pending |
| 3 | Atharva Patil | Modeling | Pending |
| 4 | Prasanna Renapurkar | Validation & report | Pending |

**Language:** R (primary, and the only runtime required for the pipeline).

## Data engineering & preprocessing status note

All three UCI #493 sub-datasets were downloaded, schema-validated, de-duplicated, feature-engineered (spatial area, normalized coordinates, distance-from-centroid), and log-transformed targets were exported — 260,000 raw rows in, 260,000 clean rows out (100 % retention across all three files). The pipeline lives in `src/preprocess.R` and is narrated in `notebooks/01_preprocessing.Rmd`; downstream persons should consume the five CSVs in `data/processed/`. Run `Rscript src/preprocess.R` to reproduce from the raw files.

## Data anomalies found

1. **157 structural null AVGs in `Range-Queries-Aggregates.csv`.** Every NA row has `Count = 0` and `SUM = 0`, so `AVG = SUM/Count` is 0/0 = undefined. Imputed to `0`. The UCI card's "no missing values" claim is therefore slightly off.
2. **Coordinate scale differs across files.** `Range-Queries-Aggregates.csv` is in raw Illinois State Plane feet (X ≈ 1.16e6, Y ≈ 1.89e6). `Radius-Queries.csv` and `Radius-Queries-Count.csv` are pre-normalized to roughly [0, 1]. Every downstream model must normalize **per dataset** — don't concatenate raw X/Y across files. The pipeline writes `X_norm`, `Y_norm` ∈ [0, 1] into each output to make this a non-issue.
3. **Boundary-effect queries dominate the radius datasets.** 49,967 / 50,000 radius queries and 10,000 / 10,000 radius-count queries have a disc that extends past the dataset bounding box; only 1,373 / 200,000 range queries do. This is a property of the Gaussian sampling used to generate the workloads, not a data bug, but Manthan should visualize it and Atharva should consider a `boundary_flag` as a feature.

## Repo layout

```
query_analytics/
├── data/
│   ├── raw/                               # 3 CSVs from UCI #493 (untouched)
│   └── processed/                         # 5 clean CSVs + schema_summary.csv + processing_log.json
├── src/preprocess.R                       # reproducible R pipeline — source of truth
├── notebooks/
│   └── 01_preprocessing.Rmd               # Data engineering & preprocessing narrative notebook (R)
├── report/
│   └── sections/03_data_processing.md     # draft §3 for the final report
├── results/                               # CV tables / feature importance
├── models/                                # trained model objects
├── slides/                                # presentation assets
├── renv_setup.R                           # one-shot R dependency installer
└── query_analytics_4day_sprint.pdf        # sprint plan
```

## Running Data engineering & preprocessing

```bash
# One-time: install R deps (writes renv.lock into the project)
Rscript renv_setup.R

# Regenerate data/processed/ from data/raw/
Rscript src/preprocess.R
```

Expected end-state of `data/processed/`:

| file | rows | notes |
| --- | --- | --- |
| `clean_range_queries.csv` | 200,000 | raw targets; adds `area`, `X_norm`, `Y_norm`, `dist_centroid` |
| `clean_range_queries_log.csv` | 200,000 | adds `log_Count`, `log_SUM` |
| `clean_radius_queries.csv` | 50,000 | no aggregate targets (queries only) |
| `clean_radius_count.csv` | 10,000 | raw targets |
| `clean_radius_count_log.csv` | 10,000 | adds `log_Count` |
| `schema_summary.csv` | 19 | per-column min/max/mean/median/SD/skew/kurtosis |
| `processing_log.json` | 1 | dedupe + boundary counts per dataset |

## Handoff for EDA & visualization

1. Load the five clean CSVs — schemas are stable and fully numeric (zero nulls).
2. Start target-distribution plots from the `clean_*_log.csv` variants; use the raw-target files for raw-scale plots.
3. **Top three features likely predictive of Count** (to be confirmed with the correlation matrix): `area`, `dist_centroid`, and the radius/range dimensions (`R` or `X_range`, `Y_range`).
4. Carry the 157-zero anomaly and the boundary-effect observation into the EDA narrative.
