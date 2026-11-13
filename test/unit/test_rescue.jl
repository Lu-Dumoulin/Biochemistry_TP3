using Test, Random, Statistics
include(joinpath(@__DIR__, "..", "support", "load.jl"))

@testset "Afternoon 5b: kymographs and rescue at exchange sites" begin

@testset "a traced sawtooth becomes growth and shrinkage rows" begin
    # Arrange: seed at col 10; grow 20 px in 40 rows, shrink back in 2 rows, pause, regrow.
    corners = [(1, 10), (41, 30), (43, 10), (60, 10), (100, 30)]

    # Act
    out = kymograph_segments(corners; px_per_um=10, px_per_min=20, track="k")

    # Assert: 2 µm grown in 2 min; the pause at the seed is excluded.
    @test [r.state for r in out.rows] == ["G", "S", "G"]
    @test [r.end_event for r in out.rows] == ["catastrophe", "seed_restart", "censored"]
    @test out.rows[1].delta_length_um ≈ 2.0
    @test out.rows[1].duration_s ≈ 120.0
    @test out.rows[2].duration_s ≈ 6.0
    @test isempty(out.warnings)
end

@testset "a shrinkage that stops above the seed is a rescue" begin
    # Arrange
    corners = [(1, 10), (41, 40), (44, 25), (80, 45)]

    # Act
    out = kymograph_segments(corners; px_per_um=10, px_per_min=20)

    # Assert
    @test [r.end_event for r in out.rows] == ["catastrophe", "rescue", "censored"]
end

@testset "with a known seed, the lowest rescue is not taken for the seed" begin
    # Arrange: the microtubule never returns to the seed, which ends at column 10.
    corners = [(1, 50), (41, 80), (44, 40), (80, 70)]

    # Act
    guessed = kymograph_segments(corners; px_per_um=10, px_per_min=20)
    known = kymograph_segments(corners; px_per_um=10, px_per_min=20, seed_col=10)

    # Assert
    @test [r.end_event for r in guessed.rows] == ["catastrophe", "seed_restart", "censored"]
    @test [r.end_event for r in known.rows] == ["catastrophe", "rescue", "censored"]
end

@testset "corners clicked out of time order are sorted, with a warning" begin
    # Arrange
    corners = [(41, 30), (1, 10), (43, 10)]

    # Act
    out = kymograph_segments(corners; px_per_um=10, px_per_min=20)

    # Assert
    @test !isempty(out.warnings)
    @test [r.state for r in out.rows] == ["G", "S"]
end

@testset "fewer than two corners give no rows and a message" begin
    # Arrange
    corners = [(1, 10)]

    # Act
    out = kymograph_segments(corners; px_per_um=10, px_per_min=20)

    # Assert
    @test isempty(out.rows)
    @test !isempty(out.warnings)
end

@testset "the Poisson interval brackets the count" begin
    for k in (0, 1, 3, 10, 100)
        # Arrange & Act
        lo, hi = poisson_interval(k)

        # Assert
        @test lo <= k <= hi
        @test lo >= 0
    end
end

@testset "Dogterom–Leibler predictions follow the paper's formulas" begin
    # Arrange: Table 1 of Schaer et al. 2023 and the critical rescue rate 4.05 / min.
    p = (; vg=0.016, vs=0.216, catastrophe=0.005)

    # Act
    below = dl_prediction(; p..., rescue=0.5 / 60)
    critical = dl_prediction(; p..., rescue=4.05 / 60)

    # Assert
    @test below.bounded
    @test below.p_complete ≈ 1 - below.r
    @test below.correlation ≈ (1 - below.r) / (1 + below.r)
    @test below.mean_length ≈ 0.016 / 0.005 / (1 - below.r)
    @test critical.r ≈ 1 atol = 0.01
end

@testset "pairs link each growth to the next completed shrinkage" begin
    # Arrange
    rows = [(; condition="c", track="1", state="G", duration_s=10.0, delta_length_um=2.0, end_event="catastrophe", source=""),
            (; condition="c", track="1", state="S", duration_s=1.0, delta_length_um=-1.5, end_event="rescue", source=""),
            (; condition="c", track="1", state="G", duration_s=10.0, delta_length_um=3.0, end_event="catastrophe", source=""),
            (; condition="c", track="1", state="S", duration_s=1.0, delta_length_um=-3.5, end_event="censored", source="")]

    # Act
    p = growth_shrink_pairs(rows)

    # Assert: the censored shrinkage is not used.
    @test p.growth == [2.0]
    @test p.shrink == [1.5]
end

@testset "without exchange there is no rescue: every shrinkage reaches the seed" begin
    # Arrange & Act
    runs = [simulate_res(; kx=0.0, seed=s) for s in 1:10]
    rows = reduce(vcat, [phase_segments(r; track=i) for (i, r) in enumerate(runs)])

    # Assert
    @test count(r -> r.end_event == "rescue", rows) == 0
    @test count(r -> r.end_event == "seed_restart", rows) > 0
end

@testset "without catastrophes the lattice grows at ka sites per second" begin
    # Arrange & Act
    r = simulate_res(; kcat=0.0, t_end=1000.0, seed=3)

    # Assert: 2 sites/s × 8 nm × 1000 s = 16 µm, Poisson noise ≈ 0.4 µm.
    @test abs(r.length[end] - 16.0) < 2.0
    @test isempty(r.events)
end

@testset "phases tile the run and match the exposure" begin
    # Arrange & Act
    r = simulate_res(; kx=3e-5, seed=5)
    rows = phase_segments(r)
    s = summarize_segments(rows)

    # Assert
    @test sum(p.t_end - p.t_start for p in r.phases) ≈ r.parameters.t_end
    @test s.growing_time ≈ r.exposure.G
    @test s.shrinking_time ≈ r.exposure.S
    @test s.n_catastrophes == count(e -> e[2] == :catastrophe, r.events)
end

@testset "spontaneous exchange alone gives the paper's rescue rate" begin
    # Arrange: k× = 1e-5 / s, as in Table 1; the paper reports about 0.5 rescue per minute.
    runs = [simulate_res(; seed=s) for s in 1:60]

    # Act
    s = summarize_segments(reduce(vcat, [phase_segments(r; track=i) for (i, r) in enumerate(runs)]))

    # Assert
    @test 0.35 < s.rescue * 60 < 0.7
end

@testset "with the effective rescue rate, P(reach the seed) follows Dogterom–Leibler" begin
    # Arrange
    runs = [simulate_res(; kx=2e-5, seed=s) for s in 1:60]
    rows = reduce(vcat, [phase_segments(r; track=i) for (i, r) in enumerate(runs)])
    s = summarize_segments(rows)

    # Act
    n_seed = count(r -> r.end_event == "seed_restart", rows)
    p_complete = n_seed / (n_seed + s.n_rescues)
    dl = dl_prediction(; vg=0.016, vs=0.216, catastrophe=0.005, rescue=s.rescue)

    # Assert
    @test abs(p_complete - dl.p_complete) < 0.06
end

@testset "rescue at exchange sites keeps growth and shrinkage more correlated" begin
    # Arrange: close to the transition, as in Fig. 7D of the paper.
    runs = [simulate_res(; kx=5e-5, seed=s) for s in 1:60]
    rows = reduce(vcat, [phase_segments(r; track=i) for (i, r) in enumerate(runs)])
    s = summarize_segments(rows)

    # Act
    p = growth_shrink_pairs(rows)
    c = pair_correlation(p.growth, p.shrink)
    dl = dl_prediction(; vg=0.016, vs=0.216, catastrophe=0.005, rescue=s.rescue)

    # Assert
    @test c > dl.correlation + 0.2
end

@testset "rescue positions are fractions of the length at the catastrophe" begin
    # Arrange & Act
    r = simulate_res(; kx=5e-5, seed=2)
    a = simulate_switching(; vg=0.016, vs=0.216, catastrophe=0.005, rescue=0.05, t_end=2700, seed=2)

    # Assert
    @test all(0 .< r.rescue_fraction .< 1)
    @test all(0 .<= switching_rescue_fraction(a) .< 1)
end

end
