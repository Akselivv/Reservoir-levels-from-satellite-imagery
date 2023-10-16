setwd("//home.org.aalto.fi/valivia1/data/Documents/GitHub/Satelliittiprojekti")

options(scipen=999)

library(lubridate)
library(magrittr)
library(raster)
library(ggplot2)
library(tidyverse)

dark_green <- "#234721"
light_green <- "#AED136"
dark_blue <- "#393594"
light_blue <- "#8482BD"
dark_red <- "#721D41"
light_red <- "#CC8EA0"
yellow <- "#FBE802"
orange <- "#F16C13"
light_orange <- "#FFF1E0"

colors <- c(dark_green, light_green, dark_blue, light_blue, dark_red, light_red, yellow, orange, light_orange)

calculate_nominal_water_extent <- FALSE
save <- FALSE
read <- TRUE

#load("Lauvastol_data/nominal_water.Rdata")
#nominal_water_sum <- readRDS("Lauvastol_data/nominal_water_sum.rds")

#coords <- c(6.6819011, 59.49226283, 6.717937099999999, 59.50659287)
coords <- c(7.015902, 59.287278, 6.725416, 59.441193)

cacheEnv <- new.env()
options("reticulate.engine.environment" = cacheEnv)

assign("coords", coords, envir = cacheEnv)

if (calculate_nominal_water_extent){
  
  library(raster)
  
  dates <- c(as.Date("2023-08-01"), as.Date("2023-09-01"))
  
  assign("dates", dates, envir = cacheEnv)
  
  reticulate::source_python("satelliitti_patoaltaat.py", envir = cacheEnv)
  
  #data <- reticulate::py$sh_statistics[1]
  
  data <- reticulate::py$response
  array <- reticulate::py$image_arr
  
  mat <- as.matrix(array[,,2])
  mat1 <- as.matrix(array[,,2])
  mat1[mat1 != 0] <- 1
  
  r <- raster(mat)
  rc <- clump(r, directions = 4)
  rcmat <- as.matrix(rc)
  rcmat[,1024]
  clump_id <- names(sort(-table(c(rcmat[,1024], rcmat[1024,]))))[1]
  
  
  rcmat[rcmat != clump_id] <- NA
  rcmat[rcmat == clump_id] <- 1
  
  image(mat1,useRaster=TRUE)
  image(rcmat,useRaster=TRUE)
  
  nominal_water <- which(rcmat == 1, arr.ind = TRUE)
  
  class(nominal_water)
  
  sum <- sum(mat[nominal_water])
  
}

if (save) {
  
  save(nominal_water, file = "nominal_water.Rdata")
  saveRDS(sum, "nominal_water_sum.rds")
  
}

## SOURCE PYTHON CODE WITH EVALSCRIPT AS INPUT ##

if (load) {
  
  load("nominal_water.Rdata")
  nominal_water_sum <- readRDS("nominal_water_sum.rds")
  
}

datevec <- seq(ymd('2019-01-01'),ymd('2023-09-01'), by = '2 weeks')
datevec <- c(datevec, ymd("2023-09-29"))
datevec %<>% as.character()

timeseries <- data.frame(end_month =datevec[-1], water_level_absolute = numeric(length(datevec[-1])), 
                         water_level_relative = numeric(length(datevec[-1])))

for (i in 2:length(datevec)) { 
  
  dates <- c(datevec[i-1], datevec[i])
  
  assign(paste("dates", as.character(i-1), sep = "_"), dates, envir = cacheEnv)
  
  reticulate::source_python("satelliitti_patoaltaat.py", envir = cacheEnv)
  
  array <- reticulate::py$image_arr
  matrix <- as.matrix(array[,,2])
  sum <- sum(matrix[nominal_water])
  
  assign(paste("array", as.character(i-1), sep = "_"), array)
  assign(paste("matrix", as.character(i-1), sep = "_"), matrix)
  assign(paste("sum", as.character(i-1), sep = "_"), sum)
  
  timeseries$water_level_absolute[i-1] <- sum
  timeseries$water_level_relative[i-1] <- sum/nominal_water_sum
  
  print(i/length(datevec))

}

print(timeseries)

timeseries$end_month[nrow(timeseries)] <- "2023-10-01"

plot(x = lubridate::ymd(timeseries$end_month), y = timeseries$water_level_relative, type = "l")

timeseries %>%
  ggplot(aes(x = lubridate::ymd(end_month), y = water_level_relative)) + 
  geom_line(aes(), color = "red" , lwd = 1.2) + 
  theme_minimal() + 
  ggtitle("Veden määrä kuukausittain. Normalisoitu vuoden 2023 elokuun suhteen.") + 
  xlab("kuukausi") + 
  ylab("veden määrä, normalisoitu")

timeseries %>%
  mutate(vuosi = substr(as.character(end_month), 1, 4)) %>%
  mutate(kuukausi = substr(as.character(end_month), 6, 7)) %>%
  ggplot(aes(x = as.character(kuukausi), y = water_level_relative, group = vuosi), color = colors) +
  geom_line(aes(color = vuosi), lwd = 1.2) + 
  theme_minimal() + 
  ggtitle("Veden määrä kuukausittain. Normalisoitu vuoden 2023 elokuun suhteen.") + 
  xlab("kuukausi") + 
  ylab("veden määrä, normalisoitu")

write.csv(timeseries, "satelliitti_vesimäärä.csv", row.names = FALSE)
