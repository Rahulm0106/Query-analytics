# Section 9 — Data Sources

**Primary dataset.** UCI Machine Learning Repository, Dataset #493: *Query Analytics Workloads Dataset* (Anagnostopoulos and Triantafillou 2015). Direct download: <https://archive.ics.uci.edu/dataset/493/query+analytics+workloads+dataset>. License: Creative Commons Attribution 4.0 (CC BY 4.0). Access: anonymous HTTP, no authentication required.

**Underlying data.** The synthetic queries are generated against the *City of Chicago Crimes* open dataset (Chicago Police Department, via the Chicago Data Portal: <https://data.cityofchicago.org/Public-Safety/Crimes-2001-to-Present/ijzp-q8t2>), capped at the 5.5-million-record snapshot used to compute ground-truth aggregates for the UCI benchmark. The raw crime records themselves are not redistributed in this repository.

**Files used.**

| File | Rows | Notes |
|---|---|---|
| `Range-Queries-Aggregates.csv`  | 200,000 | Range queries with `Count` and `SUM` ground truth; raw Illinois State-Plane coordinates |
| `Radius-Queries.csv`            | 50,000  | Radius queries (geometry only, no aggregates) |
| `Radius-Queries-Count.csv`      | 10,000  | Radius queries with `Count` ground truth; pre-normalised coordinates |

All three raw CSVs are committed unmodified to `data/raw/`. Five processed CSVs (described in `README.md`) plus a `schema_summary.csv` and `processing_log.json` are exported to `data/processed/` by `Rscript src/preprocess.R`. Data processing is fully reproducible with seed = 42; 100% row retention across all three files.
