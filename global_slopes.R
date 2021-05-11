



# Package and functions loading ----

# Packages needed
package_list <- c('raster', 'tidyverse', 'sp', 'geosphere', 'whitebox', 'rgdal', 
                  'sf', 'elevatr', 'geosphere', 'dismo', 'Rfast', 'foreach', 'parallel')

# Check if there are any packages missing
packages_missing <- setdiff(package_list, rownames(installed.packages()))

#If we find a package missing, install them
if(length(packages_missing) >= 1) install.packages(packages_missing) 

# Now load all the packages
lapply(package_list, require, character.only = TRUE)

# Whitebox may need need some manual installation of whitebox tools, see this for details: https://github.com/giswqs/whiteboxR


# source the file with the custom functions
source("0_functions.R")


# Prepare the file ----
# make a new dataset with the coordinates and a site label. As example 5 sites spread around the world
# careful, there should not be spaces in the name string as whitebox doesn't like it
coords <- data.frame(site_id= c("home_in_sweden", "my_home_village", "hubbard_brook", "mongolia", "angola"),
                 lon = c(20.459291, 0.915649, -71.736965, 99.307124, 20.816415),
                 lat = c(63.898876, 42.671793, 43.934452, 47.997440, -16.399621))
 

# Set parameters ----

## dist_to_upstream: the distance of your desired reach to get a reach slope, in meters, 
#   should be an order magnitude higher than the raster resolution for more accurate slope
dist_to_upstream = 500

## search_stream: How far you want the script to search for the closest stream to snap. 
#  make it small if you are certain your coordinates are close to the stream. It uses a jenson snapping 
#  so it will catch the closest stream regardless
search_stream = 1000

## min_catch_area: minimum catchment area to generate a stream in the DEM. It varies due to climate, runoff, season, geology...
#  this is mostly important if the your coordinates of interest are not close to the stream, otherwise it will snap to a not-real 
#  stream if the value is too low
min_catch_area = 5000

## dem_zoom_level = variable that controls the resolution of the DEM. 1 is lower resolution, 14 highest. 
#  It may need some tuning depending on the region, as not all the globe has high high res DEM. check ?get_elev_raster
dem_zoom_level = 13

keep_gis_files = FALSE

#Create some folders
dir.create("file_outputs")
dir.create("plots_outputs")

# Run on a normal loop ----
# It needs to be done one by one, if not elevatr tries to download a DEM covering all sites
#initialise an empty df
dat <- NULL

# for loop
for(i in seq_along(coords$site_id)) {
  
 a <-  snap_site_and_upstream(coords[i,],
                         max_dist =dist_to_upstream, 
                         snap_dist= search_stream,
                         init_threshold = min_catch_area,
                         zoom_level= dem_zoom_level,
                         keep_files = keep_gis_files)
  
dat <- bind_rows(dat, a)
}
# The output contains multiple variables, not only slope.
# site_id = id of the site
# lat_new = latitude of the snapped site
# lon_new = longitude of the snapped site
# lat_up = latitude of site upstream
# lon_up =  longitude of site upstream
# dist_total = total reach distance, in meters,
# dist_linear = linear distance, in meters
# z_up = elevation site upstream,
# z = elevation snapped site
# z_old= elevation original site
# slope = slope, in m/m
# flow_acc = flow accumulation, in # of cells
# flow_acc_old = flow accumulation of the original site
# resolution = resolution of the DEM, in meters
# 
# The linear distance is a useful QAQC variable, as if it is very small it often indicates there was either
# a problem or that the site is in a meander



# Run in parallel in case there are many sites ----
# In my project we have several thousand sites and it took few days to run, parallelising was worth it!
#### Run in parallel with multiple cores. Following structure by Blas Benito post:
####  https://blasbenito.com/post/02_parallelizing_loops_with_r/



#set number of cores to use
n.cores <- parallel::detectCores() - 1

#create the cluster
my.cluster <- parallel::makeCluster(
  n.cores, 
  type = "PSOCK"
)

#check cluster definition (optional)
print(my.cluster)

#register it to be used by %dopar%
doParallel::registerDoParallel(cl = my.cluster)

#check if it is registered (optional)
foreach::getDoParRegistered()

#list of packages to pass to the parallel loop, I remove the packages that will not need for processing (read files and parallel computing)
package_list_par <- package_list[!package_list %in% 
                                   grep(paste0(c( "foreach", "parallel"), collapse = "|"), 
                                        package_list, value = T)]


#loop is here, check the blog for details
dat_out8 <- foreach(
  i = nrow(coords), 
  .combine = 'rbind',
  .packages= package_list_par 
) %dopar% {
  a <-  snap_site_and_upstream(coords[i,],
                               max_dist =dist_to_upstream, 
                               snap_dist= search_stream,
                               init_threshold = min_catch_area)
  
bind_rows(a)

}


#stop the cluster after running
parallel::stopCluster(cl = my.cluster)





