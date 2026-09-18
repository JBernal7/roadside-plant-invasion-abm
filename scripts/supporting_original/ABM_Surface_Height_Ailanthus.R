# Cargar paquetes necesarios
library(sf)
library(dplyr)
library(ggplot2)

# Ruta al archivo 
ruta_shp <- "C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/ailanthus_all.shp"

# Leer shapefile
shp <- st_read(ruta_shp)

# Filtrado: eliminar NA en Height_cat y rodales con comentarios de manejo
shp_filtrado <- shp %>%
  filter(!is.na(Height_cat),
         Height_cat != "",
         !grepl("^\\s*$", Height_cat),  # no espacios en blanco
         Height_cat != "NA",
         !grepl("management", Comments, ignore.case = TRUE))


table(shp_filtrado$Height_cat, useNA = "always") # chequeo para ver si quedan NA

# Convertir Height_cat a factor ordenado
shp_filtrado$Height_cat <- factor(shp_filtrado$Height_cat, 
                                  levels = c("1", "2", "3", "4"), 
                                  ordered = TRUE)

# Visualización: boxplot
ggplot(shp_filtrado, aes(x = Height_cat, y = Sp_dens_m2)) +
  geom_boxplot() +
  scale_y_log10() + # usar log para reducir asimetría
  labs(title = "Superficie vs categoría de altura (Ailanthus)",
       x = "Height_cat", y = "Superficie (m², log escala)")

# Filtrar valores válidos para el modelo
shp_modelo <- shp_filtrado %>%
  filter(!is.na(Sp_dens_m2),
         Sp_dens_m2 > 0)

# Ajustar modelo con log
modelo <- lm(log(Sp_dens_m2) ~ Height_cat, data = shp_modelo)
summary(modelo)


# Ajustar modelo lineal (log-transformado)
modelo <- lm(log(Sp_dens_m2) ~ Height_cat, data = shp_filtrado)
summary(modelo)

# superficies derivadas del modelo por categoría 
exp(predict(modelo, newdata = data.frame(Height_cat = factor(c("1", "2", "3", "4")))))


################################################################################
######## CALCULO DE ICs Y AJUSTE DE CURVA A MODELO LOGÍSTICO ###################
################################################################################

# Ajustar curva logística sobre puntos estimados
df_sup <- data.frame(
  Height_cat = factor(c(1, 2, 3, 4)),
  Edad = c(1, 2, 3, 4),  # proxy continuo
  Sup_estimada = c(14.3, 49.2, 96.0, 182.4)
)

# Ajuste no lineal tipo logística
modelo_nl <- nls(Sup_estimada ~ SSlogis(Edad, Asym, xmid, scal), data = df_sup)
summary(modelo_nl)


# Puntos con IC del modelo lineal
pred_df <- data.frame(Height_cat = factor(c("1", "2", "3", "4"), levels = c("1", "2", "3", "4")))
pred <- predict(modelo, newdata = pred_df, interval = "confidence")
pred_df <- cbind(pred_df, exp(pred))
colnames(pred_df) <- c("Height_cat", "fit", "lwr", "upr")
pred_df$Edad <- as.numeric(as.character(pred_df$Height_cat))

# Curva logística
edad_seq <- seq(1, 4, 0.1)
pred_nl <- predict(modelo_nl, newdata = data.frame(Edad = edad_seq))

# Graficar conjunto
ggplot() +
  geom_point(data = pred_df, aes(x = Edad, y = fit), size = 3) +
  geom_errorbar(data = pred_df, aes(x = Edad, ymin = lwr, ymax = upr), width = 0.1) +
  geom_line(aes(x = edad_seq, y = pred_nl), colour = "blue", linewidth = 1.2) +
  labs(title = "Curva logística ajustada con IC por categoría",
       x = "Edad estimada (Height_cat)", y = "Superficie estimada (m²)") 

# Exportar parámetros de la logística
params <- coef(modelo_nl)
write.csv(as.data.frame(params), "./Resultados/logistic_parameters.csv", row.names = TRUE)


##############################################################################



