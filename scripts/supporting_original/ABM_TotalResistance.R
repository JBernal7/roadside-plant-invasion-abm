library(terra)

# Leer las capas
res_bio <- rast("C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/resistance_bio_10m.asc")
altitude <- rast("C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/altitud_abm_10m.asc")
slope <- rast("C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/pendiente_abm_10m.asc")

# Asegurar que tienen misma resolución, extensión y proyección
altitude <- resample(altitude, res_bio, method = "bilinear")
slope <- resample(slope, res_bio, method = "bilinear")

# Obtener los valores mínimo y máximo de altitud y pendiente
alt_minmax <- minmax(altitude)
slope_minmax <- minmax(slope)

# Normalizar altitud
altitude_norm <- (altitude - alt_minmax[1]) / (alt_minmax[2] - alt_minmax[1])

# Normalizar pendiente
slope_norm <- (slope - slope_minmax[1]) / (slope_minmax[2] - slope_minmax[1])

# Calcular total_resistance
total_resistance <- res_bio + (0.4 * altitude_norm) + (0.2 * slope_norm)

# Recortar a máximo 1 para mantener rango [0,1]
total_resistance[total_resistance > 1] <- 1

# Guardar como .asc para NetLogo
writeRaster(total_resistance,
            filename = "C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/total_resistance_10m.asc",
            overwrite = TRUE,
            gdal = c("TFW=YES"))