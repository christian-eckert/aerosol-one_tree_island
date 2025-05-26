################################################################
# Author: Christian Eckert
# Contact: c.eckert.10@student.scu.edu.au
# Project: One Tree Island aerosol analysis
# Description: Clean data collected by Miniaturized Scanning Electrical Mobility Sizer (mSEMS).
# Last Updated: 26-05-2025
################################################################

# ── Setup ─────────────────────────────────────────────────────

rm(list = ls())  # Clear environment

# Load libraries
library(tidyverse)
library(lubridate)
library(stringr)
library(data.table)
library(here)
library(tools)

# ── Define paths ──────────────────────────────────────────────

input_dir <- here("data", "raw", "msems")
output_dir <- here("data", "processed", "clean_msems")

# Create output directory if it doesn't exist
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

# ── List input files ──────────────────────────────────────────

file_list <- list.files(
  path = input_dir,
  pattern = "*_INVERTED.txt",
  full.names = TRUE
)

# ── Cleaning loop ─────────────────────────────────────────────

for (file in file_list) {
  
  # Read tab-delimited raw file, skipping header
  raw_data <- read.delim(file, sep = "\t", skip = 55)
  
  # Extract metadata from filename
  flight_date <- sub(".*_(\\d{6}[A-Z]?)_.*", "\\1", basename(file))
  location <- sub(".*_(L|SB|OW)_.*", "\\1", basename(file))
  filename_base <- gsub("(mSEMS_|_HOVER_|_INVERTED|INVERTED)", "", tools::file_path_sans_ext(basename(file)))
  
  # Bin diameters (Bin_DiaXX)
  bin_dia <- raw_data %>%
    pivot_longer(cols = starts_with("Bin_Dia"), names_to = "Bin", values_to = "Dia") %>%
    mutate(Bin = as.numeric(str_remove(Bin, "Bin_Dia")))
  
  # Bin concentrations (Bin_ConcXX)
  bin_conc <- raw_data %>%
    pivot_longer(cols = starts_with("Bin_Conc"), names_to = "Conc_Bin", values_to = "Conc") %>%
    rename(Date = X.Date) %>%
    mutate(Date = paste0("20", Date))  # Add century prefix
  
  # Prepare final dataframe
  cleaned_data <- bin_conc %>%
    select("Date", "Time", "Temp.C.", "Press.hPa.", "Conc") %>%
    mutate(
      Datetime = as.POSIXct(paste(Date, Time), format = "%Y/%m/%d %H:%M:%S", tz = "UTC"),
      Date = as.Date(Date, "%Y/%m/%d"),
      Time = format(Datetime, "%H:%M:%S"),
      Datetime_aest = with_tz(Datetime, tzone = "Australia/Brisbane"),
      Day_local = format(Datetime_aest, "%Y%m%d"),
      Time_local = format(Datetime_aest, "%H:%M:%S")
    ) %>%
    mutate(
      Bin = bin_dia$Dia,
      Bin_num = bin_dia$Bin,
      Day_local = flight_date,
      Location = location,
      Filename = gsub("(L_|OW_|SB_)", "", filename_base)
    ) %>%
    select(
      Datetime, Day_local, Time_local, Filename, Temp.C., Press.hPa.,
      Bin, Bin_num, Conc, Location, Date, Time
    ) %>%
    rename(Dia = Bin, dNdLogDP = Conc)
  
  # Write cleaned CSV
  write.csv(
    cleaned_data,
    file = file.path(output_dir, paste0("clean_", filename_base, ".csv")),
    row.names = FALSE
  )
  
  # Remove temporary objects
  rm(raw_data, bin_dia, bin_conc, cleaned_data)
}

# End script