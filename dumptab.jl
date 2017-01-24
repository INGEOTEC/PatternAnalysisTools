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


function formatgenerictweet(tweet)
    tkeys = collect(keys(tweet))
    sort!(tkeys)
    arr = [JSON.json(tweet[k]) for k in tkeys]
    string(join(arr, '\t'), "\n")
end

if length(ARGS) > 0
    for filename in ARGS
        itertweets(filename) do tweet
            write(STDOUT, tweet |> formatgenerictweet)
        end
    end
else
    while !eof(STDIN)
        line = readline(STDIN)
        write(STDOUT, line |> parsetweet |> formatgenerictweet)
    end
end
