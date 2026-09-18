# ============================================================
# Figure 4 / Appendix B6: near-optimal parameter ranges
# Selected calibration model: Test 4
# ============================================================

library(readr)
library(dplyr)
library(stringr)
library(ggplot2)
library(patchwork)

# ----------------------------
# 1) Paths
# ----------------------------

input_file <- "C:/Netlogo/Compilacion/nearoptimal_param_summary_long.csv"
output_dir <- "C:/Netlogo/Compilacion/NearOptimal_FigureRevised"

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

selected_test <- "Test4"

# ----------------------------
# 2) Read near-optimal summaries
# ----------------------------

tab_params <- read_csv(input_file, show_col_types = FALSE)

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

# ----------------------------
# 3) Parameter order by process group
# ----------------------------

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

# ----------------------------
# 4) Build patchwork figure
# ----------------------------

p1 <- make_panel(tab_sel, "Biotic resistance") + scale_x_continuous()
p2 <- make_panel(tab_sel, "Dispersal kernel") + scale_x_continuous()
p3 <- make_panel(tab_sel, "Reproduction thresholds") + scale_x_continuous()
p4 <- make_panel(tab_sel, "Reset & recovery") + scale_x_continuous()

p_all <- (p1 / p2 / p3 / p4) +
  plot_annotation(
    title = "Near-optimal parameter ranges (top 5%): selected calibration model (Test 4)",
    caption = "Points show medians; horizontal bars show 5th–95th percentiles within the near-optimal set."
  ) &
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.caption = element_text(size = 9),
    axis.title.x = element_text(size = 11)
  )

p_all <- p_all &
  labs(x = "Parameter value (median and 5th–95th percentiles within near-optimal set)")

# ----------------------------
# 5) Save outputs
# ----------------------------

png_file <- file.path(output_dir, "Fig_nearoptimal_Test4_parameter_ranges_PATCHWORK.png")
pdf_file <- file.path(output_dir, "Fig_nearoptimal_Test4_parameter_ranges_PATCHWORK.pdf")

ggsave(png_file, p_all, width = 7.6, height = 9.0, dpi = 300)
ggsave(pdf_file, p_all, width = 7.6, height = 9.0)

message("Saved figure to: ", png_file)
message("Saved figure to: ", pdf_file)
