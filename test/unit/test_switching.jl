using Test, Random, Statistics
include(joinpath(@__DIR__, "..", "support", "load.jl"))

@testset "Switching model" begin

@testset "without switching, extension grows at exactly v_g" begin
    # Arrange
    vg, duration = 0.03, 100.0

    # Act
    r = simulate_switching(; t_end=duration, vg, catastrophe=0, rescue=0)

    # Assert
    @test r.length[end] ≈ 1 + vg * duration
    @test isempty(r.events)
end

@testset "the time grid ends exactly at t_end" begin
    # Arrange
    duration, dt = 0.07, 0.05

    # Act
    r = simulate_switching(; t_end=duration, dt)

    # Assert
    @test r.t == [0.0, 0.05, 0.07]
    @test r.exposure.G + r.exposure.S ≈ duration
end

@testset "the same seed reproduces the same trajectory" begin
    # Arrange
    run(seed) = simulate_switching(; seed)

    # Act
    a, b, c = run(7), run(7), run(8)

    # Assert
    @test a.length == b.length
    @test a.events == b.events
    @test a.length != c.length
end

@testset "reaching the seed restarts growth and is not counted as a rescue" begin
    # Arrange: catastrophe at the first step, never a rescue.
    first_step_only = let fired = Ref(false)
        (rng, rate, dt) -> (rate > 0 && !fired[]) ? (fired[] = true) : false
    end

    # Act
    r = simulate_switching(; t_end=20, catastrophe=0.015, rescue=0.03,
                           initial_length=1.0, decision=first_step_only)
    stats = switching_statistics(r)

    # Assert
    @test stats.catastrophes == 1
    @test stats.rescues == 0
    @test stats.seed_restarts == 1
    @test minimum(r.length) == 0
end

@testset "rejects a time step that makes k·dt larger than 0.1" begin
    # Arrange
    too_coarse = (; catastrophe=0.5, dt=0.5)

    # Act & Assert
    @test_throws ArgumentError simulate_switching(; too_coarse...)
end

@testset "rejects negative rates" begin
    # Arrange
    bad = (; rescue=-0.01)

    # Act & Assert
    @test_throws ArgumentError simulate_switching(; bad...)
end

@testset "switch_decision fires with probability k·dt" begin
    # Arrange
    rng = Xoshiro(3); n = 200_000; p = 0.2

    # Act
    fraction = count(_ -> switch_decision(rng, p, 1.0), 1:n) / n

    # Assert: within 5 binomial standard deviations.
    @test abs(fraction - p) < 5 * sqrt(p * (1 - p) / n)
    @test !switch_decision(rng, 0.0, 0.01)
    @test switch_decision(rng, 1.0, 1.0)
end

@testset "estimated catastrophe rate recovers the input over many runs" begin
    # Arrange
    kc = 0.015

    # Act
    rates = pooled(seed -> switching_statistics(simulate_switching(; t_end=5000, seed)).catastrophe_rate, 1:12)

    # Assert
    @test abs(mean(rates) - kc) < 4 * standard_error(rates)
end

@testset "bounded regime: long-run mean length matches Dogterom–Leibler" begin
    # Arrange
    p = (; vg=0.03, vs=0.18, catastrophe=0.015, rescue=0.03)
    regime = switching_regime(; p...)

    # Act
    means = pooled(seed -> mean(simulate_switching(; p..., t_end=20_000, seed).length), 1:8)

    # Assert
    @test regime.bounded
    @test regime.mean_length ≈ 3.0
    @test abs(mean(means) - regime.mean_length) < 0.1 * regime.mean_length
end

@testset "unbounded regime when growth outweighs shrinkage" begin
    # Arrange
    p = (; vg=0.05, vs=0.18, catastrophe=0.005, rescue=0.05)

    # Act
    regime = switching_regime(; p...)

    # Assert
    @test !regime.bounded
    @test regime.drift > 0
    @test regime.mean_length == Inf
end

end
