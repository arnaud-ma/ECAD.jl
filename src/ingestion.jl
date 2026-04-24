"""
    const GTS_FALLBACK_PARTICIPANT_ID = Int(typemax(Int32))

Some GTS sources are missing participant IDs but have a consistent name
("Synoptical message from GTS"). This constant is used as a fallback participant
ID for those sources to allow them to be included in the dataset without losing
the information that they are GTS sources.
"""
const GTS_FALLBACK_PARTICIPANT_ID = Int(typemax(Int32))

# isuppercase only works for single characters, so we check if all characters are uppercase
is_str_uppercase(s) = all(x -> isuppercase(x) || !isletter(x), s)

"""
    is_header_row(line) -> Bool

Checks if a given line from the CSV file is likely to be the header row by verifying
that it contains at least two comma-separated parts and that all parts
are uppercase (ignoring whitespace).
"""
function is_header_row(line)
    parts = split(line, ',')
    length(parts) < 2 && return false
    for part in split(line, ',')
        if !is_str_uppercase(strip(part))
            return false
        end
    end
    return true
end

"""
    detect_header_row(io::IO) -> Int

Detects the line number of the header row in a CSV file by reading through the lines of the provided `IO`
stream and checking each line with `is_header_row`. If a header row is found, it returns the line number. If no header row is found after reading through the entire file, it throws an `ArgumentError`.
"""
function detect_header_row(io::IO)
    seekstart(io)
    for (i, line) in enumerate(eachline(io))
        if is_header_row(line)
            seekstart(io)
            return i
        end
    end
    seekstart(io)
    throw(ArgumentError("No header line found in the provided IO stream"))
end
detect_header_row(filename::AbstractString) = open(detect_header_row, filename)


"""
    dms2arcsec(dms::AbstractString) -> Int

Converts a DMS (Degrees, Minutes, Seconds) string to total arcseconds as an integer.
Divide the result by 3600 to get decimal degrees.
"""
function dms2arcsec(dms)
    degree, minutes, seconds = Int.(parse_dms(dms))
    return degree * 3600 + minutes * 60 + seconds
end

parse_ymd_date(d::AbstractString) = Date(d, dateformat"yyyymmdd")
parse_ymd_date(d::Integer) = parse_ymd_date(string(d))

const CSV_BASE_OPTIONS = (
    delim = ',',
    normalizenames = true,
    ignoreemptyrows = true,
    stripwhitespace = true,
)

"""
    normalize_embedded_commas(io::IO, header_line, col_name) -> IOBuffer

Streams `io` into an `IOBuffer`, quoting any unquoted commas inside
the field `col_name`.

# Arguments
- `io`: An `IO` stream containing the CSV data.
- `header_line`: The line number of the header row in the CSV data.
- `col_name`: The name of the column to check for embedded commas.

# Returns
- A new `IOBuffer` containing the normalized CSV data with embedded commas in
    `col_name` properly quoted.
"""
function normalize_embedded_commas(
        io::IO,
        header_line::Int,
        col_name::AbstractString,
    )
    seekstart(io)
    buf = IOBuffer()
    expected_cols = 0
    col_idx = 0
    n_trailing = 0

    for (i, line) in enumerate(eachline(io))
        i < header_line && continue

        if i == header_line
            parts = split(line, ',')
            expected_cols = length(parts)
            col_idx = findfirst(==(col_name), strip.(parts))
            isnothing(col_idx) && throw(ArgumentError("Column '$col_name' not found in header"))
            n_trailing = expected_cols - col_idx
            write(buf, line, '\n')
            continue
        end

        isempty(strip(line)) && continue

        if count(==(','), line) == expected_cols - 1
            write(buf, line, '\n')
        else
            parts = split(line, ',')
            for j in 1:(col_idx - 1)
                write(buf, parts[j], ',')
            end
            write(buf, '"', join(@view(parts[col_idx:(end - n_trailing)]), ','), '"')
            for j in (length(parts) - n_trailing + 1):length(parts)
                write(buf, ',', parts[j])
            end
            write(buf, '\n')
        end
    end

    seekstart(buf)
    seekstart(io)
    return buf
end


function digest_sources(io)
    header_line = detect_header_row(io)
    io = normalize_embedded_commas(io, header_line, "SOUNAME")
    return CSV.read(
        io, DataFrame;
        CSV_BASE_OPTIONS...,
        missingstring = ["", "-"],
    )
end

function digest_stations(io)
    header_row = detect_header_row(io)
    return CSV.read(
        io, DataFrame;
        CSV_BASE_OPTIONS...,
        skipto = header_row + 1,
        header = header_row,
    )
end


"""Resolve the GTS participant ID for rows whose participant is missing but name matches."""
function resolve_participant_id(id, name)
    return ismissing(id) && name == "Synoptical message from GTS" ? GTS_FALLBACK_PARTICIPANT_ID : id
end


function to_sources_df(raw::DataFrame)
    df = select(
        raw,
        :SOUID => :id,
        :SOUNAME => :name,
        :STAID => :station_id,
        :START => ByRow(parse_ymd_date) => :start_date,
        :STOP => ByRow(parse_ymd_date) => :stop_date,
        :CN => :country_code,
        :LON => ByRow(dms2arcsec) => :longitude_arcsec,
        :LAT => ByRow(dms2arcsec) => :latitude_arcsec,
        :HGHT => :height_meter,
        :PARID => :participant_id,
        :PARNAME => :participant_name,
        :ELEI => :element_id,
    )
    # Fold GTS fixup into a single transform rather than a separate @rtransform! pass
    @rtransform! df :participant_id = resolve_participant_id(:participant_id, :participant_name)
    return df
end

function to_stations_df(raw::DataFrame)
    return select(
        raw,
        :STAID => :id,
        :STANAME => :name,
        :CN => :country_code,
        :LAT => ByRow(dms2arcsec) => :latitude_arcsec,
        :LON => ByRow(dms2arcsec) => :longitude_arcsec,
        :HGHT => :height_meter,
    )
end


function digest_observations(io)
    header_line = detect_header_row(io)
    return CSV.read(
        io, DataFrame;
        delim = ',',
        normalizenames = true,
        ignoreemptyrows = true,
        skipto = header_line + 1,
        header = header_line,
        stripwhitespace = true,
        missingstring = ["", "-9999"],
    )
end

const QUALITY_LABELS = ["valid", "suspect", "missing"]
function quality_label(q)
    q == 0 && return "valid"
    q == 1 && return "suspect"
    ismissing(q) && return "missing"
    q == 9 && return "missing"
    throw(ArgumentError("Unknown quality code: $q"))
end

function to_observations_df(df, sources_df)
    res = select(
        df,
        :STAID => :station_id,
        :SOUID => :source_id,
        :DATE => ByRow(parse_ymd_date) => :date,
        4 => :value,
        5 => ByRow(quality_label) => :quality,
    )
    res.quality = categorical(res.quality, ordered = true, levels = QUALITY_LABELS)
    repair_source_ids!(res, sources_df)
    source_element = select(sources_df, :id => :source_id, :element_id)
    res = leftjoin(res, source_element, on = :source_id)
    return res
end


# ──────────────────────────── Repair bad sources ──────────────────────────── #

"""
    repair_bad_source_ids!(observation_df, sources_df)

Checks if:
- There is only one unique `station_id` in `observation_df`.
- `source_id` values in `observation_df` match any `id` in `sources_df` for the
corresponding `station_id`.

If there are `source_id` values in `observation_df` that do not match any `id` in `sources_df`
for the same `station_id`, the function attempts to repair them using a series of heuristics
defined in [`resolve_invalid_source_ids`](@ref).

# Arguments
- `observation_df`: A DataFrame containing the observations, with at least `station_id`
  and `source_id` columns.
- `sources_df`: A DataFrame containing the sources, with at least `id` and `station_id`
  columns.

# Returns
- `true` if all `source_id` values in `observation_df` are valid or were successfully repaired.
- `false` if there are still invalid `source_id` values after attempting repairs,
  or if there are multiple `station_id` values in `observation_df`. Also logs warnings in these cases.
"""
function repair_source_ids!(observation_df, sources_df; source_name = "(input)")
    stations = unique(observation_df.station_id)
    if length(stations) != 1
        @warn "File $source_name contains multiple station IDs: $(stations). Skipping."
        return false
    end

    station = only(stations)
    available_sources = let
        x1 = @select(sources_df, :id, :station_id)
        @rsubset!(x1, :station_id == station)
        @select!(x1, :id)
        collect(x1.id)
    end

    obs_sources = unique(observation_df.source_id)
    fixes, bad_sources = resolve_invalid_source_ids(obs_sources, available_sources)
    if !isempty(bad_sources)
        @warn "Could not find matches for bad source IDs $(bad_sources) in file $(source_name). Skipping."
        return false
    end
    if !isempty(fixes)
        @rtransform!(observation_df, :source_id = get(fixes, :source_id, :source_id))
    end
    return true
end

"""
    resolve_invalid_source_ids(obs_sources, available_sources; fix_funcs!)

Given a list of `obs_sources` and `available_sources`,
attempts to find matches for any `obs_sources` that are not in `available_sources`
using a series of provided fixing functions (`fix_funcs!`).

# Arguments

- `obs_sources`: A collection of source IDs from the observations that need to be checked.
- `available_sources`: A collection of valid source IDs that can be matched against.
- `fix_funcs!`: An optional collection of functions that implement heuristics to find
  matches for bad source IDs. Each function should have the signature
  `fix!(fixes::Dict, bad_sources, available_sources)` and should update the `fixes` dictionary
  fixes[bad_source] = matched_available_source for any matches it finds.

# Returns
- `fixes`: A dictionary mapping any `obs_sources` that were successfully matched to their
  corresponding `available_sources`.
- `bad_sources`: A collection of any `obs_sources` that could not be matched to any
  `available_sources` after all fixing functions were applied.
"""
function resolve_invalid_source_ids(obs_sources, available_sources; fix_funcs! = SOURCE_TO_FIXERS)
    bad_sources = setdiff(obs_sources, available_sources)
    fixes = Dict{eltype(obs_sources), eltype(available_sources)}()
    isempty(bad_sources) && return fixes, bad_sources
    for fix! in fix_funcs!
        fix!(fixes, bad_sources, available_sources)
        setdiff!(bad_sources, keys(fixes))
        isempty(bad_sources) && return fixes, bad_sources
    end
    return fixes, bad_sources
end


"""
    patch_substring!(fixes::Dict, bad_sources, available_sources)

A fix for [`resolve_invalid_source_ids`](@ref) that attempts to match any `bad_sources` that are substrings of
any `available_sources`.
"""
function patch_substring!(fixes::Dict, bad_sources, available_sources)
    for bad_source in bad_sources
        for available_source in available_sources
            if occursin(string(bad_source), string(available_source))
                fixes[bad_source] = available_source
                break
            end
        end
    end
    return fixes
end

"""
    patch_first_digit!(fixes::Dict, bad_sources, available_sources)

A fix for [`resolve_invalid_source_ids`](@ref) that attempts to match any `bad_sources` that match
an `available_sources` after removing the first character (e.g. if the bad source is
"12345" and there is an available source "22345").
"""
function patch_first_digit!(fixes::Dict, bad_sources, available_sources)
    for bad_source in bad_sources
        for available_source in available_sources
            if occursin(string(bad_source)[2:end], string(available_source))
                fixes[bad_source] = available_source
                break
            end
        end
    end
    return fixes
end

const SOURCE_TO_FIXERS = [patch_substring!, patch_first_digit!]
