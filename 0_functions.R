 
#Define functions----

## function to obtain the UTM zone based on a set of WGS84 coordinates ----
# credit: https://stackoverflow.com/questions/9186496/determining-utm-zone-to-convert-from-longitude-latitude/9188972#9188972
wgs84_to_UTM = function(lonlat) {
  utm = (floor((lonlat[1] + 180) / 6) %% 60) + 1
  if(lonlat[2] > 0) {
    utm + 32600
  } else{
    utm + 32700
  }
}

## function to transform coordinates to UTM for a custom zone ----
site_as_UTM = function(site){
  
  #Find the right UTM zone and change the projection of the coordinates
  utm_site = wgs84_to_UTM( c(site$lon[1], site$lat[1]))
  
  utm_string <- st_crs(utm_site)$proj4string
  
  
  coordinates(site) <- ~lon  + lat
  proj4string(site) <- CRS("+proj=longlat +datum=WGS84 +ellps=WGS84")
  
  # transform
  site_utm <- spTransform(site, utm_string)
  
  site_utm
}


## Main function to snp site to a stream channel and find slope upstream ----
snap_site_and_upstream = function(coords_site, max_dist, snap_dist, init_threshold, zoom_level, keep_files){
  
  
  #get a site label
  site_id <- coords_site$site_id
  
  #extract the first site, 
  site <- coords_site
  
  #function to get the site as a spatial object in local UTM
  site_utm <- site_as_UTM(site)
  
  #download the DEM at the highest resolution. In some areas this should be changed to lower values
  dem_site <- get_elev_raster(site_utm, z = zoom_level)
  
  #crop the DEM for faster raster processing
  pol <- polygons(circles(site_utm, dist_to_upstream*5, lonlat=FALSE, dissolve=FALSE))
  dem_site <- crop(dem_site, pol)
  
  #export raster as tif  
  writeRaster(dem_site, filename= paste0('file_outputs/',site_id,'_dem.tif'), overwrite=T)
  
  # print(paste("dem downloaded", i))  
  
  
  ##Breach filling
  dem_white <- paste0('file_outputs/',site_id,'_dem.tif')
  
  #Fill single cell pits (for hydrologic correctness)
  breach2 <-  paste0('file_outputs/',site_id,'_breach2.tif') 
  
  wbt_fill_single_cell_pits(dem_white, breach2)
  
  #Breach depressions (better option that pit filling according to whitebox docu
  #mentation) The flat_increment may needed to be tuned.
  breached <- paste0('file_outputs/',site_id,'_breached.tif')  
  
  wbt_breach_depressions(breach2, breached)
  
  #read the corrected dem for extraction later
  dem_corrected <- raster(breached)
  
  #D8 pointer flowdir
  d8_pntr <- paste0('file_outputs/',site_id,'_d8_pntr.tif') 
  
  wbt_d8_pointer(breached, d8_pntr)
  
  #D8 flow
  d8_flow <- paste0('file_outputs/',site_id,'_d8_flow.tif') 
  
  wbt_d8_flow_accumulation(breached, d8_flow, out_type='cells')
  
  #extract streams
  streams <- paste0('file_outputs/',site_id,'_streams.tif')  
  wbt_extract_streams( d8_flow, streams, threshold =init_threshold)
  
  
  site.init <- paste0('file_outputs/',site_id,'_site.shp') 
  
  site_utm %>% st_as_sf() %>% 
    st_write(site.init, delete_layer=T) 
  
  site.snap <- paste0('file_outputs/',site_id,'_site_snap.shp') 
  
  wbt_jenson_snap_pour_points( site.init, streams, site.snap, snap_dist = snap_dist )
  
  #read in the snapped point as utm coordinates for calcs
  new_site <- read_sf(site.snap) %>% 
    st_coordinates() %>% 
    as.data.frame()
  
  colnames(new_site) <- c("x","y")
  

 ##### find site upstream
  
  #first crop the raster for efficiency
  zoomed_site <- raster(d8_flow) %>% 
    crop(polygons(circles(site_utm, max_dist+200, lonlat=FALSE, dissolve=FALSE)))
  
 # initialise variables 
  site_origin <- new_site
  dist_total = 0
  dist_points = 0
  
 # a while loop to go upstream until we reach the reach length specified
  while(dist_total < max_dist){
    
    #find neighbour cells
    neighbours <- adjacent(zoomed_site, raster::extract(zoomed_site, site_origin, cellnumbers=TRUE)[1] ,  directions= 8)
    
    #extract the flow accumulation of the neighbours
    flow_neighbours <- raster::extract(zoomed_site, neighbours[,2])
    
    #move to the neighbour with the second highest flow accumulation (the highest is downstream)
    site_dest <- neighbours[Rfast::nth(flow_neighbours, 2, descending = T, index.return = T), 2]
    
    #get the coordinates
    site_dest_utm <- as.data.frame(xyFromCell(zoomed_site, site_dest))
    
    #calculate the distance
    dist_points <- dist(rbind(site_origin, site_dest_utm))
    
    #and a linear distance
    dist_linear <- dist(rbind(new_site, site_dest_utm))
    
    #do the total distance accumulated
    dist_total <- dist_total + dist_points
    
    # reset and repeat
    site_origin <- site_dest_utm
    
  }
  
  
#transform sites coordinates form utm to wgs84
  coordinates(site_dest_utm) <- ~x  + y
  proj4string(site_dest_utm) <- CRS(st_crs(site_utm)$proj4string)  
  up_site_wgs84 <-  spTransform(site_dest_utm, CRS("+proj=longlat +datum=WGS84 +ellps=WGS84")) 
  
  coordinates(new_site) <- ~x  + y
  proj4string(new_site) <- CRS(st_crs(site_utm)$proj4string)
  site_new_wgs84 <-  spTransform(new_site, CRS("+proj=longlat +datum=WGS84 +ellps=WGS84")) 
  
  #extract elevation at site, upstream, and flow accumulation
  z_up <- raster::extract(dem_corrected, site_dest_utm)
  z_old <- raster::extract(dem_corrected, site_utm)
  flow_acc_old <- raster::extract(zoomed_site, site_utm)
  z <- raster::extract(dem_corrected, new_site)
  flow_acc <- raster::extract(zoomed_site, new_site)
  
  #export a plot for QA
  png(paste0('plots_outputs/',site_id,'.png'))
  plot(zoomed_site)
  lines(coordinates(new_site), type="p", pch=19, cex=2)
  lines(coordinates(site_utm), type="p", pch=19, cex=2, col="grey")
  lines(coordinates(site_dest_utm), type="p", pch=19, cex=2, col="red")
  title( sub = "original site in grey, snapped site in black, site upstream in red")
  dev.off()

  # Conditional to delete all the work layers or not 
  if(keep_files == FALSE){
    file.remove(paste0( 'file_outputs/', list.files('file_outputs', pattern=site_id)))
  }

  #list for output
  function_out <- list(site_id = coords_site$site_id,
                       lat_new = site_new_wgs84@coords[2],
                       lon_new = site_new_wgs84@coords[1],
                       lat_up = up_site_wgs84@coords[2],
                       lon_up = up_site_wgs84@coords[1],
                       dist_total = dist_total,
                       dist_linear = dist_linear,
                       z_up = z_up,
                       z = z,
                       z_old= z_old,
                       slope = (z_up - z) /dist_total,
                       flow_acc = flow_acc,
                       flow_acc_old =flow_acc_old,
                       resolution = res(zoomed_site)[1]
                       )
}
