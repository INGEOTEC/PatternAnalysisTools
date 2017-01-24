## Pattern Analysis Tools
The idea behind PatternAnalysisTools is to enrich the UNIX's tool set to perform pattern matching and other kind of non-so-usual analysis techniques in datasets formated as columns.

The idea is to be used jointly with unix pipes and command line tools like awk, perl, grep, etc.; a lot of possible features will never be implemented.

Currently, PatternAnalysisTools contains a single command with several options

## Documentation of the command line

Usage: julia PatternSearch/matches.jl KIND SEP KEY CONFIG STOPWORDS PAT1 PAT2 ...
    
KIND is substring|intersect|kerrors|radius|voc
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

