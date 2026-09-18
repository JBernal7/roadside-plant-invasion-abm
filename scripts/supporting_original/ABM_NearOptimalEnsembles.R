# ============================================================
#   Near-optimal ensembles: tables + figures from modelRunHistory
# ============================================================
  
library(readr)
library(dplyr)
library(tidyr)
library(stringr)
library(ggplot2)

# ----------------------------
#   1) Paths
# ----------------------------
  
  files <- list(
    Test1 = "C:/Netlogo/Compilacion/MySearchOutput.modelRunHistory_Test1.csv",
    Test2 = "C:/Netlogo/Compilacion/MySearchOutput.modelRunHistory_Test2.csv",
    Test3 = "C:/Netlogo/Compilacion/MySearchOutput.modelRunHistory_Test3A.csv",
    Test4 = "C:/Netlogo/Compilacion/MySearchOutput.modelRunHistory_Test3B.csv"
  )
  
# ----------------------------
#     2) Functions
# ----------------------------
  
  get_param_cols <- function(df) {
    # Parameters in BehaviourSearch exports typically end with '*'
    pcols <- names(df)[stringr::str_detect(names(df), "\\*$")]
    
    # Keep only numeric parameter columns
    pcols <- pcols[vapply(df[pcols], is.numeric, logical(1))]
    
    pcols
  }
  
  calc_near_optimal <- function(df, fitness_col = "final-step-result", top_prop = 0.05) {
    stopifnot(fitness_col %in% names(df))
    n <- nrow(df)
    k <- max(1, floor(n * top_prop))
    
    df %>%
      arrange(.data[[fitness_col]]) %>%
      slice_head(n = k) %>%
      mutate(.rank = row_number())
  }
  
  summarise_params <- function(df_near, param_cols) {
    
    out <- df_near %>%
      summarise(across(
        all_of(param_cols),
        list(
          median = ~median(.x, na.rm = TRUE),
          p05    = ~quantile(.x, probs = 0.05, na.rm = TRUE),
          p95    = ~quantile(.x, probs = 0.95, na.rm = TRUE)
        ),
        .names = "{.col}__{.fn}"   # <- delimiter explícito
      ))
    
    out %>%
      pivot_longer(
        cols = everything(),
        names_to = c("parameter", "stat"),
        names_sep = "__"
      ) %>%
      pivot_wider(names_from = stat, values_from = value) %>%
      arrange(parameter)
  }
  
# ----------------------------
#     3) Read all tests + compute near-optimal sets
# ----------------------------
  
  all_hist <- lapply(names(files), function(test) {
    df <- read_csv(files[[test]], show_col_types = FALSE)
    df$.test <- test
    df
  }) %>% bind_rows()
  
  # Decide fitness column name
  
  fitness_col <- if ("final-step-result" %in% names(all_hist)) "final-step-result" else "final_step_result"
  
  # Compute near-optimal per test
  
  near_list <- all_hist %>%
    group_by(.test) %>%
    group_modify(~calc_near_optimal(.x, fitness_col = fitness_col, top_prop = 0.05)) %>%
    ungroup()
  
  # Parameter columns (use the union across tests for robustness)
  
  param_cols <- get_param_cols(all_hist)
  
# ----------------------------
#     4) Tables: median [P05–P95] per test
# ----------------------------
  
  tab_params <- near_list %>%
    group_by(.test) %>%
    group_modify(~summarise_params(.x, param_cols = intersect(param_cols, names(.x)))) %>%
    ungroup()
  
  # Create table: median [p05–p95]
  
  tab_params_fmt <- tab_params %>%
    mutate(med_p = sprintf("%.4g [%.4g–%.4g]", median, p05, p95)) %>%
    select(test = .test, parameter, med_p) %>%
    pivot_wider(names_from = test, values_from = med_p)
  
  tab_params_fmt <- tab_params_fmt %>%
    mutate(parameter = stringr::str_replace_all(parameter, "\\*", ""))
  
  # Write tables
  
  write_csv(tab_params, "C:/Netlogo/Compilacion/nearoptimal_param_summary_long.csv")
  write_csv(tab_params_fmt, "C:/Netlogo/Compilacion/nearoptimal_param_summary_wide.csv")
  
  
  common_params <- c("dispersal_radius_m*", "kernel_decay*", "maturity-age-years*",
                     "min-sup-for-reproduction*", "management_reset_size*", "gamma-recovery*")
  
  weight_params <- c("r_weight_growth*", "r_weight_estab*")     # only where applicable
  rescale_params <- c("a*", "b_minus_a*")                       # only 3A/3B
  
  # to build a formatted wide table for a given param list
  make_table <- function(tab_params, params) {
    tab_params %>%
      filter(parameter %in% params) %>%
      mutate(med_p = sprintf("%.4g [%.4g–%.4g]", median, p05, p95)) %>%
      select(test = .test, parameter, med_p) %>%
      pivot_wider(names_from = test, values_from = med_p) %>%
      mutate(parameter = stringr::str_replace_all(parameter, "\\*", ""))
  }
  
  tab_common  <- make_table(tab_params, common_params)
  tab_weights <- make_table(tab_params, weight_params)
  tab_rescale <- make_table(tab_params, rescale_params)
  
  write_csv(tab_common,  "C:/Netlogo/Compilacion/nearoptimal_common_params.csv")
  write_csv(tab_weights, "C:/Netlogo/Compilacion/nearoptimal_weight_params.csv")
  write_csv(tab_rescale, "C:/Netlogo/Compilacion/nearoptimal_rescale_params.csv")
  
# ----------------------------
#     5) Figure: VerifYn-like fitness spread in near-optimal 
# (This is NOT VerifYn, just the near-optimal fitness distribution)
# ----------------------------
  
  p_fit <- near_list %>%
    ggplot(aes(x = .test, y = .data[[fitness_col]])) +
    geom_boxplot(outlier.shape = 16) +
    labs(x = "Calibration test", y = "NRMSEΔ (fitness) within near-optimal set (top 5%)") +
    theme_bw()
  
  p_fit
  
  ggsave("C:/Netlogo/Compilacion/Fig_By_nearoptimal_fitness_boxplot.png", p_fit, width = 7, height = 4, dpi = 300)
  
# ----------------------------
#     6) Figure: Parameter uncertainty intervals (selected test)
# ----------------------------
  
  selected_test <- "Test4"
  tab_sel <- tab_params %>%
    filter(.test == selected_test) %>%
    mutate(parameter = str_replace_all(parameter, "/", "")) # remove '' if present

# Keep only a subset if too many parameters (otherwise the plot gets long)
# Example: show all parameters

p_intervals <- tab_sel %>%
ggplot(aes(y = reorder(parameter, median), x = median, xmin = p05, xmax = p95)) +
geom_errorbarh(height = 0.2) +
geom_point(size = 2) +
labs(x = "Parameter value (median and 5th–95th percentiles)", y = NULL,
title = paste0("Near-optimal uncertainty intervals (top 5%): ", selected_test)) +
theme_bw()

p_intervals

ggsave(paste0("C:/Netlogo/Compilacion/Fig_B5_nearoptimal_intervals_", selected_test, ".png"),
p_intervals, width = 7.5, height = 6, dpi = 300)

# ----------------------------
# 7) Figure: Spearman correlation heatmap (selected test)
# ----------------------------

library(stats)

df_sel <- near_list %>%
filter(.test == selected_test) %>%
select(any_of(intersect(param_cols, names(.)))) %>%

# drop columns with zero variance (would break correlations)

select(where(~sd(.x, na.rm = TRUE) > 0))

cor_mat <- cor(df_sel, method = "spearman", use = "pairwise.complete.obs")

cor_long <- as.data.frame(as.table(cor_mat)) %>%
rename(var1 = Var1, var2 = Var2, rho = Freq) %>%
mutate(var1 = str_replace_all(var1, "/", ""),
var2 = str_replace_all(var2, "/", ""))

p_cor <- cor_long %>%
ggplot(aes(x = var1, y = var2, fill = rho)) +
geom_tile() +
scale_fill_gradient2(limits = c(-1, 1)) +
coord_fixed() +
labs(x = NULL, y = NULL,
title = paste0("Spearman correlations within near-optimal set: ", selected_test),
fill = "ρ") +
theme_bw() +
theme(axis.text.x = element_text(angle = 45, hjust = 1))

p_cor

ggsave(paste0("C:/Netlogo/Compilacion/Fig_B6_spearman_heatmap_", selected_test, ".png"),
p_cor, width = 8, height = 7, dpi = 300)

# ----------------------------
# 8) Export a compact correlation report (top trade-offs)
# ----------------------------

cor_pairs <- cor_long %>%
filter(var1 < var2) %>% # keep unique pairs
arrange(desc(abs(rho))) %>%
head(20)

write_csv(cor_pairs, paste0("C:/Netlogo/Compilacion/nearoptimal_top_tradeoffs_", selected_test, ".csv"))

# == PRUEBAS VARIAS
library(readr)
library(dplyr)
library(stringr)
library(ggplot2)

tab_params <- read_csv("C:/Netlogo/Compilacion/nearoptimal_param_summary_long.csv", show_col_types = FALSE)
selected_test <- "Test4"

tab_sel <- tab_params %>%
  filter(.test == selected_test) %>%
  mutate(parameter = str_replace_all(parameter, "\\*", "")) %>%
  mutate(group = case_when(
    parameter %in% c("a","b_minus_a","r_weight_growth","r_weight_estab") ~ "Biotic resistance",
    parameter %in% c("dispersal_radius_m","kernel_decay") ~ "Dispersal kernel",
    parameter %in% c("maturity-age-years","min-sup-for-reproduction") ~ "Reproduction thresholds",
    parameter %in% c("management_reset_size","gamma-recovery") ~ "Reset & recovery",
    TRUE ~ NA_character_
  )) %>%
  filter(!is.na(group))

# Orden por panel 
tab_sel <- tab_sel %>%
  mutate(parameter = factor(parameter, levels = c(
    "r_weight_estab","r_weight_growth","b_minus_a","a",
    "dispersal_radius_m","kernel_decay",
    "min-sup-for-reproduction","maturity-age-years",
    "management_reset_size","gamma-recovery"
  ))) %>%
  arrange(group, parameter)

# crear etiqueta por panel para que NO se reciclen niveles entre facets
tab_sel <- tab_sel %>%
  mutate(parameter_facet = forcats::fct_inorder(parameter)) %>%
  group_by(group) %>%
  mutate(parameter_facet = forcats::fct_drop(parameter_facet)) %>%  # drop unused levels *within group*
  ungroup()

p_int <- ggplot(tab_sel, aes(y = parameter_facet, x = median, xmin = p05, xmax = p95)) +
  geom_errorbarh(height = 0.18) +
  geom_point(size = 2.5) +
  facet_grid(group ~ ., scales = "free_y", space = "free_y") +
  labs(
    x = "Parameter value (median and 5th–95th percentiles within near-optimal set)",
    y = NULL,
    title = "Near-optimal parameter uncertainty (top 5%): baseline calibration (Test 4)"
  ) +
  theme_bw()

p_int

ggsave("C:/Netlogo/Compilacion/Fig_3_1_nearoptimal_intervals_Test3B_faceted_clean.png",
       p_int, width = 7.2, height = 8.2, dpi = 300)

# más clara
tab_main <- tab_sel %>%
  filter(group %in% c("Biotic resistance", "Reproduction thresholds")) %>%
  droplevels()

p_main_freeX <- ggplot(tab_main, aes(y = parameter_facet, x = median, xmin = p05, xmax = p95)) +
  geom_errorbarh(height = 0.18) +
  geom_point(size = 2.5) +
  facet_wrap(~group, scales = "free_x", ncol = 1) +
  labs(
    x = "Parameter value (median and 5th–95th percentiles within near-optimal set)",
    y = NULL,
    title = "Near-optimal uncertainty intervals for resistance and reproduction parameters \n(Test 4)"
  ) +
  theme_bw()

p_main_freeX
ggsave("C:/Netlogo/Compilacion/Fig_nearoptimal_keyparams_Test3B_freeX.png",
       p_main_freeX, width = 7.2, height = 5.2, dpi = 300)

# Free_x por panel
library(readr)
library(dplyr)
library(stringr)
library(ggplot2)
library(forcats)

tab_params <- read_csv("C:/Netlogo/Compilacion/nearoptimal_param_summary_long.csv", show_col_types = FALSE)
selected_test <- "Test4"

tab_sel <- tab_params %>%
  filter(.test == selected_test) %>%
  mutate(parameter = str_replace_all(parameter, "\\*", "")) %>%
  mutate(group = case_when(
    parameter %in% c("a","b_minus_a","r_weight_growth","r_weight_estab") ~ "Biotic resistance",
    parameter %in% c("dispersal_radius_m","kernel_decay") ~ "Dispersal kernel",
    parameter %in% c("maturity-age-years","min-sup-for-reproduction") ~ "Reproduction thresholds",
    parameter %in% c("management_reset_size","gamma-recovery") ~ "Reset & recovery",
    TRUE ~ NA_character_
  )) %>%
  filter(!is.na(group)) %>%
  mutate(group = factor(group, levels = c("Biotic resistance","Dispersal kernel","Reproduction thresholds","Reset & recovery"))) %>%
  # crear un eje y "único por panel"
  mutate(y_key = paste(group, parameter, sep = " | "))

# Orden de aparición 
y_order <- c(
  "Biotic resistance | r_weight_estab",
  "Biotic resistance | r_weight_growth",
  "Biotic resistance | b_minus_a",
  "Biotic resistance | a",
  "Dispersal kernel | dispersal_radius_m",
  "Dispersal kernel | kernel_decay",
  "Reproduction thresholds | min-sup-for-reproduction",
  "Reproduction thresholds | maturity-age-years",
  "Reset & recovery | management_reset_size",
  "Reset & recovery | gamma-recovery"
)

tab_sel <- tab_sel %>%
  mutate(y_key = factor(y_key, levels = y_order)) %>%
  arrange(group, y_key)

p_freeX_clean <- ggplot(tab_sel, aes(y = y_key, x = median, xmin = p05, xmax = p95)) +
  geom_errorbarh(height = 0.18) +
  geom_point(size = 2.5) +
  facet_wrap(~group, scales = "free_x", ncol = 1) +
  # mostrar solo el nombre del parámetro en el eje y
  scale_y_discrete(labels = function(x) sub("^.*\\|\\s*", "", x)) +
  labs(
    x = "Parameter value (median and 5th–95th percentiles within near-optimal set)",
    y = NULL,
    title = "Near-optimal parameter uncertainty (top 5%): baseline calibration (Test 4)"
  ) +
  theme_bw()

p_freeX_clean

ggsave("C:/Netlogo/Compilacion/Fig_nearoptimal_Test3B_freeX_facets_clean.png",
       p_freeX_clean, width = 7.4, height = 8.4, dpi = 300)


library(stats)

# Load near-optimal solutions themselves (need the near_list; easiest: recompute quickly)
files <- list(
  Test1 = "C:/Netlogo/Compilacion/MySearchOutput.modelRunHistory_Test1.csv",
  Test2 = "C:/Netlogo/Compilacion/MySearchOutput.modelRunHistory_Test2.csv",
  Test3 = "C:/Netlogo/Compilacion/MySearchOutput.modelRunHistory_Test3A.csv",
  Test4 = "C:/Netlogo/Compilacion/MySearchOutput.modelRunHistory_Test3B.csv"
)

read_test <- function(path, test_name){
  df <- read_csv(path, show_col_types = FALSE)
  df$.test <- test_name
  df
}

all_hist <- bind_rows(lapply(names(files), \(t) read_test(files[[t]], t)))
fitness_col <- "final-step-result"

# Parameter columns: numeric + ending with '*'
param_cols <- names(all_hist)[str_detect(names(all_hist), "\\*$")]
param_cols <- param_cols[vapply(all_hist[param_cols], is.numeric, logical(1))]

# Near-optimal top 5% for selected test
df_near <- all_hist %>%
  filter(.test == selected_test) %>%
  arrange(.data[[fitness_col]]) %>%
  slice_head(n = floor(n() * 0.05)) %>%
  select(all_of(param_cols)) %>%
  select(where(~sd(.x, na.rm = TRUE) > 0))

cor_mat <- cor(df_near, method = "spearman", use = "pairwise.complete.obs")

# Clustering order
dist_mat <- as.dist(1 - abs(cor_mat))
hc <- hclust(dist_mat, method = "average")
ord <- hc$order
cor_ord <- cor_mat[ord, ord]

cor_long <- as.data.frame(as.table(cor_ord)) %>%
  rename(var1 = Var1, var2 = Var2, rho = Freq) %>%
  mutate(var1 = str_replace_all(var1, "\\*", ""),
         var2 = str_replace_all(var2, "\\*", ""))

p_cor_clust <- ggplot(cor_long, aes(x = var1, y = var2, fill = rho)) +
  geom_tile() +
  scale_fill_gradient2(limits = c(-1, 1)) +
  coord_fixed() +
  labs(title = "Spearman correlations within near-optimal set (Test 3B)",
       x = NULL, y = NULL, fill = "ρ") +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

p_cor_clust

ggsave("C:/Netlogo/Compilacion/Fig_B6_spearman_heatmap_Test3B_clustered.png",
       p_cor_clust, width = 8, height = 7, dpi = 300)

# == OTRA PRUEBA
library(readr)
library(dplyr)
library(stringr)
library(ggplot2)
library(patchwork)


tab_params <- read_csv("C:/Netlogo/Compilacion/nearoptimal_param_summary_long.csv", show_col_types = FALSE)
selected_test <- "Test4"

tab_sel <- tab_params %>%
  filter(.test == selected_test) %>%
  mutate(parameter = str_replace_all(parameter, "\\*", "")) %>%
  mutate(group = case_when(
    parameter %in% c("a","b_minus_a","r_weight_growth","r_weight_estab") ~ "Biotic resistance",
    parameter %in% c("dispersal_radius_m","kernel_decay") ~ "Dispersal kernel",
    parameter %in% c("maturity-age-years","min-sup-for-reproduction") ~ "Reproduction thresholds",
    parameter %in% c("management_reset_size","gamma-recovery") ~ "Reset & recovery",
    TRUE ~ NA_character_
  )) %>%
  filter(!is.na(group))

# Orden deseado por grupo
order_list <- list(
  "Biotic resistance" = c("r_weight_estab","r_weight_growth","b_minus_a","a"),
  "Dispersal kernel" = c("dispersal_radius_m","kernel_decay"),
  "Reproduction thresholds" = c("min-sup-for-reproduction","maturity-age-years"),
  "Reset & recovery" = c("management_reset_size","gamma-recovery")
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

# Combinar en columna
p_all <- (p1 / p2 / p3 / p4) +
  plot_annotation(
    title = "Near-optimal parameter uncertainty (top 5%): baseline calibration (Test 4)",
    caption = "Points show medians; horizontal bars show 5th–95th percentiles within the near-optimal set."
  ) &
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.caption = element_text(size = 9),
    axis.title.x = element_text(size = 11)
  )

# Añadir el eje X una sola vez (abajo) con patchwork:
p_all <- p_all & labs(x = "Parameter value (median and 5th–95th percentiles within near-optimal set)")

p_all

ggsave("C:/Netlogo/Compilacion/Fig_nearoptimal_Test3B_PATCHWORK.png",
       p_all, width = 7.6, height = 9.0, dpi = 300)
