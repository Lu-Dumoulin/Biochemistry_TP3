# Loads the course modules the same way the notebooks do: by path, not as a package.
const SRC = joinpath(@__DIR__, "..", "..", "src")
isdefined(Main, :MTLab) || include(joinpath(SRC, "MTLab.jl"))
isdefined(Main, :Schematics) || include(joinpath(SRC, "Schematics.jl"))
isdefined(Main, :Widgets) || include(joinpath(SRC, "Widgets.jl"))
using .MTLab, .Schematics, .Widgets

# Pooled per-run summaries over independent seeds.
pooled(f, seeds) = [f(seed) for seed in seeds]
standard_error(x) = std(x) / sqrt(length(x))
