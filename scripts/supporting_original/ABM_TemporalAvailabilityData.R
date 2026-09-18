# ============================================================
# Figure B1. Temporal availability of empirical calibration data
# (a) Number of mapped Ailanthus polygons per year
# (b) Observed cumulative occupied model-grid cells
# ============================================================

library(sf)
library(terra)
library(dplyr)
library(tidyr)
library(stringr)
library(ggplot2)
library(patchwork)

# ------------------------------------------------------------
# INPUTS
# ------------------------------------------------------------

# Shapefile with GSV polygons
shp_path <- "C:/Geodirectorio/Proyectos/DesFutur/Datos/DesFutur_GSV.shp"

# Survey strip mask (10-m roadside strip as observation domain)
survey10_path <- "C:/Netlogo/abm_prep/survey_mask_10m.asc"

# Directory with annual 10-m occupancy rasters derived from imagery
occ_dir <- "C:/Netlogo/abm_prep/occ_anio/"

# Output figure
out_fig <- "C:/Netlogo/Compilacion/Fig_B1_temporal_availability_calibration_data.png"

# ------------------------------------------------------------
# PANEL (a): Number of mapped stand polygons per year
# ------------------------------------------------------------

gsv_data <- st_read(shp_path, quiet = TRUE)

# Basic cleaning
gsv_data$Species[gsv_data$Species == "Opuntia spp"] <- "Opuntia ficus-indica"

# Keep Ailanthus polygons only
ail_data <- gsv_data %>%
  filter(Species == "Ailanthus altissima")

# Useful mapped polygons are only confirmed presences, keep them:
if ("Identified" %in% names(ail_data)) {
  ail_data <- ail_data %>% filter(Identified == "Y")
}

# Make sure Year is numeric/integer
ail_data <- ail_data %>%
  mutate(Year = as.integer(Year))

poly_year <- ail_data %>%
  st_drop_geometry() %>%
  count(Year, name = "n_polygons") %>%
  complete(Year = 2008:2023, fill = list(n_polygons = 0)) %>%
  arrange(Year)

p_a <- ggplot(poly_year, aes(x = Year, y = n_polygons)) +
  geom_col() +
  labs(
    title = "(a) Mapped stand polygons per year",
    x = "Year",
    y = "Number of polygons"
  ) +
  theme_bw()

p_a

# ------------------------------------------------------------
# PANEL (b): Observed cumulative occupied model-grid cells
# ------------------------------------------------------------

survey10 <- rast(survey10_path)

# Model-grid template at the effective NetLogo patch metrics
patch_w <- 59.1
patch_h <- 85.22
tmpl <- rast(ext(survey10), res = c(patch_w, patch_h), crs = crs(survey10))

# One polygon per model-grid cell
patch_pol <- as.polygons(tmpl, values = FALSE)
patch_pol$patch_id <- 1:nrow(patch_pol)

# Keep only cells whose centroid falls inside the roadside survey strip
cent <- centroids(patch_pol)
sv_pt <- extract(survey10, cent)
patch_pol$in_survey <- ifelse(sv_pt[, 2] >= 0.5, 1, 0)
inmask <- patch_pol$in_survey == 1

# Read annual occupancy rasters at imagery resolution
files <- list.files(occ_dir, pattern = "\\.tif$", full.names = TRUE)
years <- str_extract(basename(files), "\\d{4}") |> as.integer()

ord <- order(years)
files <- files[ord]
years <- years[ord]

# Aggregate annual occupancy to model grid and compute cumulative occupancy
ever_occ <- rep(0, nrow(patch_pol))
occ_year <- numeric(length(files))
occ_cum_year <- numeric(length(files))

for (i in seq_along(files)) {
  r <- rast(files[i])
  
  # Binary occupancy raster
  r_bin <- classify(r, rbind(c(-Inf, 0.5, 0),
                             c(0.5,  Inf, 1)))
  
  # Occupied model-grid cells for that year (max occupancy within each model cell)
  ex <- extract(r_bin, patch_pol, fun = max, na.rm = TRUE)
  occ_patch <- ifelse(!is.na(ex[, 2]) & ex[, 2] >= 1, 1, 0)
  
  # Annual occupied model-grid cells (within survey strip)
  occ_year[i] <- sum(occ_patch[inmask] == 1, na.rm = TRUE)
  
  # Cumulative occupancy ("ever observed")
  ever_occ <- pmax(ever_occ, occ_patch, na.rm = TRUE)
  occ_cum_year[i] <- sum(ever_occ[inmask] == 1, na.rm = TRUE)
}

obs <- data.frame(
  year = years,
  occ = occ_year,
  occ_cum = occ_cum_year
)

# Expand to full annual sequence and carry last observation forward
full <- obs %>%
  select(year, occ_cum) %>%
  right_join(data.frame(year = 2008:2023), by = "year") %>%
  arrange(year) %>%
  tidyr::fill(occ_cum, .direction = "down") %>%
  mutate(
    occ_cum = ifelse(
      is.na(occ_cum),
      first(occ_cum[!is.na(occ_cum)]),
      occ_cum
    )
  )

p_b <- ggplot(full, aes(x = year, y = occ_cum)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  labs(
    title = "(b) Observed cumulative occupied model-grid cells",
    x = "Year",
    y = "Occupied model-grid cells"
  ) +
  theme_bw()

p_b

# ------------------------------------------------------------
# COMBINE PANELS
# ------------------------------------------------------------

p_final <- p_a / p_b +
  plot_annotation(
    title = "Figure B1. Temporal availability of empirical calibration data"
  )

p_final

ggsave(out_fig, p_final, width = 8.5, height = 8, dpi = 300)

# ------------------------------------------------------------
# csv
# ------------------------------------------------------------

write.csv(poly_year,
          "C:/Netlogo/Compilacion/FigB1_panelA_polygons_per_year.csv",
          row.names = FALSE)

write.csv(full,
          "C:/Netlogo/Compilacion/FigB1_panelB_observed_cumulative_cells.csv",
          row.names = FALSE)
