using ECAD
using Documenter
using DocumenterCitations
using Pkg: Pkg

PROJECT_TOML = Pkg.TOML.parsefile(joinpath(@__DIR__, "..", "Project.toml"))
AUTHORS = PROJECT_TOML["authors"]
GITHUB = "https://github.com/arnaud-ma/ECAD.jl"

bib = CitationBibliography(
    joinpath(@__DIR__, "src", "refs.bib"),
    style = :authoryear,
)

DocMeta.setdocmeta!(ECAD, :DocTestSetup, :(using ECAD); recursive = true)


makedocs(;
    modules = [ECAD],
    authors = join(", ", AUTHORS),
    sitename = "ECAD.jl",
    format = Documenter.HTML(;
        prettyurls = true,
        canonical = "https://arnaud-ma.github.io/ECAD.jl",
        edit_link = "main",
        assets = String["assets/citations.css"],
    ),
    pages = [
        "Home" => "index.md",
        "API" => "api.md",
    ],
    plugins = [bib],
)

deploydocs(;
    repo = GITHUB,
    devbranch = "main",
)
