
# Load packages
library(readr)
library(dplyr)
library(ggplot2)
library(ggpubr)


# Load data
results <- read_csv("data_inputs/results_analysis_figure6.csv")

# Check data
str(results)


# Prepare data
results <- results %>%
  mutate(
    treatment = factor(
      treatment,
      levels = c(
        "Baseline",
        "Low intensity",
        "Intermediate intensity",
        "High intensity (eradication)"
      )
    ),
    zone = factor(zone),
    year = factor(year)
  )

# Check data
table(results$treatment, useNA = "ifany")
table(results$zone, useNA = "ifany")
table(results$year, useNA = "ifany")


# Plot theme
theme_pub <- function(base_size = 15) {
  theme_minimal(base_size = base_size) +
    theme(
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank(),
      axis.title = element_text(face = "bold"),
      axis.text.x = element_text(angle = 30, hjust = 1),
      legend.title = element_text(face = "bold"),
      legend.position = "right",
      plot.title = element_text(face = "bold", hjust = 0.5),
      strip.background = element_blank(),
      strip.text = element_text(face = "bold")
    )
}


# Color palette
pal <- c(
  "Baseline" = "#BBBBBBB3",
  "100 m" = "#FC8D59B3",
  "200 m" = "#91BFDBB3",
  "400 m" = "#66C2A5B3"
)

# Number of clusters
plot_clusters <- ggplot(
  results,
  aes(x = treatment, y = n_clusters, fill = zone)
) +
  geom_boxplot(
    width = 0.8,
    outlier.shape = NA,
    colour = "black",
    linewidth = 0.3,
    position = position_dodge(width = 0.8)
  ) +
  scale_fill_manual(values = pal, na.value = "grey80") +
  facet_wrap(~year, nrow = 1) +
  labs(
    x = "Treatment",
    y = "Number of clusters",
    fill = "Zone"
  ) +
  theme_pub()

# Mean cluster size
plot_mean_cluster <- ggplot(
  results,
  aes(x = treatment, y = mean_cluster_size, fill = zone)
) +
  geom_boxplot(
    width = 0.8,
    outlier.shape = NA,
    colour = "black",
    linewidth = 0.3,
    position = position_dodge(width = 0.8)
  ) +
  scale_fill_manual(values = pal, na.value = "grey80") +
  facet_wrap(~year, nrow = 1) +
  labs(
    x = "Treatment",
    y = "Mean cluster size (cells)",
    fill = "Zone"
  ) +
  theme_pub()

# Combine plots
combined_plot <- ggarrange(
  plot_clusters,
  plot_mean_cluster,
  ncol = 1,
  nrow = 2,
  align = "v",
  labels = c("A", "B"),
  common.legend = TRUE,
  legend = "right"
)

# Display
print(combined_plot)

# Save figure
ggsave(
  "data_outputs/Combined_plot_fig6.pdf",
  combined_plot,
  width = 8,
  height = 10
)
