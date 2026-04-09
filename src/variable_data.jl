"""
    VariableData(variable::Variable, filepath::String; memory_map = true)

A variable with its associated data. If you don't know what memory_map means, keep it to true.

# Fields

- `variable::Variable`: The variable this data corresponds to.
- `filepath::String`: The path to the zip file containing the data for this variable.
- `content::ZipReader{<:AbstractVector{UInt8}}`: A `ZipReader` instance for reading the contents of the zip file.

Accessor methods are provided for convenience:
- [`variable(var::VariableData)`](@ref): Get the variable.
- [`zipfile(var::VariableData)`](@ref): Get the path to the zip file.
- [`zipcontent(var::VariableData)`](@ref): Get the `ZipReader` for the zip file.
- `ZipArchives.zip_names(var::VariableData)`: Get the list of file names in the zip archive.
- `ZipArchives.zip_readentry(var::VariableData, args...; kwargs...)`: Read a specific entry from the zip archive.

To load specific data, use the provided functions:
- [`load_sources(var::VariableData)`](@ref): Load the sources data frame from the zip file.
- [`load_stations(var::VariableData)`](@ref): Load the stations data frame from the zip file.
- [`load_elements(var::VariableData)`](@ref): Load the elements data frame from the local elements file.
- [`load_elements(var::VariableData, file)`](@ref): Load the elements data frame from a specified file.
- [`load_observations(var::VariableData, station_id)`](@ref): Load the observations data frame for a specific station ID from the zip file.
"""
struct VariableData{B <: AbstractVector{UInt8}}
    variable::Variable
    filepath::String
    content::ZipReader{B}
end

function VariableData(variable, filepath::String; memory_map = true)
    @argcheck isfile(filepath)
    bytes = memory_map ? Mmap.mmap(filepath) : read(filepath)
    content = ZipReader(bytes)
    return VariableData{typeof(bytes)}(variable, filepath, content)
end


# allow broadcasting, treat as scalar
Base.broadcastable(var::VariableData) = Ref(var)

VariableData(variable::Variable) = VariableData(variable, dataset_zip(variable))
VariableData(name) = VariableData(from_name(name))


"""
    variable(var::VariableData) -> Variable

The variable associated with the given `VariableData`.
"""
variable(var::VariableData) = var.variable

"""
    zipfile(var::VariableData) -> String

The path to the zip file associated with the given `VariableData`.
"""
zipfile(var::VariableData) = var.filepath

"""
    zipcontent(var::VariableData) -> ZipReader

The `ZipReader` instance for the zip file associated with the given `VariableData`.
"""
zipcontent(var::VariableData) = var.content


ZipArchives.zip_names(var::VariableData) = zip_names(zipcontent(var))
ZipArchives.zip_readentry(var::VariableData, args...; kwargs...) = zip_readentry(zipcontent(var), args...; kwargs...)


"""
    station_ids(var::VariableData) -> Vector{Int}

The list of station IDs available in the zip file for the given variable.
"""
function station_ids(var::VariableData)
    names = zip_names(zipcontent(var))
    prefix = string(canonical_NAME(variable(var)), "_STAID")
    ids = Int[]
    for name in names
        startswith(name, prefix) || continue
        m = match(r"STAID\d{6}", name)
        isnothing(m) && continue
        push!(ids, parse(Int, m.match[6:11]))
    end
    return ids
end


"""
    load_sources(var::VariableData) -> DataFrame

Load the sources data frame from the zip file for the given variable.

# Columns
- `id::Int`: The source ID. Example: `1`.
- `name::String`: The name of the source.  Example: "VAEXJOE"
- `station_id::Int`: The station ID associated with this source. Example: `123`.
- `start_date::Data`: The first date of observations from this source. Example: `Date(1950, 1, 1)`.
- `end_date::Date`: The last date of observations from this source. Example: `Date(2020, 12, 31)`.
- `country_code::String`: The [ISO](https://www.iso.org/obp/ui) country code of the source. Example: "SE" for Sweden.
- `longitude_arcsec::Int`: The longitude of the source in arcseconds.
- `latitude_arcsec::Int`: The latitude of the source in arcseconds.
- `height_meter::Int`: The height of the source in meters.
- `participant_id::Int`: The ID of the participant that provided this source. Example: `42`.
- `participant_name::String`: The name of the participant that provided this source. Example: ""Marcus Flarup"
- `element_id::Int`: The ID of the element observed by this source. See [`load_elements`](@ref) for more info.
"""
function load_sources(var::VariableData)
    file = "sources.txt"
    @argcheck file in zip_names(zipcontent(var))
    x1 = zip_readentry(var, file)
    x2 = IOBuffer(x1)
    x3 = digest_sources(x2)
    x4 = to_sources_df(x3)
    return x4
end

"""
    load_stations(var::VariableData) -> DataFrame

Load the stations data frame from the zip file for the given variable.

# Columns
- `id::Int`: The station ID. Example: `123`.
- `name::String`: The name of the station. Example: "VAEXJOE".
- `country_code::String`: The [ISO](https://www.iso.org/obp/ui) country code of the station. Example: "SE" for Sweden.
- `longitude_arcsec::Int`: The longitude of the station in arcseconds.
- `latitude_arcsec::Int`: The latitude of the station in arcseconds.
- `height_meter::Int`: The height of the station in meters.
"""
function load_stations(var::VariableData)
    file = "stations.txt"
    @argcheck file in zip_names(zipcontent(var))
    x1 = zip_readentry(var, file)
    x2 = IOBuffer(x1)
    x3 = digest_stations(x2)
    x4 = to_stations_df(x3)
    return x4
end

"""
    load_elements() -> DataFrame
    load_elements(var::VariableData, file = nothing) -> DataFrame

Load the elements for the given variable, or everything. Elements are variants of the same variable
that may have different units or observation methods. For example, for :tg (temperature mean),
a variant simply compute the mean of the daily max and min, while another method compute the mean of
each hourly observation.

# Columns
- `element_id::Int`: The element ID. Example: `TX1` for the first element of the :tx (temperature max) variable.
- `description::String`: A description of the element. Example: "Daily maximum temperature calculated from the maximum of the daily observations".
- `unit::String`: The unit of the element. Example: "0.1°C".
- `variable_id::String`: The canonical name of the variable this element belongs to. Example: "TX" for :tx (temperature max).
- `variable_name::String`: A human-readable name of the variable this element belongs to. Example: "MAX TEMPERATURE" for :tx (temperature max).
"""
function load_elements(file::String)
    @argcheck isfile(file) "Elements file not found: $file"
    df = CSV.read(file, DataFrame)
    group_name, group_ids = split.(df[!, "Ele Group"], "("; limit = 2) |> invert
    df = @transform! df begin
        :variable_name = strip.(group_name)
        :variable_id = strip.(group_ids, ')')
    end

    return select!(
        df,
        "Ele ID" => :element_id,
        :Description => :description,
        :Unit => ByRow(u -> replace(u, " " => "")) => :unit,
        :variable_id,
        :variable_name,
    )
end
const ELEMENTS = joinpath(something(pkgdir(ECAD)), "data", "elements.csv") |> load_elements
load_elements() = ELEMENTS
load_elements(::Nothing) = load_elements()

function load_elements(var::VariableData, file = nothing)
    elements = load_elements(file)
    variable_id = var |> variable |> canonical_name |> string |> uppercase
    @assert variable_id in elements.variable_id "Variable ID $(variable_id) not found in elements file"
    return @rsubset(elements, :variable_id == variable_id)
end

"""
    load_observations(var::VariableData, station_id::Integer) -> DataFrame

Load the observations for the given variable and station ID from the zip file.
The station ID must be one of the IDs returned by `station_ids(var)`.

A warning is emitted if there are multiple elements in the observations, meaning
that the observations may have different units / observation methods.
In that case, the elements data frame returned by `load_elements(var)`
should be consulted to see what each element ID means.

# Columns
- `station_id::Int`: The station ID. Example: `123`.
- `source_id::Int`: The source ID associated with this observation.
    Example: `1`. See [`load_sources`](@ref) for more info on sources.
- `element_id::Int`: The element ID associated with this observation.
    Example: `TX1` for the first element of the :tx (temperature max) variable. See [`load_elements`](@ref) for more info on elements.
- `date::Date`: The date of the observation. Example: `Date(1950, 1, 1)`.
- `value::Int64?`: The value of the observation, or `missing` if not available.
    The unit depends on the element. See the `unit` column in the data frame returned by [`load_elements`](@ref) for more info on the unit of each element.
- `quality::String`: The quality flag of the observation. Is one of "valid", "suspect" or "missing".
"""
function load_observations(var::VariableData, station_id::Integer; warn_multiple_elements = true)
    obs_file = string(canonical_NAME(variable(var)), "_", @sprintf("STAID%06.d.txt", station_id))
    @argcheck obs_file in zip_names(zipcontent(var)) "Observation file for station $station_id not found in archive: $obs_file"
    result = let
        x1 = zip_readentry(var, obs_file)
        x2 = IOBuffer(x1)
        x3 = digest_observations(x2)
        to_observations_df(x3, load_sources(var))
    end
    if warn_multiple_elements
        uni = unique(result.element_id)
        if length(uni) > 1
            @warn "Multiple element IDs found in observation file for station $station_id: $(map(String, uni)). \
                Which means that e.g. the observations does not have the same unit. \
                Read elements df with load_elements(var) for the info of what each element ID means."
        end
    end
    return result
end


# ---------------------------------------------------------------------------- #
#                                    Display                                   #
# ---------------------------------------------------------------------------- #

function Base.show(io::IO, var::VariableData)
    v = variable(var)
    name = uppercase(string(canonical_name(v)))
    entries = length(zip_names(zipcontent(var)))
    print(
        io,
        "VariableData(",
        "variable=", v,
        ", name=", name,
        ", zip=\"", basename(zipfile(var)), "\"",
        ", entries=", entries,
        ")",
    )
    return nothing
end

function Base.show(io::IO, _mime::MIME"text/plain", var::VariableData)
    v = variable(var)
    zf = zipfile(var)
    names = zip_names(zipcontent(var))
    stations = station_ids(var)

    println(io, "VariableData:")
    println(io, "├ Variable: ", canonical_name(v), " (", pretty_name(v), ") -> ", v)
    println(io, "├ Zip file: ", zf)
    println(io, "├ Archive entries: ", length(names))
    if isempty(stations)
        println(io, "├ Stations: none")
    else
        println(io, "├ Stations: ", length(stations), " (min=", minimum(stations), ", max=", maximum(stations), ")")
    end

    preview_n = min(4, length(names))
    if preview_n == 0
        print(io, "└ Files: none")
    else
        preview = join(names[1:preview_n], ", ")
        if length(names) > preview_n
            print(io, "└ Files: ", preview, ", ...")
        else
            print(io, "└ Files: ", preview)
        end
    end
    return nothing
end
