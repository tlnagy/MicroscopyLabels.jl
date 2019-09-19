# MicroscopyLabels isn't published yet so we need to add the source directly
push!(LOAD_PATH, normpath(joinpath(@__DIR__, "..", "src")))

using Documenter, MicroscopyLabels

makedocs(sitename="MicroscopyLabels.jl")

deploydocs(
    repo = "github.com/tlnagy/MicroscopyLabels.jl.git",
)