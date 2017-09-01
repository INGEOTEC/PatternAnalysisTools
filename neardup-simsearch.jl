using SimilaritySearch
using TextModel
using SnowballStemmer
using JSON

function set_oracle(index, fastlinks::Dict{UInt64,KnnResult})
    function oracle(q::VBOW)::Vector{Int32}
        L = Int32[]
        for term in q.tokens
            if haskey(fastlinks, term.id)
                for p in fastlinks[term.id]
                    push!(L, p.objID)
                end
            end
        end

        if length(L) == 0
            # just link randomly for orthogonal vectors
            n = length(index.db)
            return rand(1:n, floor(Int, log2(n+1)))
        end

        # @show L, fastlinks
        L
    end

    index.options.oracle = oracle
    fastlinks
end

function update_oracle(index, fastlinks, bow::VBOW, num_fast_links)
    for term in bow.tokens
        if !haskey(fastlinks, term.id)
            fastlinks[term.id] = KnnResult(num_fast_links)
        end
        push!(fastlinks[term.id], length(index.db), term.weight)
    end
end

function create_index()
    index = LocalSearchIndex(VBOW, angle_distance, recall=0.90, neighborhood=LogSatNeighborhood(1.5))
    fastlinks = set_oracle(index, Dict{UInt64,KnnResult}())
    # index.options.verbose = false
    return index, fastlinks
end

function create_normalizer(stemming, tabufiles, config)
    tabu = Set{String}()
    if length(tabufiles) > 0
        for filename in split(tabufiles, ':')
            words = split(TextModel.normalize_text(readstring(filename), config) |> join)
            union!(tabu, words)
        end
    end

    emptystring = ""
    if length(stemming) > 0
        S = Stemmer(stemming)
        if length(tabu) > 0
            info("CREATING stemming && tabu $(length(tabu))")
            return (w) -> if w ∈ tabu
                emptystring
            else
                stem(S, w)
            end
        else
            return (w) -> stem(S, w)
        end
    else
        if length(tabu) > 0
            return (w) -> if w ∈ tabu
                emptystring
            else
                w
            end
        else
            return identity
        end
    end
end

function main(filename, dup_threshold, key, num_fast_links; stemming="", verbose=false, tabu="")
    config = TextConfig()
    config.nlist = [1]
    config.qlist = []
    config.skiplist = []
    config.normalize = create_normalizer(stemming, tabu, config)
    index, fastlinks = create_index()
    index.options.verbose = verbose

    lineno = 0

    DB = []

    iterlines(filename) do line
        tweet = TextModel.parsetweet(line)
        lineno += 1
        rawbow = compute_bow(tweet[key], config)
        # info(rawbow)
        bow = VBOW(rawbow)
        knn, N = find_neighborhood(index, bow)
        if length(knn) > 0 && first(knn).dist < dup_threshold
            if verbose
                info("- DISCARDED:", line)
                info("-  ORIGINAL:", DB[first(knn).objID])
                info("-  DISTANCE:", first(knn).dist, " < ", dup_threshold)
            end
        else
            push_neighborhood!(index, bow, N, length(index.db))
            update_oracle(index, fastlinks, bow, num_fast_links)  # adding fast links
            push!(DB, line)
            println(line)
        end

        if lineno % 1000 == 0
            info("selected $(length(DB)) of $(lineno), drop-ratio: $(length(DB) / lineno)")
        end

    end
end

if length(ARGS) == 0
    info("""
    neardup-simsearch.jl removes the number of near duplicated items in text databases. It keeps only the original version of the document.

    Usage: [environment-variables] julia neardup-simsearch.jl files...

    Each input file must contain a json-dictionary per line, the indexes are independent per file

    For simplicity, the arguments are passed as environment-variables

    - dup_threshold: items under this value are considered as duplicated
       valid range: 0 < dup_threshold < pi/2
       default: 1.0

    - key: the keyword containing the text for each json
       default: text

    - num_fast_links: the number of documents stored per token to help localsearch indexes to perform fast lookups
       default: 7

    - stemming: specifies stemming rules to apply.
      e.g. stemming=spanish
       valid values: "", "danish", "dutch", "english", "finnish", "french", "german", "hungarian", "italian", "norwegian", "porter", "portuguese", "romanian", "russian", "spanish", "swedish", "turkish"
    - verbose: if enabled (verbose=true) the output becomes too noisy :S
    """)
else
    for filename in ARGS
        main(
            filename,
            parse(Float64, get(ENV, "dup_threshold", "1.0")),
            get(ENV, "key", "text"),
            parse(Int, get(ENV, "num_fast_links", "7")),
            verbose=parse(Bool, get(ENV, "verbose", "false")),
            tabu=get(ENV, "tabu", ""),
            stemming=get(ENV, "stemming", ""),
        )
    end
end
