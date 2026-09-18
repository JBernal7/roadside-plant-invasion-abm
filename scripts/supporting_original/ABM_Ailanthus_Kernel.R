library(raster)

# Parámetros
res <- 10
radius <- 250
decay <- 0.04
a <- 2.08

# Tamaño del kernel
size <- (2 * radius / res) + 1
size <- as.integer(size)  # 51
center <- floor(size / 2)

# Crear grid de coordenadas
x_coords <- seq(-radius, radius, by = res)
y_coords <- seq(-radius, radius, by = res)
grid <- expand.grid(x = x_coords, y = y_coords)

# Calcular distancia desde el centro
grid$dist <- sqrt(grid$x^2 + grid$y^2)

# Calcular valor del kernel
grid$kernel <- a * exp(-decay * grid$dist)

# Normalizar a suma = 1
grid$kernel <- grid$kernel / sum(grid$kernel)

# Crear raster desde XYZ
kernel_raster <- rasterFromXYZ(grid[, c("x", "y", "kernel")])

# Exportar a ASCII .asc
writeRaster(kernel_raster,
            filename = "ailanthus_kernel_250m_10mres.asc",
            format = "ascii",
            overwrite = TRUE)

write.csv(as.matrix(kernel_raster), "ailanthus_kernel_matrix.csv", row.names = FALSE)