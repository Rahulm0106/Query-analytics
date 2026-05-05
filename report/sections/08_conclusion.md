# Section 8 — Conclusion

## 8.1 Positive Results

XGBoost is highly effective at spatial-query selectivity estimation on this benchmark: a Range test R² of 0.998 (RMSE = 6,575 records against a mean Count of 159,000) and a Radius test R² of 0.996 (RMSE = 8.52 against a mean Count of 265). Against the Linear baseline, XGBoost reduces test RMSE by 88.9% on Range and 92.2% on Radius. Tree-based ensembles (XGBoost > Random Forest > KNN) dominate the leaderboard on both sub-datasets, validating the EDA hypothesis that the relationship between query geometry and result size is strongly non-linear. Feature engineering — particularly `log_area` and the `area × dist_centroid` interaction — was decisive: `log_area` alone accounts for Gain = 0.63 of the XGBoost split-improvement signal.

## 8.2 Negative Results and Caveats

The Linear model fails on Radius (R² = 0.315) because the `R` (radius) variable has near-zero variance (SD ≈ 0.003), making any linear function in `R` effectively constant. Spatial residual analysis (§6, fig10) reveals ~43% RMSE variation across K-Means clusters, with the highest-error cluster also carrying the highest `boundary_flag` prevalence — boundary-crossing queries remain a residual-risk segment. Both XGBoost models hit the `nrounds` cap during cross-validation (500 for Range, 300 for Radius); CV RMSE was still decreasing, so reported metrics are upper bounds. Tree and KNN models cannot extrapolate beyond the training feature range; out-of-distribution queries (extreme areas, or coordinates outside the Chicago bounding box) carry higher prediction risk.

## 8.3 Recommendations and Future Work

Three concrete extensions: (i) re-train XGBoost with `nrounds` ≥ 1,500 and stricter early-stopping to close the convergence gap; (ii) fit a boundary-aware Radius model — possibly with a separate sub-model conditioned on `boundary_flag` — to address the 99.9% boundary-crossing rate that makes the flag uninformative as a single feature on Radius; (iii) benchmark a small MLP or learned-index baseline (e.g. MSCN, Kipf et al. 2019) to test whether deep features add value beyond hand-engineered geometric ones at this dataset scale. The current pipeline is reproducible, deterministic (seed = 42), and runs end-to-end in under an hour on commodity hardware, providing a solid foundation for these extensions.
