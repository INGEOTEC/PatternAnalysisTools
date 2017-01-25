## Pattern Analysis Tools
The idea behind PatternAnalysisTools is to enrich the UNIX's tool set to perform pattern matching and other kind of non-so-usual analysis techniques in datasets formated as columns.

The idea is to be used jointly with unix pipes and command line tools like awk, perl, grep, etc.; a lot of possible features will never be implemented.

The input is always read from STDIN

The available commands are:

- _matches.jl_ It search items for matching the given queries under text-normalization and a number of matching-methods
- _neardup.jl_ It removes the items being near duplicates, it preserves the first item seen
- _voc.jl_ It produces thesaurus and its histograms, it can work under several text-normalizing functions and tokenizers
- _radius.jl_ It filters items using geo-location information
- _dumptab.jl_ Dumps the json items as  column records
- _jsonclean.jl_ Allows to drop and select pais in the json records
