#Pkg.add("GZip")
#Pkg.add("Glob")
#Pkg.add("JSON")
#Pkg.add("PyCall")

using PyCall
@pyimport nltk.stem as nltk_stem


PUNCTUACTION = ";:,.@#&\\-\"'/:*"
SYMBOLS = "()[]¿?¡!{}~<>|"
SKIP_SYMBOLS = string(PUNCTUACTION, SYMBOLS)
# SKIP_WORDS = set(["…", "..", "...", "...."])

type TextConfig
    lc::Bool
    del_diac::Bool
    del_dup::Bool

    del_punc::Bool
    del_users::Bool
    del_urls::Bool
    del_num::Bool

    stem::Bool
    min_length::Int
    max_length::Int

    ngrams::Int
    stopwords::Set{String}
    TextConfig() = new(true, true, true, true, true, true, true, true, 2, 16, 1, Set{String}())
end

function normchars(text, config::TextConfig)
    if config.del_users
        text = replace(text, r"@\w+\s?", "")
    end

    if config.del_urls
        text = replace(text, r"https?:\S+\s?", "")
        text = replace(text, r"ftp:\S+\s?", "")
    end
    
    if config.lc
        text = lowercase(text)
    end

    L = Vector{Char}()
    blank = ' '
    prev = blank

    for u in normalize_string(text, :NFD)
        if config.del_diac
            o = Int(u)
            0x300 <= o && o <= 0x036F && continue
        end
        
        if u in ('\n', '\r', ' ', '\t')
            u = blank
        elseif config.del_dup && prev == u
            continue
        elseif config.del_punc && u in SKIP_SYMBOLS
            prev = u
            continue
        elseif config.del_num && isdigit(u)
            continue
        end
        prev = u
        push!(L, u)
    end

    return L
end

stemmer = nltk_stem.SnowballStemmer("spanish")

function tokenize(text, config::TextConfig)
    text = split(text, "(@")[1]
    text = join(normchars(text, config))
    tokens = String[]
    del_stopwords = length(config.stopwords) > 0

    for word in split(text)
        len = length(word)
        if len <= config.min_length || len >= config.max_length
            continue
        end

        del_stopwords && word in config.stopwords && continue

        if config.stem
            word = stemmer[:stem](word)
        end
        !isascii(word) && continue

        push!(tokens, word)
    end
    if config.ngrams == 1
        return tokens
    end
    
    return [join(tokens[i:i+config.ngrams-1], ' ') for i in 1:(length(tokens)-config.ngrams+1)]
end

function normtext{T <: AbstractString}(text::T, config::TextConfig)
    join(tokenize(text, config), ' ')
end
