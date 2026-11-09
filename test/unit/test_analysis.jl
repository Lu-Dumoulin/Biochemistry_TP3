using Test, Random, Statistics
include(joinpath(@__DIR__, "..", "support", "load.jl"))

const DATA = joinpath(@__DIR__, "..", "..", "data")
segment_table(lines...) = IOBuffer(join(["condition,track,state,duration_s,delta_length_um,end_event,source"; collect(lines)], "\n"))

@testset "Analysis helpers" begin

@testset "the synthetic fallback reproduces the instructor-guide estimates" begin
    # Arrange
    rows = read_segments(joinpath(DATA, "synthetic_segments.csv"))

    # Act
    s = summarize_segments(rows)

    # Assert: values from the instructor guide.
    @test s.n_tracks == 12
    @test (s.n_catastrophes, s.n_rescues) == (86, 19)
    @test s.growing_time ≈ 6237.35 atol = 0.01
    @test s.shrinking_time ≈ 962.65 atol = 0.01
    @test s.catastrophe ≈ 0.01379 atol = 1e-5
    @test s.rescue ≈ 0.01974 atol = 1e-5
end

@testset "censored time counts as time at risk, seed restarts are not rescues" begin
    # Arrange
    rows = read_segments(segment_table("c,1,G,10,1.0,catastrophe,x", "c,1,S,2,-1.0,seed_restart,x",
                                       "c,1,G,30,3.0,censored,x"))

    # Act
    s = summarize_segments(rows)

    # Assert
    @test s.catastrophe ≈ 1 / 40
    @test s.n_rescues == 0
    @test s.vg ≈ 0.1 && s.vs ≈ 0.5
end

@testset "the empty template is refused with a helpful message" begin
    # Arrange
    template = joinpath(DATA, "experimental_segments_template.csv")

    # Act & Assert
    @test_throws "No rows" read_segments(template)
end

@testset "segment errors name the line" begin
    # Arrange
    wrong_sign = segment_table("c,1,G,10,1.0,catastrophe,x", "c,1,S,2,1.0,rescue,x")
    wrong_event = segment_table("c,1,G,10,1.0,rescue,x")

    # Act & Assert
    @test_throws "Line 3" read_segments(wrong_sign)
    @test_throws "cannot end with" read_segments(wrong_event)
end

@testset "bootstrap intervals bracket the pooled estimate" begin
    # Arrange
    rows = read_segments(joinpath(DATA, "synthetic_segments.csv"))
    s = summarize_segments(rows)

    # Act
    ci = bootstrap_tracks(rows; repeats=200)

    # Assert
    for k in (:vg, :vs, :catastrophe, :rescue)
        @test ci[k][1] <= s[k] <= ci[k][2]
    end
end

@testset "a simulated run analyzed as segments gives back its internal counts" begin
    # Arrange
    r = simulate_switching(; t_end=3000, seed=3)
    internal = switching_statistics(r)

    # Act
    s = summarize_segments(simulated_segments(r))

    # Assert
    @test s.n_catastrophes == internal.catastrophes
    @test s.n_rescues == internal.rescues
    @test s.growing_time ≈ internal.growing_time
    @test s.shrinking_time ≈ internal.shrinking_time
    @test s.vg ≈ 0.03 atol = 1e-3
    @test s.vs ≈ 0.18 atol = 1e-3
end

@testset "a single fast collapse is counted once" begin
    # Arrange: rise to 20, fall to 2 in one time unit, regrow.
    L = [0, 5, 10, 15, 20, 14, 8, 2, 4, 6, 8]
    r = (; t=collect(0.0:0.5:5.0), length=L)

    # Act
    c = count_collapses(r; drop=5, window=2.0)

    # Assert
    @test length(c) == 1
    @test c[1] == (2.0, 20)
end

@testset "a slow decline is not a collapse" begin
    # Arrange
    r = (; t=collect(0.0:1.0:10.0), length=[20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10])

    # Act
    c = count_collapses(r; drop=5, window=2.0)

    # Assert
    @test isempty(c)
end

@testset "two collapses separated by regrowth are both counted" begin
    # Arrange
    r = (; t=collect(0.0:1.0:9.0), length=[10, 2, 5, 8, 12, 15, 3, 4, 5, 6])

    # Act
    c = count_collapses(r; drop=5, window=1.0)

    # Assert
    @test length(c) == 2
end

@testset "the material image marks T, D and empty sites" begin
    # Arrange
    r = simulate_chain(with(DYNAMIC_INSTABILITY; hydrolysis=0); initial_length=10, initial_T=10,
                       t_end=5, sample_dt=1)

    # Act
    m = material_image(r)

    # Assert: no hydrolysis, so every occupied site is T.
    @test all(in((0, 2)), m.image)
    @test vec(sum(m.image .== 2; dims=2)) == r.length
end

@testset "the pulse image marks only material added during the pulse" begin
    # Arrange
    r = simulate_chain(TREADMILLING; seeded=false, initial_length=50, initial_T=10,
                       t_end=80, sample_dt=1, seed=2)

    # Act
    m = material_image(r; mode=:pulse, pulse=(50, 60))

    # Assert: nothing is labeled before the pulse starts.
    @test !any(m.image[r.t .< 50, :] .== 2)
    @test any(m.image[r.t .>= 60, :] .== 2)
end

@testset "following the minus end starts every row at column 1" begin
    # Arrange
    r = simulate_chain(TREADMILLING; seeded=false, initial_length=50, initial_T=10,
                       t_end=40, sample_dt=1, seed=3)

    # Act
    m = material_image(r; frame=:minus_end)

    # Assert
    @test first(m.sites) == 0
    @test all(m.image[j, 1] != 0 for j in eachindex(r.t) if r.length[j] > 0)
    @test vec(sum(m.image .!= 0; dims=2)) == r.length
end

@testset "the chain CSV records parameters, seed and every sample" begin
    # Arrange
    r = simulate_chain(DYNAMIC_INSTABILITY; t_end=10, sample_dt=1, seed=7,
                       initial_length=10, initial_T=10)

    # Act
    lines = split(chomp(chain_csv(r)), "\n")

    # Assert
    @test occursin("random seed=7", lines[3])
    @test occursin("hydrolysis=1.0", lines[2])
    @test lines[4] == "t,length,cap,nT,plus_net,minus_net,xminus,xplus"
    @test length(lines) == 4 + length(r.t)
end

@testset "trace_events follows the worked example of the manual" begin
    # Arrange: two T subunits at the plus end, u+ = 2, w+T = 0.2, h = 1.
    p = ChainParameters(plus_on=2, plus_off_T=0.2, plus_off_D=20, hydrolysis=1)

    # Act
    steps = trace_events(p; n_events=1, initial_length=2, initial_T=2)

    # Assert
    @test steps[1].event == :start
    @test steps[2].total ≈ 4.2
    @test steps[2].rates.hydrolysis ≈ 2.0
end

@testset "trace_events and simulate_chain apply the same rules" begin
    # Arrange
    p = DYNAMIC_INSTABILITY

    # Act
    steps = trace_events(p; n_events=200, seed=9, initial_length=10, initial_T=10)
    t_last = steps[end].t
    r = simulate_chain(p; seed=9, initial_length=10, initial_T=10, t_end=t_last + 1e-9,
                       sample_dt=t_last / 2)

    # Assert: same random stream, same final chain.
    @test r.length[end] == length(steps[end].chain)
    @test r.nT[end] == count(steps[end].chain)
end

end
