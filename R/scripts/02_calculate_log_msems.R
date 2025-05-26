################################################################
# Author: Christian Eckert
# Contact: c.eckert.10@student.scu.edu.au
# Project: One Tree Island aerosol analysis
# Description: Calculate dN/dlogDp and total concentration out of inverted mSEMS data
# Last Updated: 26-05-2025
################################################################

# ── Setup ─────────────────────────────────────────────────────

rm(list = ls())  # Clear environment

# Load libraries
library(tidyverse)
library(lubridate)
library(stringr)
library(here)

# ── Define paths ──────────────────────────────────────────────

input_dir <- here("data", "processed", "clean_msems")
output_dir_conc <- here("data", "processed", "dndlogdp_corrected")
output_dir_mean <- here("data", "processed", "mean_sd_corrected")
loss_file <- here("data", "raw", "transportloss", "transportloss.csv")

# Create output directories if they don't exist
dir.create(output_dir_conc, recursive = TRUE, showWarnings = FALSE)
dir.create(output_dir_mean, recursive = TRUE, showWarnings = FALSE)

# ── Load transport loss data ─────────────────────────────────

loss <- read_csv(loss_file, show_col_types = FALSE)

# ── List input files ─────────────────────────────────────────

file_list <- list.files(
  path = input_dir,
  pattern = "*.csv",
  full.names = TRUE
)

# ── Processing loop ──────────────────────────────────────────

for (file in file_list) {
  
  # Load cleaned data
  data <- read_csv(file, show_col_types = FALSE) %>% 
    filter(dNdLogDP >= 0.01) %>%  
    mutate(Dia = Dia * 0.9) %>%
    left_join(loss, by = c("Bin_num" = "Bin")) %>%
    mutate(
      Loss = ifelse(is.na(Loss), 0, Loss),
      dNdLogDP = dNdLogDP * (1 + Loss / 100)
    ) %>%
    select(-Loss)
  
  # Calculate bin edges and derived metrics
  data <- data %>% 
    group_by(Time) %>% 
    mutate(
      Bin_L = sqrt(lag(Dia) * Dia),
      Bin_U = sqrt(lead(Dia) * Dia),
      Bin_L_first = Dia^2 / lead(Bin_L),
      Bin_U_last = Dia^2 / lag(Bin_U),
      Bin_L = ifelse(is.na(Bin_L), Bin_L_first, Bin_L),
      Bin_U = ifelse(is.na(Bin_U), Bin_U_last, Bin_U),
      logbinsize = log(Bin_U) - log(Bin_L)
    ) %>% 
    select(-Bin_L_first, -Bin_U_last) %>%
    rename(Bin_Mid = Dia) %>%
    mutate(
      total_conc = sum(logbinsize * dNdLogDP),
      total_area = 1e-6 * sum(logbinsize * dNdLogDP * pi * Bin_Mid^2),
      total_volume = 1e-9 * sum(logbinsize * dNdLogDP * pi * (Bin_Mid^3) / 6)
    ) %>%
    ungroup() %>%
    select(
      Datetime, Day_local, Time_local, Filename, Bin_num, Temp.C., Press.hPa.,
      Bin_Mid, dNdLogDP, logbinsize, total_conc, total_area, total_volume,
      Bin_L, Bin_U, Location, Date, Time
    )
  
  # Write concentration-corrected file
  write_csv(
    data,
    file = file.path(output_dir_conc, paste0("dNdLogDP_", basename(file)))
  )
  
  # ── Calculate mean & SD by bin ─────────────────────────────
  
  summary_stats <- data %>% 
    group_by(Bin_num) %>%
    summarise(
      avg_dNdLogDP = mean(dNdLogDP, na.rm = TRUE),
      sd = sd(dNdLogDP, na.rm = TRUE),
      avg_bin_mid = mean(Bin_Mid, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      sdL = avg_dNdLogDP - sd,
      sdH = avg_dNdLogDP + sd
    )
  
  # Write summary file
  write_csv(
    summary_stats,
    file = file.path(output_dir_mean, paste0("mean_dNdLogDP_corrected_", basename(file)))
  )
}
# End script