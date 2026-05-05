---
editor_options: 
  markdown: 
    wrap: 72
---

# Section 4 - Data Analysis

## 4.1 Distribution of Aggregate Targets

The three aggregate targets in the Range Queries sub-dataset, Count,
SUM, and AVG, exhibit markedly different distributional shapes. Count
(mean ≈ 159,553, SD ≈ 154,476) and SUM (mean ≈ 47,932, SD ≈ 47,948) are
heavily right-skewed (skewness 1.35 and 1.48 respectively), with long
tails driven by large-rectangle queries that capture thousands of crime
records. A log1p transformation shifts both distributions toward a more
symmetric shape, though mild left skewness persists (−1.71 and −1.61)
due to zero-inflation at the low end. AVG is already near-symmetric
(skewness ≈ −0.06) and requires no transformation. All regression models
in Section 5 therefore train on log1p-transformed Count and SUM, with
targets back-transformed via expm1() for metric reporting.

In contrast, the Radius Count sub-dataset's Count ranges only from 2 to
695 (mean ≈ 265, SD ≈ 130), which is approximately 600× smaller than
Range Queries. This confirms that the two workloads cannot share a
single predictive model (Figure 5).

## 4.2 Spatial Distribution of Query Origins (Figure 1)

The spatial heatmap (Figure 1) shows that all three sub-datasets
concentrate query origins in a central band of normalized Chicago space
(X_norm ≈ 0.2–0.6, Y_norm ≈ 0.3–0.7), consistent with the Gaussian
sampling used to generate the workloads. Range Queries exhibit the
widest spatial spread across all four quadrants, while Radius Queries
cluster more tightly in the lower-X portion of the grid. The high
proportion of boundary-crossing queries in the radius datasets (≈99.9%,
flagged by Person 1) is visible as a dense core that tapers sharply near
the bounding-box edges, where truncated coverage artificially reduces
Count.

## 4.3 Feature Correlation Analysis (Figure 2)

Pearson and Spearman correlation matrices (Figure 2) confirm that `area`
is the dominant predictor of Count (Spearman ρ = 0.95), followed by
`Y_range` (ρ = 0.66) and `X_range` (ρ = 0.61). Because area is
constructed as 4 × X_range × Y_range, all three features are collinear,
so a VIF analysis in the modeling phase is expected to flag VIF \> 10
for at least one of them. `dist_centroid` contributes a weak secondary
spatial signal (ρ ≈ 0.08). Outlier detection flagged approximately 3% of
Range Queries rows for Count and SUM via combined IQR (1.5×) and Z-score
(\|z\| \> 3) criteria; these correspond to large-area queries at the
distributional extremes.

## 4.4 Spatial Heterogeneity by Quadrant (Figure 3)

Dividing Chicago into four quadrants at the normalized spatial midpoint
(X_norm = 0.5, Y_norm = 0.5) reveals broadly similar Count distributions
across all zones (Figure 3). The North-West and North-East quadrants
show slightly higher median Counts, consistent with higher crime density
in central and northern Chicago. However, the wide IQR within each
quadrant (≈60,000–200,000) dwarfs the between-quadrant difference,
confirming that query rectangle area, not geographic zone, is the
primary driver of Count variance. Quadrant can serve as a weak
categorical feature in modeling but should not be expected to improve
R-squared substantially.
