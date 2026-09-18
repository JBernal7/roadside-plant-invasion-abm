# =============================================================================
# Candidate-level near-optimal reanalysis for the Ailanthus roadside ABM
# =============================================================================
# Purpose
# -------
# Recalculate near-optimal parameter summaries from BehaviorSearch
# objectiveFunctionHistory files, where each row is one candidate
# parameterisation and `fitness` is the median NRMSEΔ across 7 stochastic
# replicates.
# 
# Unit of analysis:
#   5 independent searches x 160 candidates = 800 candidates per test
#   800 candidates x 7 stochastic replicates = 5,600 NetLogo model runs/test
#   Near-optimal ensemble = top 5% of 800 candidates = 40 candidates/test
#
# Manuscript mapping:
#   BehaviorSearch Test3A = Test 3
#   BehaviorSearch Test3B = Test 4 (selected model)
#
# Outputs
# -------
# Tables / CSVs:
#   nearoptimal_param_summary_long.csv
#   nearoptimal_param_summary_wide.csv
#   nearoptimal_common_params.csv            [Table B5]
#   nearoptimal_weight_params.csv            [Table B6]
#   nearoptimal_rescale_params.csv           [Table B7]
#   nearoptimal_candidates_Test1.csv ... Test4.csv
#   nearoptimal_top_tradeoffs_Test4.csv
#   candidate_level_spearman_check.csv
#
# Figures:
#   Fig_nearoptimal_Test4_parameter_ranges_PATCHWORK.png/.pdf   [Main Fig. 4]
#   Figure_B6_nearoptimal_parameter_ranges_Test4.png/.pdf       [Appendix B6]
#   Figure_B7_heatmap_nearoptimal_Test3B.png/.pdf               [Appendix B7]
#   Figure_B8_tradeoff_a_vs_minsup_Test3B.png/.pdf              [Appendix B8]
#
# NOTE: The B7/B8 filenames retain the historical "Test3B" label 
# Test3B corresponds to Test 4.
# =============================================================================

library(readr)
library(dplyr)
library(tidyr)
library(stringr)
library(ggplot2)
library(patchwork)
library(stats)

# -----------------------------------------------------------------------------
# 1) PATHS
# -----------------------------------------------------------------------------

calibration_root <- "C:/Netlogo/Calibracion"
output_dir <- "C:/Netlogo/Compilacion/Corrected_candidate_level"

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(output_dir, "Figures_AppendixB"), recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 2) BehaviorSearch candidate-level files
# -----------------------------------------------------------------------------

files <- list(
  Test1 = file.path(
    calibration_root,
    "Calibration_20260203_Test1",
    "MySearchOutput.objectiveFunctionHistory.csv"
  ),
  Test2 = file.path(
    calibration_root,
    "Calibration_20260204_Test2",
    "MySearchOutput.objectiveFunctionHistory.csv"
  ),
  Test3 = file.path(
    calibration_root,
    "Calibration_20260206_Test3A",
    "MySearchOutput.objectiveFunctionHistory.csv"
  ),
  Test4 = file.path(
    calibration_root,
    "Calibration_20260208_Test3B",
    "MySearchOutput.objectiveFunctionHistory.csv"
  )
)

missing_files <- unlist(files)[!file.exists(unlist(files))]
if (length(missing_files) > 0) {
  stop(
    "The following BehaviorSearch files were not found:\n",
    paste(missing_files, collapse = "\n"),
    "\n\nEdit `calibration_root` at the top of the script."
  )
}

# -----------------------------------------------------------------------------
# 3) Functions
# -----------------------------------------------------------------------------

get_param_cols <- function(df) {
  pcols <- names(df)[str_detect(names(df), "\\*$")]
  pcols[vapply(df[pcols], is.numeric, logical(1))]
}

read_candidate_history <- function(path, test_name) {
  df <- read_csv(path, show_col_types = FALSE)

  required <- c("search-number", "evaluation", "fitness", "num-replicates")
  if (!all(required %in% names(df))) {
    stop("Unexpected objectiveFunctionHistory structure in: ", path)
  }

  if (nrow(df) != 800) {
    warning(test_name, ": expected 800 candidate parameterisations, found ", nrow(df), ".")
  }

  if (!all(df$`num-replicates` == 7, na.rm = TRUE)) {
    warning(test_name, ": not all candidates report 7 stochastic replicates.")
  }

  search_counts <- table(df$`search-number`)
  if (length(search_counts) != 5 || any(search_counts != 160)) {
    warning(
      test_name,
      ": expected five searches with 160 candidates each; observed: ",
      paste(names(search_counts), search_counts, sep = "=", collapse = ", ")
    )
  }

  df %>% mutate(.test = test_name)
}

calc_near_optimal <- function(df, top_prop = 0.05) {
  n <- nrow(df)
  k <- max(1, floor(n * top_prop))

  df %>%
    arrange(fitness) %>%
    slice_head(n = k) %>%
    mutate(.rank = row_number())
}

summarise_params <- function(df_near, param_cols) {
  usable <- param_cols[
    vapply(
      df_near[param_cols],
      function(x) any(is.finite(x)),
      logical(1)
    )
  ]

  df_near %>%
    summarise(
      across(
        all_of(usable),
        list(
          median = ~median(.x, na.rm = TRUE),
          p05    = ~quantile(.x, probs = 0.05, na.rm = TRUE),
          p95    = ~quantile(.x, probs = 0.95, na.rm = TRUE)
        ),
        .names = "{.col}__{.fn}"
      )
    ) %>%
    pivot_longer(
      cols = everything(),
      names_to = c("parameter", "stat"),
      names_sep = "__"
    ) %>%
    pivot_wider(names_from = stat, values_from = value) %>%
    arrange(parameter)
}

make_formatted_table <- function(tab_params, params, test_order) {
  tab_params %>%
    filter(parameter %in% params) %>%
    mutate(
      med_p = sprintf("%.4g [%.4g–%.4g]", median, p05, p95),
      .test = factor(.test, levels = test_order)
    ) %>%
    arrange(parameter, .test) %>%
    select(test = .test, parameter, med_p) %>%
    pivot_wider(names_from = test, values_from = med_p) %>%
    mutate(parameter = str_replace_all(parameter, "\\*", ""))
}

safe_spearman <- function(x, y) {
  ok <- is.finite(x) & is.finite(y)
  x <- x[ok]
  y <- y[ok]

  if (length(x) < 3 || length(unique(x)) < 2 || length(unique(y)) < 2) {
    return(tibble(rho = NA_real_, p_value = NA_real_, n = length(x)))
  }

  ct <- suppressWarnings(cor.test(x, y, method = "spearman", exact = FALSE))
  tibble(
    rho = unname(ct$estimate),
    p_value = ct$p.value,
    n = length(x)
  )
}

# -----------------------------------------------------------------------------
# 4) Read all candidate-level histories
# -----------------------------------------------------------------------------

candidate_list <- lapply(names(files), function(test) {
  read_candidate_history(files[[test]], test)
})
names(candidate_list) <- names(files)

all_candidates <- bind_rows(candidate_list)
param_cols <- get_param_cols(all_candidates)

# Sanity check: these are distinct candidate parameterisations in the supplied
# BehaviorSearch histories, not the 7 replicate-level model runs.
for (test in names(candidate_list)) {
  df_test <- candidate_list[[test]]
  p_test <- get_param_cols(df_test)
  n_unique <- nrow(distinct(df_test, across(all_of(p_test))))
  if (n_unique != nrow(df_test)) {
    warning(test, ": duplicated candidate parameter combinations detected.")
  }
}

# -----------------------------------------------------------------------------
# 5) Near-optimal ensemble = top 5% of candidate parameterisations
# -----------------------------------------------------------------------------

near_list <- all_candidates %>%
  group_by(.test) %>%
  group_modify(~calc_near_optimal(.x, top_prop = 0.05)) %>%
  ungroup()

# Expected: 40 per test
near_counts <- near_list %>% count(.test, name = "n_near_optimal")
print(near_counts)

if (!all(near_counts$n_near_optimal == 40)) {
  warning("Expected 40 near-optimal candidate parameterisations per test.")
}

# Export the actual candidate-level near-optimal sets for reproducibility
for (test in names(files)) {
  near_list %>%
    filter(.test == test) %>%
    write_csv(file.path(output_dir, paste0("nearoptimal_candidates_", test, ".csv")))
}

# -----------------------------------------------------------------------------
# 6) Parameter summaries: median [5th-95th percentiles]
# -----------------------------------------------------------------------------

# Compute only parameters that exist within each test
tab_params <- near_list %>%
  group_by(.test) %>%
  group_modify(~summarise_params(.x, param_cols = intersect(param_cols, names(.x)))) %>%
  ungroup()

# Long and wide outputs, retaining the established filenames
tab_params_fmt <- tab_params %>%
  mutate(med_p = sprintf("%.4g [%.4g–%.4g]", median, p05, p95)) %>%
  select(test = .test, parameter, med_p) %>%
  pivot_wider(names_from = test, values_from = med_p) %>%
  mutate(parameter = str_replace_all(parameter, "\\*", ""))

write_csv(tab_params, file.path(output_dir, "nearoptimal_param_summary_long.csv"))
write_csv(tab_params_fmt, file.path(output_dir, "nearoptimal_param_summary_wide.csv"))

# Established manuscript table groups
common_params <- c(
  "dispersal_radius_m*",
  "kernel_decay*",
  "maturity-age-years*",
  "min-sup-for-reproduction*",
  "management_reset_size*",
  "gamma-recovery*"
)

weight_params <- c("r_weight_growth*", "r_weight_estab*")
rescale_params <- c("a*", "b_minus_a*")

tab_common <- make_formatted_table(
  tab_params,
  common_params,
  c("Test1", "Test2", "Test3", "Test4")
)

tab_weights <- make_formatted_table(
  tab_params,
  weight_params,
  c("Test1", "Test2", "Test4")
) %>%
  select(parameter, Test1, Test2, Test4)

tab_rescale <- make_formatted_table(
  tab_params,
  rescale_params,
  c("Test3", "Test4")
) %>%
  select(parameter, Test3, Test4)

# Preserve historical filenames used by the manuscript workflow
write_csv(tab_common,  file.path(output_dir, "nearoptimal_common_params.csv"))
write_csv(tab_weights, file.path(output_dir, "nearoptimal_weight_params.csv"))
write_csv(tab_rescale, file.path(output_dir, "nearoptimal_rescale_params.csv"))

# Also write explicit manuscript-table aliases
write_csv(tab_common,  file.path(output_dir, "Table_B5_nearoptimal_common_params.csv"))
write_csv(tab_weights, file.path(output_dir, "Table_B6_nearoptimal_weight_params.csv"))
write_csv(tab_rescale, file.path(output_dir, "Table_B7_nearoptimal_rescale_params.csv"))

# -----------------------------------------------------------------------------
# 7) Main Figure 4 / Appendix Figure B6
# -----------------------------------------------------------------------------

selected_test <- "Test4"

tab_sel <- tab_params %>%
  filter(.test == selected_test) %>%
  mutate(parameter = str_replace_all(parameter, "\\*", "")) %>%
  mutate(group = case_when(
    parameter %in% c("a", "b_minus_a", "r_weight_growth", "r_weight_estab") ~ "Biotic resistance",
    parameter %in% c("dispersal_radius_m", "kernel_decay") ~ "Dispersal kernel",
    parameter %in% c("maturity-age-years", "min-sup-for-reproduction") ~ "Reproduction thresholds",
    parameter %in% c("management_reset_size", "gamma-recovery") ~ "Reset & recovery",
    TRUE ~ NA_character_
  )) %>%
  filter(!is.na(group))

order_list <- list(
  "Biotic resistance" = c("r_weight_estab", "r_weight_growth", "b_minus_a", "a"),
  "Dispersal kernel" = c("dispersal_radius_m", "kernel_decay"),
  "Reproduction thresholds" = c("min-sup-for-reproduction", "maturity-age-years"),
  "Reset & recovery" = c("management_reset_size", "gamma-recovery")
)

make_panel <- function(df, g) {
  df_g <- df %>%
    filter(group == g) %>%
    mutate(parameter = factor(parameter, levels = order_list[[g]]))

  ggplot(df_g, aes(y = parameter, x = median, xmin = p05, xmax = p95)) +
    geom_errorbarh(height = 0.18) +
    geom_point(size = 2.5) +
    labs(title = g, x = NULL, y = NULL) +
    theme_bw() +
    theme(
      plot.title = element_text(size = 11, face = "bold"),
      axis.text.y = element_text(size = 10)
    )
}

p1 <- make_panel(tab_sel, "Biotic resistance") + scale_x_continuous()
p2 <- make_panel(tab_sel, "Dispersal kernel") + scale_x_continuous()
p3 <- make_panel(tab_sel, "Reproduction thresholds") + scale_x_continuous()
p4 <- make_panel(tab_sel, "Reset & recovery") + scale_x_continuous()

p_ranges <- (p1 / p2 / p3 / p4) +
  plot_annotation(
    title = "Near-optimal parameter ranges (top 5%): selected calibration model (Test 4)",
    caption = "Points show medians; horizontal bars show 5th–95th percentiles within the near-optimal set."
  ) &
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.caption = element_text(size = 9),
    axis.title.x = element_text(size = 11)
  )

p_ranges <- p_ranges &
  labs(x = "Parameter value (median and 5th–95th percentiles within near-optimal set)")

# Main manuscript Figure 4
ggsave(
  file.path(output_dir, "Fig_nearoptimal_Test4_parameter_ranges_PATCHWORK.png"),
  p_ranges,
  width = 7.6,
  height = 9.0,
  dpi = 300
)
ggsave(
  file.path(output_dir, "Fig_nearoptimal_Test4_parameter_ranges_PATCHWORK.pdf"),
  p_ranges,
  width = 7.6,
  height = 9.0
)

# Appendix Figure B6
ggsave(
  file.path(output_dir, "Figure_B6_nearoptimal_parameter_ranges_Test4.png"),
  p_ranges,
  width = 7.6,
  height = 9.0,
  dpi = 300
)
ggsave(
  file.path(output_dir, "Figure_B6_nearoptimal_parameter_ranges_Test4.pdf"),
  p_ranges,
  width = 7.6,
  height = 9.0
)

# -----------------------------------------------------------------------------
# 8) Figure B7: pairwise Spearman heatmap within Test 4 near-optimal ensemble
# -----------------------------------------------------------------------------

standardise_test4 <- function(df) {
  df %>%
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
      b_minus_a                = `b_minus_a*`
    )
}

df_near4 <- near_list %>%
  filter(.test == "Test4") %>%
  standardise_test4()

param_cols_b7 <- c(
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

df_cor <- df_near4 %>%
  select(all_of(param_cols_b7)) %>%
  select(where(~sum(is.finite(.x)) >= 3 && n_distinct(.x[is.finite(.x)]) >= 2))

cor_mat <- cor(df_cor, method = "spearman", use = "pairwise.complete.obs")

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

appendix_dir <- file.path(output_dir, "Figures_AppendixB")

# Historical filenames retained
ggsave(
  file.path(appendix_dir, "Figure_B7_heatmap_nearoptimal_Test3B.png"),
  plot = p_B7,
  width = 8,
  height = 7,
  dpi = 300
)
ggsave(
  file.path(appendix_dir, "Figure_B7_heatmap_nearoptimal_Test3B.pdf"),
  plot = p_B7,
  width = 8,
  height = 7
)

# Clear Test 4 aliases for the repository
ggsave(
  file.path(appendix_dir, "Figure_B7_heatmap_nearoptimal_Test4.png"),
  plot = p_B7,
  width = 8,
  height = 7,
  dpi = 300
)
ggsave(
  file.path(appendix_dir, "Figure_B7_heatmap_nearoptimal_Test4.pdf"),
  plot = p_B7,
  width = 8,
  height = 7
)

# -----------------------------------------------------------------------------
# 9) Figure B8: a vs minimum reproductive surface trade-off
# -----------------------------------------------------------------------------

rho_a_min <- suppressWarnings(
  cor(
    df_near4$a,
    df_near4$min_sup_for_reproduction,
    method = "spearman",
    use = "pairwise.complete.obs"
  )
)

p_B8 <- ggplot(
  df_near4,
  aes(x = a, y = min_sup_for_reproduction, colour = fitness)
) +
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
    x = Inf,
    y = Inf,
    label = paste0("Spearman ", "\u03C1", " = ", round(rho_a_min, 2)),
    hjust = 1.1,
    vjust = 1.5,
    size = 4
  ) +
  theme(plot.title = element_text(face = "bold"))

# Historical filenames retained
ggsave(
  file.path(appendix_dir, "Figure_B8_tradeoff_a_vs_minsup_Test3B.png"),
  plot = p_B8,
  width = 7,
  height = 5.5,
  dpi = 300
)
ggsave(
  file.path(appendix_dir, "Figure_B8_tradeoff_a_vs_minsup_Test3B.pdf"),
  plot = p_B8,
  width = 7,
  height = 5.5
)

# Clear Test 4 aliases for the repository
ggsave(
  file.path(appendix_dir, "Figure_B8_tradeoff_a_vs_minsup_Test4.png"),
  plot = p_B8,
  width = 7,
  height = 5.5,
  dpi = 300
)
ggsave(
  file.path(appendix_dir, "Figure_B8_tradeoff_a_vs_minsup_Test4.pdf"),
  plot = p_B8,
  width = 7,
  height = 5.5
)

# -----------------------------------------------------------------------------
# 10) Compact trade-off report for Test 4
# -----------------------------------------------------------------------------

cor_pairs <- cor_long %>%
  filter(as.character(var1) < as.character(var2)) %>%
  arrange(desc(abs(rho))) %>%
  slice_head(n = 20)

write_csv(
  cor_pairs,
  file.path(output_dir, "nearoptimal_top_tradeoffs_Test4.csv")
)

write_csv(
  tibble(
    parameter_1 = "a",
    parameter_2 = "min_sup_for_reproduction",
    spearman_rho = rho_a_min,
    n_near_optimal = nrow(df_near4)
  ),
  file.path(output_dir, "Figure_B8_tradeoff_statistic.csv")
)

# -----------------------------------------------------------------------------
# 11) Candidate-level marginal Spearman check 
# -----------------------------------------------------------------------------
# This output is included only as an audit/consistency check. It uses the
# candidate-level fitness already stored by BehaviorSearch (median of 7 runs).

spearman_check <- all_candidates %>%
  group_by(.test) %>%
  group_modify(~{
    pcols <- get_param_cols(.x)

    bind_rows(lapply(pcols, function(p) {
      res <- safe_spearman(.x[[p]], .x$fitness)
      tibble(
        parameter = str_replace_all(p, "\\*", ""),
        rho = res$rho,
        p_value = res$p_value,
        n_candidates = res$n
      )
    }))
  }) %>%
  ungroup() %>%
  mutate(abs_rho = abs(rho))

write_csv(
  spearman_check,
  file.path(output_dir, "candidate_level_spearman_check.csv")
)

# -----------------------------------------------------------------------------
# 12) Reproducibility log
# -----------------------------------------------------------------------------

log_lines <- c(
  "Candidate-level near-optimal reanalysis completed.",
  "",
  "Definition:",
  "- 800 candidate parameterisations per test",
  "- 7 stochastic model runs per candidate",
  "- 5,600 stochastic model runs per test",
  "- near-optimal ensemble = top 5% of candidate-level BehaviorSearch fitness",
  "- n = 40 near-optimal candidates per test",
  "",
  paste0("Test 4 Spearman rho(a, min_sup_for_reproduction) = ", round(rho_a_min, 6)),
  "",
  paste0("Output directory: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
)

writeLines(log_lines, file.path(output_dir, "candidate_level_reanalysis_log.txt"))

message("Candidate-level reanalysis completed successfully.")
message("Outputs written to: ", output_dir)
message("Expected near-optimal set size per test: 40 candidates.")
message("Test 4 rho(a, min_sup_for_reproduction) = ", round(rho_a_min, 3))
