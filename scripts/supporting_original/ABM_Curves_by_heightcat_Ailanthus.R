# Cargar paquetes necesarios
library(sf)
library(dplyr)
library(ggplot2)

# Ruta al archivo
ruta_shp <- "C:/Geodirectorio/Geodatos/DesFutur_GSV/abm_prep/ailanthus_all.shp"

# Leer shapefile
shp <- st_read(ruta_shp)

# Asegurar que las variables necesarias están disponibles:
# ID: identificador del rodal
# Year: año de observación
# Height_cat: categoría de altura
# Sp_dens_m2: superficie en m² del rodal en ese año

# Filtrado: eliminar NA en Height_cat y Sp_dens_m2, y comentarios de manejo
shp_filtrado <- shp %>%
  filter(!is.na(Height_cat),
         Height_cat != "",
         !grepl("^\\s*$", Height_cat), # no espacios en blanco
         Height_cat != "NA",
         !grepl("management", Comments, ignore.case = TRUE),
         !is.na(Sp_dens_m2),
         Sp_dens_m2 > 0)

table(shp_filtrado$Height_cat, useNA = "always") # chequeo para ver si quedan NA

# Convertir Height_cat a factor ordenado
shp_filtrado$Height_cat <- factor(shp_filtrado$Height_cat, 
                                  levels = c("1", "2", "3", "4"), 
                                  ordered = TRUE)

# Agrupar por rodal, Height_cat y año, y calcular superficie media
df_curve <- shp_filtrado %>%
  group_by(Height_cat, Year) %>%
  summarise(Sup_m2_mean = mean(Sp_dens_m2, na.rm = TRUE),
            n = n(), .groups = "drop")

# Visualizar la curva de crecimiento por Height_cat
ggplot(df_curve, aes(x = Year, y = Sup_m2_mean, colour = Height_cat)) +
  geom_line(size = 1) +
  geom_point(aes(size = n), alpha = 0.7) +
  labs(title = "Curvas de crecimiento en superficie por categoría de altura",
       x = "Año", y = "Superficie media (m²)",
       colour = "Categoría de altura", size = "n (rodales)") +
  theme_minimal()

###############################################################################
############### PROBANDO MODELOS DE CRECIMIENTO ###############################
###############################################################################

library(mgcv)
library(tidyr)

# Eliminar años con muy baja representación (menos de 5 rodales)
df_curve_clean <- df_curve %>%
  filter(n >= 5)

# Crear una tabla para almacenar resultados
resultados_modelos <- df_curve_clean %>%
  group_by(Height_cat) %>%
  do({
    datos = .
    
    # Modelo lineal sobre log
    modelo_lm <- lm(log(Sup_m2_mean) ~ Year, data = datos)
    r2_lm <- summary(modelo_lm)$adj.r.squared
    aic_lm <- AIC(modelo_lm)
    
    # Modelo GAM
    modelo_gam <- gam(Sup_m2_mean ~ s(Year, k = 5), data = datos)
    r2_gam <- summary(modelo_gam)$r.sq
    aic_gam <- AIC(modelo_gam)
    
    data.frame(
      Modelo = c("LM (log)", "GAM"),
      AIC = c(aic_lm, aic_gam),
      R2_adj = c(r2_lm, r2_gam)
    )
  }) %>%
  ungroup()

# Mostrar resultados
print(resultados_modelos)


# Crear predicciones para cada grupo y modelo
predicciones <- df_curve_clean %>%
  group_by(Height_cat) %>%
  do({
    data = .
    model_lm = lm(log(Sup_m2_mean) ~ Year, data = data)
    model_gam = gam(Sup_m2_mean ~ s(Year, k = 5), data = data)
    year_seq = seq(min(data$Year), max(data$Year), by = 1)
    data.frame(
      Year = rep(year_seq, 2),
      Sup_pred = c(exp(predict(model_lm, newdata = data.frame(Year = year_seq))),
                   predict(model_gam, newdata = data.frame(Year = year_seq))),
      Modelo = rep(c("LM (log)", "GAM"), each = length(year_seq)),
      Height_cat = unique(data$Height_cat)
    )
  })

# Visualización comparativa
ggplot(df_curve_clean, aes(x = Year, y = Sup_m2_mean)) +
  geom_point(aes(size = n), alpha = 0.6) +
  geom_line(data = predicciones, aes(x = Year, y = Sup_pred, colour = Modelo), linewidth = 1) +
  facet_wrap(~ Height_cat, scales = "free_y") +
  scale_y_continuous("Superficie media (m²)") +
  labs(title = "Modelos de crecimiento por categoría de altura",
       colour = "Modelo", size = "n rodales") +
  theme_minimal()


###############################################################################
########## Height_cat en dos niveles y sin outliers ###########################
###############################################################################

# Agrupar Height_cat en dos niveles: 'baja' (1,2) y 'alta' (3,4)
df_curve_clean <- df_curve_clean %>%
  filter(n >= 5) %>%
  mutate(H_cat_grp = case_when(
    Height_cat %in% c("1", "2") ~ "baja",
    Height_cat %in% c("3", "4") ~ "alta"
  ))

# Filtrar outliers extremos: valores fuera de 1.5*IQR por grupo
df_no_outliers <- df_curve_clean %>%
  group_by(H_cat_grp) %>%
  filter(Sup_m2_mean < quantile(Sup_m2_mean, 0.75) + 1.5 * IQR(Sup_m2_mean),
         Sup_m2_mean > quantile(Sup_m2_mean, 0.25) - 1.5 * IQR(Sup_m2_mean)) %>%
  ungroup()

# Ajuste de modelos por grupo simplificado
resultados <- df_no_outliers %>%
  group_by(H_cat_grp) %>%
  do({
    data = .
    
    # Modelo lineal log-transformado
    modelo_lm <- lm(log(Sup_m2_mean) ~ Year, data = data)
    r2_lm <- summary(modelo_lm)$adj.r.squared
    aic_lm <- AIC(modelo_lm)
    
    # Modelo GAM
    modelo_gam <- gam(Sup_m2_mean ~ s(Year, k = 5), data = data)
    r2_gam <- summary(modelo_gam)$r.sq
    aic_gam <- AIC(modelo_gam)
    
    data.frame(
      H_cat_grp = unique(data$H_cat_grp),
      Modelo = c("LM (log)", "GAM"),
      AIC = c(aic_lm, aic_gam),
      R2_adj = c(r2_lm, r2_gam)
    )
  })

print(resultados)

# Gráfico comparativo
# Curvas ajustadas
predicciones <- df_no_outliers %>%
  group_by(H_cat_grp) %>%
  do({
    data = .
    model_lm = lm(log(Sup_m2_mean) ~ Year, data = data)
    model_gam = gam(Sup_m2_mean ~ s(Year, k = 5), data = data)
    year_seq = seq(min(data$Year), max(data$Year), by = 1)
    data.frame(
      Year = rep(year_seq, 2),
      Sup_pred = c(exp(predict(model_lm, newdata = data.frame(Year = year_seq))),
                   predict(model_gam, newdata = data.frame(Year = year_seq))),
      Modelo = rep(c("LM (log)", "GAM"), each = length(year_seq)),
      H_cat_grp = unique(data$H_cat_grp)
    )
  })

# Visualización
ggplot(df_no_outliers, aes(x = Year, y = Sup_m2_mean)) +
  geom_point(aes(size = n), alpha = 0.6) +
  geom_line(data = predicciones, aes(x = Year, y = Sup_pred, colour = Modelo), linewidth = 1) +
  facet_wrap(~ H_cat_grp, scales = "free_y") +
  scale_y_continuous("Superficie media (m²)") +
  labs(title = "Modelos de crecimiento por grupo de altura (sin outliers)",
       colour = "Modelo", size = "n rodales") +
  theme_minimal()




