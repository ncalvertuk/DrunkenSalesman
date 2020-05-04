"""
Script to solve the Travelling Salesperson Problem for the Craft Brewery Taprooms in Manchester City Centre
Let's start by importing the required packages.
"""
using TravelingSalesmanHeuristics
using CSV
using PyCall
using Statistics
using Printf
using JSON
using Gadfly
"""
Add the following Python libraries.
"""
ors = pyimport("openrouteservice")
req = pyimport("requests")
fol = pyimport("folium")


"""
First we're going to read in the data and generate the base map, without the route present.
"""
# The filename of the csv file containing the Latitude and Longitude.
csv_filename = "Data/LatLon.csv"
# Read in this file into a data array. The columns should be:
# brewery (String), longitude (Float64), latitude(Float64), labelname(String), n(Int64)
csv_Data = CSV.read(csv_filename,header=true)
# Calculate the median coordinate, we will centre the map on this point
median_long = median(csv_Data.longitude)
median_lat = median(csv_Data.latitude)
# Get the number of breweries in the list
n_breweries = size(csv_Data.longitude)[1]
# We want the coordinates in a vector of Tuples, each row is of the form (long,lat)
body_latlon = Array(collect(zip(csv_Data.longitude,csv_Data.latitude)))



# Create the map based on the OpenStreetMap, centred at the median point.
m = fol.Map(tiles="OpenStreetMap",location=(median_lat, median_long), zoom_start=14)
# The Starting_index will be used to reorder the optimal path so that it starts and ends at this point.
# Temporarily set it to the first point, later we will set it to Piccadily Station
Starting_index = 1
# ind is a counter for what row we are at in the loop
ind = 0
# Loop through the rows, create an icon on the map for each one with the coordinates and the name of the location.
for row in eachrow(csv_Data)
    global ind += 1
    name = row.brewery
    lat = row.latitude
    lon = row.longitude
    popup = @sprintf "%s\nLat: %.7f\nLong: %.7f" name lat lon;
    # If the location is a taproom use the beer icon, if it's a station then use the train icon
    icon_type = "beer"
    if (name == "Piccadilly Station")
        icon_type = "train"
        global Starting_index = ind
    end
    # Set the icon
    icon = fol.map.Icon(color="lightgray",
    icon_color="#b5231a",
    icon=icon_type,
    prefix="fa")
    # Put the icon on the map
    fol.map.Marker([lat, lon], icon=icon, popup=popup).add_to(m)
end

"""
Calculate the distance matrix using Openrouteservice, save a visualisation of the array to an SVG file.
"""
#
# Get the API credentials from the ors_dred.json file
credfile = open("Data/ors_cred.json")
headers = JSON.parse(read(credfile,String))
# Put the coordinates in a dictionary.
body = Dict("locations"=>body_latlon)
# Call ORS and get the walking durations to put into the distance matrix
call = req.post("https://api.openrouteservice.org/v2/matrix/foot-walking", json=body, headers=headers)
data = call.json()
dist_array = data["durations"]
# Visualise the distance matrix and save to a SVG file.
p = (spy(dist_array,Guide.xticks(ticks = 1:n_breweries, orientation=:vertical),Scale.x_continuous(labels = x -> csv_Data.labelname[x]),Guide.yticks(ticks = 1:n_breweries, orientation=:horizontal),Scale.y_continuous(labels = x -> csv_Data.labelname[x]),Guide.title("Distance Matrix"),Guide.xlabel(""),Guide.ylabel("")))
img = SVG("DistanceArray.svg")
draw(img,p)

"""
Calculate an estimate of the optimal route using the heuristic algorithms.
"""
# Solve the TSP.
@time path, cost = solve_tsp(dist_array; quality_factor = 100)
# We'll reorder the path so that the location at Starting_index is at the beginning and end of the path.
path_reorder = zeros(Int64,size(path))
reorder_index = findall(x->x==Starting_index,path)
path_reorder[1:(length(path) - reorder_index[1])+1]=path[reorder_index[1]:end]
path_reorder[(length(path) - reorder_index[1])+2:(end)]=path[2:reorder_index[1]]



"""
Calculate the walking directions for the optimal path
"""
# Get the coordinates in a Vector of tuples (Long,Lat) in the correct order for the optimal route.
optimal_coords = map((i,j)->(i,j),csv_Data.longitude[path_reorder],csv_Data.latitude[path_reorder])
# Use the ORS API again, similar to before but using the Directions function.
opt_body = Dict("coordinates"=>optimal_coords)
call = req.post("https://api.openrouteservice.org/v2/directions/foot-walking/geojson", json=opt_body, headers=headers)
# Get the total walking time and print to the screen.
data = call.json()
println("Total Walking Time calculated using TSP = $(data["features"][1]["properties"]["summary"]["duration"] / 60)")


"""
Map the walking directions for the optimal path
"""
# Folium requires the points in (Lat,Long), the opposite to the ORS.
# We get the coordinates of the walking directions (a new point for each change of direction) from the  data JSON.
points_temp = data["features"][1]["geometry"]["coordinates"]
points = zeros(size(points_temp))
points[:,1] = points_temp[:,2]
points[:,2] = points_temp[:,1]

# Add the points to map in the form of a line and save the map.
fol.PolyLine(points, color="red", weight=2.5, opacity=1,name="Optimal Brewery Crawl",overlay=true).add_to(m)
m.add_child(fol.map.LayerControl())
m.save("OptimalBreweryCrawl.html")

# Print the optimal route to the screen
println("Optimal Path:")
for p in path_reorder[1:end-1]
     print(string(csv_Data.brewery[p],"=>"))
end
println(csv_Data.brewery[path_reorder[end]])
