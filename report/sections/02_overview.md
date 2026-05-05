# Section 2 — Overview

## 2.1 Problem Statement

Modern relational and spatial database engines rely on **selectivity estimation** — predicting the result-set size of a query before execution — to choose efficient query plans (Kipf et al. 2019). Cardinality misestimation is the single largest source of query-optimiser regression in production systems. UCI dataset #493 (Anagnostopoulos and Triantafillou 2015) provides a controlled benchmark for this task: 260,000 synthetic spatial queries against the City of Chicago crime database, paired with ground-truth aggregates. The supervised regression targets are `Count` (number of records intersected) and `SUM` (sum of an aggregate field over the records). A model that accurately maps query geometry → result size could be embedded in a query planner as a learned cardinality estimator.

## 2.2 Relevant Literature

Tree-based ensembles have been the workhorses of tabular-data regression for the past two decades. Random Forest (Breiman 2001) reduces variance through bagging and feature subsampling but tends to memorise training data on dense regression tasks. Gradient-boosted trees, and in particular XGBoost (Chen and Guestrin 2016), introduce regularised boosting with second-order optimisation and have repeatedly topped public regression benchmarks. For spatial cardinality estimation specifically, recent learned-database work (Kipf et al. 2019) has demonstrated that gradient-boosted trees on hand-crafted geometric features can match or exceed deep-learning estimators while remaining order-of-magnitude cheaper to train and serve.

## 2.3 Proposed Methodology

Our approach is a four-stage pipeline executed as a one-person-at-a-time team sprint: (1) **data engineering** — schema validation, de-duplication, coordinate normalisation per file, and log-transform of skewed targets; (2) **exploratory data analysis** — distributional and spatial visualisation, correlation/Spearman screening, identification of multicollinearity (`area` vs `X_range × Y_range`); (3) **modeling** — feature engineering (`log_area`, `aspect_ratio`, `interact_area_dist`, `boundary_flag`), VIF-based feature selection for the linear baseline, and grid-search–tuned XGBoost with 5-fold cross-validation; (4) **validation** — held-out-set diagnostics (residuals, predicted-vs-actual), unsupervised K-Means clustering for spatial bias analysis, and per-decile/per-cluster bias decomposition. All code is reproducible with seed = 42; the pipeline runs end-to-end in R (no Python dependencies).
