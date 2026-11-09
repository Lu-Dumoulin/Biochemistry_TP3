# Usage (from Pluto_jl/):
#   julia --project=. test/runtests.jl          # unit, then e2e
#   julia --project=. test/runtests.jl unit     # one level
using Test

const LEVELS = isempty(ARGS) ? ["unit", "e2e"] : ARGS

@testset "MT practical (Pluto)" begin
    for level in LEVELS, file in sort(readdir(joinpath(@__DIR__, level); join=true))
        endswith(file, ".jl") && include(file)
    end
end
