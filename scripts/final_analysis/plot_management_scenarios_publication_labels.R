# Load packages
library(raster)
library(terra)
library(dplyr)
library(stringr)
library(ggplot2)
library(ggpubr)

# Plots theme
theme_pub <- function(base_size = 15){
  theme_minimal(base_size = base_size) +
    theme(
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank(),
      axis.title = element_text(face = "bold"),
      axis.text.x = element_text(angle = 30, hjust = 1),
      legend.title = element_text(face = "bold"),
      legend.position = "right",
      plot.title = element_text(face = "bold", hjust = 0.5)
    )
}

# Colorblind-friendly palette
pal <- c(
    "control" = "#BBBBBBB3",      
    "low_intensity" = "#91BFDBB3", 
    "high_intensity" = "#FC8D59B3",
    "erradication" = "#66C2A5B3"    
)   


# Publication-facing labels. Raw output/folder names are preserved for reproducibility.
publication_treatment_labels <- c(
  "control" = "Baseline",
  "low_intensity" = "Low intensity",
  "high_intensity" = "Intermediate intensity",
  "erradication" = "High intensity (eradication)"
)

##### 1. Simulation results for all the study area #####
# Baseline 2008
base_raster <- rast("data_inputs/baseline_2008.asc")

# Operate with raster
base_raster <- raster(base_raster)

# 8-connectivity clustering
b1 <- base_raster
b1[b1 == 0] <- NA
bcl <- clump(b1, directions = 8)

# n clusters and mean cluster size
sizes_base <- as.data.frame(freq(bcl))
sizes_base <- sizes_base[!is.na(sizes_base$value), ]
n_clusters_base <- maxValue(bcl)
mean_cluster_size_base <- mean(sizes_base$count)

# total occupied cells
base_vals <- getValues(base_raster)
base_vals <- base_vals[!is.na(base_vals)]
ct_base <- sum(base_vals == 1)


# SIMULATIONS
treatments <- c(
  "baseline_2025","baseline_2035","baseline_2045",
  "highintensity_100m_2035","highintensity_200m_2035",
  "highintensity_100m_2045","highintensity_200m_2045",
  "lowintensity_100m_2035","lowintensity_200m_2035",
  "lowintensity_100m_2045","lowintensity_200m_2045",
  "highintensity_400m_2035","highintensity_400m_2045",
  "lowintensity_400m_2035","lowintensity_400m_2045",
  "erradication_100m_2035","erradication_100m_2045",
  "erradication_200m_2035","erradication_200m_2045",
  "erradication_400m_2035","erradication_400m_2045"
)

# Initialize results
results_list <- list()
counter <- 1

for (treat in treatments) {
  files <- list.files(file.path("data_inputs/", treat),
                      pattern = "\\.asc$",
                      full.names = TRUE)
  
  for (f in files) {
    cat("Processing:", f, "\n")
    
    # Read raster
    simu_raster <- raster(f)
    simu_raster[simu_raster > 0] <- 1
    simu_raster[is.na(simu_raster[])] <- 0
    
    # Ensure extent consistency
    simu_raster <- rast(simu_raster)
    ext(simu_raster) <- ext(base_raster)
    simu_raster <- raster(simu_raster)
    
    # 8-connectivity clustering
    r1 <- simu_raster
    r1[r1 == 0] <- NA
    cl <- clump(r1, directions = 8)
    
    # Number of clusters
    n_clusters <- maxValue(cl)
    
    # Cluster sizes
    sizes <- as.data.frame(freq(cl))
    sizes <- sizes[!is.na(sizes$value), ]
    mean_cluster_size <- mean(sizes$count)
    
    # Total occupied cells
    vals <- getValues(simu_raster)
    vals <- vals[!is.na(vals)]
    ct <- sum(vals == 1)
    
    # Percentage change from baseline
    ct_perc <- ((ct - ct_base) / ct_base) * 100
    
    # Store result
    results_list[[counter]] <- data.frame(
      treatment = treat,
      file = basename(f),
      ct_perc = round(ct_perc, 3),
      n_clusters = round(n_clusters, 3),
      mean_cluster_size = round(mean_cluster_size, 3),
      stringsAsFactors = FALSE
    )
    
    counter <- counter + 1
  }
}

# Combine results
results <- bind_rows(results_list)

# Treatment classification
results <- results %>%
  mutate(type = case_when(
      str_detect(treatment, "baseline")       ~ "control",
      str_detect(treatment, "highintensity")  ~ "high_intensity",
      str_detect(treatment, "lowintensity")   ~ "low_intensity",
      str_detect(treatment, "erradication")   ~ "erradication",
      TRUE ~ NA_character_),
    year = str_extract(treatment, "2025|2035|2045"),
    zone = case_when(
      str_detect(treatment, "baseline") ~ "control",
      str_detect(treatment, "100m") ~ "100m",
      str_detect(treatment, "200m") ~ "200m",
      str_detect(treatment, "400m") ~ "400m",
      TRUE ~ NA_character_
    )
  )

# Factor ordering
results$type <- factor(results$type,
                       levels = c("control",
                                  "low_intensity",
                                  "high_intensity",
                                  "erradication"))

results$year <- factor(results$year,
                       levels = c("2025", "2035", "2045"))

results$zone <- factor(results$zone,
                       levels = c("control", "100m", "200m", "400m"))


# Surface increase plot
plot_surface <- ggplot(results,
                       aes(x = zone,
                           y = ct_perc,
                           fill = type)) +
  geom_boxplot(width = 0.8,
               outlier.shape = NA,
               colour = "black",
               size = 0.3) +
  scale_fill_manual(values = pal, breaks = names(publication_treatment_labels), labels = publication_treatment_labels) +
  facet_wrap(~ year, nrow = 1) +
  labs(x = "Buffer zone",
       y = "Surface increase (% from 2008)",
       fill = "Treatment intensity") +
  theme_pub() +
  theme(
    strip.background = element_blank(),
    strip.text = element_text(face = "bold")
  )

plot_surface

# Remove 2025 data
results_filtered <- results %>%
  filter(year != "2025")

# Drop unused factor level
results_filtered$year <- droplevels(results_filtered$year)

# Surface increase plot without 2025
plot_surface <- ggplot(results_filtered,
                       aes(x = zone,
                           y = ct_perc,
                           fill = type)) +
  geom_boxplot(width = 0.8,
               outlier.shape = NA,
               colour = "black",
               size = 0.3) +
  scale_fill_manual(values = pal, breaks = names(publication_treatment_labels), labels = publication_treatment_labels) +
  facet_wrap(~ year, nrow = 1) +
  labs(x = "Buffer zone",
       y = "Surface increase (% from 2008)",
       fill = "Treatment intensity") +
  theme_pub() +
  theme(
    strip.background = element_blank(),
    strip.text = element_text(face = "bold")
  )

plot_surface


# Number of clusters plot
plot_clusters <- ggplot(results,
                        aes(x = zone,
                            y = n_clusters,
                            fill = type)) +
  geom_boxplot(width = 0.8,
               outlier.shape = NA,
               colour = "black",
               size = 0.3) +
  scale_fill_manual(values = pal, breaks = names(publication_treatment_labels), labels = publication_treatment_labels) +
  facet_wrap(~ year, nrow = 1) +
  labs(x = "Buffer zone",
       y = "Number of clusters",
       fill = "Treatment intensity") +
  theme_pub()

plot_clusters


# Number of clusters plot without 2025
plot_clusters <- ggplot(results_filtered,
                        aes(x = zone,
                            y = n_clusters,
                            fill = type)) +
  geom_boxplot(width = 0.8,
               outlier.shape = NA,
               colour = "black",
               size = 0.3) +
  scale_fill_manual(values = pal, breaks = names(publication_treatment_labels), labels = publication_treatment_labels) +
  facet_wrap(~ year, nrow = 1) +
  labs(x = "Buffer zone",
       y = "Number of clusters",
       fill = "Treatment intensity") +
  theme_pub()

plot_clusters


# Mean cluster size plot
plot_mean_cluster <- ggplot(results,
                            aes(x = zone,
                                y = mean_cluster_size,
                                fill = type)) +
  geom_boxplot(width = 0.8,
               outlier.shape = NA,
               colour = "black",
               size = 0.3) +
  scale_fill_manual(values = pal, breaks = names(publication_treatment_labels), labels = publication_treatment_labels) +
  facet_wrap(~ year, nrow = 1) +
  labs(x = "Buffer zone",
       y = "Mean cluster size (cells)",
       fill = "Treatment intensity") +
  theme_pub()

plot_mean_cluster


# Mean cluster size plot without 2025
plot_mean_cluster <- ggplot(results_filtered,
                            aes(x = zone,
                                y = mean_cluster_size,
                                fill = type)) +
  geom_boxplot(width = 0.8,
               outlier.shape = NA,
               colour = "black",
               size = 0.3) +
  scale_fill_manual(values = pal, breaks = names(publication_treatment_labels), labels = publication_treatment_labels) +
  facet_wrap(~ year, nrow = 1) +
  labs(x = "Buffer zone",
       y = "Mean cluster size (cells)",
       fill = "Treatment intensity") +
  theme_pub()

plot_mean_cluster


# Combine all plots
combined_plot_all <- ggarrange(
  plot_surface,
  plot_clusters,
  plot_mean_cluster,
  ncol = 1,  
  nrow = 3,  
  align = "v",
  labels = c("A", "B", "C") 
)

combined_plot_all


# Export results
write.csv(results,
          "data_outputs/results_analysis.csv",
          row.names = FALSE)

# Save figure
ggsave("data_outputs/Combined_plot.pdf",
       combined_plot_all,
       width = 10,
       height = 15)



##### 2. Simulation results only for Poqueira #####

# Clip area of interest
clip_area <- vect("C:/Users/claud/Downloads/UCO_contrato/Proyecto/02_ABM_Capitulo2/02_ABM_Capitulo2/abm_prep/recorte_all_poqueira.shp")

base_raster <- rast("data_inputs/treatments_v21_v3/baseline_2008/baseline_2008_tick1.asc")

# Rasterize clip area
mask_raster <- rasterize(clip_area, base_raster, field = 1, background = NA)

# Crop baseline to area of interest
base_raster <- mask(base_raster, mask_raster)

# Binarize
base_raster <- raster(base_raster)
base_raster[base_raster > 0] <- 1
base_raster[is.na(base_raster[])] <- 0

# 8-connectivity clustering
b1 <- base_raster
b1[b1 == 0] <- NA
bcl <- clump(b1, directions = 8)

# n clusters and mean cluster size
sizes_base <- as.data.frame(freq(bcl))
sizes_base <- sizes_base[!is.na(sizes_base$value), ]
n_clusters_base <- maxValue(bcl)
mean_cluster_size_base <- mean(sizes_base$count)

# total occupied cells
base_vals <- getValues(base_raster)
base_vals <- base_vals[!is.na(base_vals)]
ct_base <- sum(base_vals == 1)

# Load simulations
treatments <- c(
  "baseline_2025","baseline_2035","baseline_2045",
  "erradication_poqueira_2035","erradication_poqueira_2045",
  "highintensity_poqueira_2035","highintensity_poqueira_2045",
  "lowintensity_poqueira_2035","lowintensity_poqueira_2045"
)

results_list <- list()
counter <- 1

for (treat in treatments) {
  files <- list.files(file.path("data_inputs/", treat),
                      pattern = "\\.asc$",
                      full.names = TRUE)
  
  for (f in files) {
    cat("Processing:", f, "\n")
    
    simu_raster <- rast(f)
    
    # Clip to Poqueira
    simu_raster <- mask(simu_raster, mask_raster)
    
    # Binarize
    simu_raster <- raster(simu_raster)
    simu_raster[simu_raster > 0] <- 1
    simu_raster[is.na(simu_raster[])] <- 0
    
    # Ensure extent
    simu_raster <- rast(simu_raster)
    ext(simu_raster) <- ext(base_raster)
    simu_raster <- raster(simu_raster)
    
    # 8-connectivity clustering
    r1 <- simu_raster
    r1[r1 == 0] <- NA
    cl <- clump(r1, directions = 8)
    
    # Number of clusters
    n_clusters <- maxValue(cl)
    
    # Cluster sizes
    sizes <- as.data.frame(freq(cl))
    sizes <- sizes[!is.na(sizes$value), ]
    mean_cluster_size <- mean(sizes$count)
    
    # Total occupied cells
    vals <- getValues(simu_raster)
    vals <- vals[!is.na(vals)]
    ct <- sum(vals == 1)
    
    # Percentage change from baseline
    ct_perc <- ((ct - ct_base)/ct_base)*100
    
    # Store
    results_list[[counter]] <- data.frame(
      treatment = treat,
      file = basename(f),
      ct_perc = round(ct_perc, 3),
      n_clusters = round(n_clusters, 3),
      mean_cluster_size = round(mean_cluster_size, 3),
      stringsAsFactors = FALSE
    )
    
    counter <- counter + 1
  }
}

results <- bind_rows(results_list)

# Treatment classification
results <- results %>%
  mutate(
    type = case_when(
      str_detect(treatment, "baseline") ~ "control",
      str_detect(treatment, "highintensity") ~ "high_intensity",
      str_detect(treatment, "lowintensity") ~ "low_intensity",
      str_detect(treatment, "erradication") ~ "erradication",
      TRUE ~ NA_character_),
    year = str_extract(treatment, "2025|2035|2045"),
    zone = case_when(
      str_detect(treatment, "baseline") ~ "control",
      str_detect(treatment, "poqueira") ~ "poqueira",
      TRUE ~ NA_character_))

# Factor ordering
results$type <- factor(results$type, levels=c("control","low_intensity","high_intensity","erradication"))
results$year <- factor(results$year, levels=c("2025","2035","2045"))

# Surface increase plot
plot_surface <- ggplot(results,
                       aes(x = year, y = ct_perc, fill = type)) +
  geom_boxplot(width=0.8, outlier.shape=NA, colour="black", size=0.3) +
  scale_fill_manual(values=pal) +
  labs(x="Buffer zone", y="Surface increase (% from 2008)", fill="Treatment type") +
  theme_pub() +
  theme(strip.background=element_blank(),
        strip.text=element_text(face="bold"))
plot_surface

# Surface increase without 2025
results_filtered <- results %>% filter(year != "2025")
results_filtered$year <- droplevels(results_filtered$year)

plot_surface <- ggplot(results_filtered,
                              aes(x = year, y = ct_perc, fill = type)) +
  geom_boxplot(width=0.8, outlier.shape=NA, colour="black", size=0.3) +
  scale_fill_manual(values=pal) +
  labs(x="Zone", y="Surface increase (% from 2008)", fill="Treatment type") +
  theme_pub() +
  theme(strip.background=element_blank(),
        strip.text=element_text(face="bold"))
plot_surface

# Number of clusters
plot_clusters <- ggplot(results,
                        aes(x=year, y=n_clusters, fill=type)) +
  geom_boxplot(width=0.8, outlier.shape=NA, colour="black", size=0.3) +
  scale_fill_manual(values=pal) +
  labs(x="Zone", y="Number of clusters", fill="Treatment type") +
  theme_pub()
plot_clusters

plot_clusters <- ggplot(results_filtered,
                               aes(x=year, y=n_clusters, fill=type)) +
  geom_boxplot(width=0.8, outlier.shape=NA, colour="black", size=0.3) +
  scale_fill_manual(values=pal) +
  labs(x="Zone", y="Number of clusters", fill="Treatment type") +
  theme_pub()
plot_clusters

# Mean cluster size
plot_mean_cluster <- ggplot(results,
                            aes(x=year, y=mean_cluster_size, fill=type)) +
  geom_boxplot(width=0.8, outlier.shape=NA, colour="black", size=0.3) +
  scale_fill_manual(values=pal) +
  labs(x="Zone", y="Mean cluster size (cells)", fill="Treatment type") +
  theme_pub()
plot_mean_cluster

plot_mean_cluster <- ggplot(results_filtered,
                                   aes(x=year, y=mean_cluster_size, fill=type)) +
  geom_boxplot(width=0.8, outlier.shape=NA, colour="black", size=0.3) +
  scale_fill_manual(values=pal) +
  labs(x="Zone", y="Mean cluster size (cells)", fill="Treatment type") +
  theme_pub()
plot_mean_cluster
