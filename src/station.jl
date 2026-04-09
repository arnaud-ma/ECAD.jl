"""
    StationData(
        var_data::Union{VariableData, AbstractVector{<:VariableData}},
        station_id::Integer;
        include_sources = false
    ) -> StationData

A struct representing all the data available for a given station, including its metadata and observations
for multiple variables.

# Fields

- `id::Int`: The station ID. Example: `123`.
- `name::String`: The name of the station. Example: "VAEXJOE
- `latitude::Int`: The latitude of the station in arcseconds. Example: `1234567` for 34.2919°.
- `longitude::Int`: The longitude of the station in arcseconds. Example: `-1234567` for -34.2919°.
- `elevation::Int`: The elevation of the station in meters. Example: `100` for 100 meters above sea level.
- `variables::Vector{VariableData}`: The list of variables for which observations are included in this station data.
- `observations::DataFrame`: A data frame containing the observations for this station, with one row per date and variable.
    The columns are:
    - `station_id::Int`: The station ID. Example: `123`.
    - `date::Date`: The date of the observation. Example: `Date(1950, 1, 1)`.
    - For each variable, there are three columns:
        - `$(variable)_value`: The value of the observation for this variable. Example: `150` for a temperature of 15.0°C if the unit is 0.1
        - `$(variable)_quality`: The quality flag of the observation for this variable. Is one of "valid", "suspect" or "missing". Example: "valid".
        - `$(variable)_element_id`: The element ID of the observation for this variable. Example: `TX1` for the first element of the :tx (temperature max) variable.
"""
struct StationData
    id::Int
    name::String
    latitude::Int
    longitude::Int
    elevation::Int
    observations::DataFrame
    variables::Vector{VariableData}
end

"""
    raw_station(observations::DataFrame, var_data::VariableData, station_id::Integer) -> DataFrameRow

Extract the raw station metadata for a given station ID from the observations data frame and variable data.
This is used internally to ensure that the station metadata is consistent across multiple variables when building
a `StationData` for multiple variables.

# Returns
A `DataFrameRow` with the following attributes:
- `id::Int`: The station ID. Example: `123`.
- `name::String`: The name of the station. Example: "VAEXJOE
- `country_code::String`: The [ISO](https://www.iso.org/obp/ui) country code of the station. Example: "SE" for Sweden.
- `latitude_arcsec::Int`: The latitude of the station in arcseconds. Example: `1234567` for 34.2919°.
- `longitude_arcsec::Int`: The longitude of the station in arcseconds. Example: `-1234567` for -34.2919°.
- `height_meter::Int`: The height of the station in meters. Example: `100` for 100 meters above sea level.
"""
function raw_station(observations, var_data::VariableData{T}, station_id::Integer) where {T}
    station_ids = unique(observations.station_id)
    @argcheck length(station_ids) == 1 "Multiple station IDs found in observations for station $station_id: $(map(String, station_ids))"
    station_id = only(station_ids)
    x1 = load_stations(var_data)
    x2 = @rsubset(x1, :id == station_id)
    x3 = only(eachrow(x2))
    return x3
end

"""
    raw_observations(observations::DataFrame, var_data::VariableData; include_sources = false) -> DataFrame

Extract the raw observations for a given station ID from the observations data frame and
variable data, and rename the columns to include the variable name.

The columns are renamed as follows:
- `value` -> `$(variable)_value`
- `quality` -> `$(variable)_quality`
- `element_id` -> `$(variable)_element_id`
- `source_id` -> `$(variable)_source_id` (only if `include_sources = true`)
"""
function raw_observations(observations, var_data::VariableData; include_sources)
    name = var_data |> variable |> canonical_name
    rename!(
        observations,
        :value => name,
        :quality => Symbol("$(name)_quality"),
        :element_id => Symbol("$(name)_element_id")
    )

    if include_sources
        rename!(observations, :source_id => Symbol("$(name)_source_id"))
    else
        select!(observations, Not(:source_id))
    end
    return observations
end

function StationData(
        var_data::VariableData{T}, station_id::Integer;
        include_sources = false,
        warn_multiple_elements
    ) where {T}
    observations_pre = load_observations(var_data, station_id; warn_multiple_elements)
    station = raw_station(observations_pre, var_data, station_id)
    observations = raw_observations(observations_pre, var_data; include_sources)
    return StationData(
        station_id,
        station.name,
        station.latitude_arcsec,
        station.longitude_arcsec,
        station.height_meter,
        observations,
        [var_data],
    )
end

function StationData(
        vars_data::AbstractVector{<:VariableData}, station_id::Integer;
        include_sources = false,
        warn_multiple_elements = true,
    )
    observations = DataFrame()
    station_info = nothing

    for var_data in vars_data
        observations_pre = load_observations(var_data, station_id; warn_multiple_elements)

        if station_info === nothing
            station_info = raw_station(observations_pre, var_data, station_id)
        else
            @argcheck raw_station(observations_pre, var_data, station_id) == station_info "Station info mismatch for station $station_id between variables $(variable(var_data)) and $(variable(first(vars_data)))"
        end

        obs = raw_observations(observations_pre, var_data; include_sources)
        if isempty(observations)
            observations = obs
        else
            observations = outerjoin(observations, obs, on = [:station_id, :date], makeunique = true)
        end
    end
    return StationData(
        station_id,
        station_info.name,
        station_info.latitude_arcsec,
        station_info.longitude_arcsec,
        station_info.height_meter,
        observations,
        vars_data,
    )
end

"""
    intersect_stations(vars::AbstractVector{<:VariableData}) -> DataFrame

Find all stations that are present across **all** provided variables, returning
their shared metadata.

This is useful when you want to build a [`StationData`](@ref) for multiple
variables and need to know which station IDs are valid for all of them —
i.e. which stations have observations for every variable in `vars`.

Returns a `DataFrame` with one row per common station, with columns:
- `id::Int`: The station ID.
- `name::String`: The name of the station.
- `country_code::String`: The [ISO](https://www.iso.org/obp/ui) country code.
- `latitude_arcsec::Int`: The latitude in arcseconds.
- `longitude_arcsec::Int`: The longitude in arcseconds.
- `height_meter::Int`: The elevation in meters above sea level.

# Throws
- `ArgumentError` if `vars` is empty.

# Example
```julia
vars = VariableData.([:tg, :tx, :tn])
common = intersect_stations(vars)
station_data = StationData.(Ref(vars), common.id)
```
"""
function intersect_stations(vars::AbstractVector{<:VariableData})
    @argcheck !isempty(vars) "At least one variable must be provided"
    on_cols = [:id, :name, :country_code, :latitude_arcsec, :longitude_arcsec, :height_meter]
    return reduce(load_stations.(vars)) do x, y
        innerjoin(x, y, on = on_cols, validate = (true, true))
    end
end

# ---------------------------------------------------------------------------- #
#                                    Display                                   #
# ---------------------------------------------------------------------------- #

function Base.show(io::IO, station::StationData)
    vars = join(string.(variable.(station.variables)), ", ")
    print(
        io,
        "StationData(",
        "id=", station.id,
        ", name=\"", station.name, "\"",
        ", lat=", station.latitude, " arcsec",
        ", lon=", station.longitude, " arcsec",
        ", elev=", station.elevation, " m",
        ", vars=[", vars, "]",
        ", rows=", nrow(station.observations),
        ", cols=", ncol(station.observations),
        ")",
    )
    return nothing
end

function Base.show(io::IO, _mime::MIME"text/plain", station::StationData)
    obs = station.observations
    vars = string.(variable.(station.variables))

    println(io, "StationData:")
    println(io, "├ ID: ", station.id)
    println(io, "├ Name: ", station.name)
    println(io, "├ Coordinates: lat=", station.latitude, " arcsec, lon=", station.longitude, " arcsec")
    println(io, "├ Elevation: ", station.elevation, " m")
    println(io, "├ Variables (", length(vars), "): ", isempty(vars) ? "none" : join(vars, ", "))
    println(io, "├ Observations: ", nrow(obs), " rows × ", ncol(obs), " cols")

    cols = String.(names(obs))
    if ("date" in cols) && nrow(obs) > 0
        println(io, "├ Date range: ", minimum(obs.date), " -> ", maximum(obs.date))
    else
        println(io, "├ Date range: n/a")
    end

    preview_n = min(8, length(cols))
    if preview_n == 0
        print(io, "└ Columns: none")
    else
        preview = join(cols[1:preview_n], ", ")
        if length(cols) > preview_n
            print(io, "└ Columns: ", preview, ", ...")
        else
            print(io, "└ Columns: ", preview)
        end
    end
    return nothing
end
