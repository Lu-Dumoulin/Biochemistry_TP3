using Test, Random, Statistics
include(joinpath(@__DIR__, "..", "support", "load.jl"))
isdefined(Main, :Experiment) || include(joinpath(SRC, "Experiment.jl"))
using .Experiment

# Runs one condition of a model with small, fast settings.
function quick_runs(model_name, inputs=nothing; runs=4, duration=nothing, seed_base=0)
    m = model_by_name(model_name)
    s = inputs === nothing ? baseline_inputs(m) : inputs
    return m, s, run_condition(m, s; runs, duration=something(duration, m.duration), seed_base)
end

@testset "Experiment designer" begin

@testset "every example question names a valid design" begin
    for ex in EXAMPLES
        # Arrange
        m = model_by_name(ex.model)

        # Act
        s = setting(m, ex.setting)

        # Assert
        @test all(v -> v in s.grid, ex.values)
        @test observable(m, ex.observables[1]) isa Experiment.Observable
        @test ex.observables[2] == :none || observable(m, ex.observables[2]) isa Experiment.Observable
        @test control(m, ex.control) isa Experiment.Control
    end
end

@testset "every baseline value is on its own menu grid" begin
    for m in MODELS, s in m.settings
        # Arrange & Act
        on_grid = s.baseline in s.grid

        # Assert
        @test on_grid
    end
end

@testset "every observable gives one finite number per run at baseline" begin
    for m in MODELS
        # Arrange
        _, s, runs = quick_runs(m.name)

        for obs in m.observables
            # Act
            values = summarize(runs, obs, s; omit=m.omit, duration=m.duration)

            # Assert
            @test length(values) == length(runs)
            @test all(isfinite, values)
        end
    end
end

@testset "a condition changes only the chosen input" begin
    # Arrange
    m = model_by_name(:two_end_chain)

    # Act
    s = condition_inputs(m, :minus_off_D, 3.5)

    # Assert
    @test s[:minus_off_D] == 3.5
    @test all(s[k] == v for (k, v) in baseline_inputs(m) if k != :minus_off_D)
end

@testset "the no-switching control grows at exactly v_g" begin
    # Arrange
    m = model_by_name(:switching)
    s = control(m, :no_switching).apply(baseline_inputs(m))

    # Act
    _, _, runs = quick_runs(:switching, s; duration=300)

    # Assert
    @test all(r -> r.length[end] ≈ 1 + 0.03 * 300, runs)
    @test all(==(0), summarize(runs, observable(m, :catastrophe_rate), s; omit=0, duration=300))
end

@testset "the no-hydrolysis control shows no collapse" begin
    # Arrange
    m = model_by_name(:seeded_chain)
    s = control(m, :no_hydrolysis).apply(baseline_inputs(m))

    # Act
    _, _, runs = quick_runs(:seeded_chain, s)

    # Assert
    @test all(==(0), summarize(runs, observable(m, :collapse_rate), s; omit=m.omit, duration=m.duration))
end

@testset "the protected and empty controls give their predicted survival" begin
    # Arrange
    m = model_by_name(:two_end_chain)
    protected = control(m, :protected).apply(baseline_inputs(m))
    empty = control(m, :empty).apply(baseline_inputs(m))

    # Act
    _, _, safe = quick_runs(:two_end_chain, protected; duration=200)
    _, _, gone = quick_runs(:two_end_chain, empty; duration=200)
    survived = observable(m, :survived)

    # Assert
    @test all(==(1), summarize(safe, survived, protected; omit=100, duration=200))
    @test all(==(0), summarize(safe, observable(m, :J_minus), protected; omit=100, duration=200))
    @test all(==(0), summarize(gone, survived, empty; omit=100, duration=200))
end

@testset "scaling all rates keeps the mean length but scales turnover" begin
    # Arrange
    m = model_by_name(:two_end_chain)
    slow = condition_inputs(m, :rate_scale, 0.5)

    # Act
    _, s1, fast_runs = quick_runs(:two_end_chain; runs=8)
    _, _, slow_runs = quick_runs(:two_end_chain, slow; runs=8, seed_base=100)
    J(runs, s) = mean(summarize(runs, observable(m, :J_plus), s; omit=100, duration=400))

    # Assert: half the rates, half the flux (within run-to-run noise).
    @test 0.4 < J(slow_runs, slow) / J(fast_runs, s1) < 0.6
end

@testset "sampling every step recovers the true growth episodes" begin
    # Arrange: no rescue, so every growth episode ends in a catastrophe or at the end of the run.
    r = simulate_switching(; t_end=20_000, seed=2, rescue=0.0)

    # Act
    apparent = apparent_growth_duration(r, 0.05)
    coarse = apparent_growth_duration(r, 30.0)

    # Assert: the true mean growth episode is 1/k_c ≈ 66.7 s.
    @test abs(apparent - 1 / 0.015) < 8
    @test coarse > apparent
end

@testset "the bootstrap interval brackets a clear difference and excludes zero" begin
    # Arrange
    a = [1.0, 1.1, 0.9, 1.0, 1.05, 0.95]
    b = a .+ 1

    # Act
    d = bootstrap_difference(a, b)

    # Assert
    @test d.difference ≈ 1
    @test d.lo > 0 && d.hi > d.lo
end

@testset "undefined run summaries are dropped from the difference" begin
    # Arrange
    a = [1.0, NaN, 1.2, 0.8]
    b = [2.0, 2.2, NaN, 1.8]

    # Act
    d = bootstrap_difference(a, b)

    # Assert
    @test d.difference ≈ 1
end

@testset "the methods paragraph records model, values, seeds and statistics" begin
    # Arrange
    m = model_by_name(:seeded_chain)

    # Act
    text = methods_text(; model=m, setting=setting(m, :hydrolysis), values=[1.0, 0.5],
                        observables=[observable(m, :collapse_rate)], control=control(m, :no_hydrolysis),
                        runs=8, duration=250, omit=50, drop=5, window=1.0, seed_bases=[1000, 2000])

    # Assert
    @test occursin("A: 1", text) && occursin("B: 0.5", text)
    @test occursin("A 1001–1008, B 2001–2008", text)
    @test occursin("drop of at least 5 subunits", text)
    @test occursin("bootstrap", text)
end

end
