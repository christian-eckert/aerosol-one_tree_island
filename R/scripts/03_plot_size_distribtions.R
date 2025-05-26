################################################################
# Author: Christian Eckert
# Contact: c.eckert.10@student.scu.edu.au
# Project: One Tree Island aerosol analysis
# Description: Plot mSEMS data with error bars by location 
# Last Updated: 26-05-2025
################################################################

# Clear workspace
rm(list = ls())

# Load libraries
library(tidyverse)
library(lubridate)
library(stringr)
library(gridExtra)
library(here)

# Create output directory
output_dir <- here("R", "plots", "size_distributions")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Read data ----------------------------------------------------
listfiles <- list.files(
  path = here("data", "processed", "dndlogdp_corrected"),
  pattern = "\\.csv$",
  full.names = TRUE
)

# Read all CSV files
all_sd <- lapply(listfiles, read.csv, colClasses = c("Day_local" = "character")) %>%
  bind_rows() %>%
  mutate(
    Datetime = as.POSIXct(Datetime, format = "%Y-%m-%d %H:%M:%S"),
    Date = as.Date(Date),
    Time = format(as.POSIXct(Datetime), format = "%H:%M:%S")
  )

# List of unique flight days
vp_list <- unique(all_sd$Day_local)

# Axis limits
x_limits <- c(30, 300)
y_limits <- c(1, 1600)

# Plot colours
colors <- c("Scans" = "gray50", "Lagoon" = "turquoise3", "Surf Break" = "goldenrod2", "Open Water" = "royalblue4")

# Summarise function
summarise_location <- function(df) {
  df %>%
    group_by(Bin_num) %>%
    summarise(
      avg_dndlog = mean(dNdLogDP, na.rm = TRUE),
      sd = sd(dNdLogDP, na.rm = TRUE),
      avg_bin_mid = mean(Bin_Mid, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      sdL = avg_dndlog - sd,
      sdH = avg_dndlog + sd
    )
}

# Plot function
make_plot <- function(df_raw, df_avg, label) {
  df_raw <- df_raw %>%
    filter(Bin_Mid >= x_limits[1], Bin_Mid <= x_limits[2],
           dNdLogDP >= y_limits[1], dNdLogDP <= y_limits[2])
  
  df_avg <- df_avg %>%
    filter(avg_bin_mid >= x_limits[1], avg_bin_mid <= x_limits[2],
           avg_dndlog >= y_limits[1], avg_dndlog <= y_limits[2])
  
  ggplot() +
    geom_point(data = df_raw, aes(x = Bin_Mid, y = dNdLogDP, group = Time, color = "Scans"), size = 0.3, alpha = 0.4) +
    geom_line(data = df_avg, aes(x = avg_bin_mid, y = avg_dndlog, color = label), linewidth = 0.9) +
    geom_errorbar(data = df_avg, aes(x = avg_bin_mid, ymin = sdL, ymax = sdH, color = label), width = 0.02, alpha = 0.8) +
    scale_x_continuous(trans = "log10", limits = x_limits) +
    scale_y_continuous(limits = y_limits) +
    scale_color_manual(name = NULL, values = colors) +
    labs(
      x = "Particle diameter [nm]",
      y = "dN/dlogdp",
      title = label
    ) +
    theme_minimal(base_size = 10) +
    theme(
      legend.position = "none",
      axis.text = element_text(colour = "gray30"),
      axis.title = element_text(colour = "gray30")
    )
}

# Loop through each day and generate plots
for (day in vp_list) {
  cat("Plotting:", day, "\n")
  
  # Filter raw data
  l_sd <- filter(all_sd, Day_local == day, Location == "L", dNdLogDP >= 0.01)
  sb_sd <- filter(all_sd, Day_local == day, Location == "SB", dNdLogDP >= 0.01)
  ow_sd <- filter(all_sd, Day_local == day, Location == "OW", dNdLogDP >= 0.01)
  
  # Summarise
  l_sd_stats <- summarise_location(l_sd)
  sb_sd_stats <- summarise_location(sb_sd)
  ow_sd_stats <- summarise_location(ow_sd)
  
  # Generate plots
  p1 <- make_plot(l_sd, l_sd_stats, "Lagoon")
  p2 <- make_plot(sb_sd, sb_sd_stats, "Surf Break")
  p3 <- make_plot(ow_sd, ow_sd_stats, "Open Water")
  
  # Combine and save
  combined_plot <- grid.arrange(p1, p2, p3, ncol = 1)
  plot_file_svg <- file.path(output_dir, paste0("daily_plot_", day, ".svg"))
  
  suppressWarnings(
    ggsave(
      filename = plot_file_svg,
      plot = combined_plot,
      width = 8,
      height = 12
    )
  )
}
# End script