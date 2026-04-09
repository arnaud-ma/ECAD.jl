module ECAD

using ArgCheck: @argcheck
using AstroAngles: parse_dms
using CSV: CSV
using DataDeps: DataDeps, DataDep
using DataFrames: Not, innerjoin, ncol, nrow, outerjoin, rename!
using DataFramesMeta: @rsubset, @rsubset!, @rtransform!, @select, @select!, @transform!, ByRow, DataFrame,
    leftjoin, select, select!
using Dates: @dateformat_str, Date, Day
using Downloads: Downloads
using InteractiveUtils: subtypes
using Mmap: Mmap
using Printf: @sprintf
using ProgressMeter: ProgressMeter, Progress, finish!
using SplitApplyCombine: invert
using TypedTables: TypedTables
using URIs: resolvereference
using ZipArchives: ZipArchives, ZipReader, zip_names, zip_readentry


include("utils.jl")

include("variables.jl")
export canonical_name, longname, pretty_name, summary_variables
public @defvariable

include("data.jl")
export dataset_zip

include("ingestion.jl")

include("variable_data.jl")
export VariableData
export variable, zipfile, zipcontent
export station_ids
export load_sources, load_stations, load_elements, load_observations


include("station.jl")
export StationData
export intersect_stations

function __init__()
    return _init_datadep()
end

end
