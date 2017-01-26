# Eric S. Tellez <eric.tellez@infotec.mx>

#Pkg.add("GZip")
#Pkg.add("Glob")
#Pkg.add("JSON")

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

function intersectmatch(tokens, pat)
    for w in pat
        if !(w in tokens)
            return false
        end
    end
    return true
end

function intersectmatch(fun, wrap, input, config::TextConfig, key, patlist::Vector{Vector{String}})
    patlist = normpatternsset(patlist, config)

    itertweets(input) do tweet
        tokens = tokenize(tweet[key], config) |> Set
        
        matches = 0
        for (i, patterns) in enumerate(patlist)
            for pat in patterns
                if intersectmatch(tokens, pat)
                    matches +=1
                    break
                end
            end
            matches != i && break
        end

        wrap(matches == length(patlist)) && fun(tweet)
    end
end

function kerrorsmatch{T1 <: Any, T2 <: Any}(a::T1, b::T2, errors::Int)::Bool
    # if length(a) < length(b)
    #     a, b = b, a
    # end

    alen::Int = length(a)
    blen::Int = length(b)

    alen == 0 && return alen == blen
    blen == 0 && return true

    C::Vector{Int} = Vector{Int}(0:blen)

    for i in 1:alen
	prevA::Int = 0
	prevC::Int = C[1]
	j::Int = 1
        
	while j <= blen
	    cost::Int = 1
	    @inbounds if a[i] == b[j]
		cost = 0
	    end
	    @inbounds C[j] = prevA
	    j += 1
	    @inbounds prevA = min(C[j]+1, prevA+1, prevC+cost)
	    @inbounds prevC = C[j]
	end
	@inbounds C[j] = prevA
        if prevA <= errors
            return true
        end
    end

    return false
end

function kerrorsmatch(fun, wrap, input, config::TextConfig, key, patlist::Vector{Vector{String}}, maxerrors::Int=1)
    # config.stem = false
    patlist = normpatterns(patlist, config)

    itertweets(input) do tweet
        text = normtext(tweet[key], config)

        matches = 0
        for (i, patterns) in enumerate(patlist)
            for pat in patterns
                if kerrorsmatch(text, pat, maxerrors)
                    matches += 1
                    break
                end
            end
            matches != i && break
        end

        wrap(matches == length(patlist)) && fun(tweet)
    end
end

function substringmatch(fun, wrap, input, config::TextConfig, key, patlist::Vector{Vector{String}})
    # patlist = [[normtext(pat, config) for pat in patterns] for patterns in patlist]
    patlist = normpatterns(patlist, config)

    itertweets(input) do tweet
        text = normtext(tweet[key], config)
        
        matches = 0
        for (i, patterns) in enumerate(patlist)
            for pat in patterns
                if contains(text, pat)
                    matches += 1
                    break
                end
            end
            matches != i && break
        end

        wrap(matches == length(patlist)) && fun(tweet)
    end
end

function main()
    config = TextConfig()
    patlist = Vector{String}[]
    stopwords = ""
    kind = ""
    key = "text"
    errors = 1
    wrapfun = identity
    
    for arg in ARGS
        arg = strip(arg)
        if arg[1] == '{'
            _config = JSON.parse(arg)
            for (k, v) in JSON.parse(arg)
                setfield!(config, Symbol(k), v)
            end
        elseif arg[1] == '['
            push!(patlist, JSON.parse(arg))
        elseif startswith(arg, "file:")
            push!(patlist, readlines(arg[6:end]))
        elseif startswith(arg, "stopwords:")
            stopwords = arg[length("stopwords:")+1:end]
        else
            if startswith(arg, "substring")
                kind = "substring"
            elseif startswith(arg, "intersect")
                kind = "intersect"
            elseif startswith(arg, "kerror")
                kind = "kerrors"
                if ':' in kind
                    errors = parse(Int, split(arg, ':')[2])
                end
            elseif startswith(arg, "voc")
                kind = "voc"
            elseif startswith(arg, "key")
                key = split(arg, ':')[2]
            elseif startswith(arg, "neg")
                wrapfun = (x) -> !x
            else
                error("Unknown command $arg")
            end
        end
    end
    
    load(config, stopwords)
    
    if kind == "substring"
        substringmatch(wrapfun, STDIN, config, key, patlist) do tweet
            write(STDOUT, JSON.json(tweet), '\n')
        end
    elseif kind == "intersect"
        intersectmatch(wrapfun, STDIN, config, key, patlist) do tweet
            write(STDOUT, JSON.json(tweet), '\n')
        end
    elseif kind == "kerrors"
        kerrorsmatch(wrapfun, STDIN, config, key, patlist, errors) do tweet
            write(STDOUT, JSON.json(tweet), '\n')
        end
    else
        info("""
Usage: julia PatternSearch/matches.jl KIND KEY CONFIG STOPWORDS PAT1 PAT2 ...
    Where
    
    KIND is substring|intersect|kerrors|voc|radius
    - in the case of kerrors you can specify the maximum number of errors using the syntax kerrors:numerrors
    - the default kind is not specified, it is a mandatory argument

    KEY indicates the keywords containing the text
    - defaults to "text"

    CONFIG is a json-dictionary representing a TextConfig object, it controls how the text is preprocessed for the match
    - please check PatternSearch/textmodel.jl to check the fields and default values
    - the default value is created with the default constructor of TextConfig

    STOPWORDS indicates the path of the stopwords file
    - the syntax is stopwords:filename
  
    PAT is a json-list of strings, each string is a pattern in the list
    - PatternSearch/matches.jl basically evaluates a intersection-union tree
    - each PAT defines a list of patterns, the text needs to match at least one to be a candidate (union)
    - a real match is a candidate matching all given PATs (intersection)

    The input is always read from STDIN

    Note: This tool is intended to be used with unix pipes and command line tools like awk, perl, grep, PatternSearch/matches.jl, etc.;
    so a lot of possible features will never be implemented.
    
    """)
        error("please read the help")
    end
end

main()
