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

function intersectmatch(fun, input, config::TextConfig, sep, key, patlist::Vector{Vector{String}})
    patlist = normpatternsset(patlist, config)

    while !eof(input)
        arr = split(rstrip(readline(input)), sep)
        if key < 0
            tokens = tokenize(arr[length(arr)+key+1], config) |> Set
        else
            tokens = tokenize(arr[key], config) |> Set
        end
        
        matches = 0
        for (i, patterns) in enumerate(patlist)
            for pat in patterns
                iset = intersect(tokens, pat)
                if length(iset) == length(pat)
                    matches += 1
                    break
                end
            end
            matches != i && break
        end

        matches == length(patlist) && fun(arr)
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


function kerrorsmatch(fun, input, config::TextConfig, sep, key, patlist::Vector{Vector{String}}, maxerrors::Int=1)
    # config.stem = false
    patlist = normpatterns(patlist, config)

    while !eof(input)
        arr = split(rstrip(readline(input)), sep)
        if key < 0
            text = normtext(arr[length(arr)+key+1], config)
        else
            text = normtext(arr[key], config)
        end

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

        matches == length(patlist) && fun(arr)
    end
end

function substringmatch(fun, input, config::TextConfig, sep, key, patlist::Vector{Vector{String}})
    # patlist = [[normtext(pat, config) for pat in patterns] for patterns in patlist]
    patlist = normpatterns(patlist, config)

    while !eof(input)
        arr = split(rstrip(readline(input)), sep)
        if key < 0
            text = normtext(arr[length(arr)+key+1], config)
        else
            text = normtext(arr[key], config)
        end
        
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

        matches == length(patlist) && fun(arr)
    end
end

function harvesine(p1::Vector{Float64}, p2::Vector{Float64})
    # Tweets use GEOJson format: [longitude, latitude]
    lon1, lat1 = p1
    lon2, lat2 = p2
    2 * 6372.8 * asin(sqrt(sind((lat2-lat1)/2)^2 + cosd(lat1) * cosd(lat2) * sind((lon2 - lon1)/2)^2))
end

function radius(fun, input, sep, key, coordinates)
    center = [x |> Float64 for x in coordinates["coordinates"]]
    distance = coordinates["radius"]
    
    while !eof(input)
        arr = split(rstrip(readline(input)), sep)
        if key < 0
            _coord = arr[length(arr)+key+1] 
        else
            _coord = arr[key]
        end

        _coord == "{}" && continue
        p = JSON.parse(_coord)

        coord = [x |> Float64 for x in p["coordinates"]]

        if harvesine(center, coord) <= distance
            fun(arr)
        end
    end
end

function vocextraction(fun, input, config::TextConfig, sep, key)
    # patlist = [[normtext(pat, config) for pat in patterns] for patterns in patlist]
    thesaurus = Dict{String,Int}()
    while !eof(input)
        arr = split(rstrip(readline(input)), sep)
        if key < 0
            tokens = tokenize(arr[length(arr)+key+1], config)
        else
            tokens = tokenize(arr[key], config)
        end

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

config = TextConfig()
patlist = Vector{String}[]
stopwords = ""
kind = ""
key = -1
sep = "\t"
coordinates = nothing
errors = 1

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
            key = parse(Int, split(arg, ':')[2])
        elseif startswith(arg, "sep")
            key = split(arg, ':')[2]
        elseif startswith(arg, "radius")
            kind = "radius"
            coordinates = JSON.parse(arg[8:end])  ## radius:{"coordinates":[long,lat],"radius":radius}
        else
            error("Unknown command $arg")
        end
    end
end


if length(stopwords) > 0
    config.stopwords = Set([join(normchars(strip(line), config)) for line in readlines(stopwords)])
end

if kind == "substring"
    substringmatch(STDIN, config, sep, key, patlist) do arr
        write(STDOUT, join(arr, sep), '\n')
    end
elseif kind == "intersect"
    intersectmatch(STDIN, config, sep, key, patlist) do arr
        write(STDOUT, join(arr, sep), '\n')
    end
elseif kind == "kerrors"
    kerrorsmatch(STDIN, config, sep, key, patlist, errors) do arr
        write(STDOUT, join(arr, sep), '\n')
    end
elseif kind == "radius"
    radius(STDIN, sep, key, coordinates) do arr
        write(STDOUT, join(arr, sep), '\n')
    end
elseif kind == "voc"
    vocextraction(STDIN, config, sep, key) do arr
        write(STDOUT, join(arr, '\t'), '\n')
    end
else
    info("""
    Usage: julia PatternSearch/matches.jl KIND SEP KEY CONFIG STOPWORDS PAT1 PAT2 ...
    Where
    
    KIND is substring|intersect|kerrors|voc|radius
    - in the case of kerrors you can specify the maximum number of errors using the syntax kerrors:numerrors
    - the default kind is not specified, it is a mandatory argument
    - radius dumps records intersecting a ball; the center and radius of the ball (in kilometers). It uses the harvesing formulae to compute distances. The syntax is radius:JSON-coordinates
        - JSON-coordinates are of the form {"coordinates": [longitude, latitute], "radius": kilometers}
        - for example,
             - radius:'{"coordinates":[-102.295914,21.918859], "radius": 0.3}'
    - voc dumps the vocabulary's histogram sorted by increasing frequency

    SEP is the separator string
    - the syntax is sep:sepstring, e.g.,
        - sep:"<SEP>" -- a <SEP> string
        - sep:,       -- a single comma
        - sep:\$'\\t'  -- a single tab
    - the tabulator is the default separator

    KEY indicates the id of the column
    - the syntax is key:numcolumn, e.g., key:1
    - negative keys are mapped to numcolumns-abs(key)+1 (so, the last column, -1, is just numcolumns)
    - the default key is the last one, i.e., key:-1

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
