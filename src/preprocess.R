suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(moments)
  library(jsonlite)
})

# ---- paths -------------------------------------------------------------
root <- tryCatch({
  dirname(dirname(normalizePath(sys.frame(1)$ofile)))
}, error = function(e) getwd())
RAW <- file.path(root, "data", "raw")
PROCESSED <- file.path(root, "data", "processed")
dir.create(PROCESSED, showWarnings = FALSE, recursive = TRUE)

EXPECTED_ROWS <- list(
  range_queries  = 200000L,
  radius_queries = 50000L,
  radius_count   = 10000L
)

# ---- loaders -----------------------------------------------------------
load_range_queries <- function() {
  df <- read_csv(file.path(RAW, "Range-Queries-Aggregates.csv"),
                 show_col_types = FALSE)
  # Drop the unnamed integer index column (first col).
  df <- df[, -1, drop = FALSE]
  df %>% rename(X = x, Y = y,
                X_range = x_range, Y_range = y_range,
                Count = count, SUM = sum_, AVG = avg)
}

load_radius_queries <- function() {
  read_csv(file.path(RAW, "Radius-Queries.csv"),
           col_names = c("X", "Y", "R"),
           show_col_types = FALSE)
}

load_radius_count <- function() {
  read_csv(file.path(RAW, "Radius-Queries-Count.csv"),
           col_names = c("X", "Y", "R", "Count"),
           show_col_types = FALSE)
}

# ---- helpers -----------------------------------------------------------
describe_numeric <- function(df) {
  num <- df %>% select(where(is.numeric))
  tibble(
    column   = names(num),
    min      = vapply(num, min,    numeric(1), na.rm = TRUE),
    max      = vapply(num, max,    numeric(1), na.rm = TRUE),
    mean     = vapply(num, mean,   numeric(1), na.rm = TRUE),
    median   = vapply(num, median, numeric(1), na.rm = TRUE),
    sd       = vapply(num, sd,     numeric(1), na.rm = TRUE),
    skew     = vapply(num, moments::skewness, numeric(1), na.rm = TRUE),
    kurtosis = vapply(num, moments::kurtosis, numeric(1), na.rm = TRUE)
  )
}

engineer_features <- function(df, kind) {
  if (kind == "range") {
    df$area <- 4 * df$X_range * df$Y_range
  } else {
    df$area <- pi * df$R^2
  }
  x_min <- min(df$X); x_max <- max(df$X)
  y_min <- min(df$Y); y_max <- max(df$Y)
  df$X_norm <- (df$X - x_min) / (x_max - x_min)
  df$Y_norm <- (df$Y - y_min) / (y_max - y_min)
  cx <- mean(df$X); cy <- mean(df$Y)
  df$dist_centroid <- sqrt((df$X - cx)^2 + (df$Y - cy)^2)
  df
}

count_boundary <- function(df, kind) {
  x_min <- min(df$X); x_max <- max(df$X)
  y_min <- min(df$Y); y_max <- max(df$Y)
  if (kind == "range") {
    hx <- df$X_range / 2; hy <- df$Y_range / 2
    cross <- (df$X - hx < x_min) | (df$X + hx > x_max) |
             (df$Y - hy < y_min) | (df$Y + hy > y_max)
  } else {
    cross <- (df$X - df$R < x_min) | (df$X + df$R > x_max) |
             (df$Y - df$R < y_min) | (df$Y + df$R > y_max)
  }
  sum(cross)
}

log_transform <- function(df) {
  if ("Count" %in% names(df)) df$log_Count <- log1p(df$Count)
  if ("SUM"   %in% names(df)) df$log_SUM   <- log1p(df$SUM)
  df
}

# ---- per-dataset pipeline ---------------------------------------------
process_one <- function(name, df, kind) {
  cat(sprintf("\n=== Processing %s ===\n", name))
  raw_rows <- nrow(df)

  expected <- EXPECTED_ROWS[[name]]
  if (raw_rows == expected) {
    cat(sprintf("[OK]   %s rows match UCI documentation (%d)\n",
                name, raw_rows))
  } else {
    cat(sprintf("[WARN] %s: expected %d, got %d\n",
                name, expected, raw_rows))
  }

  # Null handling. UCI card claims no nulls; in practice range_queries.AVG
  # has ~157 NAs where Count = 0 and SUM = 0 (AVG = 0/0 is undefined).
  null_counts <- sapply(df, function(v) sum(is.na(v)))
  avg_zero_imputed <- 0L
  if (name == "range_queries" && any(is.na(df$AVG))) {
    mask <- is.na(df$AVG) & df$Count == 0
    avg_zero_imputed <- sum(mask)
    other <- sum(is.na(df$AVG) & df$Count != 0)
    cat(sprintf("[INFO] AVG nulls: %d from Count=0 rows (imputed 0), %d unexplained\n",
                avg_zero_imputed, other))
    df$AVG[mask] <- 0
  }
  stopifnot(sum(is.na(df)) == 0)
  cat("[OK]   no null values after imputation\n")

  # De-duplication.
  before <- nrow(df)
  df <- distinct(df)
  removed <- before - nrow(df)
  retention <- nrow(df) / before
  cat(sprintf("[INFO] duplicates removed: %d (%.3f%% retention)\n",
              removed, retention * 100))

  # Feature engineering + boundary check.
  df <- engineer_features(df, kind)
  n_boundary <- count_boundary(df, kind)
  cat(sprintf("[INFO] boundary-effect queries flagged: %d\n", n_boundary))

  # Write outputs.
  out_raw <- file.path(PROCESSED, sprintf("clean_%s.csv", name))
  write_csv(df, out_raw)
  cat(sprintf("[OK]   wrote %s (%d rows)\n", out_raw, nrow(df)))

  if (any(c("Count", "SUM") %in% names(df))) {
    out_log <- file.path(PROCESSED, sprintf("clean_%s_log.csv", name))
    write_csv(log_transform(df), out_log)
    cat(sprintf("[OK]   wrote %s (with log targets)\n", out_log))
  }

  desc <- describe_numeric(df) %>% mutate(dataset = name, .before = 1)

  list(
    name = name,
    raw_rows = raw_rows,
    duplicates_removed = removed,
    retention_rate = retention,
    null_counts = as.list(null_counts),
    avg_zero_imputed = avg_zero_imputed,
    boundary_rows = n_boundary,
    columns = names(df),
    stats = desc
  )
}

# ---- orchestrator ------------------------------------------------------
run <- function() {
  r1 <- process_one("range_queries",  load_range_queries(),  "range")
  r2 <- process_one("radius_queries", load_radius_queries(), "radius")
  r3 <- process_one("radius_count",   load_radius_count(),   "radius")

  schema_summary <- bind_rows(r1$stats, r2$stats, r3$stats)
  write_csv(schema_summary, file.path(PROCESSED, "schema_summary.csv"))
  cat(sprintf("\n[OK]   schema summary -> data/processed/schema_summary.csv\n"))

  reports <- list(r1, r2, r3)
  for (r in reports) r$stats <- NULL  # strip before JSON
  writeLines(toJSON(lapply(reports, function(r) {
    r$stats <- NULL; r
  }), pretty = TRUE, auto_unbox = TRUE),
    file.path(PROCESSED, "processing_log.json"))
  cat("[OK]   processing log -> data/processed/processing_log.json\n")

  invisible(reports)
}

# Run when sourced as a script.
if (!interactive() && sys.nframe() == 0L) run()
