# 00_setup.R
suppressPackageStartupMessages({
  library(sf); library(terra); library(dplyr); library(stringr)
})

# ---- Rutas de entrada ----
sipna_gpkg   <- "C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/sipna_2025.gpkg"  # polígonos con campos d_*
roads_layer  <- "C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/roads.shp"            # ejes viales (líneas)
template_ras <- "C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/altitud_abm_10m.asc"  # grilla 10 m (extent/CRS del ABM)

# ---- Parámetros ----
params <- list(
  slope_urb    = 0.30,   # modulación urbano
  R_road_min   = 0.10,   # valor en eje
  lambda_road  = 40,     # m (escala del gradiente vial)
  fallback_R   = 0.40    # R por defecto
)

# ---- 1) Leer datos ----
sipna <- st_read(sipna_gpkg, quiet = TRUE)
roads <- st_read(roads_layer, quiet = TRUE)
tmpl  <- rast(template_ras)

# Asegurar CRS
sipna <- st_transform(sipna, st_crs(tmpl))
roads <- st_transform(roads, st_crs(tmpl))

# ---- 2) Clasificación por criterio dominante ----
# columnas: d_arbo, d_querc, d_euc, d_mato, d_herb, d_cultl, d_culth, d_olivar, d_edif, d_vial (0–100)
sipna_cls <- sipna %>%
  mutate(
    clase = case_when(
      d_arbo > 40 & d_querc > 20 ~ "bosque_autoctono",
      d_euc  > 20                ~ "eucaliptal",
      d_arbo > 40                ~ "bosque_otros",
      d_olivar > 20              ~ "olivar",
      d_cultl > 20               ~ "cultivo_leñoso",
      d_culth > 20               ~ "cultivo_herbaceo",
      d_mato  > 30               ~ "matorral",
      d_herb  > 30               ~ "pastizal",
      d_edif  > 30               ~ "urbano",
      d_vial  > 20               ~ "infraestructura",
      TRUE                       ~ "mixto_indefinido"
    ),
    R_base = case_when(
      clase == "bosque_autoctono"  ~ 1.00,
      clase == "bosque_otros"      ~ 0.80,
      clase == "eucaliptal"        ~ 0.20,
      clase == "matorral"          ~ 0.60,
      clase == "pastizal"          ~ 0.55,
      clase == "cultivo_leñoso"    ~ 0.40,
      clase == "cultivo_herbaceo"  ~ 0.40,
      clase == "olivar"            ~ 0.35,
      clase == "urbano"            ~ NA_real_,      # se calculará luego
      clase == "infraestructura"   ~ NA_real_,      # se calculará luego
      TRUE                         ~ params$fallback_R
    )
  )

# Factores y códigos para la clase 
sipna_cls$clase <- factor(sipna_cls$clase)
class_codes <- c(
  bosque_autoctono = 1,
  eucaliptal      = 2,
  bosque_otros    = 3,
  olivar          = 4,
  cultivo_leñoso  = 5,
  cultivo_herbaceo= 6,
  matorral        = 7,
  pastizal        = 8,
  urbano          = 9,
  infraestructura = 10,
  mixto_indefinido= 11
)
sipna_cls$class_id <- class_codes[as.character(sipna_cls$clase)]

# ---- 3) Rasterizar R_base ----
R_base_r <- terra::rasterize(vect(sipna_cls), tmpl, field="R_base", background=params$fallback_R)

# Rasterizar la clase como códigos enteros
clase_r  <- terra::rasterize(vect(sipna_cls), tmpl, field = "class_id")

# ---- 4) Módulo URBANO (depende d_edif) ----
# Raster d_edif (pixel-wise)
d_edif_r <- terra::rasterize(vect(sipna_cls), tmpl, field="d_edif", background=0)
R_urb_r <- terra::clamp(0.35 - params$slope_urb * (d_edif_r/100), 0.05, 0.35)

# Aplicar R_urb en celdas clase == 'urbano'
# mask_urbano <- clase_r == class_codes["urbano"]
# R1 <- R_base_r
# R1[mask_urbano] <- R_urb_r[mask_urbano]
R1 <- cover( ifel(clase_r == class_codes["urbano"], R_urb_r, NA), R_base_r )

# ---- 5) Módulo INFRAESTRUCTURA (gradiente radial) ----
# Distancia al eje vial (en metros)
road_r <- rasterize(vect(roads), tmpl, field=1, background=NA)
dist_r <- distance(road_r)  # distancia euclídea en celdas/CRS métrico

# Opción A: volver al R del entorno (R1) con gradiente desde R_road_min
# R_infra(d) = R_min + (R_bg - R_min) * (1 - exp(-d/lambda))
R_bg <- R1
R_min <- params$R_road_min
lambda <- params$lambda_road
R_infra_r <- R_min + (R_bg - R_min) * (1 - exp(- (dist_r / lambda)))

# # Aplicar sólo donde clase == "infraestructura"
# mask_infra <- clase_r == class_codes["infraestructura"]
# R2 <- R1
# R2[mask_infra] <- R_infra_r[mask_infra]
R2 <- cover( ifel(clase_r == class_codes["infraestructura"], R_infra_r, NA), R1 )

# ---- 6) Recorte y límites ----
resistance_bio <- clamp(R2, 0, 1)
# Rellenar cualquier NA residual con el fallback:
resistance_bio <- ifel( is.na(resistance_bio), params$fallback_R, resistance_bio )

# Comprobación de QA:
print( global(is.na(resistance_bio), "sum", na.rm=TRUE) )  # debe ser 0


# ---- 7) Exportar ----

writeRaster(resistance_bio,
            filename = "C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/resistance_bio_10m.asc",
            overwrite = TRUE,
            gdal = c("TFW=YES"))

# ---- 8) QA rápido ----
summary(values(resistance_bio))
