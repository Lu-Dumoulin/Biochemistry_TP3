using Test
include(joinpath(@__DIR__, "..", "support", "load.jl"))

@testset "Schematics" begin

@testset "every schematic is a self-contained SVG with an accessible label" begin
    # Arrange
    figures = [levels_schematic(), kymograph_schematic(), two_state_schematic(),
               decision_schematic(0.2, [0.1, 0.5, 0.9]), course_map_schematic(),
               segments_schematic(), chain_events_schematic(), chain_events_schematic(two_ends=true),
               gillespie_schematic([2, 0.2, 0, 0, 2]; chosen=1), pulse_schematic(),
               chain_schematic([false, true, true]), chain_schematic(Bool[]; seeded=false),
               chain_schematic(trues(50))]

    for fig in figures
        # Act
        html = fig.content

        # Assert
        @test occursin("<svg", html) && occursin("</svg>", html)
        @test occursin("aria-label=", html)
        @test !occursin("NaN", html)
    end
end

@testset "the decision schematic counts draws below the threshold" begin
    # Arrange
    draws = [0.05, 0.15, 0.25, 0.95]

    # Act
    html = decision_schematic(0.2, draws).content

    # Assert
    @test occursin("2 of the 4 draws shown", html)
end

@testset "notebook links survive spaces and accents in the path" begin
    # Arrange
    path = "/Users/a b/OneDrive - Université de Genève/n.pluto.jl"

    # Act
    encoded = Schematics.encode_path(path)

    # Assert
    @test encoded == "/Users/a%20b/OneDrive%20-%20Universit%C3%A9%20de%20Gen%C3%A8ve/n.pluto.jl"
end

@testset "a link to an existing notebook opens it in Pluto" begin
    # Arrange
    path = @__FILE__

    # Act
    html = notebook_link(path, "Open me").content

    # Assert
    @test occursin("./open?path=", html)
    @test occursin("Open me", html)
end

@testset "a link to a missing notebook says it is in preparation" begin
    # Arrange
    path = joinpath(@__DIR__, "no_such_notebook.pluto.jl")

    # Act
    html = notebook_link(path, "Afternoon 9").content

    # Assert
    @test occursin("in preparation", html)
    @test !occursin("href", html)
end

@testset "the kymograph example respects v_g and v_s" begin
    # Arrange
    traj = Schematics.example_trajectory()

    # Act
    slopes = [(L1 - L0) / (t1 - t0) for (_, t0, L0, t1, L1) in traj.pieces]
    states = [p[1] for p in traj.pieces]

    # Assert
    @test all(isapprox.(slopes[states .== :G], 0.03))
    @test all(isapprox.(slopes[states .== :S], -0.18))
    @test count(e -> e[1] == :seed_restart, traj.events) == 1
end

end
