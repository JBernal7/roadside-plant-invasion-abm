library(readr)
library(ggplot2)
library(dplyr)

df <- read_csv("C:/Netlogo/Calibration_20260206_Test3A/verif_series_3A_best_seed12345_PATCHOBS.csv", )

# ABSOLUTO 
ggplot(df, aes(x=year)) +
  geom_ribbon(aes(ymin=sim_p25, ymax=sim_p75), alpha=0.2) +
  geom_line(aes(y=sim_median, linetype="Sim median")) +
  geom_line(aes(y=obs, linetype="Observed")) +
  scale_linetype_manual(values=c("solid","dashed"), name=NULL) +
  labs(x="Year", y="Occupied cells (exported units)", title="Observed vs simulated (as exported)") +
  theme_bw()


# DELTA (respecto a 2008)
df2 <- df %>%
  mutate(obs_d = obs - first(obs),
         sim_d = sim_median - first(sim_median),
         p25_d = sim_p25 - first(sim_p25),
         p75_d = sim_p75 - first(sim_p75))

ggplot(df2, aes(x=year)) +
  geom_ribbon(aes(ymin=p25_d, ymax=p75_d), alpha=0.2) +
  geom_line(aes(y=sim_d, linetype="Sim Δ median")) +
  geom_line(aes(y=obs_d, linetype="Obs Δ")) +
  labs(x="Year", y="Δ occupied cells (baseline 2008)", title="Observed vs simulated Δ") +
  theme_bw()

