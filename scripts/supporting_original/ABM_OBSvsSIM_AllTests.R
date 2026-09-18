library(dplyr)
library(ggplot2)
library(readr)
library(stringr)

# =========================================================
# 1. INPUT FILES
# =========================================================
files <- tibble::tribble(
  ~test,  ~file,
  "Test 1",  "C:/Netlogo/Calibration_20260203_Test1/verif_series_1_best_seed12345_PATCHOBS.csv",
  "Test 2",  "C:/Netlogo/Calibration_20260204_Test2/verif_series_2_best_seed12345_PATCHOBS.csv",
  "Test 3", "C:/Netlogo/Calibration_20260206_Test3A/verif_series_3A_best_seed12345_PATCHOBS.csv",
  "Test 4", "C:/Netlogo/Calibration_20260208_Test3B/verif_series_3B_best_seed12345_PATCHOBS.csv"
)

out_dir <- "C:/Netlogo/Compilacion/Calibration_Figures_AppendixB"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# =========================================================
# 2. READ + COMBINE
# =========================================================
all_df <- files %>%
  rowwise() %>%
  do({
    df <- read_csv(.$file, show_col_types = FALSE)
    df$test <- .$test
    df
  }) %>%
  ungroup()

# Ordering of panels
all_df <- all_df %>%
  mutate(test = factor(test, levels = c("Test 1", "Test 2", "Test 3", "Test 4")))

# =========================================================
# 3. DELTA SERIES
# =========================================================
all_df_delta <- all_df %>%
  group_by(test) %>%
  mutate(
    obs_d = obs - first(obs),
    sim_d = sim_median - first(sim_median),
    p25_d = sim_p25 - first(sim_p25),
    p75_d = sim_p75 - first(sim_p75)
  ) %>%
  ungroup()

# =========================================================
# 4. COMMON THEME
# =========================================================
base_theme <- theme_bw() +
  theme(
    legend.position = "bottom",
    legend.title = element_blank(),
    strip.background = element_rect(fill = "grey90", colour = "grey40"),
    strip.text = element_text(face = "bold"),
    plot.title = element_text(face = "bold")
  )

# =========================================================
# 5. FIGURE B2: ABSOLUTE CUMULATIVE OCCUPANCY
# =========================================================
p_B2 <- ggplot(all_df, aes(x = year)) +
  geom_ribbon(aes(ymin = sim_p25, ymax = sim_p75), alpha = 0.2) +
  geom_line(aes(y = obs,        linetype = "Observed"), linewidth = 0.9) +
  geom_line(aes(y = sim_median, linetype = "Simulated median"), linewidth = 0.9) +
  scale_linetype_manual(
    values = c("Observed" = "solid", "Simulated median" = "dashed"),
    breaks = c("Observed", "Simulated median")
  ) +
  facet_wrap(~ test, ncol = 2) +
  labs(
    x = "Year",
    y = "Occupied model-grid cells",
    title = "Observed versus simulated cumulative occupancy trajectories"
  ) +
  base_theme

p_B2

ggsave(
  file.path(out_dir, "Figure_B2_obs_vs_sim_cumulative.png"),
  plot = p_B2, width = 10, height = 7, dpi = 300
)

ggsave(
  file.path(out_dir, "Figure_B2_obs_vs_sim_cumulative.pdf"),
  plot = p_B2, width = 10, height = 7
)

# =========================================================
# 6. FIGURE B3: INCREMENT TRAJECTORIES (Δ RELATIVE TO 2008)
# =========================================================
p_B3 <- ggplot(all_df_delta, aes(x = year)) +
  geom_ribbon(aes(ymin = p25_d, ymax = p75_d), alpha = 0.2) +
  geom_line(aes(y = obs_d, linetype = "Observed"), linewidth = 0.9) +
  geom_line(aes(y = sim_d, linetype = "Simulated median"), linewidth = 0.9) +
  scale_linetype_manual(
    values = c("Observed" = "solid", "Simulated median" = "dashed"),
    breaks = c("Observed", "Simulated median")
  ) +
  facet_wrap(~ test, ncol = 2) +
  labs(
    x = "Year",
    y = expression(Delta*" occupied model-grid cells (relative to 2008)"),
    title = "Observed versus simulated increment trajectories"
  ) +
  base_theme

p_B3

ggsave(
  file.path(out_dir, "Figure_B3_obs_vs_sim_delta.png"),
  plot = p_B3, width = 10, height = 7, dpi = 300
)

ggsave(
  file.path(out_dir, "Figure_B3_obs_vs_sim_delta.pdf"),
  plot = p_B3, width = 10, height = 7
)


# comprobacion IQR
all_df %>%
  mutate(iqr_width = sim_p75 - sim_p25) %>%
  group_by(test) %>%
  summarise(
    min_iqr = min(iqr_width, na.rm = TRUE),
    max_iqr = max(iqr_width, na.rm = TRUE),
    mean_iqr = mean(iqr_width, na.rm = TRUE)
  )

# Hubo un error en la función de exportado de IQR
# Dejamos fuera (ARREGLAR SI EN FUTURO REPETIMOS)

# =========================================================
# 7. EXPORT INDIVIDUAL FIGURES BY TEST
# =========================================================
tests_levels <- levels(all_df$test)

for (tt in tests_levels) {
  
  df_abs <- all_df %>% filter(test == tt)
  df_del <- all_df_delta %>% filter(test == tt)
  
  tt_file <- str_replace_all(tt, " ", "_")
  
  p_abs_single <- ggplot(df_abs, aes(x = year)) +
    geom_ribbon(aes(ymin = sim_p25, ymax = sim_p75), alpha = 0.2) +
    geom_line(aes(y = obs,        linetype = "Observed"), linewidth = 0.9) +
    geom_line(aes(y = sim_median, linetype = "Simulated median"), linewidth = 0.9) +
    scale_linetype_manual(
      values = c("Observed" = "solid", "Simulated median" = "dashed"),
      breaks = c("Observed", "Simulated median")
    ) +
    labs(
      x = "Year",
      y = "Occupied model-grid cells",
      title = paste0(tt, ": observed versus simulated cumulative occupancy")
    ) +
    base_theme
  
  ggsave(
    file.path(out_dir, paste0(tt_file, "_obs_vs_sim_cumulative.png")),
    plot = p_abs_single, width = 6.5, height = 4.8, dpi = 300
  )
  
  ggsave(
    file.path(out_dir, paste0(tt_file, "_obs_vs_sim_cumulative.pdf")),
    plot = p_abs_single, width = 6.5, height = 4.8
  )
  
  p_del_single <- ggplot(df_del, aes(x = year)) +
    geom_ribbon(aes(ymin = p25_d, ymax = p75_d), alpha = 0.2) +
    geom_line(aes(y = obs_d, linetype = "Observed"), linewidth = 0.9) +
    geom_line(aes(y = sim_d, linetype = "Simulated median"), linewidth = 0.9) +
    scale_linetype_manual(
      values = c("Observed" = "solid", "Simulated median" = "dashed"),
      breaks = c("Observed", "Simulated median")
    ) +
    labs(
      x = "Year",
      y = expression(Delta*" occupied model-grid cells (relative to 2008)"),
      title = paste0(tt, ": observed versus simulated increment trajectory")
    ) +
    base_theme
  
  ggsave(
    file.path(out_dir, paste0(tt_file, "_obs_vs_sim_delta.png")),
    plot = p_del_single, width = 6.5, height = 4.8, dpi = 300
  )
  
  ggsave(
    file.path(out_dir, paste0(tt_file, "_obs_vs_sim_delta.pdf")),
    plot = p_del_single, width = 6.5, height = 4.8
  )
}


# =========================================================
# FIGURA INDIVIDUAL COMPUESTA: TEST 4 (ABSOLUTA + DELTA)
# =========================================================

df_test4_abs <- all_df %>%
  filter(test == "Test 4") %>%
  mutate(panel = "A. Cumulative occupancy")

df_test4_del <- all_df_delta %>%
  filter(test == "Test 4") %>%
  mutate(panel = "B. Increment relative to 2008")

# preparamos un dataset común
df_test4_combo <- bind_rows(
  df_test4_abs %>%
    transmute(
      year,
      obs = obs,
      sim_median = sim_median,
      lower = sim_p25,
      upper = sim_p75,
      panel
    ),
  df_test4_del %>%
    transmute(
      year,
      obs = obs_d,
      sim_median = sim_d,
      lower = p25_d,
      upper = p75_d,
      panel
    )
)

p_test4_combo <- ggplot(df_test4_combo, aes(x = year)) +
  geom_ribbon(aes(ymin = lower, ymax = upper), alpha = 0.2) +
  geom_line(aes(y = obs, linetype = "Observed"), linewidth = 0.9) +
  geom_line(aes(y = sim_median, linetype = "Simulated median"), linewidth = 0.9) +
  scale_linetype_manual(
    values = c("Observed" = "solid", "Simulated median" = "dashed"),
    breaks = c("Observed", "Simulated median")
  ) +
  facet_wrap(~ panel, ncol = 1, scales = "free_y") +
  labs(
    x = "Year",
    y = NULL,
    title = "Test 4: observed versus simulated trajectories"
  ) +
  base_theme

p_test4_combo

ggsave(
  file.path(out_dir, "Test_4_combined_abs_delta.png"),
  plot = p_test4_combo, width = 7, height = 8, dpi = 300
)

ggsave(
  file.path(out_dir, "Test_4_combined_abs_delta.pdf"),
  plot = p_test4_combo, width = 7, height = 8
)
