library(dplyr)
library(ggplot2)
library(readr)


df <- read_csv("C:/Netlogo/Calibration_20260203_Test1/verif_series_1_best_seed12345_PATCHOBS.csv", )

out_dir <- "C:/Netlogo/Calibration_20260203_Test1/plots"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

base_theme <- theme_bw() +
  theme(
    legend.position = "bottom",
    legend.title = element_blank()
  )

# =========================
# ABSOLUTO (Observed lisa, Sim punteada)
# =========================
p_abs <- ggplot(df, aes(x = year)) +
  geom_ribbon(aes(ymin = sim_p25, ymax = sim_p75), alpha = 0.2) +
  geom_line(aes(y = obs,        linetype = "Observed"),     linewidth = 1) +
  geom_line(aes(y = sim_median, linetype = "Sim (median)"), linewidth = 1) +
  scale_linetype_manual(
    values = c("Observed" = "solid", "Sim (median)" = "dashed"),
    breaks = c("Observed", "Sim (median)")
  ) +
  labs(
    x = "Year",
    y = "Occupied cells (exported units)",
    title = "Observed vs simulated (absolute)"
  ) +
  base_theme


p_abs

ggsave(file.path(out_dir, "ABSOLUTO_obs_vs_sim.png"),
       plot = p_abs, width = 8, height = 4.8, dpi = 300)
ggsave(file.path(out_dir, "ABSOLUTO_obs_vs_sim.pdf"),
       plot = p_abs, width = 8, height = 4.8)

# =========================
# DELTA (Observed lisa, Sim punteada)
# =========================
df2 <- df %>%
  mutate(
    obs_d = obs - first(obs),
    sim_d = sim_median - first(sim_median),
    p25_d = sim_p25 - first(sim_p25),
    p75_d = sim_p75 - first(sim_p75)
  )

p_delta <- ggplot(df2, aes(x = year)) +
  geom_ribbon(aes(ymin = p25_d, ymax = p75_d), alpha = 0.2) +
  geom_line(aes(y = obs_d, linetype = "Observed Δ"),     linewidth = 1) +
  geom_line(aes(y = sim_d, linetype = "Sim Δ (median)"), linewidth = 1) +
  scale_linetype_manual(
    values = c("Observed Δ" = "solid", "Sim Δ (median)" = "dashed"),
    breaks = c("Observed Δ", "Sim Δ (median)")
  ) +
  labs(
    x = "Year",
    y = "Δ occupied cells (baseline = first year)",
    title = "Observed vs simulated Δ"
  ) +
  base_theme

p_delta

ggsave(file.path(out_dir, "DELTA_obs_vs_sim.png"),
       plot = p_delta, width = 8, height = 4.8, dpi = 300)
ggsave(file.path(out_dir, "DELTA_obs_vs_sim.pdf"),
       plot = p_delta, width = 8, height = 4.8)
