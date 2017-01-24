# Eric S. Tellez <eric.tellez@infotec.mx>

#Pkg.add("GZip")
#Pkg.add("Glob")
#Pkg.add("JSON")

using ArgParse
import JSON
import Glob

include("textmodel.jl")
include("io.jl")

function delete(fun, input, keys)
    itertweets(input) do tweet
        for key in keys
            delete!(tweet, key)
        end

        fun(tweet)
    end
end

function select(fun, input, keys)
    itertweets(input) do tweet
        a = Dict()
        for key in keys
            a[key] = getkeypath(tweet, key)
        end

        fun(a)
    end
end


function main()
    s = ArgParseSettings()
    @add_arg_table s begin
        "--delete"
        help = "deletes all pairs with the keys listed here"
        arg_type = String
        default = ""
        "--select"
        help = "selects all pairs with the keys listed here"
        arg_type = String
        default = ""
    end
    
    args = parse_args(ARGS, s)
    
    if length(args["delete"]) > 0
        delete(STDIN, split(args["delete"], ',')) do tweet
            write(STDOUT, JSON.json(tweet), '\n')
        end
    elseif length(args["select"]) > 0
        select(STDIN, split(args["select"], ',')) do tweet
            write(STDOUT, JSON.json(tweet), '\n')
        end
    end
end

if length(ARGS) > 0
    main()
end
