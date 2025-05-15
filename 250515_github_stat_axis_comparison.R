## Set Working Directory
setwd("C:/Users")

# Load Libraries
library(dplyr)
library(data.table)
library(readxl)
library(openxlsx)
library(multcompView)
library(ggplot2)

# Install if needed
if (!require("FSA")) install.packages("FSA")
if (!require("rcompanion")) install.packages("rcompanion")
library(FSA)
library(rcompanion)

# Load and Prepare Data
data <- read_excel("Final_data.xlsx")
data_prep <- data %>% filter(Classification %in% c("lying", "standing", "eating", "walking"))

# Axis-wise Comparison per Cow per Behavior
axis_stat_results <- list()
axis_groups <- list(
  acc = c("accX", "accY", "accZ"),
  gyro = c("gyroX", "gyroY", "gyroZ")
)

for (behavior in unique(data_prep$Classification)) {
  for (sensor_type in names(axis_groups)) {
    axis_vars <- axis_groups[[sensor_type]]
    
    for (cow in unique(data_prep$ID)) {
      df_cow <- data_prep %>% filter(Classification == behavior, ID == cow)
      
      if (nrow(df_cow) > 3) {
        df_long <- df_cow %>%
          select(all_of(axis_vars)) %>%
          pivot_longer(cols = everything(), names_to = "Axis", values_to = "Value") %>%
          mutate(Axis = factor(Axis))
        
        if (length(unique(df_long$Axis)) > 1) {
          aov_res <- aov(Value ~ Axis, data = df_long)
          tukey <- TukeyHSD(aov_res)
          letters <- toupper(multcompLetters(tukey[[1]][, "p adj"])$Letters)
          
          result <- data.frame(
            Axis = names(letters),
            Letter = letters,
            ID = cow,
            Classification = behavior,
            ParameterGroup = sensor_type
          )
          axis_stat_results[[paste(behavior, cow, sensor_type, sep = "_")]] <- result
        }
      }
    }
  }
}

axis_letters_df <- bind_rows(axis_stat_results)