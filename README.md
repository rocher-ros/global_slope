# Intro
River slope is a very useful parameter in stream geomorphology, aquatic ecology, hydrology... but hard to obtain easily at any location in the globe. 
This R script can obtain the stream channel ust providing a pair of coordinates of a stream.
The workflow is as follows: 
- Download a high resolution digital elevation model (DEM) around the site, using the package "elevatr".
- Model the flow accumulation in the landscape to see the stream channels.
- Snap the coordinates provided to the closest stream.
- An algorithm then follows the stream channel upstream for a predetermined length, and estimates the slope as the elevation difference between the site and upstream divided by the distance. 

![An example of the algorithm working. The black point is the low site, and the red the site upstream. The raster shows the flow accumulation in the landscape](https://github.com/rocher-ros/global_slope/blob/master/slope.png)


A primitive approach has been archived as branch 0.1, which was used in the publication: (Landscape process domains drive patterns of CO<sub>2</sub> evasion from river networks, [published in **Limnology and Oceanography Letters**](https://aslopubs.onlinelibrary.wiley.com/doi/full/10.1002/lol2.10108) )
