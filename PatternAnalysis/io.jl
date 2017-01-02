#Pkg.add("GZip")
#Pkg.add("Glob")
#Pkg.add("JSON")

import GZip
import JSON

function iterlines(fun, filename)
    if endswith(filename, ".gz")
        f = GZip.open(filename)
        while !eof(f)
            line = readline(f)
            if length(line) == 0
                continue
            end
            fun(line)
        end
        close(f)
    else
        open(filename) do f
            while !eof(f)
                line = readline(f)
                fun(line)
            end
        end
    end
end

function parsetweet(line)
    if line[1] == '{'
        tweet = JSON.parse(value)
    else
        key, value = split(line, '\t', limit=2)
        tweet = JSON.parse(value)
        tweet["key"] = key
    end

    tweet
end

function itertweets(fun, filename)
    iterlines(filename) do line
        tweet = parsetweet(line)
        fun(tweet)
    end
end
