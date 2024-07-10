library(lubridate)
library(magrittr)
library(raster)
library(ggplot2)
library(tidyverse)
library(reticulate)

#Your working directory should contain the file of reservoir coordinates (reservoir_coords.xlsx)
setwd("your_working_directory")

#Your python installation and python virtual environment, this code uses reticulate.
use_python("User/Documents/.virtualenvs/r-reticulate/Scripts/python.exe")
use_virtualenv("User/Documents/.virtualenvs/r-reticulate")

#Note that the following python libraries have to be installed in the python environment for the code to work:
  #oauthlib and requests-oauthlib
  #PIL
  #io
  #numpy
  #shapely
  #matplotlib
#They have to be usually installed separately with reticulate::py_install()

calculate_nominal_water_extent <- TRUE
build_ts <- TRUE
#Both should be true

cacheEnv <- new.env()
options("reticulate.engine.environment" = cacheEnv)

reservoir_data <- as.data.frame(readxl::read_excel("./reservoir_coords.xlsx")) %>%
  set_colnames(c("name", "coords", "coords1", "coords2", "notes")) %>%
  mutate(name = gsub(" \\(", "_", name)) %>%
  mutate(name = gsub("\\)", "", name)) %>%
  mutate(name = gsub(", ", "_", name)) %>%
  mutate(name = gsub("/", "_", name)) %>%
  mutate(name = gsub("-", "_", name)) %>%
  mutate(name = gsub(" ", "_", name)) %>%
  mutate(nominal_water_sum = 0) %>%
  mutate(water_pixel_sum = 0)

collect <- reservoir_data

collect <- separate_wider_delim(collect, cols = coords1 , delim = ", ", names = c("ycoord1", "xcoord1"))
collect <- separate_wider_delim(collect, cols = coords2 , delim = ", ", names = c("ycoord2", "xcoord2"))

collect <- collect %>%
  mutate(ycoord1 = as.numeric(ycoord1)) %>%
  mutate(ycoord2 = as.numeric(ycoord2)) %>%
  mutate(xcoord1 = as.numeric(xcoord1)) %>%
  mutate(xcoord2 = as.numeric(xcoord2)) %>%
  mutate(size = ycoord2 - ycoord1 + xcoord2 - xcoord1)

starttime <- Sys.time()

nominal_water_extent <- collect

for (k in 1:nrow(nominal_water_extent)) {
  
  rowK <- as.data.frame(nominal_water_extent[c(k),])
  
  coords <- c(c(rowK$xcoord1, rowK$ycoord1, rowK$xcoord2, rowK$ycoord2))
  
  assign("coords", coords, envir = cacheEnv)
  
  ## SOURCE PYTHON CODE WITH EVALSCRIPT AS INPUT ##

  if (calculate_nominal_water_extent){
    
    #The highest nominal water extent is likely to occurr in spring/early summer. 
    #For the sample years, reservoir levels were generally highest in 2020.
    dates <- c(as.Date("2020-10-01"), as.Date("2020-11-01"))
    
    assign("dates", dates, envir = cacheEnv)
    
    source_python(".satellite_reservoir.py", envir = cacheEnv)
    
    image_arr <- reticulate::py$image_arr
    
    mat_raw <- as.matrix(image_arr[,,2])
    mat <- as.matrix(image_arr[,,2])
    
    mat[mat != 0] <- 1
    rc <- clump(raster(mat), directions = 4)
    rcmat <- as.matrix(rc)
    clump_id <- names(sort(-table(c(rcmat[,1024], rcmat[1024,]))))[1]
    rcmat[rcmat != clump_id] <- NA
    rcmat[rcmat == clump_id] <- 1
    nominal_water <- which(rcmat == 1, arr.ind = TRUE)
    nominal_water_sum <- sum(mat_raw[nominal_water])
    water_pixel_sum <- sum(mat[nominal_water])
    
    if (FALSE){
      image(mat_raw,useRaster=TRUE)
      image(mat,useRaster=TRUE)
      image(rcmat,useRaster=TRUE)
    }
    
    nominal_water_extent$nominal_water_sum[k] <- nominal_water_sum
    nominal_water_extent$water_pixel_sum[k] <- water_pixel_sum
    
  }
  
  if (build_ts) {
    
    datevec <- seq(ymd('2020-01-01'),ymd('2023-12-31'), by = '1 month')
    datevec %<>% as.character()
    
    timeseries <- data.frame(end_month =datevec[-1], water_level_absolute = numeric(length(datevec[-1])), 
                             water_level_relative = numeric(length(datevec[-1])))
    
    for (i in 2:length(datevec)) { 
      
      dates <- c(datevec[i-1], datevec[i])
      assign("dates", dates, envir = cacheEnv)
      
      assign(paste("dates", as.character(i-1), sep = "_"), dates, envir = cacheEnv)
      
      source_python(".satellite_reservoir.py", envir = cacheEnv)
      
      array <- reticulate::py$image_arr
      matrix <- as.matrix(array[,,2])
      sum <- sum(matrix[nominal_water])

      #Save intermediary data to a temporary folder
      saveRDS(array, paste0("tempdata/satellite_waterlevel_array_", as.character(collect[k,1]), "_", as.character(datevec[i]), ".rds"))
      saveRDS(matrix, paste0("tempdata/satellite_waterlevel_matrix_", as.character(collect[k,1]), "_", as.character(datevec[i]), ".rds"))
      saveRDS(sum, paste0("tempdata/satellite_waterlevel_sum_", as.character(collect[k,1]), "_", as.character(datevec[i]), ".rds"))
      
      timeseries$water_level_absolute[i-1] <- sum
      timeseries$water_level_relative[i-1] <- sum/nominal_water_sum
      
      print(i/length(datevec))
      
    }
    
  }

  data.table::fwrite(timeseries, paste0("./timeseries_", as.character(collect[k,1]), ".csv))
  
}

endtime <- Sys.time()

print(endtime - starttime)

