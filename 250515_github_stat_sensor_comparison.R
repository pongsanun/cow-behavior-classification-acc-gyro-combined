## Set Working Directory
setwd("C:")
install.packages("FSA")

library(dplyr)
library(data.table)
library(readxl)
library(openxlsx)
library(multcompView)   # For Tukey letters
library(ggplot2)
library(FSA)            # For Dunn test
library(rcompanion)     # For compact letter display

# Import Data
data <- read_excel("Final_data.xlsx")

# Filter relevant behaviors
data_prep <- data[data$Classification %in% c("lying", "standing", "eating", "walking"), ]

# List of variables
var_list <- c("accX", "accY", "accZ", "gyroX", "gyroY", "gyroZ", "SVM_acc", "SVM_gyro")
skewed_vars <- c("SVM_acc", "SVM_gyro")

# Descriptive Statistics
summary_func_by_sensor <- function(df, var) {
  df %>%
    group_by(Sensor, Classification) %>%
    summarise(
      n = n(),
      mean = round(mean(.data[[var]], na.rm = TRUE), 3),
      sd = round(sd(.data[[var]], na.rm = TRUE), 3),
      median = round(median(.data[[var]], na.rm = TRUE), 3),
      p25 = round(quantile(.data[[var]], 0.25, na.rm = TRUE), 3),
      p75 = round(quantile(.data[[var]], 0.75, na.rm = TRUE), 3),
      min = round(min(.data[[var]], na.rm = TRUE), 3),
      max = round(max(.data[[var]], na.rm = TRUE), 3),
      .groups = "drop"
    ) %>%
    mutate(Parameter = var,
           mean_sd = paste0(mean, "+-", sd))
}

sensor_summary_results <- lapply(var_list, function(x) summary_func_by_sensor(data_prep, x))
sensor_summary_all <- bind_rows(sensor_summary_results)

# Statistical Comparison
stat_comparison_results <- list()

for (var in var_list) {
  for (sensor in unique(data_prep$Sensor)) {
    df_sub <- data_prep %>% filter(Sensor == sensor)
    
    if (length(unique(df_sub$Classification)) > 1) {
      formula <- as.formula(paste(var, "~ Classification"))
      
      if (var %in% skewed_vars) {
        # Non-parametric test: Kruskal-Wallis + Dunn
        kw <- kruskal.test(formula, data = df_sub)
        if (kw$p.value < 0.05) {
          dunn <- dunnTest(formula, data = df_sub, method = "bonferroni")
          dunn_df <- dunn$res
          compact <- cldList(P.adj ~ Comparison, data = dunn_df, threshold = 0.05)
          result <- data.frame(
            Sensor = sensor,
            Classification = compact$Group,
            Letter = compact$Letter,
            Parameter = var
          )
          stat_comparison_results[[paste(sensor, var, sep = "_")]] <- result
        }
      } else {
        # Parametric test: ANOVA + TukeyHSD
        aov_res <- aov(formula, data = df_sub)
        tukey <- TukeyHSD(aov_res)
        letters <- multcompView::multcompLetters(tukey[[1]][, "p adj"])$Letters
        result <- data.frame(
          Sensor = sensor,
          Classification = names(letters),
          Letter = letters,
          Parameter = var
        )
        stat_comparison_results[[paste(sensor, var, sep = "_")]] <- result
      }
    }
  }
}

# Combine all results
letter_results_all <- bind_rows(stat_comparison_results)

# Merge Summary + Letters
final_summary <- sensor_summary_all %>%
  left_join(letter_results_all, by = c("Sensor", "Classification", "Parameter"))
head(final_summary)
