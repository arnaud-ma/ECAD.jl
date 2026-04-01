module ECAD

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
