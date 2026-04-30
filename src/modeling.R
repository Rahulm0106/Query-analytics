options(repos = c(CRAN = "https://cloud.r-project.org"))

pkgs <- c("readr", "dplyr", "car", "randomForest", "xgboost", "FNN",
          "ggplot2", "Metrics", "tidyr")
for (p in pkgs) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
}

library(readr); library(dplyr); library(car)
library(randomForest); library(xgboost); library(FNN)
library(ggplot2); library(Metrics); library(tidyr)

set.seed(42)
dir.create("results", showWarnings = FALSE)
dir.create("models",  showWarnings = FALSE)

# ── Load Data ──────────────────────────────────────────────────────────────────
range_log  <- read_csv("data/processed/clean_range_queries_log.csv")
radius_log <- read_csv("data/processed/clean_radius_count_log.csv")
cat("Range:", nrow(range_log), "rows | Radius:", nrow(radius_log), "rows\n")

# ── Feature Engineering ────────────────────────────────────────────────────────
x_min_r <- min(range_log$X); x_max_r <- max(range_log$X)
y_min_r <- min(range_log$Y); y_max_r <- max(range_log$Y)

range_fe <- range_log %>%
  mutate(
    aspect_ratio       = X_range / (Y_range + 1e-9),
    log_area           = log1p(area),
    interact_area_dist = log_area * dist_centroid,
    boundary_flag      = as.integer(
      (X - X_range / 2 < x_min_r) | (X + X_range / 2 > x_max_r) |
      (Y - Y_range / 2 < y_min_r) | (Y + Y_range / 2 > y_max_r)
    )
  )
cat("Range boundary rows:", sum(range_fe$boundary_flag), "\n")

radius_fe <- radius_log %>%
  mutate(
    log_area           = log1p(area),
    interact_area_dist = area * dist_centroid
  )

# ── VIF Analysis ───────────────────────────────────────────────────────────────
lm_vif_range <- lm(
  log_Count ~ log_area + X_range + Y_range + dist_centroid +
              aspect_ratio + interact_area_dist + boundary_flag,
  data = range_fe
)
vif_range <- vif(lm_vif_range)
cat("\nVIF (Range):\n"); print(round(vif_range, 2))

lm_vif_radius <- lm(
  log_Count ~ log_area + dist_centroid + X_norm + Y_norm,
  data = radius_fe
)
vif_radius <- vif(lm_vif_radius)
cat("\nVIF (Radius):\n"); print(round(vif_radius, 2))

# ── Train / Test Split ─────────────────────────────────────────────────────────
set.seed(42)
n_range       <- nrow(range_fe)
train_idx_r   <- sample(n_range, size = floor(0.8 * n_range))
test_idx_r    <- setdiff(seq_len(n_range), train_idx_r)
range_train   <- range_fe[train_idx_r, ]
range_test    <- range_fe[test_idx_r,  ]

n_radius      <- nrow(radius_fe)
train_idx_rad <- sample(n_radius, size = floor(0.8 * n_radius))
test_idx_rad  <- setdiff(seq_len(n_radius), train_idx_rad)
radius_train  <- radius_fe[train_idx_rad, ]
radius_test   <- radius_fe[test_idx_rad,  ]

write_csv(data.frame(index = train_idx_r,   split = "train"), "results/split_range.csv")
write_csv(data.frame(index = train_idx_rad, split = "train"), "results/split_radius.csv")
cat("Range — train:", nrow(range_train), "| test:", nrow(range_test), "\n")
cat("Radius — train:", nrow(radius_train), "| test:", nrow(radius_test), "\n")

# ── Metric Helper ──────────────────────────────────────────────────────────────
calc_metrics <- function(actual_log, pred_log, label = "") {
  actual <- expm1(actual_log)
  pred   <- pmax(expm1(pred_log), 0)
  rmse_v <- rmse(actual, pred)
  mae_v  <- mae(actual, pred)
  r2_v   <- 1 - sum((actual - pred)^2) / sum((actual - mean(actual))^2)
  mape_v <- mean(abs((actual - pred) / (actual + 1))) * 100
  if (nchar(label) > 0)
    cat(sprintf("  %-8s RMSE=%-10.2f MAE=%-10.2f R2=%.4f MAPE=%.2f%%\n",
                label, rmse_v, mae_v, r2_v, mape_v))
  c(RMSE = rmse_v, MAE = mae_v, R2 = r2_v, MAPE = mape_v)
}

make_row <- function(dataset, model, split, m)
  data.frame(dataset, model, split,
             RMSE = m["RMSE"], MAE = m["MAE"], R2 = m["R2"], MAPE = m["MAPE"],
             row.names = NULL)

# ── Linear Regression ──────────────────────────────────────────────────────────
cat("\n── Linear Regression ──\n")
lm_feats_range <- c("log_area", "dist_centroid", "interact_area_dist",
                    "aspect_ratio", "boundary_flag")
lm_range     <- lm(as.formula(paste("log_Count ~", paste(lm_feats_range, collapse = " + "))),
                   data = range_train)
lm_range_sum <- lm(as.formula(paste("log_SUM ~",   paste(lm_feats_range, collapse = " + "))),
                   data = range_train)

lm_range_train <- calc_metrics(range_train$log_Count, predict(lm_range, range_train), "Train")
lm_range_test  <- calc_metrics(range_test$log_Count,  predict(lm_range, range_test),  "Test ")
cat("Range LM SUM — "); calc_metrics(range_test$log_SUM, predict(lm_range_sum, range_test), "Test ")

write_csv(data.frame(dataset="range", model="linear",
                     split=c("train","test"),
                     RMSE=c(lm_range_train["RMSE"], lm_range_test["RMSE"]),
                     MAE =c(lm_range_train["MAE"],  lm_range_test["MAE"]),
                     R2  =c(lm_range_train["R2"],   lm_range_test["R2"]),
                     MAPE=c(lm_range_train["MAPE"], lm_range_test["MAPE"])),
          "results/model_linear.csv")

lm_feats_rad <- c("log_area", "dist_centroid", "X_norm", "Y_norm")
lm_radius    <- lm(as.formula(paste("log_Count ~", paste(lm_feats_rad, collapse = " + "))),
                   data = radius_train)
lm_rad_train <- calc_metrics(radius_train$log_Count, predict(lm_radius, radius_train), "Train")
lm_rad_test  <- calc_metrics(radius_test$log_Count,  predict(lm_radius, radius_test),  "Test ")

# ── Random Forest ──────────────────────────────────────────────────────────────
cat("\n── Random Forest (500 trees) — Range [slow ~15min] ──\n")
rf_feats_range <- c("log_area", "X_range", "Y_range", "dist_centroid",
                    "aspect_ratio", "interact_area_dist", "boundary_flag",
                    "X_norm", "Y_norm")
set.seed(42)
rf_range <- randomForest(x = range_train[, rf_feats_range], y = range_train$log_Count,
                         ntree = 500, mtry = floor(sqrt(length(rf_feats_range))),
                         importance = TRUE, do.trace = 100)
rf_range_train <- calc_metrics(range_train$log_Count, predict(rf_range, range_train[, rf_feats_range]), "Train")
rf_range_test  <- calc_metrics(range_test$log_Count,  predict(rf_range, range_test[,  rf_feats_range]), "Test ")

imp_range <- importance(rf_range, type = 1)
fi_range  <- data.frame(feature = rownames(imp_range), importance = imp_range[,1],
                        dataset = "range", model = "randomForest") %>%
             arrange(desc(importance))
write_csv(fi_range, "results/feature_importance.csv")

cat("\n── Random Forest (500 trees) — Radius ──\n")
rf_feats_rad <- c("R", "log_area", "dist_centroid", "interact_area_dist", "X_norm", "Y_norm")
set.seed(42)
rf_radius <- randomForest(x = radius_train[, rf_feats_rad], y = radius_train$log_Count,
                          ntree = 500, mtry = floor(sqrt(length(rf_feats_rad))),
                          importance = TRUE, do.trace = 100)
rf_rad_train <- calc_metrics(radius_train$log_Count, predict(rf_radius, radius_train[, rf_feats_rad]), "Train")
rf_rad_test  <- calc_metrics(radius_test$log_Count,  predict(rf_radius, radius_test[,  rf_feats_rad]), "Test ")

# ── XGBoost ────────────────────────────────────────────────────────────────────
cat("\n── XGBoost grid search — Range Count [slow ~15min] ──\n")
xgb_feats_range <- c("log_area", "X_range", "Y_range", "dist_centroid",
                     "aspect_ratio", "interact_area_dist", "boundary_flag", "X_norm", "Y_norm")
dtrain_r   <- xgb.DMatrix(data = as.matrix(range_train[, xgb_feats_range]), label = range_train$log_Count)
dtest_r    <- xgb.DMatrix(data = as.matrix(range_test[,  xgb_feats_range]), label = range_test$log_Count)
dtrain_sum <- xgb.DMatrix(data = as.matrix(range_train[, xgb_feats_range]), label = range_train$log_SUM)
dtest_sum  <- xgb.DMatrix(data = as.matrix(range_test[,  xgb_feats_range]), label = range_test$log_SUM)

grid_r <- expand.grid(eta = c(0.05, 0.1, 0.3), max_depth = c(4, 6, 8), subsample = c(0.7, 0.9))
cv_results_r <- vector("list", nrow(grid_r))
for (i in seq_len(nrow(grid_r))) {
  cv <- xgb.cv(
    params = list(booster="gbtree", objective="reg:squarederror",
                  eta=grid_r$eta[i], max_depth=grid_r$max_depth[i],
                  subsample=grid_r$subsample[i], colsample_bytree=0.8, seed=42),
    data = dtrain_r, nrounds = 500, nfold = 5, metrics = "rmse",
    early_stopping_rounds = 20, verbose = 0)
  best_rmse  <- min(cv$evaluation_log$test_rmse_mean)
  best_round <- which.min(cv$evaluation_log$test_rmse_mean)
  cv_results_r[[i]] <- data.frame(grid_r[i,], best_rmse, best_round)
  cat(sprintf("Grid %2d/18 | eta=%.2f depth=%d sub=%.1f | CV-RMSE=%.4f @ round %d\n",
              i, grid_r$eta[i], grid_r$max_depth[i], grid_r$subsample[i], best_rmse, best_round))
}
cv_summary_r <- bind_rows(cv_results_r)
best_row_r   <- cv_summary_r[which.min(cv_summary_r$best_rmse), ]
cat("Best params (Range/Count):\n"); print(best_row_r)

best_params_r <- list(booster="gbtree", objective="reg:squarederror",
                      eta=best_row_r$eta, max_depth=best_row_r$max_depth,
                      subsample=best_row_r$subsample, colsample_bytree=0.8, seed=42)
set.seed(42)
xgb_range_count <- xgb.train(params=best_params_r, data=dtrain_r, nrounds=best_row_r$best_round, verbose=0)
xgb_range_sum   <- xgb.train(params=best_params_r, data=dtrain_sum, nrounds=best_row_r$best_round, verbose=0)

xgb_rc_train <- calc_metrics(range_train$log_Count, predict(xgb_range_count, dtrain_r),   "Train")
xgb_rc_test  <- calc_metrics(range_test$log_Count,  predict(xgb_range_count, dtest_r),    "Test ")
xgb_rs_train <- calc_metrics(range_train$log_SUM,   predict(xgb_range_sum,   dtrain_sum), "Train")
xgb_rs_test  <- calc_metrics(range_test$log_SUM,    predict(xgb_range_sum,   dtest_sum),  "Test ")

cat("\n── XGBoost grid search — Radius Count ──\n")
xgb_feats_rad <- c("R", "log_area", "dist_centroid", "interact_area_dist", "X_norm", "Y_norm")
dtrain_rad <- xgb.DMatrix(data = as.matrix(radius_train[, xgb_feats_rad]), label = radius_train$log_Count)
dtest_rad  <- xgb.DMatrix(data = as.matrix(radius_test[,  xgb_feats_rad]), label = radius_test$log_Count)

grid_rad <- expand.grid(eta = c(0.05, 0.1, 0.3), max_depth = c(4, 6), subsample = c(0.7, 0.9))
cv_results_rad <- vector("list", nrow(grid_rad))
for (i in seq_len(nrow(grid_rad))) {
  cv <- xgb.cv(
    params = list(booster="gbtree", objective="reg:squarederror",
                  eta=grid_rad$eta[i], max_depth=grid_rad$max_depth[i],
                  subsample=grid_rad$subsample[i], colsample_bytree=0.8, seed=42),
    data = dtrain_rad, nrounds = 300, nfold = 5, metrics = "rmse",
    early_stopping_rounds = 20, verbose = 0)
  best_rmse  <- min(cv$evaluation_log$test_rmse_mean)
  best_round <- which.min(cv$evaluation_log$test_rmse_mean)
  cv_results_rad[[i]] <- data.frame(grid_rad[i,], best_rmse, best_round)
  cat(sprintf("Grid %2d/12 | eta=%.2f depth=%d sub=%.1f | CV-RMSE=%.4f @ round %d\n",
              i, grid_rad$eta[i], grid_rad$max_depth[i], grid_rad$subsample[i], best_rmse, best_round))
}
cv_summary_rad <- bind_rows(cv_results_rad)
best_row_rad   <- cv_summary_rad[which.min(cv_summary_rad$best_rmse), ]
cat("Best params (Radius/Count):\n"); print(best_row_rad)

best_params_rad <- list(booster="gbtree", objective="reg:squarederror",
                        eta=best_row_rad$eta, max_depth=best_row_rad$max_depth,
                        subsample=best_row_rad$subsample, colsample_bytree=0.8, seed=42)
set.seed(42)
xgb_radius_count <- xgb.train(params=best_params_rad, data=dtrain_rad, nrounds=best_row_rad$best_round, verbose=0)
xgb_radc_train <- calc_metrics(radius_train$log_Count, predict(xgb_radius_count, dtrain_rad), "Train")
xgb_radc_test  <- calc_metrics(radius_test$log_Count,  predict(xgb_radius_count, dtest_rad),  "Test ")

# ── KNN ────────────────────────────────────────────────────────────────────────
cat("\n── KNN (K = 5, 10, 20) — Range [slow ~5min] ──\n")
norm_col <- function(x) (x - min(x)) / (max(x) - min(x) + 1e-12)
knn_feats_range <- c("log_area", "dist_centroid", "X_norm", "Y_norm", "aspect_ratio", "interact_area_dist")
X_knn_train_r <- as.matrix(range_train[, knn_feats_range] %>% mutate(across(everything(), norm_col)))
X_knn_test_r  <- as.matrix(range_test[,  knn_feats_range] %>%
                   mutate(across(everything(), ~(. - min(range_train[[cur_column()]])) /
                                               (max(range_train[[cur_column()]]) - min(range_train[[cur_column()]]) + 1e-12))))
best_knn_rmse_r <- Inf; best_k_r <- 5
for (k in c(5, 10, 20)) {
  pred <- knn.reg(train=X_knn_train_r, test=X_knn_test_r, y=range_train$log_Count, k=k)$pred
  m <- calc_metrics(range_test$log_Count, pred, paste0("K=", k))
  if (m["RMSE"] < best_knn_rmse_r) { best_knn_rmse_r <- m["RMSE"]; best_k_r <- k }
}
cat("Best K (Range):", best_k_r, "\n")

cat("\n── KNN — Radius ──\n")
knn_feats_rad <- c("log_area", "dist_centroid", "X_norm", "Y_norm", "interact_area_dist")
X_knn_train_rad <- as.matrix(radius_train[, knn_feats_rad] %>% mutate(across(everything(), norm_col)))
X_knn_test_rad  <- as.matrix(radius_test[,  knn_feats_rad] %>%
                    mutate(across(everything(), ~(. - min(radius_train[[cur_column()]])) /
                                                (max(radius_train[[cur_column()]]) - min(radius_train[[cur_column()]]) + 1e-12))))
best_knn_rmse_rad <- Inf; best_k_rad <- 5
for (k in c(5, 10, 20)) {
  pred <- knn.reg(train=X_knn_train_rad, test=X_knn_test_rad, y=radius_train$log_Count, k=k)$pred
  m <- calc_metrics(radius_test$log_Count, pred, paste0("K=", k))
  if (m["RMSE"] < best_knn_rmse_rad) { best_knn_rmse_rad <- m["RMSE"]; best_k_rad <- k }
}
cat("Best K (Radius):", best_k_rad, "\n")

# ── Compile Results ────────────────────────────────────────────────────────────
cat("\n── Compiling results ──\n")
knn_rc_test  <- calc_metrics(range_test$log_Count,
  knn.reg(train=X_knn_train_r, test=X_knn_test_r, y=range_train$log_Count, k=best_k_r)$pred, "")
knn_rc_train <- calc_metrics(range_train$log_Count,
  knn.reg(train=X_knn_train_r, test=X_knn_train_r, y=range_train$log_Count, k=best_k_r)$pred, "")
knn_radc_test <- calc_metrics(radius_test$log_Count,
  knn.reg(train=X_knn_train_rad, test=X_knn_test_rad, y=radius_train$log_Count, k=best_k_rad)$pred, "")
knn_radc_train <- calc_metrics(radius_train$log_Count,
  knn.reg(train=X_knn_train_rad, test=X_knn_train_rad, y=radius_train$log_Count, k=best_k_rad)$pred, "")

cv_comparison <- bind_rows(
  make_row("range",  "linear",                    "train", lm_range_train),
  make_row("range",  "linear",                    "test",  lm_range_test),
  make_row("range",  "randomForest",              "train", rf_range_train),
  make_row("range",  "randomForest",              "test",  rf_range_test),
  make_row("range",  "xgboost",                   "train", xgb_rc_train),
  make_row("range",  "xgboost",                   "test",  xgb_rc_test),
  make_row("range",  paste0("knn_k", best_k_r),  "train", knn_rc_train),
  make_row("range",  paste0("knn_k", best_k_r),  "test",  knn_rc_test),
  make_row("radius", "linear",                    "train", lm_rad_train),
  make_row("radius", "linear",                    "test",  lm_rad_test),
  make_row("radius", "randomForest",              "train", rf_rad_train),
  make_row("radius", "randomForest",              "test",  rf_rad_test),
  make_row("radius", "xgboost",                   "train", xgb_radc_train),
  make_row("radius", "xgboost",                   "test",  xgb_radc_test),
  make_row("radius", paste0("knn_k", best_k_rad), "train", knn_radc_train),
  make_row("radius", paste0("knn_k", best_k_rad), "test",  knn_radc_test)
)
write_csv(cv_comparison, "results/cv_comparison.csv")
cat("[OK] results/cv_comparison.csv written\n")

# ── Feature Importance Plot ────────────────────────────────────────────────────
xgb_fi    <- xgb.importance(feature_names = xgb_feats_range, model = xgb_range_count)
xgb_fi_df <- as.data.frame(xgb_fi) %>% mutate(Feature = reorder(Feature, Gain))
p_fi <- ggplot(xgb_fi_df, aes(x = Feature, y = Gain)) +
  geom_col(fill = "#2E86AB") + coord_flip() +
  labs(title = "XGBoost Feature Importance — Range Queries (Count)",
       subtitle = "Gain = average improvement in loss per split", x = NULL, y = "Gain") +
  theme_minimal(base_size = 13)
ggsave("report/figures/fig07_feature_importance.png", p_fi, width = 8, height = 5, dpi = 300)
cat("[OK] report/figures/fig07_feature_importance.png saved\n")

fi_combined <- bind_rows(fi_range,
  xgb_fi_df %>% transmute(feature=as.character(Feature), importance=Gain,
                           dataset="range", model="xgboost"))
write_csv(fi_combined, "results/feature_importance.csv")

# ── Save Models ────────────────────────────────────────────────────────────────
saveRDS(lm_range,  "models/model_linear_range.rds")
saveRDS(lm_radius, "models/model_linear_radius.rds")
saveRDS(rf_range,  "models/model_rf_range.rds")
saveRDS(rf_radius, "models/model_rf_radius.rds")
xgb.save(xgb_range_count,  "models/model_xgb_range_count.model")
xgb.save(xgb_range_sum,    "models/model_xgb_range_sum.model")
xgb.save(xgb_radius_count, "models/model_xgb_radius_count.model")
saveRDS(list(k=best_k_r,   X_train=X_knn_train_r,   y_train=range_train$log_Count),
        "models/model_knn_range.rds")
saveRDS(list(k=best_k_rad, X_train=X_knn_train_rad, y_train=radius_train$log_Count),
        "models/model_knn_radius.rds")

write_csv(bind_rows(mutate(best_row_r,   dataset="range",  target="Count"),
                    mutate(best_row_rad, dataset="radius", target="Count")),
          "results/xgb_best_params.csv")

cat("[OK] All model objects saved to models/\n")
cat("[OK] Done. Run: Rscript src/modeling.R\n")
