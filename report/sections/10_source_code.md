# Section 10 - Source Code

**Repository.** <https://github.com/Rahulm0106/Query-analytics> (public, MIT-style usage). Layout: `data/{raw,processed}/` (3 raw + 5 processed CSVs), `src/{preprocess,eda,modeling}.R` (Day 1–3 pipeline scripts), `notebooks/0{1..4}_*.Rmd` (per-day narratives, Day 4 = this report), `report/{sections,figures}/` (11 sections + 10 figures at 300 DPI), `results/` (CV, benchmark, bias CSVs), `models/` (trained objects via Git LFS), `renv_setup.R` (dependency installer).

**Dependencies.** R ≥ 4.2.0 with CRAN packages `readr`, `dplyr`, `tidyr`, `ggplot2`, `viridis`, `gridExtra`, `scales`, `car`, `randomForest`, `xgboost`, `FNN`, `cluster`, `Metrics` are all open-source. Run `Rscript renv_setup.R` for one-shot install; an `renv.lock` pins exact versions.

**Reproducibility.** Seed = 42 throughout. Run end-to-end with: `Rscript src/preprocess.R` (data), `Rscript src/eda.R` (figs 1–6), then knit `notebooks/03_modeling.Rmd` (models + fig 7) and `notebooks/04_validation.Rmd` (validation + figs 8–10). Trained models in `models/` are stored via Git LFS, but `04_validation.Rmd` refits XGBoost from `results/xgb_best_params.csv` (\~3 min) so the report can be reproduced without `git lfs pull`.
