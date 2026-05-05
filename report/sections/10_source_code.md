# Section 10 — Source Code

**Repository.** <https://github.com/Rahulm0106/Query-analytics> (public, MIT-style usage).

**Layout.**

```
Query-analytics/
├── data/{raw,processed}/        # 3 raw + 5 processed CSVs
├── src/
│   ├── preprocess.R             # Day 1: data engineering pipeline
│   ├── eda.R                    # Day 2: EDA and figure generation
│   └── modeling.R               # Day 3: feature engineering + model training
├── notebooks/
│   ├── 01_preprocessing.Rmd     # Day 1 narrative
│   ├── 02_eda.Rmd               # Day 2 narrative
│   ├── 03_modeling.Rmd          # Day 3 narrative
│   └── 04_validation.Rmd        # Day 4 narrative (this report)
├── report/{sections,figures}/   # 11 markdown sections + 10 figures (300 DPI)
├── results/                     # CV / benchmark / bias CSVs
├── models/                      # Trained model objects (Git LFS)
└── renv_setup.R                 # one-shot dependency installer
```

**Dependencies.** R ≥ 4.2.0 with CRAN packages: `readr`, `dplyr`, `tidyr`, `ggplot2`, `viridis`, `gridExtra`, `scales`, `car`, `randomForest`, `xgboost`, `FNN`, `cluster`, `Metrics`. All are open-source. Run `Rscript renv_setup.R` for a one-shot install; the project ships an `renv.lock` for fully pinned versions.

**Reproducibility.** Seed = 42 throughout. End-to-end pipeline:

```bash
Rscript renv_setup.R                                    # install
Rscript src/preprocess.R                                # data
Rscript src/eda.R                                       # figures 1–6
Rscript -e 'rmarkdown::render("notebooks/03_modeling.Rmd")'   # models + fig 7
Rscript -e 'rmarkdown::render("notebooks/04_validation.Rmd")' # validation + figs 8–10
```

**Note on saved models.** Trained model objects in `models/` are tracked via Git LFS. To avoid an LFS dependency, `notebooks/04_validation.Rmd` refits XGBoost from `results/xgb_best_params.csv` (~3 minutes on commodity hardware), so all validation deliverables can be reproduced without `git lfs pull`.
