# =========================================================
# Figure 3: observed calibration target versus simulated trajectory
# Final manuscript version v2
#
# - Single panel: increment relative to 2008
# - Observed target plotted as a connected line, not a step function
# - Points mark years with direct visual information
# - Legend shortened and arranged to avoid clipping
# - Optional title included by default
# =========================================================

library(dplyr)
library(ggplot2)
library(readr)

# -----------------------------
# 1. User settings
# -----------------------------

# Verification series for the selected calibration model (Test 4)
input_file <- "C:/Netlogo/Calibration_20260208_Test3B/verif_series_3B_best_seed12345_PATCHOBS.csv"

# Output folder
out_dir <- "C:/Netlogo/Compilacion/Calibration_Figures_Revised"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# Years with direct visual information according to the Ailanthus observation layer
visual_information_years <- c(2008, 2010, 2011, 2012, 2014, 2018, 2019, 2021, 2022, 2023)

# Figure options
include_title <- TRUE
figure_title <- "Test 4: observed calibration target and simulated trajectory"
show_iqr_band <- FALSE

# Output size. Increase height if your local device still clips the title or legend.
out_width  <- 8.6
out_height <- 6.0
out_dpi    <- 300

# -----------------------------
# 2. Read and prepare data
# -----------------------------

if (!file.exists(input_file)) {
  stop("Input file not found: ", input_file)
}

series <- readr::read_csv(input_file, show_col_types = FALSE) %>%
  arrange(year) %>%
  mutate(
    obs_delta = obs - first(obs),
    sim_delta = sim_median - first(sim_median),
    p25_delta = sim_p25 - first(sim_p25),
    p75_delta = sim_p75 - first(sim_p75),
    direct_visual_information = as.integer(year) %in% visual_information_years
  )

message(
  "Years plotted as direct visual information: ",
  paste(visual_information_years, collapse = ", ")
)

# Diagnostic table for checking plotted values
readr::write_csv(
  series %>%
    select(year, obs, obs_delta, sim_median, sim_delta, direct_visual_information),
  file.path(out_dir, "Figure_3_diagnostic_increment_visual_years.csv")
)

# -----------------------------
# 3. Build Figure 3
# -----------------------------

p <- ggplot(series, aes(x = year))

if (show_iqr_band) {
  p <- p +
    geom_ribbon(
      aes(ymin = p25_delta, ymax = p75_delta),
      alpha = 0.15
    )
}

p <- p +
  # Empirical calibration target after carry-forward, plotted as connected annual values
  geom_line(
    aes(y = obs_delta, linetype = "Empirical target"),
    linewidth = 0.9
  ) +
  # Years with direct visual information
  geom_point(
    data = series %>% filter(direct_visual_information),
    aes(y = obs_delta, shape = "Direct visual years"),
    size = 2.4
  ) +
  # Median simulated trajectory from VerifYn replicates
  geom_line(
    aes(y = sim_delta, linetype = "Simulated median"),
    linewidth = 0.95
  ) +
  scale_linetype_manual(
    values = c(
      "Empirical target" = "solid",
      "Simulated median" = "longdash"
    ),
    breaks = c("Empirical target", "Simulated median")
  ) +
  scale_shape_manual(
    values = c("Direct visual years" = 16),
    breaks = c("Direct visual years")
  ) +
  guides(
    linetype = guide_legend(
      order = 1,
      nrow = 1,
      byrow = TRUE,
      override.aes = list(linewidth = 1.05)
    ),
    shape = guide_legend(
      order = 2,
      nrow = 1,
      override.aes = list(size = 2.8)
    )
  ) +
  labs(
    x = "Year",
    y = "Increment in occupied model-grid cells\nrelative to 2008",
    title = if (include_title) figure_title else NULL
  ) +
  theme_bw() +
  theme(
    legend.position = "bottom",
    legend.title = element_blank(),
    legend.box = "horizontal",
    legend.box.just = "center",
    legend.key.width = grid::unit(1.35, "cm"),
    legend.spacing.x = grid::unit(0.35, "cm"),
    legend.text = element_text(size = 10),
    axis.title = element_text(size = 12),
    axis.text = element_text(size = 10),
    plot.title = element_text(face = "bold", size = 14, hjust = 0),
    plot.margin = margin(t = 18, r = 16, b = 16, l = 12),
    panel.grid.minor = element_line(linewidth = 0.25),
    panel.grid.major = element_line(linewidth = 0.35)
  )

print(p)

# -----------------------------
# 4. Save outputs
# -----------------------------

ggsave(
  filename = file.path(out_dir, "Figure_3_increment_visual_years_v2.png"),
  plot = p,
  width = out_width,
  height = out_height,
  dpi = out_dpi,
  bg = "white"
)

ggsave(
  filename = file.path(out_dir, "Figure_3_increment_visual_years_v2.pdf"),
  plot = p,
  width = out_width,
  height = out_height,
  bg = "white"
)

message("Figure saved to: ", out_dir)
