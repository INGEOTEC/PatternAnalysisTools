# Eric S. Tellez <eric.tellez@infotec.mx>

#Pkg.add("GZip")
#Pkg.add("Glob")
#Pkg.add("JSON")

using ArgParse
import JSON
import Glob

include("textmodel.jl")
include("io.jl")

function groupby(fun, input, textkey, userkey, popkey, minsize)
    H = Dict{String,Dict}()
    lineno = 0
    
    dopopkey = popkey != ""
    itertweets(input) do tweet
        lineno += 1
        key = getkeypath(tweet, userkey)
        text = getkeypath(tweet, textkey)

        if dopopkey
            arr = split(key, popkey[1])
            pop!(arr)
            key = join(arr, popkey[1])
        end

        if haskey(H, key)
            push!(H[key][textkey], text)
        else
            tweet[textkey] = [text]
            tweet[userkey] = key
            # info(JSON.json(tweet), " --- ", length(H))
            H[key] = tweet
        end

        if lineno % 1000 == 0
            info("Advance $uniques from $lineno")
        end
    end

    for (k, v) in H
        if length(v[textkey]) >= minsize
            fun(v)
        end
    end
end

function main()
    s = ArgParseSettings()
    @add_arg_table s begin
        "--by"
        help = "specifies the key to group"
        arg_type = String
        default = "key"
        "--text"
        help = "specifies the key pointing to the text"
        arg_type = String
        default = "text"
        "--pop"
        help = "specifies the character to split the key; also it applies a pop to create the key"
        arg_type = String
        default = ""
        "--minsize"
        help = "specifies the minimum size of the group to be part of the output"
        arg_type = Int
        default = 1

    end

    args = parse_args(ARGS, s)
    groupby(STDIN, args["text"], args["by"], args["pop"], args["minsize"]) do tweet
        write(STDOUT, JSON.json(tweet), '\n')
    end
end

main()
