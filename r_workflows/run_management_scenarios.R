# ============================================================
# Management-scenario run for Ailanthus ABM using nlrx
# 10 scenarios x 50 seeds = 500 runs
# Outputs: ticks 27 (2035) and 37 (2045)
# ============================================================

library(nlrx)

# ------------------------------------------------------------
# 1. SETTINGS
# ------------------------------------------------------------

NETLOGO_PATH <- "C:/Program Files/NetLogo 6.4.0/"
MODEL_PATH <- "IASExpansion_ManagementModel.nlogo"
OUT_PATH <- "./management_final_50seeds"

NSEEDS <- 50
JVM_MEM <- 2048
NETLOGO_VERSION <- "6.4.0"
EXPNAME <- "management_final"

# Fixed R seed so that the same 50 NetLogo seeds can be regenerated
set.seed(20260928)


# ------------------------------------------------------------
# 2. CHECKS + JAVA / GIS
# ------------------------------------------------------------

if (!dir.exists(NETLOGO_PATH)) {
  stop("NETLOGO_PATH does not exist: ", NETLOGO_PATH)
}

if (!file.exists(MODEL_PATH)) {
  stop("MODEL_PATH does not exist: ", MODEL_PATH)
}

if (!dir.exists("abm_prep")) {
  stop("abm_prep directory not found.")
}

java_exe <- Sys.which("java")

if (java_exe == "") {
  stop("java.exe is not available on PATH.")
}

Sys.setenv(
  JAVA_HOME = dirname(dirname(java_exe))
)

BUNDLED_EXT <- file.path(
  NETLOGO_PATH,
  "extensions",
  ".bundled"
)

GIS_JAR <- file.path(
  BUNDLED_EXT,
  "gis",
  "gis.jar"
)

if (!file.exists(GIS_JAR)) {
  stop("NetLogo GIS extension not found: ", GIS_JAR)
}

EXT_DIR <- normalizePath(
  BUNDLED_EXT,
  winslash = "/",
  mustWork = TRUE
)

Sys.setenv(
  "_JAVA_OPTIONS" = paste0(
    '-Dnetlogo.extensions.dir="',
    EXT_DIR,
    '"'
  )
)

if (dir.exists(OUT_PATH) &&
    length(list.files(OUT_PATH, all.files = TRUE, no.. = TRUE)) > 0) {
  stop(
    "OUT_PATH is not empty. Rename or remove it before the final run: ",
    OUT_PATH
  )
}

dir.create(OUT_PATH, recursive = TRUE, showWarnings = FALSE)

old_asc <- list.files(
  dirname(MODEL_PATH),
  pattern = "^management_final_.*_tick(27|37)\\.asc$",
  full.names = TRUE
)

if (length(old_asc) > 0) {
  stop(
    "Existing management_final ASC files found beside the model. ",
    "Move or remove them before running."
  )
}

cat("\nWorking directory:\n")
print(getwd())

cat("\nJava:\n")
print(java_exe)

cat("\nNetLogo GIS extensions:\n")
print(EXT_DIR)


# ------------------------------------------------------------
# 3. SCENARIOS
# ------------------------------------------------------------

scenario_name <- c(
  "baseline",
  "low_100m",
  "low_200m",
  "low_400m",
  "intermediate_100m",
  "intermediate_200m",
  "intermediate_400m",
  "high_eradication_100m",
  "high_eradication_200m",
  "high_eradication_400m"
)

management_enabled <- c(
  "false",
  "true", "true", "true",
  "true", "true", "true",
  "true", "true", "true"
)

management_buffer <- c(
  100,
  100, 200, 400,
  100, 200, 400,
  100, 200, 400
)

management_type <- c(
  "\"none\"",
  "\"cut\"", "\"cut\"", "\"cut\"",
  "\"cut+revegetation\"", "\"cut+revegetation\"", "\"cut+revegetation\"",
  "\"eradication\"", "\"eradication\"", "\"eradication\""
)

management_frequency <- c(
  "\"once\"",
  "\"once\"", "\"once\"", "\"once\"",
  "\"annual\"", "\"annual\"", "\"annual\"",
  "\"once\"", "\"once\"", "\"once\""
)

management_start_tick <- rep(17, 10)

scenario_table <- data.frame(
  siminputrow = 1:10,
  scenario = scenario_name,
  management_enabled = management_enabled,
  buffer_m = management_buffer,
  management_type = gsub('"', '', management_type),
  frequency = gsub('"', '', management_frequency),
  start_tick = management_start_tick,
  stringsAsFactors = FALSE
)

write.csv(
  scenario_table,
  file.path(OUT_PATH, "management_scenario_matrix.csv"),
  row.names = FALSE
)


# ------------------------------------------------------------
# 4. nlrx EXPERIMENT
# ------------------------------------------------------------

nl <- nl(
  nlversion = NETLOGO_VERSION,
  nlpath = NETLOGO_PATH,
  modelpath = MODEL_PATH,
  jvmmem = JVM_MEM
)

nl@experiment <- experiment(
  expname = EXPNAME,
  outpath = OUT_PATH,
  repetition = 1,
  tickmetrics = "false",
  idsetup = "setup",
  idgo = "go",
  runtime = 37,
  
  metrics = c(
    "count turtles",
    "count patches with [occupied?]"
  ),
  
  variables = list(
    "management-enabled?" = list(values = management_enabled),
    "management-buffer-m" = list(values = management_buffer),
    "management-type" = list(values = management_type),
    "management-frequency" = list(values = management_frequency),
    "management-start-tick" = list(values = management_start_tick)
  ),
  
  idrunnum = "nlrx-run-id"
)

eval_variables_constants(nl)

nl@simdesign <- simdesign_distinct(
  nl = nl,
  nseeds = NSEEDS
)

print(nl)

seed_table <- data.frame(
  seed = nl@simdesign@simseeds
)

write.csv(
  seed_table,
  file.path(OUT_PATH, "simulation_seeds.csv"),
  row.names = FALSE
)

write.csv(
  as.data.frame(nl@simdesign@siminput),
  file.path(OUT_PATH, "nlrx_siminput_matrix.csv"),
  row.names = FALSE
)

writeLines(
  capture.output(sessionInfo()),
  file.path(OUT_PATH, "R_sessionInfo.txt")
)

metadata <- c(
  paste0("date=", Sys.time()),
  paste0("NetLogo=", NETLOGO_VERSION),
  paste0("nlrx=", packageVersion("nlrx")),
  paste0("Java=", java_exe),
  paste0("GIS_extensions=", EXT_DIR),
  paste0("model_MD5=", unname(tools::md5sum(MODEL_PATH))),
  paste0("scenarios=", length(scenario_name)),
  paste0("seeds_per_scenario=", NSEEDS),
  paste0("expected_runs=", length(scenario_name) * NSEEDS),
  paste0("expected_ASC=", length(scenario_name) * NSEEDS * 2)
)

writeLines(
  metadata,
  file.path(OUT_PATH, "run_metadata.txt")
)


# ------------------------------------------------------------
# 5. RUN
# ------------------------------------------------------------

cat("\nStarting final nlrx run: 10 scenarios x 50 seeds = 500 runs\n\n")

results <- run_nl_all(nl)

results_df <- as.data.frame(results)

saveRDS(
  results,
  file.path(OUT_PATH, "nlrx_results_50_seeds.rds")
)

write.csv(
  results_df,
  file.path(OUT_PATH, "nlrx_results_50_seeds.csv"),
  row.names = FALSE
)


# ------------------------------------------------------------
# 6. VALIDATE RUNS
# ------------------------------------------------------------

if (nrow(results_df) != 500) {
  stop(
    "Expected 500 nlrx result rows, found ",
    nrow(results_df),
    "."
  )
}

if (length(unique(results_df$`random-seed`)) != 50) {
  stop("Expected 50 unique random seeds.")
}

if (!setequal(unique(results_df$siminputrow), 1:10)) {
  stop("Expected siminputrow 1:10.")
}

run_counts <- table(
  results_df$siminputrow,
  results_df$`random-seed`
)

if (any(run_counts != 1)) {
  stop("Each scenario-seed combination should occur exactly once.")
}


# ------------------------------------------------------------
# 7. VALIDATE AND ORGANISE ASC OUTPUTS
# ------------------------------------------------------------

asc_files <- list.files(
  dirname(MODEL_PATH),
  pattern = "^management_final_.*_tick(27|37)\\.asc$",
  full.names = TRUE
)

if (length(asc_files) != 1000) {
  stop(
    "Expected 1000 ASC files, found ",
    length(asc_files),
    "."
  )
}

asc_names <- basename(asc_files)

asc_manifest <- data.frame(
  run_id = sub("_tick(27|37)\\.asc$", "", asc_names),
  tick = as.integer(
    sub(".*_tick(27|37)\\.asc$", "\\1", asc_names)
  ),
  filename = asc_names,
  stringsAsFactors = FALSE
)

asc_manifest$year <- ifelse(
  asc_manifest$tick == 27,
  2035,
  2045
)

if (!setequal(
  unique(asc_manifest$run_id),
  results_df$`nlrx-run-id`
)) {
  stop("ASC run IDs do not match the nlrx results.")
}

asc_per_run <- table(asc_manifest$run_id)

if (length(asc_per_run) != 500 || any(asc_per_run != 2)) {
  stop("Each NetLogo run should have exactly two ASC files.")
}

ticks_per_run <- split(
  asc_manifest$tick,
  asc_manifest$run_id
)

if (!all(vapply(
  ticks_per_run,
  function(x) identical(sort(x), c(27L, 37L)),
  logical(1)
))) {
  stop("Each run must contain exactly tick 27 and tick 37.")
}

run_info <- unique(
  results_df[
    ,
    c("nlrx-run-id", "random-seed", "siminputrow")
  ]
)

asc_manifest <- merge(
  asc_manifest,
  run_info,
  by.x = "run_id",
  by.y = "nlrx-run-id",
  all.x = TRUE
)

asc_manifest$scenario <- scenario_name[
  asc_manifest$siminputrow
]

asc_manifest <- asc_manifest[
  order(
    asc_manifest$siminputrow,
    asc_manifest$`random-seed`,
    asc_manifest$tick
  ),
]

ASC_OUT <- file.path(OUT_PATH, "asc")
dir.create(ASC_OUT, showWarnings = FALSE)

moved <- file.rename(
  asc_files,
  file.path(ASC_OUT, basename(asc_files))
)

if (!all(moved)) {
  stop("Some ASC files could not be moved to the final output folder.")
}

write.csv(
  asc_manifest,
  file.path(OUT_PATH, "ASC_manifest.csv"),
  row.names = FALSE
)

writeLines(
  c(
    "SUCCESS",
    "500 NetLogo runs validated",
    "1000 ASC files validated",
    "Ticks 27 and 37 present for every scenario-seed combination"
  ),
  file.path(OUT_PATH, "RUN_COMPLETE.txt")
)

cat("\nFinal run completed successfully.\n")
cat("500 NetLogo runs validated.\n")
cat("1000 ASC files validated.\n")
cat("Outputs: ", normalizePath(OUT_PATH, winslash = "/"), "\n", sep = "")
