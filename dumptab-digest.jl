import JSON
import Glob
import GZip

# include("textmodel.jl")
include("io.jl")

separator='\t'
emptydict = Dict()

function normspaces(text)
    replace(replace(text, "\n", " "), "\t", " ")
end

function formattext(tweet)
    key = tweet["key"]
    country = "UNK"
    place = get(tweet, "place", emptydict)
    country = get(place, "country_code", "UNK")
    text = normspaces(tweet["text"])
    date = replace(tweet["created_at"], "+", "")
    date = string(Dates.DateTime(date, "e u d H:M:S s y"))
    coordinates = get(tweet, "coordinates", emptydict)
    string(key, separator, date, separator, country, separator, JSON.json(coordinates), separator, text, '\n')    
end

if length(ARGS) > 0
    for filename in ARGS
        itertweets(filename) do tweet
            write(STDOUT, tweet |> formattext)
        end
    end
else
    while !eof(STDIN)
        line = readline(STDIN)
        write(STDOUT, line |> parsetweet |> formattext)
    end
end
