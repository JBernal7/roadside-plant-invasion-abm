library(terra)

# Ráster de referencia
ref_rast <- rast("C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/total_resistance_10m.asc")

# Leer capas vectoriales
area_total <- vect("C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/plantilla_extensionABM_bbox.shp")
area_activa <- vect("C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/Celdas_activas_1km.shp")

# Asegurar misma proyección
area_total <- project(area_total, crs(ref_rast))
area_activa <- project(area_activa, crs(ref_rast))

crs(ref_rast)
crs(area_activa)
crs(area_total)

ext(ref_rast)
ext(area_activa)
ext(area_total)

# Recortar vectores al extent del ráster
area_total_crop <- crop(area_total, ref_rast)
area_activa_crop <- crop(area_activa, ref_rast)

# Rasterizar usando field = 1 y touches = TRUE
r_area_total <- rasterize(area_total_crop, ref_rast, field = 1, touches = TRUE)
r_area_activa <- rasterize(area_activa_crop, ref_rast, field = 1, touches = TRUE)

# Construir capa binaria: 1 si está en área activa, 0 si está en total pero no activa
area_binaria <- classify(r_area_total, matrix(c(NA, NA, 0)), others = 0)
area_binaria[!is.na(r_area_activa)] <- 1

# Guardar como .asc
writeRaster(area_binaria,
            filename = "C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/area_activa_binaria.asc",
            overwrite = TRUE,
            NAflag = -9999)
