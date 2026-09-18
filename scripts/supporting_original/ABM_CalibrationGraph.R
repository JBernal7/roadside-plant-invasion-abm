# install.packages(c("readr","ggplot2"))
library(readr); library(ggplot2)

df <- read_csv("C:/Netlogo/calibracion_mediana_IQR.csv", show_col_types = FALSE)

ggplot(df, aes(x = year)) +
  geom_ribbon(aes(ymin = sim_p25, ymax = sim_p75), alpha = 0.2) +
  geom_line(aes(y = sim_median), linewidth = 1) +
  geom_point(aes(y = obs), shape = 21, fill = "white", stroke = 1.1, size = 2.8) +
  geom_line(aes(y = obs), linetype = "dashed") +
  labs(x = "Año", y = "Celdas ocupadas (10 m)",
       title = "Ailanthus – Observado vs Simulación (mediana e IQR, 20 réplicas)") +
  theme_minimal(base_size = 12)

p <- ggplot(df, aes(x = year)) +
  geom_ribbon(aes(ymin = sim_p25, ymax = sim_p75), alpha = 0.2) +
  geom_line(aes(y = sim_median), linewidth = 1) +
  geom_point(aes(y = obs), shape = 21, fill = "white", stroke = 1.1, size = 2.8) +
  geom_line(aes(y = obs), linetype = "dashed") +
  labs(x = "Año", y = "Celdas ocupadas (10 m)",
       title = "Ailanthus – Observado vs Simulación (mediana e IQR, 20 réplicas)") +
  theme_minimal(base_size = 12)


ggsave("C:/Netlogo/calibracion_mediana_IQR.png", p, width = 9, height = 5, dpi = 300)


