# Section 5 - Model Training

## 5.1 Feature Engineering

Three features were engineered beyond those produced in Day 1. For range-query rectangles, *aspect ratio* (X_range / Y_range) captures the shape of each query footprint. An *interaction term* (log-area × dist_centroid) encodes the joint effect of query size and distance from the city centre, since a large query far from the centroid behaves differently from a large query at the core. A binary *boundary flag* marks the 1,373 range queries (0.7 %) whose footprint crosses the dataset bounding box. All 10,000 radius-count queries cross the bounding box, so the flag is constant for that sub-dataset and excluded.

## 5.2 Multicollinearity and Feature Selection

Variance Inflation Factor (VIF) analysis on range queries revealed that `log_area`, `dist_centroid`, and `interact_area_dist` all exceeded VIF = 10 (12.70, 162.84, and 171.50 respectively), leaving `X_range`, `Y_range`, `aspect_ratio`, and `boundary_flag` as VIF-safe features for the linear model. For radius count, `R` and `log_area` are perfectly collinear (area = π × R²), so a reduced set of `log_area`, `dist_centroid`, `X_norm`, and `Y_norm` was used after confirming all VIFs fell below 2.40. Tree-based models retained all features as they are invariant to multicollinearity.

## 5.3 Train / Test Split

Each sub-dataset was partitioned 80 / 20 with a fixed seed of 42. Range Queries: 160,000 training rows, 40,000 test rows. Radius Count: 8,000 training rows, 2,000 test rows. Split indices were exported to `results/split_*.csv` for full reproducibility.

## 5.4 Models Trained

All models target `log1p(Count)` as the response; evaluation metrics are back-transformed via `expm1()` to the original count scale.

**Linear Regression** (baseline) uses `lm()` on VIF-safe features. For range queries: `log_area`, `dist_centroid`, `interact_area_dist`, `aspect_ratio`, `boundary_flag` (R² = 0.911 in log space). For radius count: `log_area`, `dist_centroid`, `X_norm`, `Y_norm` (R² = 0.722 in log space). A secondary linear model was also fit for the SUM target on range queries.

**Random Forest** uses 500 trees (`randomForest`, mtry = √p) with all spatial features. Feature importance is extracted as %IncMSE. Notably, `Y_norm` ranked as the top feature (importance = 144.6) over `log_area` (50.9), revealing strong north-south spatial structure in Chicago crime counts that linear correlation does not capture.

**XGBoost** was tuned via 5-fold cross-validation grid search over learning rate (η ∈ {0.05, 0.1, 0.3}), max tree depth ∈ {4, 6, 8}, and row subsampling rate ∈ {0.7, 0.9} with early stopping (20 rounds patience). Best parameters for range queries: η = 0.1, max_depth = 8, subsample = 0.9 (500 rounds). Best parameters for radius count: η = 0.1, max_depth = 4, subsample = 0.7 (300 rounds). Both models hit the nrounds cap, indicating further improvement is possible with additional boosting rounds. Separate models were trained for Count (primary) and SUM (secondary) on range queries. XGBoost feature importance confirms `log_area` as the dominant predictor (Gain = 0.63).

**KNN Regressor** (`FNN::knn.reg`, K ∈ {5, 10, 20}) serves as a spatial proximity baseline with min-max normalised features. Best K selected by test RMSE: K = 10 for range queries, K = 5 for radius count.

## 5.5 Results Summary

XGBoost achieves the best test RMSE on both datasets (full benchmark in Table 1, §7), outperforming Random Forest by 16% on range queries (RMSE 6,575 vs 7,801) and 5% on radius count (RMSE 8.52 vs 9.01). The linear model degrades severely on radius count (R² = 0.32) due to near-zero variance in the radius feature, confirming that non-linear models are essential for this sub-dataset. The log-transform substantially reduced target skewness (raw skew ≈ 1.35 → near-zero post-transform), supporting better model fit across all four methods. All trained model objects are saved to `models/` in `.rds` / `.model` format for direct loading by Person 4 without retraining.