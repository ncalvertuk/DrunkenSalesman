using TravelingSalesmanHeuristics
using CSV
using PyCall
using Statistics
using Printf
using JSON
using Gadfly

ors = pyimport("openrouteservice")
sjson = pyimport("simplejson")
req = pyimport("requests")
fol = pyimport("folium")

csv_filename = "Data/LatLon.csv"
csv_Data = CSV.read(csv_filename,header=true)
median_long = median(csv_Data.longitude)
median_lat = median(csv_Data.latitude)
n_breweries = size(csv_Data.longitude)[1]
body_latlon = Array(collect(zip(csv_Data.longitude,csv_Data.latitude)))
m = fol.Map(tiles="OpenStreetMap",location=(median_lat, median_long), zoom_start=14)
Starting_index = 1
ind = 0
for row in eachrow(csv_Data)
    global ind += 1
    name = row.brewery
    lat = row.latitude
    lon = row.longitude
    popup = @sprintf "%s\nLat: %.7f\nLong: %.7f" name lat lon;
    icon_type = "beer"
    if (name == "Piccadilly Station")
        icon_type = "train"
        global Starting_index = ind
    end
    icon = fol.map.Icon(color="lightgray",
    icon_color="#b5231a",
    icon=icon_type, # fetches font-awesome.io symbols
    prefix="fa")
    fol.map.Marker([lat, lon], icon=icon, popup=popup).add_to(m)
end

credfile = open("Data/ors_cred.json")
headers = JSON.parse(read(credfile,String))
body = Dict("locations"=>body_latlon)
call = req.post("https://api.openrouteservice.org/v2/matrix/foot-walking", json=body, headers=headers)
data = call.json()
dist_array = data["durations"]
p = (spy(dist_array,Guide.xticks(ticks = 1:n_breweries, orientation=:vertical),Scale.x_continuous(labels = x -> csv_Data.labelname[x]),Guide.yticks(ticks = 1:n_breweries, orientation=:horizontal),Scale.y_continuous(labels = x -> csv_Data.labelname[x]),Guide.title("Distance Matrix"),Guide.xlabel(""),Guide.ylabel("")))
img = SVG("DistanceArray.svg")
draw(img,p)
@time path, cost = solve_tsp(dist_array; quality_factor = 100)
path_reorder = zeros(Int64,size(path))
reorder_index = findall(x->x==Starting_index,path)
path_reorder[1:(length(path) - reorder_index[1])+1]=path[reorder_index[1]:end]
path_reorder[(length(path) - reorder_index[1])+2:(end)]=path[2:reorder_index[1]]
optimal_coords = map((i,j)->(i,j),csv_Data.longitude[path_reorder],csv_Data.latitude[path_reorder])
opt_body = Dict("coordinates"=>optimal_coords)
call = req.post("https://api.openrouteservice.org/v2/directions/foot-walking/geojson", json=opt_body, headers=headers)
data = call.json()
println("Total Walking Time calculated using TSP = $(data["features"][1]["properties"]["summary"]["duration"] / 60)")
points_temp = data["features"][1]["geometry"]["coordinates"]
points = zeros(size(points_temp))
points[:,1] = points_temp[:,2]
points[:,2] = points_temp[:,1]
fol.PolyLine(points, color="red", weight=2.5, opacity=1,name="Optimal Brewery Crawl",overlay=true).add_to(m)
m.add_child(fol.map.LayerControl())
m.save("OptimalBreweryCrawl.html")
println("Optimal Path:")
for p in path_reorder[1:end-1]
     print(string(csv_Data.brewery[p],"=>"))
end
println(csv_Data.brewery[path_reorder[end]])
