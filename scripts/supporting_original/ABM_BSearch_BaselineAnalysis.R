# =============================================================================
# Análisis de correlación de BSearch 
# =============================================================================

library(readr)
library(dplyr)
library(purrr)
library(ggplot2)
library(rlang)

# 1) Carga del histórico de BehaviorSearch
bs_file <- "C:/Netlogo/Calibration_20260208/IASModel.modelRunHistory.csv"
raw <- read_csv(bs_file, show_col_types = FALSE)

names(raw)

# ---- Encontrar nombres de columnas
find_col <- function(nms, candidates) {
  hit <- candidates[candidates %in% nms]
  if (length(hit) == 0) return(NA_character_)
  hit[1]
}

nms <- names(raw)

# Columnas base
col_rwg   <- find_col(nms, c("r_weight_growth*", "r_weight_growth"))
col_rwe   <- find_col(nms, c("r_weight_estab*", "r_weight_estab"))
col_gam   <- find_col(nms, c("gamma-recovery*", "gamma_recovery*", "gamma-recovery", "gamma_recovery"))
col_mat   <- find_col(nms, c("maturity-age-years*", "maturity_age_years*", "maturity-age-years", "maturity_age_years"))
col_mins  <- find_col(nms, c("min-sup-for-reproduction*", "min_sup_for_reproduction*", "min-sup-for-reproduction", "min_sup_for_reproduction"))
col_disp  <- find_col(nms, c("dispersal_radius_m*", "dispersal-radius-m*", "dispersal_radius_m"))
col_mgmt  <- find_col(nms, c("management_reset_size*", "management-reset-size*", "management_reset_size"))
col_fit   <- find_col(nms, c("mean-result", "mean_result", "fitness", "result"))

# Columnas para Test 3A y 3B
col_a     <- find_col(nms, c("a*", "a", "resistance_a*", "resistance_a"))
col_bma   <- find_col(nms, c("b_minus_a*", "b-minus-a*", "b_minus_a", "b-minus-a", "bma*", "bma"))


# ---- Rename con lo que exista 
df <- raw

if (!is.na(col_rwg))  df <- df %>% rename(r_weight_growth = !!sym(col_rwg))
if (!is.na(col_rwe))  df <- df %>% rename(r_weight_estab  = !!sym(col_rwe))
if (!is.na(col_gam))  df <- df %>% rename(gamma_recovery  = !!sym(col_gam))
if (!is.na(col_mat))  df <- df %>% rename(maturity_age_years = !!sym(col_mat))
if (!is.na(col_mins)) df <- df %>% rename(min_sup_for_reproduction = !!sym(col_mins))
if (!is.na(col_disp)) df <- df %>% rename(dispersal_radius_m = !!sym(col_disp))
if (!is.na(col_mgmt)) df <- df %>% rename(management_reset_size = !!sym(col_mgmt))
if (!is.na(col_fit))  df <- df %>% rename(fitness = !!sym(col_fit))

if (!is.na(col_a))    df <- df %>% rename(a = !!sym(col_a))
if (!is.na(col_bma))  df <- df %>% rename(b_minus_a = !!sym(col_bma))

# Define el set "candidato" de parámetros que podrían aparecer
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

# Qué parámetros existen realmente en este CSV
param_cols <- intersect(param_candidates, names(df))

# Avisar de qué falta
missing <- setdiff(param_candidates, param_cols)
message("Using parameters: ", paste(param_cols, collapse = ", "))
if (length(missing) > 0) message("Missing (not in this run): ", paste(missing, collapse = ", "))

# ---- Agrupación por combinación de parámetros
df_param <- df %>%
  group_by(across(all_of(param_cols))) %>%
  summarise(
    fitness = mean(fitness, na.rm = TRUE),
    .groups = "drop"
  )

# ---- Spearman por parámetro
cor_table <- map_dfr(param_cols, function(p) {
  x <- df_param[[p]]
  y <- df_param$fitness
  
  ct <- suppressWarnings(cor.test(x, y, method = "spearman", exact = FALSE))
  
  tibble(
    parameter = p,
    rho       = unname(ct$estimate),
    p_value   = ct$p.value
  )
}) %>%
  arrange(desc(abs(rho)))

print(cor_table)

# ---- Lollipop
cor_plot <- cor_table %>%
  mutate(
    abs_rho   = abs(rho),
    parameter = factor(parameter, levels = parameter[order(abs_rho)])
  )

p_lollipop <- ggplot(cor_plot, aes(x = abs_rho, y = parameter)) +
  geom_segment(aes(x = 0, xend = abs_rho, y = parameter, yend = parameter)) +
  geom_point(aes(color = rho > 0), size = 3) +
  scale_color_manual(
    values = c("TRUE" = "darkred", "FALSE" = "darkblue"),
    labels = c("FALSE" = "negative", "TRUE" = "positive"),
    name   = "Sign of ρ"
  ) +
  labs(
    x = "Absolute Spearman correlation (|ρ|) with calibration error",
    y = "Parameter"
  ) +
  theme_minimal()

print(p_lollipop)

# ---- Carpeta de salida
out_dir <- "C:/Netlogo/Calibration_20260208/AnalysesR" # Ajustar
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

ggsave(file.path(out_dir, "sens_lollipop.png"), p_lollipop, width = 6, height = 4, dpi = 300)


# ---- Sensibilidad (scatter + loess) por parámetro
for (p in param_cols) {
  
  p_plot <- ggplot(df_param, aes(x = .data[[p]], y = fitness)) +
    geom_point(alpha = 0.4, size = 1) +
    geom_smooth(method = "loess", se = FALSE) +
    labs(
      x = p,
      y = "Calibration error (NRMSEΔ)"
    ) +
    theme_minimal()
  
  print(p_plot)
  
  ggsave(
    filename = file.path(out_dir, paste0("sens_", p, ".png")),
    plot = p_plot,
    width = 6,
    height = 4,
    dpi = 300
  )
}
