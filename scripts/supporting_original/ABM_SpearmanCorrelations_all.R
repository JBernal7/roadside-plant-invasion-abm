# =============================================================================
# Figure B4 and Figure B5
# Post hoc sensitivity from BehaviourSearch histories
# =============================================================================

library(readr)
library(dplyr)
library(purrr)
library(ggplot2)
library(rlang)
library(stringr)
library(tidyr)
library(forcats)

# -------------------------------------------------------------------------
# 1) Input files: one modelRunHistory per test
# -------------------------------------------------------------------------
files <- tibble::tribble(
  ~test,   ~file,
  "Test 1",  "C:/Netlogo/Compilacion/MySearchOutput.modelRunHistory_Test1.csv",
  "Test 2",  "C:/Netlogo/Compilacion/MySearchOutput.modelRunHistory_Test2.csv",
  "Test 3", "C:/Netlogo/Compilacion/MySearchOutput.modelRunHistory_Test3A.csv",
  "Test 4", "C:/Netlogo/Compilacion/MySearchOutput.modelRunHistory_Test3B.csv"
)

out_dir <- "C:/Netlogo/Compilacion/Figures_AppendixB"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# -------------------------------------------------------------------------
# 2) find first matching column name
# -------------------------------------------------------------------------
find_col <- function(nms, candidates) {
  hit <- candidates[candidates %in% nms]
  if (length(hit) == 0) return(NA_character_)
  hit[1]
}

# -------------------------------------------------------------------------
# 3) Read and standardise one file
# -------------------------------------------------------------------------
read_bsearch_history <- function(path, test_name) {
  
  raw <- read_csv(path, show_col_types = FALSE)
  nms <- names(raw)
  
  # Parameter columns
  col_rwg  <- find_col(nms, c("r_weight_growth*", "r_weight_growth"))
  col_rwe  <- find_col(nms, c("r_weight_estab*", "r_weight_estab"))
  col_gam  <- find_col(nms, c("gamma-recovery*", "gamma_recovery*", "gamma-recovery", "gamma_recovery"))
  col_mat  <- find_col(nms, c("maturity-age-years*", "maturity_age_years*", "maturity-age-years", "maturity_age_years"))
  col_mins <- find_col(nms, c("min-sup-for-reproduction*", "min_sup_for_reproduction*", "min-sup-for-reproduction", "min_sup_for_reproduction"))
  col_disp <- find_col(nms, c("dispersal_radius_m*", "dispersal-radius-m*", "dispersal_radius_m"))
  col_mgmt <- find_col(nms, c("management_reset_size*", "management-reset-size*", "management_reset_size"))
  col_a    <- find_col(nms, c("a*", "a"))
  col_bma  <- find_col(nms, c("b_minus_a*", "b-minus-a*", "b_minus_a", "b-minus-a"))
  
  # Fitness column: prefer final-step-result
  col_fit  <- find_col(nms, c("final-step-result", "final_step_result", "mean-result", "mean_result", "fitness", "result"))
  
  df <- raw
  
  if (!is.na(col_rwg))  df <- df %>% rename(r_weight_growth = !!sym(col_rwg))
  if (!is.na(col_rwe))  df <- df %>% rename(r_weight_estab  = !!sym(col_rwe))
  if (!is.na(col_gam))  df <- df %>% rename(gamma_recovery  = !!sym(col_gam))
  if (!is.na(col_mat))  df <- df %>% rename(maturity_age_years = !!sym(col_mat))
  if (!is.na(col_mins)) df <- df %>% rename(min_sup_for_reproduction = !!sym(col_mins))
  if (!is.na(col_disp)) df <- df %>% rename(dispersal_radius_m = !!sym(col_disp))
  if (!is.na(col_mgmt)) df <- df %>% rename(management_reset_size = !!sym(col_mgmt))
  if (!is.na(col_a))    df <- df %>% rename(a = !!sym(col_a))
  if (!is.na(col_bma))  df <- df %>% rename(b_minus_a = !!sym(col_bma))
  if (!is.na(col_fit))  df <- df %>% rename(fitness = !!sym(col_fit))
  
  param_candidates <- c(
    "r_weight_growth",
    "r_weight_estab",
    "gamma_recovery",
    "maturity_age_years",
    "min_sup_for_reproduction",
    "dispersal_radius_m",
    "management_reset_size",
    "a",
    "b_minus_a"
  )
  
  param_cols <- intersect(param_candidates, names(df))
  
  if (!"fitness" %in% names(df)) {
    stop("No fitness column detected in: ", path)
  }
  
  df %>%
    mutate(test = test_name) %>%
    select(any_of(c("test", param_cols, "fitness")))
}

# -------------------------------------------------------------------------
# 4) Read all tests
# -------------------------------------------------------------------------
all_raw <- pmap_dfr(files, \(test, file) read_bsearch_history(file, test))

# -------------------------------------------------------------------------
# 5) Aggregate identical parameter combinations within each test
# -------------------------------------------------------------------------
param_candidates <- c(
  "r_weight_growth",
  "r_weight_estab",
  "gamma_recovery",
  "maturity_age_years",
  "min_sup_for_reproduction",
  "dispersal_radius_m",
  "management_reset_size",
  "a",
  "b_minus_a"
)

df_param <- all_raw %>%
  group_by(test) %>%
  group_modify(~{
    param_cols <- intersect(param_candidates, names(.x))
    .x %>%
      group_by(across(all_of(param_cols))) %>%
      summarise(
        fitness = mean(fitness, na.rm = TRUE),
        .groups = "drop"
      )
  }) %>%
  ungroup()

# -------------------------------------------------------------------------
# 6) Spearman table by test
# -------------------------------------------------------------------------
safe_spearman <- function(x, y) {
  ok <- is.finite(x) & is.finite(y)
  x <- x[ok]
  y <- y[ok]
  
  # Need enough data and variation
  if (length(x) < 3) {
    return(tibble(rho = NA_real_, p_value = NA_real_, n = length(x)))
  }
  if (length(unique(x)) < 2 || length(unique(y)) < 2) {
    return(tibble(rho = NA_real_, p_value = NA_real_, n = length(x)))
  }
  
  ct <- suppressWarnings(cor.test(x, y, method = "spearman", exact = FALSE))
  
  tibble(
    rho = unname(ct$estimate),
    p_value = ct$p.value,
    n = length(x)
  )
}

cor_table <- df_param %>%
  group_by(test) %>%
  group_modify(~{
    param_cols <- intersect(param_candidates, names(.x))
    
    map_dfr(param_cols, function(p) {
      res <- safe_spearman(.x[[p]], .x$fitness)
      
      tibble(
        parameter = p,
        rho       = res$rho,
        p_value   = res$p_value,
        n_pairs   = res$n
      )
    })
  }) %>%
  ungroup() %>%
  mutate(
    abs_rho = abs(rho),
    parameter_label = recode(
      parameter,
      r_weight_growth = "r_weight_growth",
      r_weight_estab = "r_weight_estab",
      gamma_recovery = "gamma_recovery",
      maturity_age_years = "maturity_age_years",
      min_sup_for_reproduction = "min_sup_for_reproduction",
      dispersal_radius_m = "dispersal_radius_m",
      management_reset_size = "management_reset_size",
      a = "a",
      b_minus_a = "b_minus_a"
    )
  )

write_csv(cor_table, file.path(out_dir, "Table_B4_spearman_by_test.csv"))

# -------------------------------------------------------------------------
# 7) Figure B4: lollipop with four panels
# -------------------------------------------------------------------------
library(tidytext)

cor_plot <- cor_table %>%
  filter(!is.na(rho)) %>%
  mutate(
    parameter_label = reorder_within(parameter_label, abs_rho, test)
  )

p_B4 <- ggplot(cor_plot, aes(x = abs_rho, y = parameter_label)) +
  geom_segment(aes(x = 0, xend = abs_rho, yend = parameter_label)) +
  geom_point(aes(shape = rho > 0), size = 2.8) +
  scale_shape_manual(
    values = c("TRUE" = 16, "FALSE" = 1),
    labels = c("FALSE" = "negative", "TRUE" = "positive"),
    name = "Sign of ρ"
  ) +
  facet_wrap(~ test, ncol = 2, scales = "free_y") +
  scale_y_reordered() +
  labs(
    x = "Absolute Spearman rank correlation (|ρ|) with calibration error",
    y = "Parameter",
    title = "Absolute Spearman rank correlations between calibrated parameters and calibration error"
  ) +
  theme_bw() +
  theme(
    legend.position = "bottom",
    strip.background = element_rect(fill = "grey90", colour = "grey40"),
    strip.text = element_text(face = "bold"),
    plot.title = element_text(face = "bold")
  )

p_B4

ggsave(
  file.path(out_dir, "Figure_B4_lollipop_spearman.png"),
  plot = p_B4, width = 10, height = 7, dpi = 300
)

ggsave(
  file.path(out_dir, "Figure_B4_lollipop_spearman.pdf"),
  plot = p_B4, width = 10, height = 7
)



# -------------------------------------------------------------------------
# 7b) Figure B4 singular: lollipop only for Test 4
# -------------------------------------------------------------------------
cor_plot_test4 <- cor_plot %>%
  filter(test == "Test 4") %>%
  mutate(parameter_label = fct_reorder(parameter_label, abs_rho))

p_B4_test4 <- ggplot(cor_plot_test4, aes(x = abs_rho, y = parameter_label)) +
  geom_segment(aes(x = 0, xend = abs_rho, y = parameter_label, yend = parameter_label)) +
  geom_point(aes(shape = rho > 0), size = 2.8) +
  scale_shape_manual(
    values = c("TRUE" = 16, "FALSE" = 1),
    labels = c("FALSE" = "negative", "TRUE" = "positive"),
    name = "Sign of ρ"
  ) +
  labs(
    x = "Absolute Spearman rank correlation (|ρ|) with calibration error",
    y = "Parameter",
    title = "Test 4: absolute Spearman rank correlations"
  ) +
  theme_bw() +
  theme(
    legend.position = "bottom",
    plot.title = element_text(face = "bold")
  )

p_B4_test4

ggsave(
  file.path(out_dir, "Figure_B4_Test_4_lollipop_spearman.png"),
  plot = p_B4_test4, width = 7, height = 5.5, dpi = 300
)

ggsave(
  file.path(out_dir, "Figure_B4_Test_4_lollipop_spearman.pdf"),
  plot = p_B4_test4, width = 7, height = 5.5
)

# -------------------------------------------------------------------------
# 8) Figure B5: scatterplots + LOESS, one page per test
# -------------------------------------------------------------------------
make_scatter_page <- function(df_test, test_name) {
  
  param_cols <- intersect(param_candidates, names(df_test))
  
  # Keep only parameters with enough finite values and variation
  keep_params <- param_cols[vapply(param_cols, function(p) {
    x <- df_test[[p]]
    ok <- is.finite(x) & is.finite(df_test$fitness)
    x <- x[ok]
    length(x) >= 3 && length(unique(x)) >= 2
  }, logical(1))]
  
  df_long <- df_test %>%
    select(any_of(c("fitness", keep_params))) %>%
    pivot_longer(
      cols = all_of(keep_params),
      names_to = "parameter",
      values_to = "value"
    ) %>%
    filter(is.finite(value), is.finite(fitness)) %>%
    mutate(
      parameter = recode(
        parameter,
        r_weight_growth = "r_weight_growth",
        r_weight_estab = "r_weight_estab",
        gamma_recovery = "gamma_recovery",
        maturity_age_years = "maturity_age_years",
        min_sup_for_reproduction = "min_sup_for_reproduction",
        dispersal_radius_m = "dispersal_radius_m",
        management_reset_size = "management_reset_size",
        a = "a",
        b_minus_a = "b_minus_a"
      )
    )
  
  ggplot(df_long, aes(x = value, y = fitness)) +
    geom_point(alpha = 0.35, size = 0.9) +
    geom_smooth(method = "loess", se = FALSE, linewidth = 0.8) +
    facet_wrap(~ parameter, scales = "free_x", ncol = 3) +
    labs(
      x = "Parameter value",
      y = "Calibration error (NRMSEΔ)",
      title = paste0("Calibration error versus parameter value: ", test_name)
    ) +
    theme_bw() +
    theme(
      strip.background = element_rect(fill = "grey90", colour = "grey40"),
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold")
    )
}

pdf(file.path(out_dir, "Figure_B5_scatter_loess_by_test.pdf"), width = 11, height = 8.5)

for (tt in unique(df_param$test)) {
  p_test <- make_scatter_page(df_param %>% filter(test == tt), tt)
  print(p_test)
}

dev.off()

# Optional PNG export: one PNG per test
for (tt in unique(df_param$test)) {
  p_test <- make_scatter_page(df_param %>% filter(test == tt), tt)
  
  safe_name <- str_replace_all(tt, " ", "_")
  
  ggsave(
    file.path(out_dir, paste0("Figure_B5_", safe_name, "_scatter_loess.png")),
    plot = p_test, width = 11, height = 8.5, dpi = 300
  )
}
