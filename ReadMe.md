The Drunken Salesman: Applying the Travelling Salesperson Problem to Manchester Breweries
==============

### Introduction
A Julia script to calculate the optimal walking route around the brewery taprooms of Manchester City Centre (Travelling Salesperson Problem). A blogpost describing the code can be found [here](www.ncalvert.uk/posts/drunkensalesman/)

### Prerequisites
The following Julia packages are required:
* [TravelingSalesmanHeuristics](https://github.com/evanfields/TravelingSalesmanHeuristics.jl)
* [PyCall](https://github.com/JuliaPy/PyCall.jl)
* [JSON](https://github.com/JuliaIO/JSON.jl)
* [GadFly](http://gadflyjl.org/stable/)
These can all be added using the Julia Pkg.add() function. Some setup of PyCall is required if you want to use an external install of python, this is well documented in the documentation. You will need the following Python packages installed as part of your Python installation too:
* [Openrouteservice](https://openrouteservice.org/)
* [Folium](https://python-visualization.github.io/folium/)

### Openrouteservice API Key
In order to execute the script you will need your own key for the Openrouteservice API. This can be aquired [here](https://openrouteservice.org/log-in/). The key will need to be placed in ```Data/ors_cred.json``` before the script will run. 

### Changing the Locations
To apply the algorithm to a different set of locations you can edit the CSV fil ```Data/LatLon.csv```.
