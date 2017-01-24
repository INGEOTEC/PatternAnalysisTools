# Eric S. Tellez <eric.tellez@infotec.mx>

#Pkg.add("GZip")
#Pkg.add("Glob")
#Pkg.add("JSON")

using ArgParse
import JSON
import Glob

include("textmodel.jl")
include("io.jl")

function normpatterns(patlist::Vector{Vector{String}}, config::TextConfig)
    A = Vector{String}[]
    for patterns in patlist
        B = String[]
        for pat in patterns
            T = tokenize(pat, config)
            length(T) > 0 && push!(B, join(T, ' '))
        end
        length(B) > 0 && push!(A, B)
    end

    Set(A)
end

function normpatternsset(patlist::Vector{Vector{String}}, config::TextConfig)
    A = Vector{Set{String}}[]

    for patterns in patlist
        B = Set{String}[]
        for pat in patterns
            T = tokenize(pat, config)
            length(T) > 0 && push!(B, Set(T))
        end
        length(B) > 0 && push!(A, B)
    end

    Set(A)
end

function neardup(fun, input, config::TextConfig, key)
    # config.stem = false
    H = Set{String}()
    lineno = 0
    uniques = 0
    
    itertweets(input) do tweet
        lineno += 1
        text = normtext(getkeypath(tweet, key), config)

        if !(text in H)
            push!(H, text)
            fun(tweet)
            uniques += 1
        end

        if lineno % 100000 == 0
            info("Advance $uniques from $lineno")
        end
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

    neardup(STDIN, config, args["key"]) do tweet
        write(STDOUT, JSON.json(tweet), '\n')
    end
end

main()
