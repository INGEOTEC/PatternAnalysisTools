using SimilaritySearch
using TextModel
using JSON

const NUM_FAST_LINKS = 7

function set_oracle(index, fastlinks::Dict{UInt64,KnnResult})
    function oracle(q::HBOW)::Vector{Int32}
        L = Int32[]
        for term in q.terms
            if haskey(fastlinks, term.id)
                for p in fastlinks[term.id]
                    push!(L, p.objID)
                end
            end
        end
        # @show L, fastlinks
        L
    end

    index.options.oracle = oracle
    fastlinks
end

function update_oracle(index, fastlinks, bow::HBOW)
    for term in bow.terms
        if !haskey(fastlinks, term.id)
            fastlinks[term.id] = KnnResult(NUM_FAST_LINKS)
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
    
    index = LocalSearchIndex(HBOW, AngleDistance(), recall=0.90, neighborhood=Nullable{NeighborhoodAlgorithm}(LogSatNeighborhood(1.5)))
    fastlinks = set_oracle(index, Dict{UInt64,KnnResult}())
    # index.options.verbose = false
    return index, config, fastlinks
end

function main(filename)
    index, config, fastlinks = create_index()
    lineno = 0
    DB = []

    iterlines(filename) do line
        tweet = TextModel.parsetweet(line)
        lineno += 1
        bow = compute_bow(tweet["text"], config) |> HBOW

        knn, N = find_neighborhood(index, bow)
        if length(knn) > 0 && first(knn).dist < 1.0
            info("VERY NEAR OBJECT:", first(knn), line, "; ORIGINAL:", DB[first(knn).objID])
        else
            push_neighborhood!(index, bow, N, length(index.db))
            update_oracle(index, fastlinks, bow)  # adding fast links
            push!(DB, line)
            println(line)
        end

        if lineno % 1000 == 0
            info("selected $(length(DB)) of $(lineno)")
        end
        
    end
end

main(ARGS[1])
