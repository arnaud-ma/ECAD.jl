const DATA_LINK = "https://knmi-ecad-assets-prd.s3.amazonaws.com/download/"

"""
    download_progress(remote_filepath, local_directory_path)

Download a file from `remote_filepath` to `local_directory_path`
while displaying a progress bar.
"""
function download_progress(remote_filepath, local_directory_path)
    println("Downloading $remote_filepath to $local_directory_path")
    remote = string(remote_filepath)
    local_dir = string(local_directory_path)
    progress = Ref{Union{Progress, Nothing}}(nothing)
    output_file = joinpath(local_dir, basename(remote))
    Downloads.download(
        remote, output_file;
        progress = (total_bytes, bytes_downloaded) -> begin
            total_bytes <= 0 && return
            if isnothing(progress[])
                progress[] = Progress(
                    total_bytes;
                    desc = "Downloading $(basename(remote)) ($(human_bytes(total_bytes)))",
                    showspeed = true,
                    dt = 0.5,
                    output = stderr,
                )
            end
            p = progress[]
            if !isnothing(p)
                ProgressMeter.update!(p, bytes_downloaded)
            end
        end
    )
    p = progress[]
    if !isnothing(p)
        finish!(p)
    end
    return output_file
end

function _init_datadep()
    for var in all_variables()
        url = resolvereference(DATA_LINK, "ECA_blend_$(canonical_name(var)).zip")
        DataDeps.register(
            DataDep(
                "ECA&D_$(canonical_name(var))",
                """
                Dataset: ECA&D (European Climate Assessment & Dataset) - Predefined subset of daily observations
                Variable: $(canonical_name(var)) ($(pretty_name(var)))
                Website: https://www.ecad.eu/
                Data policy: https://knmi-ecad-assets-prd.s3.amazonaws.com/documents/ECAD_datapolicy.pdf (non-commercial research and educational use only)
                Source:  $DATA_LINK

                Klein Tank, A.M.G. and Coauthors, 2002. Daily dataset of 20th-century surface air
                temperature and precipitation series for the European Climate Assessment. Int. J. of Climatol.,
                22, 1441-1453.
                """,
                string(url),
                sha(var);
                fetch_method = download_progress,
            )
        )
    end
    return
end


"""
    dataset_zip(var)

Get the path to the zip file for the given variable.
The variable can be specified using any of its aliases, e.g. `:tx`, `:temperature_max`, or `"temperature_max"`.
"""
function dataset_zip(var)
    name = canonical_name(var)
    folder = DataDeps.resolve("ECA&D_$(name)", @__FILE__)
    file = "ECA_blend_$(name).zip"
    return joinpath(folder, file)
end

_init_datadep()
