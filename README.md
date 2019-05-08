# Intro
River slope is a very useful parameter in stream geomorphology, but hard to obtain at a global scale. Within a publication (to be linked later), we needed to obtain slopes of rivers across the globe. I wrote an script in R that can obtain the river slope using a global repository of digital elevation model (DEM).

Currently digital elevation models are largely useful in topographic studies, but its sources are often different among countries, and is hard to use globally at a high resolution. Here I did an R script to estimate channel slope from rivers in any part of the globe.
For each site, we downloaded the DEM covering each site hosted in the Amazon Web Services (https://registry.opendata.aws/terrain-tiles/), with a pixel resolution ranging from 9-19 m, depending on the source. For each site within the database (cross) we extracted the elevation of all locations around 500 m of the site (black dots). By finding the location with the lowest elevation (red dot), we assumed that it corresponds to the stream channel downstream. And calculated the slope as the elevation difference divided by the distance. 

![An example of the algorithm working](https://github.com/rocher-ros/global_slope/blob/master/slope.png)
