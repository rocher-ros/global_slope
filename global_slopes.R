#####
##### R script to calculate river slope of a global dataset. Written by G Rocher-Ros. 2018

# Needed packages:
library(ggplot2)
library(elevatr)
library(sp)
library(geosphere)
library(raster)
library(dplyr)
library(readr)
library(rgdal)
library(extrafont)
library(rworldmap)

# First we read the file with coordinates in WGS84 and make a new column for the slopes
dataset<- read_csv("dataset_coords.csv") %>% mutate(slope=NA)


## we set a range to 500 m, to calculate the slope as the difference in elevation between two points of the river channel
range <- 500

#We set the projection to WGS84
prj_dd <- "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs"


#This loop will for each site:
#1. Obtain the coordinates
#2. Retrieve the coordinates of the points located at a defined range around the site
#3. Download a raster of DEM of that area
#4. Extract the elevation of the site and the points around the site.
#5. Find the minimum elevation within the circle, that corresponds to the downstream of the site.
#   Ideally, I would prefer the upstream, but that would require a complex algorithim to determine.
#6. Calculate the slope between the site and the downstream site

for(i in 1:nrow(dataset)){

#Obtain the coordinates
coords_site <-  data.frame(x=dataset$Longitude[i], y=dataset$Latitude[i])

#Retrieve the coordinates of the points located a defined range around the site
coords_corners <- destPoint(coords_site[1,], seq(0, 350, by=10), range)

coords_site <- coords_site %>% add_row( x=coords_corners[,1], y=coords_corners[,2])

#Download a raster of DEM of that area
dem_point <- get_elev_raster(coords_site, prj = prj_dd,z = 12, src = "aws")

coords_site <-   tibble::add_column(coords_site, z=extract(dem_point, coords_site) )

# Calculate the slope between the site and the downstream site
chem_geo$slope[i] <- abs(min(coords_site$z[-1])-coords_site$z[1])/range

print(paste("we've done", i, "slope is", round(dataset$slope[i],5)))
}

# a simple way to visualize it
plot(dem_point)
lines(coords_site, type="p", pch=19, cex=.6)
lines(coords_site[13,], type="p", pch=19, cex=.6, col="red")
