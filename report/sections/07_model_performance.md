# Section 7 - Model Performance

Table 1 reports test-set metrics on the original Count scale for the four trained model families on each sub-dataset, sorted by RMSE within dataset. Full train+test metrics are in `results/final_benchmark.csv`; CV grid-search results in `results/xgb_best_params.csv`.

\begin{table}[H]
\centering
\caption{Test-set performance on the held-out 20\% partition (seed = 42). Best model per dataset in \textbf{bold}.}
\label{tab:perf}
\footnotesize
\begin{tabular}{@{}llrrrr@{}}
\toprule
\textbf{Dataset} & \textbf{Model} & \textbf{RMSE} & \textbf{MAE} & \textbf{R\textsuperscript{2}} & \textbf{MAPE} \\
\midrule
Range  & \textbf{XGBoost}     & \textbf{6{,}575}  & \textbf{4{,}411}  & \textbf{0.9982} & 10.61\% \\
Range  & Random Forest        & 7{,}801           & 4{,}668           & 0.9974          & 15.83\% \\
Range  & KNN (K = 10)         & 21{,}742          & 14{,}091          & 0.9801          & 22.24\% \\
Range  & Linear               & 59{,}655          & 40{,}428          & 0.8505          & 82.02\% \\
\midrule
Radius & \textbf{XGBoost}     & \textbf{8.52}     & \textbf{5.13}     & \textbf{0.9958} & 2.31\%  \\
Radius & Random Forest        & 9.01              & 4.02              & 0.9953          & 1.96\%  \\
Radius & KNN (K = 5)          & 10.56             & 6.05              & 0.9935          & 2.74\%  \\
Radius & Linear               & 108.80            & 83.21             & 0.3151          & 35.50\% \\
\bottomrule
\end{tabular}
\end{table}

**Baseline comparison.** Against the linear baseline, XGBoost reduces Range test RMSE by **88.9%** (59,655 → 6,575) and Radius test RMSE by **92.2%** (108.80 → 8.52). The Linear R² of 0.315 on Radius underscores why tree-based methods are essential: the radius variable `R` has near-zero variance (SD ≈ 0.003), so any linear function in `R` is effectively constant, and the linear model is forced to rely on weakly-correlated spatial features.

**Why XGBoost wins.** Feature-importance analysis (fig07) shows `log_area` dominates with Gain = 0.63 on Range, confirming the EDA correlation finding (Spearman ρ = 0.95 between `area` and `Count`). Tree ensembles also capture the non-linear interaction between query size and spatial position `Y_norm` ranks first by Random Forest %IncMSE (importance = 144.6, vs `log_area` = 50.9), exposing strong north–south crime-density structure that linear correlation does not surface. XGBoost gains a further 16% RMSE reduction over Random Forest on Range (6,575 vs 7,801) by combining boosting with depth-8 trees and 5-fold CV regularisation.

**Improvement summary.** XGBoost's R² of 0.998 on Range approaches a perfect fit; the remaining absolute error is concentrated in the highest area decile (§6, fig09). On Radius, MAE of 5.13 against a mean Count of 265 represents ≈ 2% relative error a tight fit despite the much smaller training sample (8,000 rows). Both XGBoost models hit the `nrounds` cap during CV, so further improvement is plausible with extended boosting.
