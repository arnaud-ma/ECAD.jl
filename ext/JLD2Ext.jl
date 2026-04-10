module JLD2Ext

import JLD2
using ECAD: VariableData, Variable

struct VariableDataSerial
    variable::Variable
    filepath::String
end

JLD2.writeas(::Type{<:VariableData}) = VariableDataSerial

function JLD2.wconvert(::Type{VariableDataSerial}, v::VariableData)
    return VariableDataSerial(v.variable, v.filepath)
end

function JLD2.rconvert(::Type{<:VariableData}, v::VariableDataSerial)
    return VariableData(v.variable, v.filepath; memory_map = true)
end

end # module JLD2Ext
