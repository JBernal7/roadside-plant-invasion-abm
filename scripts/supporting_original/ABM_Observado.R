library(terra)
library(dplyr)
library(stringr)


# Inputs
survey10_path <- "C:/Netlogo/abm_prep/survey_mask_10m.asc"
# Ocupación observada por año a 10 m 
occ_dir <- "C:/Netlogo/abm_prep/occ_anio/"

survey10 <- rast(survey10_path)

# Plantilla a resolución patch (valores medidos en Netlogo)
patch_w <- 59.1
patch_h <- 85.22
tmpl <- rast(ext(survey10), res=c(patch_w, patch_h), crs=crs(survey10))

# Polígonos de patch para agregación (1 polígono por patch)
patch_pol <- as.polygons(tmpl, values=FALSE)
patch_pol$patch_id <- 1:nrow(patch_pol)

# in_survey por centro (como NetLogo)
cent <- centroids(patch_pol)
sv_pt <- extract(survey10, cent)
patch_pol$in_survey <- ifelse(sv_pt[,2] >= 0.5, 1, 0)
inmask <- patch_pol$in_survey == 1

# Cargar rasters de ocupación por año (10 m)
files <- list.files(occ_dir, pattern="\\.tif$", full.names=TRUE)
years <- str_extract(basename(files), "\\d{4}") |> as.integer()

# Ordenar por año
ord <- order(years)
files <- files[ord]
years <- years[ord]

# ---- acumulado por patch ----
ever_occ <- rep(0, nrow(patch_pol))     # 0/1 por patch
occ_year <- numeric(length(files))
occ_cum_year <- numeric(length(files))

for (i in seq_along(files)) {
  r <- rast(files[i])
  r_bin <- classify(r, rbind(c(-Inf, 0.5, 0), c(0.5, Inf, 1)))
  
  # ocupación del año en patches (max dentro del patch)
  ex <- extract(r_bin, patch_pol, fun=max, na.rm=TRUE)
  occ_patch <- ifelse(!is.na(ex[,2]) & ex[,2] >= 1, 1, 0)  # NA -> 0
  
  # conteo anual (no acumulado)
  occ_year[i] <- sum(occ_patch[inmask] == 1, na.rm=TRUE)
  
  # acumulado OR
  ever_occ  <- pmax(ever_occ, occ_patch, na.rm = TRUE)
  
  # conteo acumulado (ever occupied)
  occ_cum_year[i] <- sum(ever_occ[inmask] == 1, na.rm=TRUE)
}

obs <- data.frame(
  year = years,
  occ = occ_year,
  occ_cum = occ_cum_year
)

print(obs)

library(dplyr)
library(tidyr)

full <- obs %>%
  select(year, occ_cum) %>%
  right_join(data.frame(year=2008:2023), by="year") %>%
  arrange(year) %>%
  tidyr::fill(occ_cum, .direction="down") %>%
  mutate(occ_cum = ifelse(is.na(occ_cum), first(occ_cum[!is.na(occ_cum)]), occ_cum))

print(full)

# Lista lista para NetLogo:
cat("NetLogo list:\n[", paste(full$occ_cum, collapse=" "), "]\n", sep="")
write.csv(full, "obs_patches_series_full_2008_2023.csv", row.names=FALSE)
