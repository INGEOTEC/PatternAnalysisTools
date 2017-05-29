using SimilaritySearch
using TextModel
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
            return rand(1:n, floor(Int, log2(n)))
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
    config = TextConfig()
    config.nlist = []
    config.qlist = [5]
    #config.qlist = [2, 3, 5]
    config.skiplist = []

    index = LocalSearchIndex(VBOW, angle_distance, recall=0.90, neighborhood=Nullable{NeighborhoodAlgorithm}(LogSatNeighborhood(1.5)))
    fastlinks = set_oracle(index, Dict{UInt64,KnnResult}())
    # index.options.verbose = false
    return index, config, fastlinks
end

function main(filename, dup_threshold, key, num_fast_links)
    index, config, fastlinks = create_index()
    lineno = 0
    DB = []

    iterlines(filename) do line
        tweet = TextModel.parsetweet(line)
        lineno += 1
        bow = compute_bow(tweet[key], config) |> VBOW

        knn, N = find_neighborhood(index, bow)
        if length(knn) > 0 && first(knn).dist < dup_threshold
            info("NEAR OBJECT:", first(knn), line, "; ORIGINAL:", DB[first(knn).objID])
        else
            push_neighborhood!(index, bow, N, length(index.db))
            update_oracle(index, fastlinks, bow, num_fast_links)  # adding fast links
            push!(DB, line)
            println(line)
        end

        if lineno % 1000 == 0
            info("selected $(length(DB)) of $(lineno)")
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
    """)
else
    for filename in ARGS
        main(
            filename,
            parse(Float64, get(ENV, "dup_threshold", "1.0")),
            get(ENV, "key", "text"),
            parse(Int, get(ENV, "num_fast_links", "7"))
        )
    end
end
