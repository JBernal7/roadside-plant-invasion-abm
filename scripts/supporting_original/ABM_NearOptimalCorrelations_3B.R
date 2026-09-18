# =============================================================================
# Figure B7 and Figure B8
# Near-optimal trade-offs and correlations for Test 3B
# =============================================================================

library(readr)
library(dplyr)
library(stringr)
library(ggplot2)
library(tidyr)

# -------------------------------------------------------------------------
# 1) Read Test 3B history
# -------------------------------------------------------------------------
file_3b <- "C:/Netlogo/Compilacion/MySearchOutput.modelRunHistory_Test3B.csv"
out_dir <- "C:/Netlogo/Compilacion/Figures_AppendixB"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

raw <- read_csv(file_3b, show_col_types = FALSE)

# -------------------------------------------------------------------------
# 2) Standardise names
# -------------------------------------------------------------------------
df <- raw %>%
  rename(
    dispersal_radius_m       = `dispersal_radius_m*`,
    kernel_decay             = `kernel_decay*`,
    maturity_age_years       = `maturity-age-years*`,
    min_sup_for_reproduction = `min-sup-for-reproduction*`,
    r_weight_growth          = `r_weight_growth*`,
    r_weight_estab           = `r_weight_estab*`,
    management_reset_size    = `management_reset_size*`,
    gamma_recovery           = `gamma-recovery*`,
    a                        = `a*`,
    b_minus_a                = `b_minus_a*`,
    fitness                  = `final-step-result`
  )

# -------------------------------------------------------------------------
# 3) Near-optimal set = top 5%
# -------------------------------------------------------------------------
n_top <- max(1, floor(nrow(df) * 0.05))

df_near <- df %>%
  arrange(fitness) %>%
  slice_head(n = n_top)

nrow(df_near) # Debe dar 280 si df tiene 5600 filas.

# -------------------------------------------------------------------------
# 4) Parameter set used for B7
# -------------------------------------------------------------------------
param_cols <- c(
  "a",
  "b_minus_a",
  "r_weight_growth",
  "r_weight_estab",
  "dispersal_radius_m",
  "kernel_decay",
  "maturity_age_years",
  "min_sup_for_reproduction",
  "management_reset_size",
  "gamma_recovery"
)

# Keep only columns with variation
df_cor <- df_near %>%
  select(all_of(param_cols)) %>%
  select(where(~ sum(is.finite(.x)) >= 3 && dplyr::n_distinct(.x[is.finite(.x)]) >= 2))

# -------------------------------------------------------------------------
# 5) Figure B7: pairwise Spearman correlation heatmap
# -------------------------------------------------------------------------
cor_mat <- cor(df_cor, method = "spearman", use = "pairwise.complete.obs")

# Optional clustering order
dist_mat <- as.dist(1 - abs(cor_mat))
hc <- hclust(dist_mat, method = "average")
ord <- hc$order
cor_ord <- cor_mat[ord, ord]

cor_long <- as.data.frame(as.table(cor_ord)) %>%
  rename(var1 = Var1, var2 = Var2, rho = Freq)

p_B7 <- ggplot(cor_long, aes(x = var1, y = var2, fill = rho)) +
  geom_tile() +
  scale_fill_gradient2(limits = c(-1, 1)) +
  coord_fixed() +
  labs(
    x = NULL,
    y = NULL,
    fill = expression(rho),
    title = "Pairwise Spearman correlations within the near-optimal ensemble \n (Test 4)"
  ) +
  theme_bw() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    plot.title = element_text(face = "bold")
  )

p_B7

ggsave(
  file.path(out_dir, "Figure_B7_heatmap_nearoptimal_Test3B.png"),
  plot = p_B7, width = 8, height = 7, dpi = 300
)

ggsave(
  file.path(out_dir, "Figure_B7_heatmap_nearoptimal_Test3B.pdf"),
  plot = p_B7, width = 8, height = 7
)

# -------------------------------------------------------------------------
# 6) Figure B8: bivariate trade-off scatter
# -------------------------------------------------------------------------
rho_a_min <- suppressWarnings(
  cor(df_near$a, df_near$min_sup_for_reproduction,
      method = "spearman", use = "pairwise.complete.obs")
)

p_B8 <- ggplot(df_near, aes(x = a, y = min_sup_for_reproduction, colour = fitness)) +
  geom_point(alpha = 0.7, size = 1.8) +
  geom_smooth(method = "loess", se = FALSE, colour = "black", linewidth = 0.8) +
  labs(
    x = "a",
    y = "Minimum stand surface required for reproduction",
    colour = "NRMSEΔ",
    title = "Trade-off between a and minimum stand surface required for reproduction \n (Test 4)"
  ) +
  theme_bw() +
  annotate(
    "text",
    x = Inf, y = Inf,
    label = paste0("Spearman ", "\u03C1", " = ", round(rho_a_min, 2)),
    hjust = 1.1, vjust = 1.5, size = 4
  ) +
  theme(
    plot.title = element_text(face = "bold")
  )

p_B8

ggsave(
  file.path(out_dir, "Figure_B8_tradeoff_a_vs_minsup_Test3B.png"),
  plot = p_B8, width = 7, height = 5.5, dpi = 300
)

ggsave(
  file.path(out_dir, "Figure_B8_tradeoff_a_vs_minsup_Test3B.pdf"),
  plot = p_B8, width = 7, height = 5.5
)
