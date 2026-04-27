# Day 2 — EDA & Visualization | Manthan Sarjuse
# Run: Rscript src/eda.R
# Produces: report/figures/fig01–fig06.png and reports to console

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(corrplot)
  library(patchwork)
  library(viridis)
  library(moments)
  library(scales)
})

proc_dir <- "data/processed"
fig_dir  <- "report/figures"
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

save_fig <- function(p, name, w = 10, h = 6) {
  out <- file.path(fig_dir, name)
  ggsave(out, plot = p, width = w, height = h, dpi = 300, units = "in")
  message("  saved: ", out)
}

# ── 1. Load data ─────────────────────────────────────────────────────────────
message("Loading clean CSVs …")
range_q    <- read_csv(file.path(proc_dir, "clean_range_queries.csv"),     show_col_types = FALSE)
range_log  <- read_csv(file.path(proc_dir, "clean_range_queries_log.csv"), show_col_types = FALSE)
radius_q   <- read_csv(file.path(proc_dir, "clean_radius_queries.csv"),    show_col_types = FALSE)
radius_c   <- read_csv(file.path(proc_dir, "clean_radius_count.csv"),      show_col_types = FALSE)
radius_log <- read_csv(file.path(proc_dir, "clean_radius_count_log.csv"),  show_col_types = FALSE)

# ── 2. Schema check ───────────────────────────────────────────────────────────
message("Schema validation …")
check <- tibble(
  dataset   = c("range_queries", "radius_queries", "radius_count"),
  rows      = c(nrow(range_q), nrow(radius_q), nrow(radius_c)),
  expected  = c(200000L, 50000L, 10000L),
  nulls     = c(sum(is.na(range_q)), sum(is.na(radius_q)), sum(is.na(radius_c)))
) %>% mutate(ok = rows == expected & nulls == 0)
print(check)
stopifnot("Schema check failed" = all(check$ok))

# ── 3. Skewness / kurtosis ────────────────────────────────────────────────────
message("Computing skewness/kurtosis …")
skew_tbl <- bind_rows(
  tibble(target = "Count (raw)",   dataset = "range_queries",
         skewness = skewness(range_q$Count),  kurtosis = kurtosis(range_q$Count)),
  tibble(target = "Count (log1p)", dataset = "range_queries",
         skewness = skewness(range_log$log_Count), kurtosis = kurtosis(range_log$log_Count)),
  tibble(target = "SUM (raw)",     dataset = "range_queries",
         skewness = skewness(range_q$SUM),    kurtosis = kurtosis(range_q$SUM)),
  tibble(target = "SUM (log1p)",   dataset = "range_queries",
         skewness = skewness(range_log$log_SUM),   kurtosis = kurtosis(range_log$log_SUM)),
  tibble(target = "AVG",           dataset = "range_queries",
         skewness = skewness(range_q$AVG),    kurtosis = kurtosis(range_q$AVG)),
  tibble(target = "Count (raw)",   dataset = "radius_count",
         skewness = skewness(radius_c$Count), kurtosis = kurtosis(radius_c$Count)),
  tibble(target = "Count (log1p)", dataset = "radius_count",
         skewness = skewness(radius_log$log_Count), kurtosis = kurtosis(radius_log$log_Count))
)
print(skew_tbl, n = Inf)

# ── 4. fig04 — Target distribution histograms ─────────────────────────────────
message("Building fig04 (distributions) …")
p_count_raw <- ggplot(range_q,   aes(x = Count))     +
  geom_histogram(bins = 60, fill = "#2166ac", colour = "white", linewidth = 0.2) +
  scale_x_continuous(labels = comma) + scale_y_continuous(labels = comma) +
  labs(title = "Count — raw (Range Queries)", x = "Count", y = "Frequency") +
  theme_classic(base_size = 11)

p_count_log <- ggplot(range_log, aes(x = log_Count)) +
  geom_histogram(bins = 60, fill = "#4dac26", colour = "white", linewidth = 0.2) +
  scale_y_continuous(labels = comma) +
  labs(title = "Count — log1p (Range Queries)", x = "log1p(Count)", y = "Frequency") +
  theme_classic(base_size = 11)

p_sum_raw   <- ggplot(range_q,   aes(x = SUM))       +
  geom_histogram(bins = 60, fill = "#d01c8b", colour = "white", linewidth = 0.2) +
  scale_x_continuous(labels = comma) + scale_y_continuous(labels = comma) +
  labs(title = "SUM — raw (Range Queries)", x = "SUM", y = "Frequency") +
  theme_classic(base_size = 11)

p_sum_log   <- ggplot(range_log, aes(x = log_SUM))   +
  geom_histogram(bins = 60, fill = "#e66101", colour = "white", linewidth = 0.2) +
  scale_y_continuous(labels = comma) +
  labs(title = "SUM — log1p (Range Queries)", x = "log1p(SUM)", y = "Frequency") +
  theme_classic(base_size = 11)

p_avg       <- ggplot(range_q,   aes(x = AVG))       +
  geom_histogram(bins = 60, fill = "#7b2d8b", colour = "white", linewidth = 0.2) +
  scale_y_continuous(labels = comma) +
  labs(title = "AVG (Range Queries)", x = "AVG", y = "Frequency") +
  theme_classic(base_size = 11)

p_rc_raw    <- ggplot(radius_c,  aes(x = Count))     +
  geom_histogram(bins = 50, fill = "#b35806", colour = "white", linewidth = 0.2) +
  scale_y_continuous(labels = comma) +
  labs(title = "Count — raw (Radius Count)", x = "Count", y = "Frequency") +
  theme_classic(base_size = 11)

p_rc_log    <- ggplot(radius_log, aes(x = log_Count)) +
  geom_histogram(bins = 50, fill = "#fdb863", colour = "white", linewidth = 0.2) +
  scale_y_continuous(labels = comma) +
  labs(title = "Count — log1p (Radius Count)", x = "log1p(Count)", y = "Frequency") +
  theme_classic(base_size = 11)

fig04 <- (p_count_raw | p_count_log) /
         (p_sum_raw   | p_sum_log)   /
         (p_avg       | p_rc_raw | p_rc_log) +
  plot_annotation(
    title   = "Figure 4 — Target distribution histograms (raw and log-transformed)",
    caption = "Top: Range Count | Middle: Range SUM | Bottom: Range AVG & Radius Count",
    theme   = theme(plot.title = element_text(face = "bold"))
  )
save_fig(fig04, "fig04.png", w = 14, h = 10)

# ── 5. fig05 — Count overlay ──────────────────────────────────────────────────
message("Building fig05 (Count overlay) …")
overlay_df <- bind_rows(
  range_log  %>% transmute(log_Count, dataset = "Range Queries (n=200k)"),
  radius_log %>% transmute(log_Count, dataset = "Radius Count   (n=10k)")
)
fig05 <- ggplot(overlay_df, aes(x = log_Count, fill = dataset, colour = dataset)) +
  geom_density(alpha = 0.45, linewidth = 0.8) +
  scale_fill_manual(values   = c("Range Queries (n=200k)" = "#2166ac",
                                  "Radius Count   (n=10k)" = "#b35806")) +
  scale_colour_manual(values = c("Range Queries (n=200k)" = "#2166ac",
                                  "Radius Count   (n=10k)" = "#b35806")) +
  labs(title = "Figure 5 — Count distributions: Range Queries vs Radius Count",
       subtitle = "log1p-transformed Count; density curves overlaid",
       x = "log1p(Count)", y = "Density", fill = "Dataset", colour = "Dataset") +
  theme_classic(base_size = 12) +
  theme(legend.position = "top", plot.title = element_text(face = "bold"))
save_fig(fig05, "fig05.png", w = 10, h = 5)

# ── 6. fig01 — Spatial heatmap ────────────────────────────────────────────────
message("Building fig01 (spatial heatmap) …")
hm_theme <- theme_minimal(base_size = 11) +
  theme(panel.grid = element_blank(), axis.ticks = element_line(),
        plot.title = element_text(face = "bold"))

p_h1 <- ggplot(range_q,  aes(x = X_norm, y = Y_norm)) +
  geom_bin2d(bins = 50) +
  scale_fill_viridis_c(option = "magma", labels = comma, name = "Query\ncount") +
  coord_fixed() +
  labs(title = "Range Queries Aggregates (n = 200,000)",
       x = "X (normalized)", y = "Y (normalized)") + hm_theme

p_h2 <- ggplot(radius_q, aes(x = X_norm, y = Y_norm)) +
  geom_bin2d(bins = 50) +
  scale_fill_viridis_c(option = "magma", labels = comma, name = "Query\ncount") +
  coord_fixed() +
  labs(title = "Radius Queries (n = 50,000)",
       x = "X (normalized)", y = "Y (normalized)") + hm_theme

p_h3 <- ggplot(radius_c, aes(x = X_norm, y = Y_norm)) +
  geom_bin2d(bins = 50) +
  scale_fill_viridis_c(option = "magma", labels = comma, name = "Query\ncount") +
  coord_fixed() +
  labs(title = "Radius Count (n = 10,000)",
       x = "X (normalized)", y = "Y (normalized)") + hm_theme

fig01 <- (p_h1 | p_h2 | p_h3) +
  plot_annotation(
    title   = "Figure 1 — Spatial heatmap: 2D density of query origins",
    caption = "Viridis/magma scale. Coordinates normalized to [0, 1] per dataset.",
    theme   = theme(plot.title = element_text(face = "bold", size = 13))
  )
save_fig(fig01, "fig01.png", w = 15, h = 5)

# ── 7. Outlier detection ──────────────────────────────────────────────────────
message("Flagging outliers …")
flag_outliers <- function(x) {
  q1  <- quantile(x, 0.25, na.rm = TRUE)
  q3  <- quantile(x, 0.75, na.rm = TRUE)
  iqr <- q3 - q1
  z   <- (x - mean(x, na.rm = TRUE)) / sd(x, na.rm = TRUE)
  (x < q1 - 1.5 * iqr) | (x > q3 + 1.5 * iqr) | (abs(z) > 3)
}

range_q <- range_q %>%
  mutate(
    outlier_Count = flag_outliers(Count),
    outlier_SUM   = flag_outliers(SUM),
    outlier_AVG   = flag_outliers(AVG)
  )
radius_c <- radius_c %>%
  mutate(outlier_Count = flag_outliers(Count))

out_summary <- tibble(
  column = c("range_q$Count", "range_q$SUM", "range_q$AVG", "radius_c$Count"),
  outliers = c(sum(range_q$outlier_Count), sum(range_q$outlier_SUM),
               sum(range_q$outlier_AVG),   sum(radius_c$outlier_Count)),
  pct = outliers / c(rep(nrow(range_q), 3), nrow(radius_c)) * 100
)
print(out_summary)

# ── 8. fig06 — Scatter plots with outlier overlay ─────────────────────────────
message("Building fig06 (scatter + outliers) …")
set.seed(42)
rq_s <- range_q %>% slice_sample(n = 5000)

p_s1 <- ggplot(rq_s, aes(x = area, y = Count, colour = outlier_Count)) +
  geom_point(alpha = 0.4, size = 0.8) +
  scale_colour_manual(values = c("FALSE" = "#2166ac", "TRUE" = "#d73027"),
                      labels = c("Normal", "Outlier")) +
  scale_x_continuous(labels = comma) + scale_y_continuous(labels = comma) +
  labs(title = "Area vs Count (Range, n=5k)", x = "Area", y = "Count", colour = NULL) +
  theme_classic(base_size = 11) + theme(legend.position = "top")

p_s2 <- ggplot(rq_s, aes(x = area, y = SUM, colour = outlier_SUM)) +
  geom_point(alpha = 0.4, size = 0.8) +
  scale_colour_manual(values = c("FALSE" = "#4dac26", "TRUE" = "#d73027"),
                      labels = c("Normal", "Outlier")) +
  scale_x_continuous(labels = comma) + scale_y_continuous(labels = comma) +
  labs(title = "Area vs SUM (Range, n=5k)", x = "Area", y = "SUM", colour = NULL) +
  theme_classic(base_size = 11) + theme(legend.position = "top")

p_s3 <- ggplot(rq_s, aes(x = area, y = AVG, colour = outlier_AVG)) +
  geom_point(alpha = 0.4, size = 0.8) +
  scale_colour_manual(values = c("FALSE" = "#7b2d8b", "TRUE" = "#d73027"),
                      labels = c("Normal", "Outlier")) +
  scale_x_continuous(labels = comma) + scale_y_continuous(labels = comma) +
  labs(title = "Area vs AVG (Range, n=5k)", x = "Area", y = "AVG", colour = NULL) +
  theme_classic(base_size = 11) + theme(legend.position = "top")

p_s4 <- ggplot(radius_c, aes(x = R, y = Count, colour = outlier_Count)) +
  geom_point(alpha = 0.5, size = 0.9) +
  scale_colour_manual(values = c("FALSE" = "#b35806", "TRUE" = "#d73027"),
                      labels = c("Normal", "Outlier")) +
  labs(title = "Radius vs Count (Radius Count, n=10k)",
       x = "Radius R", y = "Count", colour = NULL) +
  theme_classic(base_size = 11) + theme(legend.position = "top")

fig06 <- (p_s1 | p_s2) / (p_s3 | p_s4) +
  plot_annotation(
    title   = "Figure 6 — Scatter plots with IQR/Z-score outlier overlay",
    caption = "Red = IQR (1.5×) OR Z-score (|z|>3). Range downsampled to n=5,000.",
    theme   = theme(plot.title = element_text(face = "bold"))
  )
save_fig(fig06, "fig06.png", w = 14, h = 10)

# ── 9. fig02 — Correlation matrix ─────────────────────────────────────────────
message("Building fig02 (correlation matrix) …")
rq_corr <- range_q %>%
  select(X_norm, Y_norm, X_range, Y_range, area, dist_centroid, Count, SUM, AVG)
cor_p <- cor(rq_corr, method = "pearson",  use = "complete.obs")
cor_s <- cor(rq_corr, method = "spearman", use = "complete.obs")

png(file.path(fig_dir, "fig02.png"), width = 14, height = 7,
    units = "in", res = 300)
par(mfrow = c(1, 2), mar = c(2, 2, 4, 2))
corrplot(cor_p,
         method = "color", type = "upper", order = "hclust",
         addCoef.col = "black", number.cex = 0.65,
         tl.cex = 0.8, tl.col = "black", tl.srt = 45,
         col = colorRampPalette(c("#2166ac", "white", "#d73027"))(200),
         title = "Pearson Correlation", mar = c(0, 0, 2, 0))
corrplot(cor_s,
         method = "color", type = "upper", order = "hclust",
         addCoef.col = "black", number.cex = 0.65,
         tl.cex = 0.8, tl.col = "black", tl.srt = 45,
         col = colorRampPalette(c("#2166ac", "white", "#d73027"))(200),
         title = "Spearman Correlation", mar = c(0, 0, 2, 0))
dev.off()
message("  saved: ", file.path(fig_dir, "fig02.png"))

# ── 10. Top 3 features ────────────────────────────────────────────────────────
message("Top 3 features correlated with Count …")
top3_df <- data.frame(
  feature    = rownames(cor_s),
  pearson_r  = cor_p[, "Count"],
  spearman_r = cor_s[, "Count"]
) %>%
  filter(!feature %in% c("Count", "SUM", "AVG")) %>%   # exclude other targets
  arrange(desc(abs(spearman_r)))
print(top3_df)
message("Top 3: ", paste(top3_df$feature[1:3], collapse = ", "))

# ── 11. fig03 — Quadrant boxplots ─────────────────────────────────────────────
message("Building fig03 (quadrant boxplots) …")
range_q <- range_q %>%
  mutate(quadrant = case_when(
    X_norm >= 0.5 & Y_norm >= 0.5 ~ "NE (high-X, high-Y)",
    X_norm <  0.5 & Y_norm >= 0.5 ~ "NW (low-X, high-Y)",
    X_norm >= 0.5 & Y_norm <  0.5 ~ "SE (high-X, low-Y)",
    X_norm <  0.5 & Y_norm <  0.5 ~ "SW (low-X, low-Y)"
  ),
  quadrant = factor(quadrant,
    levels = c("NW (low-X, high-Y)", "NE (high-X, high-Y)",
               "SW (low-X, low-Y)", "SE (high-X, low-Y)")))

fig03 <- ggplot(range_q, aes(x = quadrant, y = Count, fill = quadrant)) +
  geom_boxplot(outlier.size = 0.3, outlier.alpha = 0.3,
               linewidth = 0.5, median.linewidth = 1.5) +
  stat_summary(fun = mean, geom = "point", shape = 23,
               size = 2.5, fill = "white", colour = "black") +
  scale_fill_manual(values = c(
    "NW (low-X, high-Y)"  = "#4393c3",
    "NE (high-X, high-Y)" = "#2166ac",
    "SW (low-X, low-Y)"   = "#92c5de",
    "SE (high-X, low-Y)"  = "#d1e5f0"
  )) +
  scale_y_continuous(labels = comma) +
  labs(
    title    = "Figure 3 — Count distribution by spatial quadrant (Range Queries)",
    subtitle = "Quadrants at X_norm = 0.5 and Y_norm = 0.5; diamond = mean",
    x = "Quadrant", y = "Count"
  ) +
  theme_classic(base_size = 12) +
  theme(legend.position = "none",
        axis.text.x = element_text(angle = 15, hjust = 1),
        plot.title  = element_text(face = "bold"))
save_fig(fig03, "fig03.png", w = 10, h = 6)

message("\nAll 6 figures written to ", fig_dir)
message("EDA script complete.")
