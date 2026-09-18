# --- packages ---
suppressPackageStartupMessages({
  library(sf); library(terra); library(dplyr); library(stringr)
})

# --- paths ---
tmpl_path   <- "C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/altitud_abm_10m.asc"
mask10_path <- "C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/survey_mask_10m.asc"
spp_path    <- "C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/ailanthus_all.shp"

out_csv     <- "C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/obs_series_10m.csv"

years_full  <- 2008:2023

# ---- define anchor years ----
anchors <- c(2008, 2012, 2018, 2022)
# anchors <- NULL   # NULL to auto-detect

# ---- load template and mask (must align to ABM grid) ----
tmpl  <- rast(tmpl_path)
mask10 <- rast(mask10_path)
stopifnot(all.equal(ext(mask10), ext(tmpl)),
          all.equal(res(mask10), res(tmpl)),
          crs(mask10) == crs(tmpl))
mask10 <- clamp(mask10, 0, 1)

# ---- load presences (polygons with a 'year' field) ----
spp <- st_read(spp_path, quiet = TRUE) |> st_transform(crs(tmpl))
stopifnot("Year" %in% names(spp))
spp$year <- as.integer(spp$Year)

# ---- auto-detect anchors if not supplied ----
if (is.null(anchors)) {
  # criterion: keep years with at least Nmin polygons (or Nmin cells once rasterized).
  # Adjust Nmin to corpus size (e.g., 50 polygons).
  Nmin <- 50
  yrs_tab <- spp |>
    st_drop_geometry() |>
    count(Year, name = "n_polys") |>
    arrange(Year)
  anchors <- yrs_tab$Year[yrs_tab$n_polys >= Nmin]
  if (length(anchors) == 0L) {
    stop("Auto-detection found no anchor years; set 'anchors' manually.")
  }
}

cat("Anchors ->", paste(anchors, collapse = ", "), "\n")

# ---- cumulative presence inside 10 m buffer per anchor year ----
count_cells_in_mask <- function(sf_geom) {
  if (nrow(sf_geom) == 0L) return(0L)
  r <- rasterize(vect(sf_geom), tmpl, field = 1, background = 0)
  r <- clamp(r, 0, 1)
  r_masked <- mask(r, mask10)          # outside mask -> NA
  r_masked[is.na(r_masked)] <- 0
  as.integer(global(r_masked, "sum", na.rm = TRUE)[1,1])
}

obs_anchors <- integer(length(anchors))
for (i in seq_along(anchors)) {
  y <- anchors[i]
  # cumulative union up to year y
  add <- spp |> filter(year <= y)
  if (nrow(add) == 0L) {
    obs_anchors[i] <- 0L
  } else {
    # union to avoid double counts; simpler: rasterize all polys directly (same effect in binary 10 m)
    obs_anchors[i] <- count_cells_in_mask(add)
  }
  cat(sprintf("Anchor %d -> cells_in_10m = %d\n", y, obs_anchors[i]))
}

# ---- build LOCF series for 2008–2023 ----
# step function: for each t, take the last anchor <= t
obs_cells_by_year_10m <- integer(length(years_full))
for (i in seq_along(years_full)) {
  t <- years_full[i]
  prev <- anchors[anchors <= t]
  if (length(prev) == 0L) {
    obs_cells_by_year_10m[i] <- 0L
  } else {
    idx <- match(max(prev), anchors)
    obs_cells_by_year_10m[i] <- obs_anchors[idx]
  }
}

# ---- save CSV and print NetLogo list ----
out <- data.frame(
  year = years_full,
  cells_10m_locf = obs_cells_by_year_10m
)
write.csv(out, out_csv, row.names = FALSE)
cat("\nNetLogo list (paste into setup):\n")
cat("set obs_cells_by_year_10m [",
    paste(obs_cells_by_year_10m, collapse = " "),
    "]\n\n", sep = "")

# ---- quick plot for QA (optional) ----
try({
  oldpar <- par(no.readonly = TRUE); on.exit(par(oldpar))
  plot(years_full, obs_cells_by_year_10m, type = "s", xlab = "Year", ylab = "Occupied 10 m cells (LOCF)")
})



#☺ arreglo ráster para Netlogo
suppressPackageStartupMessages({ library(terra) })
options(OutDec = ".")  # si el sistema usa coma decimal

mask10 <- rast("C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/survey_mask_10m.asc")  # o crea desde el shapefile
mask10 <- clamp(mask10, 0, 1)
mask10[is.na(mask10)] <- 0

writeRaster(
  mask10,
  filename = "C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/survey_mask_10m.asc",
  overwrite = TRUE,
  filetype = "AAIGrid",   # ESRI ASCII Grid
  NAflag   = -9999,
  datatype = "INT1U"      # 0/1 entero
)

