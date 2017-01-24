# Eric S. Tellez <eric.tellez@infotec.mx>

#Pkg.add("GZip")
#Pkg.add("Glob")
#Pkg.add("JSON")

import JSON
import Glob

include("textmodel.jl")
include("io.jl")


function harvesine(p1::Vector{Float64}, p2::Vector{Float64})
    # Tweets use GEOJson format: [longitude, latitude]
    lon1, lat1 = p1
    lon2, lat2 = p2
    2 * 6372.8 * asin(sqrt(sind((lat2-lat1)/2)^2 + cosd(lat1) * cosd(lat2) * sind((lon2 - lon1)/2)^2))
end

function radius(fun, input, key, coordinates)
    center = [x |> Float64 for x in coordinates["coordinates"]]
    distance = coordinates["radius"]
    # @show center, distance
    itertweets(input) do tweet
        p = getkeypath(tweet, key)

        if p["type"] == "Point"
            coord = [x |> Float64 for x in p["coordinates"]]
        else  #  p["type"] == "Polygon"
            A = p["coordinates"][1]
            coord = Float64[0.0, 0.0]
            for x in A
                coord[1] += x[1]
                coord[2] += x[2]
            end
            coord[1] /= length(A)
            coord[2] /= length(A)
        end
        if harvesine(center, coord) <= distance
            fun(tweet)
        end
    end
end

function main()
    config = TextConfig()
    s = ArgParseSettings()
    @add_arg_table s begin
        "--query"
        help = "a GeoJSON-formatted dictionary describing the query, e.g. '{\"coordinates\": [long,lat], \"radius\": radius_km}'"
        arg_type = String
        default = "{}"
        "--key"
        help = "specifies the key pointing to the text"
        arg_type = String
        default = "text"
    end

    args = parse_args(ARGS, s)
    radius(STDIN, args["key"], args["query"]) do tweet
        write(STDOUT, JSON.json(tweet), '\n')
    end
end

main()
