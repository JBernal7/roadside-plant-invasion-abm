library(terra)

# Cargar rásters
r_alt <- rast("C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/altitud_abm_10m.asc")
r_bio <- rast("C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/resistance_bio_10m.asc")
r_total <- rast("C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/total_resistance_10m.asc")
r_activa <- rast("C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/area_activa_binaria.asc")

# Comparar
all.equal(ext(r_alt), ext(r_bio))
all.equal(res(r_alt), res(r_bio))
all.equal(crs(r_alt), crs(r_bio))
compareGeom(r_alt, r_bio)  # más exigente: compara todo (ext/bbox, res, nfilas, 
                          # ncol, alineación de grilla, crs)

# Repetir con r_total y r_activa
compareGeom(r_alt, r_total)
compareGeom(r_alt, r_activa)

################################################################################
######################### ALINEAR Y SOBREESCRIBIR LAS CAPAS ####################
######## Ojo: importante tener las capas originales a buen recaudo ###########
###########################  antes de proceder  ################################

# Plantilla base: altitud (ya alineada correctamente)
r_alt <- rast("C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/altitud_abm_10m.asc")

# 1. Cargar resistencia_bio y alinear
r_bio <- rast("C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/resistance_bio_10m.asc")
r_bio_aligned <- resample(r_bio, r_alt, method = "bilinear")
writeRaster(r_bio_aligned, "C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/resistance_bio_10m.asc",
            overwrite = TRUE, NAflag = -9999)

# 2. Cargar total_resistance y alinear
r_total <- rast("C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/total_resistance_10m.asc")
r_total_aligned <- resample(r_total, r_alt, method = "bilinear")
writeRaster(r_total_aligned, "C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/total_resistance_10m.asc",
            overwrite = TRUE, NAflag = -9999)

# 3. Cargar area_activa_binaria y alinear
r_activa <- rast("C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/area_activa_binaria.asc")
r_activa_aligned <- resample(r_activa, r_alt, method = "near")  # para conservar 0 y 1 exactos
writeRaster(r_activa_aligned, "C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/area_activa_binaria.asc",
            overwrite = TRUE, NAflag = -9999)

compareGeom(r_alt, r_bio_aligned)
compareGeom(r_alt, r_total_aligned)
compareGeom(r_alt, r_activa_aligned)


####################### VERIFICACIÓN VISUAL ####################################
# Cargar las capas alineadas
r_alt <- rast("C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/altitud_abm_10m.asc")
r_bio <- rast("C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/resistance_bio_10m.asc")
r_total <- rast("C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/total_resistance_10m.asc")
r_activa <- rast("C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/area_activa_binaria.asc")

# Superponer capas en visualización // También sacar mapas modificando el título
plot(r_alt, main = "Altitud (gris) + Resistance_bio", col = gray.colors(100))
plot(r_bio, col = terrain.colors(100), alpha = 0.5, add = TRUE)

plot(r_alt, main = "Altitud (gris) + Total_resistance", col = gray.colors(100))
plot(r_total, col = heat.colors(100), alpha = 0.5, add = TRUE)

plot(r_alt, main = "Área activa sobre altitud", col = gray.colors(100))
plot(r_activa, col = "#00FF0040", legend = FALSE, add = TRUE) 


##################### AMPLIACIÓN: RÁSTER DE IDONEIDAD ##########################
# Cargar raster de idoneidad generado
r_idoneidad <- rast("C:/Geodirectorio/Proyectos/DesFutur/Resultados/Ailanthus_suitability_ABM_10m_buffer.asc")

# Plantilla base: altitud (que ya está bien alineada)
r_alt <- rast("C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/altitud_abm_10m.asc")

# Comprobar geometría
compareGeom(r_alt, r_idoneidad)  # Si da FALSE, hay que alinear

# Si no están alineados:
r_idoneidad_aligned <- resample(r_idoneidad, r_alt, method = "bilinear")

# Guardar raster corregido (sobrescribir o crear uno nuevo)
writeRaster(r_idoneidad_aligned,
            "C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/Ailanthus_suitability_ABM_10m.asc",
            overwrite = TRUE, NAflag = -9999)

# Verificación final
compareGeom(r_alt, r_idoneidad_aligned)


##### Visualización

library(terra)

# Cargar la altitud (fondo gris) y la idoneidad alineada
r_alt <- rast("C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/altitud_abm_10m.asc")
r_idoneidad_aligned <- rast("C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/Ailanthus_suitability_ABM_10m.asc")

# Asegurar que los NA estén correctos
NAflag(r_idoneidad_aligned) <- -9999
r_idoneidad_aligned[is.na(r_idoneidad_aligned)] <- NA

# Crear una paleta con colores invertidos (verde → baja, rojo → alta)
paleta_idon <- colorRampPalette(c("green", "yellow", "red"))(100)

# Graficar con layout similar al de otros mapas
plot(r_alt, main = "Altitud (gris) + Idoneidad de Ailanthus", 
     col = gray.colors(100))

# Superponer idoneidad con transparencia
plot(r_idoneidad_aligned, col = paleta_idon, alpha = 0.5, add = TRUE)

# Agregar leyenda personalizada (manual)
legend("topright", legend = c("Baja idoneidad", "Media", "Alta idoneidad"),
       fill = paleta_idon[c(1,50,100)], border = NA, bty = "n", cex = 0.9,
       title = "Probabilidad (0-1)")


####################### AMPLIACIÓN II - RASTER IDONEIDAD CAMBIANDO VALORES SIN DATOS ################

# Rutas de los archivos
ruta_idoneidad <- "C:/Netlogo/abm_prep/Ailanthus_ABM10m_probs.asc"
ruta_altitud   <- "C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/altitud_abm_10m.asc"

# Cargar rasters
r_idoneidad <- rast(ruta_idoneidad)
r_alt <- rast(ruta_altitud)

# 1. Sustituir NA por 0 en el raster de idoneidad
r_idoneidad[is.na(r_idoneidad)] <- 0

# 2. Comprobar geometría
if (!compareGeom(r_alt, r_idoneidad, stopOnError = FALSE)) {
  message("Geometries not aligned. Resampling suitability raster...")
  r_idoneidad <- resample(r_idoneidad, r_alt, method = "bilinear")
}

# 3. Guardar raster corregido (sobrescribe el original)
writeRaster(r_idoneidad,
            ruta_idoneidad,
            overwrite = TRUE,
            NAflag = -9999)  # Solo se usará para celdas fuera del extent real

# 4. Verificación final
print(compareGeom(r_alt, r_idoneidad))  # Debería ser TRUE

# Visualización (opcional)
plot(r_alt, col = gray.colors(50), main = "Altitud (fondo gris)")
plot(r_idoneidad, add = TRUE, alpha = 0.5, col = terrain.colors(50))



####################### AMPLIACIÓN III - RASTER CONTROL AGRICULTURA ################

# Rutas de los archivos
ruta_agricultura <- "C:/Netlogo/abm_prep/agriculture_control.asc"
ruta_altitud   <- "C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/altitud_abm_10m.asc"

# Cargar rasters
r_agri <- rast(ruta_agricultura)
r_alt <- rast(ruta_altitud)


# 2. Comprobar geometría
if (!compareGeom(r_alt, r_agri, stopOnError = FALSE)) {
  message("Geometries not aligned. Resampling suitability raster...")
  r_agri_aligned <- resample(r_agri, r_alt, method = "near") # método conservador: mantiene 0 y 1
}

# Guardar raster alineado (sobrescribiendo) ## Estaban alineados :)
writeRaster(r_agri_aligned,
            ruta_agricultura,
            overwrite = TRUE,
            NAflag = -9999)

# Verificación
compareGeom(r_alt, r_agri)

# Visualización
plot(r_alt, main = "Altitud (gris) + Suelo agrícola", col = gray.colors(100))
plot(r_agri_aligned, col = "#99CC00AA", legend = FALSE, add = TRUE)

