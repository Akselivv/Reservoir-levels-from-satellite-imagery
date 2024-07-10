# Reservoir levels from satellite data

 Detecting the amount of water in reservoirs from satellite imagery

## Description of the algorithm

The only inputs required for the algorithm are four coordinates, which specify a rectangular box around a water reservoir. The user can also specify the start and end points for the time series the algorithm collects, as well as the time between observations. Areas that experience a high level of cloudiness require a higher time between osbervations, with 2 weeks being somewhat of a minimum in the Nordic countries. The repository includes coordinates for all reservoirs in the NO5 pricing zone of western Norway.

Using the algorithm requires an account and credentials to the Sentinel Hub API, which the user can insert directly into the script or store in a text file (the default).

The R script calls a separate Python script which makes the API call for the date specified by the R script. Before the analysis can take place, the R script must have data of the nominal water extent of a particular reservoir. This is calculated automatically from a satellite image by a script that recognizes the largest contiguous water body in the image. 

The R script then makes API calls to form a time series of water amounts and displays them as a time series. 
