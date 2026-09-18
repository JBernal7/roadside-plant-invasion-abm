# Cargar librerías
library(sf)
library(terra)
library(dplyr)
library(stringr)

# Leer la capa vectorial desde el .gpkg
sipna <- st_read("C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/sipna_2025.gpkg")

# Explorar las columnas útiles (cober_label, d_edif, d_arbó, etc.)
names(sipna)

################################################################################
############################# resistance-bio ###################################
################# Clasificación básica según tipo funcional ####################
################################################################################

# Clasificación funcional según criterios jerárquicos
sipna <- sipna %>%
  mutate(tipo_funcional = case_when(
    d_arbo > 40 & d_querc > 20 ~ "bosque_autoctono",
    d_arbo > 40 ~ "bosque_otros",
    d_mato > 30 ~ "matorral",
    d_herb > 30 ~ "pastizal",
    d_cultl > 20 ~ "cultivo_lenoso",
    d_culth > 20 ~ "cultivo_herbaceo",
    d_olivar > 20 ~ "olivar",
    d_euc > 20 ~ "eucaliptal",
    d_edif > 30 ~ "urbano",
    d_vial > 20 ~ "infraestructura",
    TRUE ~ "mixto_indefinido"
  ))

# Asignación de resistencia biótica
sipna <- sipna %>%
  mutate(resistance_bio = case_when(
    tipo_funcional == "bosque_autoctono" ~ 1.0,
    tipo_funcional == "bosque_otros" ~ 0.8,
    tipo_funcional == "matorral" ~ 0.6,
    tipo_funcional == "pastizal" ~ 0.5,
    tipo_funcional == "cultivo_lenoso" ~ 0.3,
    tipo_funcional == "cultivo_herbaceo" ~ 0.3,
    tipo_funcional == "olivar" ~ 0.25,
    tipo_funcional == "eucaliptal" ~ 0.2,
    tipo_funcional == "urbano" ~ 0.05,
    tipo_funcional == "infraestructura" ~ 0.1,
    TRUE ~ 0.4
  ))

# Convertir a SpatVector (terra)
sipna_vect <- vect(sipna)

# Crear plantilla ráster en EPSG:25830 (ETRS89 / UTM zona 30N)
template <- rast(ext(sipna_vect), resolution = 10, crs = "EPSG:25830")

# Reproyectar geometría a EPSG:25830 antes de rasterizar
sipna_vect_proj <- project(sipna_vect, crs(template))

# Rasterizar
rast_resistance <- rasterize(sipna_vect_proj, template, field = "resistance_bio")

# Guardar el ráster
writeRaster(rast_resistance,
            filename = "C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/resistance_bio_10m.tif",
            overwrite = TRUE)

# Guardar como .asc para NetLogo
writeRaster(rast_resistance,
            filename = "C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/resistance_bio_10m.asc",
            overwrite = TRUE,
            gdal = c("TFW=YES"))

message("Raster de resistance_bio generado y guardado correctamente.")


################################################################################
########################## RASTER DEL TIPO FUNCIONAL ###########################
######## No para Netlogo, sino para inspección o análisis futuro ###############
################################################################################

# Crear tabla de correspondencia tipo_funcional → código entero
tipo_codigos <- c(
  bosque_autoctono = 1,
  bosque_otros = 2,
  matorral = 3,
  pastizal = 4,
  cultivo_lenoso = 5,
  cultivo_herbaceo = 6,
  olivar = 7,
  eucaliptal = 8,
  urbano = 9,
  infraestructura = 10,
  mixto_indefinido = 11
)

# Asignar códigos
sipna <- sipna %>%
  mutate(tipo_funcional_cod = tipo_codigos[tipo_funcional])

# Reproyectar si no está ya en EPSG:25830
sipna_vect_proj <- project(vect(sipna), "EPSG:25830")

# Crear ráster plantilla
template <- rast(ext(sipna_vect_proj), resolution = 10, crs = "EPSG:25830")

# Rasterizar campo tipo_funcional_cod
rast_tipo_funcional <- rasterize(sipna_vect_proj, template, field = "tipo_funcional_cod")

# Guardar ráster
writeRaster(rast_tipo_funcional,
            filename = "C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/tipo_funcional_10m.tif",
            overwrite = TRUE)