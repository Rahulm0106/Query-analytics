# Query Analytics Workloads — R environment setup
# Run once on a fresh machine: source("renv_setup.R")
# This creates renv.lock capturing all project R dependencies.

if (!requireNamespace("renv", quietly = TRUE)) {
  install.packages("renv", repos = "https://cloud.r-project.org")
}

renv::init(bare = TRUE)

pkgs <- c(
  "readr", "dplyr", "tidyr", "janitor", "moments",
  "ggplot2", "corrplot", "GGally", "patchwork", "viridis",
  "randomForest", "xgboost", "caret", "FNN", "car",
  "cluster", "factoextra", "Metrics",
  "rmarkdown", "knitr"
)

install.packages(pkgs, repos = "https://cloud.r-project.org")
renv::snapshot(prompt = FALSE)
