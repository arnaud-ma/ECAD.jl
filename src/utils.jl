"""
    camelcase_to_words(io::IO, s::AbstractString)

Convert a CamelCase string `s` to a space-separated lowercase string,
writing the result to the provided `IO` stream `io`.
Modifies the input string in-place and returns the `IO` stream.

# Example
```julia-repl
julia> io = IOBuffer()
IOBuffer(data=UInt8[...], readable=true, writable=true, seekable=true, append=false, size=0, maxsize=Inf, ptr=1, mark=-1)

julia> camelcase_to_words!(io, "CamelCaseToWords", ' ')
IOBuffer(data=UInt8[...], readable=true, writable=true, seekable=true, append=false, size=19, maxsize=Inf, ptr=20, mark=-1)

julia> String(take!(io))
"camel case to words"
```

See also: [`camelcase_to_words`](@ref) for a version that returns a new string instead of modifying in-place.
"""
function camelcase_to_words!(io::IO, s::AbstractString, sep = ' ')
    first = true
    for c in s
        if !first && isuppercase(c)
            write(io, sep)
        end
        write(io, lowercase(c))
        first = false
    end
    return io
end

"""
    camelcase_to_words(s::String, sep=' ') -> String

Convert a CamelCase string `s` to a sep-separated lowercase string. Returns the converted string.

# Example
```julia-repl
julia> camelcase_to_words("CamelCaseToWords")
"camel case to words"

julia> camelcase_to_words("CamelCaseToWords", '_')
"camel_case_to_words"
```

See also: [`camelcase_to_words!`](@ref) for an in-place version that writes to an `IO` stream.
"""
function camelcase_to_words(s::String, sep = ' ')
    extra_spaces = count(isuppercase, Iterators.drop(s, 1))
    io = IOBuffer(sizehint = ncodeunits(s) + extra_spaces)
    camelcase_to_words!(io, s, sep)
    return String(take!(io))
end


"""
    human_bytes(bytes::Integer) -> String

Convert a byte count to a human-readable string with appropriate units (B, KB, MB, GB, TB, PB).

# Example
```julia-repl
julia> human_bytes(123)
"123.00 B"

julia> human_bytes(123456)
"120.56 KB"

julia> human_bytes(123456789)
"117.74 MB"
```
"""
function human_bytes(bytes::Integer)
    units = ["B", "KB", "MB", "GB", "TB", "PB"]
    size = float(bytes)
    for u in units
        if size < 1024
            return @sprintf("%.2f %s", size, u)
        end
        size /= 1024
    end
    return @sprintf("%.2f PB", size)
end
