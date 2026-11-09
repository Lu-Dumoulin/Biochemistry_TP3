using Test, Random, Statistics
include(joinpath(@__DIR__, "..", "support", "load.jl"))

@testset "T/D chain model" begin

@testset "length change equals net plus plus net minus additions" begin
    # Arrange
    cases = [(true, DYNAMIC_INSTABILITY), (false, TREADMILLING)]

    for (seeded, p) in cases
        # Act
        r = simulate_chain(p; seeded, initial_length=100, initial_T=20, t_end=300)

        # Assert
        @test r.length .- 100 == r.plus_net .+ r.minus_net
        @test r.length == r.xplus .- r.xminus
        @test all(0 .<= r.cap .<= r.nT .<= r.length)
        @test length(r.snapshots) == length(r.t)
    end
end

@testset "without hydrolysis an all-T chain never acquires D" begin
    # Arrange
    p = with(DYNAMIC_INSTABILITY; hydrolysis=0)

    # Act
    r = simulate_chain(p; initial_length=10, initial_T=10, t_end=100)

    # Assert
    @test r.length == r.nT
    @test r.counts.hydrolysis == 0
end

@testset "with changes only the named rates" begin
    # Arrange
    p = TREADMILLING

    # Act
    q = with(p; minus_on=0.5)

    # Assert
    @test q.minus_on == 0.5
    @test q.plus_on == p.plus_on && q.hydrolysis == p.hydrolysis
    @test_throws MethodError with(p; not_a_rate=1)
end

@testset "zero rates leave the chain frozen" begin
    # Arrange
    zero = ChainParameters(0, 0, 0, 0, 0, 0, 0)

    # Act
    r = simulate_chain(zero; initial_length=3, initial_T=3, t_end=10)

    # Assert
    @test all(==(3), r.length)
end

@testset "an empty unseeded chain stays empty (absorbing)" begin
    # Arrange
    p = TREADMILLING

    # Act
    r = simulate_chain(p; seeded=false, initial_length=0, initial_T=0)

    # Assert
    @test all(==(0), r.length)
    @test r.extinction_time == 0
end

@testset "an unseeded fragment can disappear and records when" begin
    # Arrange
    loss_only = ChainParameters(0, 2, 2, 0, 0, 0, 0)

    # Act
    r = simulate_chain(loss_only; seeded=false, initial_length=1, initial_T=1, t_end=30)

    # Assert
    @test r.extinction_time !== nothing
    @test r.length[end] == 0
end

@testset "a seeded chain regrows from zero extension" begin
    # Arrange
    growth_only = ChainParameters(2, 0, 0, 0, 0, 0, 0)

    # Act
    r = simulate_chain(growth_only; seeded=true, initial_length=0, initial_T=0, t_end=10)

    # Assert
    @test r.length[end] > 0
end

@testset "a seeded chain refuses minus-end rates" begin
    # Arrange
    p = TREADMILLING

    # Act & Assert
    @test_throws ArgumentError simulate_chain(p; seeded=true)
end

@testset "pure plus-end addition is a Poisson process" begin
    # Arrange
    rate, duration = 2.0, 10.0
    growth_only = ChainParameters(rate, 0, 0, 0, 0, 0, 0)

    # Act
    final = pooled(seed -> simulate_chain(growth_only; initial_length=0, initial_T=0,
                                          t_end=duration, seed, record_snapshots=false).length[end],
                   1:500)

    # Assert: mean and variance both equal rate × duration.
    @test abs(mean(final) - rate * duration) < 4 * sqrt(rate * duration / 500)
    @test 0.8 < var(final) / (rate * duration) < 1.2
end

@testset "each T hydrolyzes independently: survival is exp(−h t)" begin
    # Arrange
    h, duration, n0 = 0.5, 2.0, 50
    hydrolysis_only = ChainParameters(0, 0, 0, 0, 0, 0, h)

    # Act
    surviving = pooled(seed -> simulate_chain(hydrolysis_only; initial_length=n0, initial_T=n0,
                                              t_end=duration, seed, record_snapshots=false).nT[end],
                       1:200)

    # Assert
    expected = exp(-h * duration)
    @test abs(mean(surviving) / n0 - expected) < 0.02
end

@testset "the same seed reproduces the same chain history" begin
    # Arrange
    run(seed) = simulate_chain(DYNAMIC_INSTABILITY; initial_length=10, initial_T=10,
                               t_end=50, seed, record_snapshots=false)

    # Act
    a, b, c = run(4), run(4), run(5)

    # Assert
    @test a.length == b.length && a.counts == b.counts
    @test a.length != c.length
end

@testset "seeded dynamic-instability preset shows repeated collapses" begin
    # Arrange: instructor smoke check, a drop of ≥ 5 subunits within one 0.2 sample.
    drops(r) = count(<=(-5), diff(r.length))

    # Act
    n_drops = pooled(seed -> drops(simulate_chain(DYNAMIC_INSTABILITY; initial_length=10,
                                                  initial_T=10, t_end=250, sample_dt=0.2,
                                                  seed, record_snapshots=false)), 1:6)

    # Assert
    @test all(>=(2), n_drops)
end

@testset "treadmilling preset: opposite end fluxes of similar size" begin
    # Arrange: values from the instructor guide, 12 runs, window 100–400.
    run(seed) = end_currents(simulate_chain(TREADMILLING; seeded=false, initial_length=100,
                                            initial_T=20, t_end=400, sample_dt=1.0, seed,
                                            record_snapshots=false); start=100)

    # Act
    f = pooled(run, 1:12)
    jp, jm = [x.J_plus for x in f], [x.J_minus for x in f]

    # Assert
    @test abs(mean(jp) - 5.676) < 0.3
    @test abs(mean(jm) + 5.643) < 0.3
    @test abs(mean(jp .+ jm)) < 0.3
end

@testset "end_currents refuses a window that starts at the last sample" begin
    # Arrange
    r = simulate_chain(DYNAMIC_INSTABILITY; t_end=10, sample_dt=1, initial_length=10, initial_T=10)

    # Act & Assert
    @test_throws ArgumentError end_currents(r; start=10)
end

end
