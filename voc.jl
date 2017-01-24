# Eric S. Tellez <eric.tellez@infotec.mx>

#Pkg.add("GZip")
#Pkg.add("Glob")
#Pkg.add("JSON")

using ArgParse
import JSON
import Glob

include("textmodel.jl")
include("io.jl")


function voc(fun, input, config::TextConfig, key)
    # patlist = [[normtext(pat, config) for pat in patterns] for patterns in patlist]
    thesaurus = Dict{String,Int}()

    itertweets(input) do tweet
        tokens = tokenize(getkeypath(tweet, key), config)

        for tok in tokens
            thesaurus[tok] = get(thesaurus, tok, 0) + 1
        end
    end

    L = [(v, k) for (k,v) in thesaurus]
    sort!(L, by=(x) -> x[1])
    for x in L
        fun(x)
    end
end

function main()
    config = TextConfig()
    s = ArgParseSettings()
    @add_arg_table s begin
        "--config"
        help = "a json-formatted dictionary with the TextModel configuration"
        arg_type = String
        default = "{}"
        "--stopwords"
        help = "the file containing the list of stopwords, one per line"
        arg_type = String
        default = ""
        "--key"
        help = "specifies the key pointing to the text"
        arg_type = String
        default = "text"
    end

    args = parse_args(ARGS, s)
    config = TextConfig()
    for (k, v) in JSON.parse(args["config"])
        setfield!(config, Symbol(k), v)
    end
    load(config, args["stopwords"])

    voc(STDIN, config, args["key"]) do tweet
        write(STDOUT, JSON.json(tweet), '\n')
    end
end

main()
