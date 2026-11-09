"""
    Experiment

The machinery behind afternoon 5: one controlled comparison designed through menus.
Each model lists the inputs that can be varied, the observables that can be measured, and
predictable controls. Students choose; this module runs, summarizes and documents.
"""
module Experiment

using Random, Statistics
using ..MTLab

export MODELS, EXAMPLES, model_by_name, setting, observable, control, baseline_inputs,
       condition_inputs, run_condition, summarize, bootstrap_difference, apparent_growth_duration,
       format_value, methods_text

const FACTORS = round.(exp10.(range(-1, 1; length=41)); sigdigits=2)

"An input that can be varied, with the values offered in the menus."
struct Setting
    name::Symbol
    label::String
    unit::String
    baseline::Float64
    grid::Vector{Float64}
    log_scale::Bool
end
rate_setting(name, label, unit, baseline) =
    Setting(name, label, unit, baseline, unique(round.(baseline .* FACTORS; sigdigits=3)), true)

"A number computed from one run; `f(run, ctx)` with `ctx = (; inputs, omit, duration, drop, window)`."
struct Observable
    name::Symbol
    label::String
    f::Function
end

"A condition whose outcome can be predicted without running it."
struct Control
    name::Symbol
    label::String
    expectation::String
    apply::Function   # inputs::Dict -> modified copy
end

struct Model
    name::Symbol
    label::String
    description::String
    time_unit::String
    settings::Vector{Setting}
    fixed::Dict{Symbol,Float64}   # inputs that are never varied (hidden switches)
    observables::Vector{Observable}
    controls::Vector{Control}
    durations::Vector{Int}
    duration::Int
    omit::Int
end

in_window(run, omit) = run.t .>= omit
window_length(ctx) = ctx.duration - ctx.omit

"""
    apparent_growth_duration(run, interval; omit=0)

Mean duration of growth episodes as seen in a trace sampled every `interval` seconds: an
apparent episode is a run of consecutive increases of the sampled length. `NaN` if the
sampled trace never grows.
"""
function apparent_growth_duration(run, interval; omit=0.0)
    dt = run.t[2] - run.t[1]
    step = max(1, round(Int, interval / dt))
    sampled = run.length[findall(in_window(run, omit))][1:step:end]
    episodes = Int[]
    current = 0
    for growing in (diff(sampled) .> 0)
        if growing
            current += 1
        elseif current > 0
            push!(episodes, current); current = 0
        end
    end
    current > 0 && push!(episodes, current)
    return isempty(episodes) ? NaN : mean(episodes) * step * dt
end

const SWITCHING = Model(:switching, "Growing/shrinking model (afternoons 1–2)",
    "effective two-state model; length in µm, time in s, Δt = 0.05 s, protected seed", "s",
    [rate_setting(:vg, "growth speed v_g", "µm/s", 0.03),
     rate_setting(:vs, "shrinkage speed v_s", "µm/s", 0.18),
     rate_setting(:catastrophe, "catastrophe rate k_c", "1/s", 0.015),
     rate_setting(:rescue, "rescue rate k_r", "1/s", 0.03),
     Setting(:observation, "observation interval Δ", "s", 3.0, [0.05, 0.5, 1, 2, 3, 5, 10, 20, 30], true)],
    Dict{Symbol,Float64}(),
    [Observable(:mean_length, "mean length (µm)", (r, c) -> mean(r.length[in_window(r, c.omit)])),
     Observable(:max_length, "maximum length (µm)", (r, c) -> maximum(r.length[in_window(r, c.omit)])),
     Observable(:catastrophe_rate, "catastrophes per minute",
                (r, c) -> 60 * count(e -> e[2] == :catastrophe && e[1] >= c.omit, r.events) / window_length(c)),
     Observable(:growing_fraction, "fraction of time growing", (r, c) -> mean(r.growing[in_window(r, c.omit)])),
     Observable(:apparent_growth, "apparent mean growth episode (s), seen every Δ",
                (r, c) -> apparent_growth_duration(r, c.inputs[:observation]; omit=c.omit))],
    [Control(:no_switching, "no switching (k_c = k_r = 0)",
             "Without catastrophes the filament only grows, at exactly v_g: zero catastrophes, mean length L(0) + v_g × (time) averaged over the window.",
             s -> merge(s, Dict(:catastrophe => 0.0, :rescue => 0.0))),
     Control(:every_step, "observe every step (Δ = 0.05 s)",
             "Sampling every simulation step misses nothing: apparent growth episodes are the true ones, with mean close to 1/k_c (slightly shorter, because the end of the run cuts the last episode).",
             s -> merge(s, Dict(:observation => 0.05)))],
    [300, 600, 1200, 3000], 600, 0)

const SEEDED_CHAIN = Model(:seeded_chain, "T/D chain on a protected seed (afternoon 3)",
    "exact Gillespie T/D chain, protected minus end, initially 10 T subunits; length in subunits, time in model units, sampled every 0.2",
    "model time",
    [rate_setting(:plus_on, "plus-end addition u+", "1/time", 2.0),
     rate_setting(:plus_off_T, "loss of a terminal T w+T", "1/time", 0.2),
     rate_setting(:plus_off_D, "loss of a terminal D w+D", "1/time", 20.0),
     Setting(:hydrolysis, "hydrolysis h (per T)", "1/time", 1.0, [0.0; unique(round.(FACTORS; sigdigits=3))], true)],
    Dict{Symbol,Float64}(),
    [Observable(:collapse_rate, "collapses per 100 time units",
                (r, c) -> 100 * count(x -> x[1] >= c.omit, count_collapses(r; drop=c.drop, window=c.window)) / window_length(c)),
     Observable(:mean_length, "mean length (subunits)", (r, c) -> mean(r.length[in_window(r, c.omit)])),
     Observable(:max_length, "maximum length (subunits)", (r, c) -> maximum(r.length[in_window(r, c.omit)])),
     Observable(:mean_cap, "mean terminal T cap (subunits)", (r, c) -> mean(r.cap[in_window(r, c.omit)]))],
    [Control(:no_hydrolysis, "no hydrolysis (h = 0)",
             "Without hydrolysis no D ever appears, so the end is always T: no collapse, and the length grows steadily at about u+ − w+T subunits per time unit.",
             s -> merge(s, Dict(:hydrolysis => 0.0)))],
    [100, 250, 500], 250, 50)

const TWO_END_CHAIN = Model(:two_end_chain, "T/D chain with two dynamic ends (afternoon 4)",
    "exact Gillespie T/D chain without seed (both ends dynamic, disappearance absorbing), initially 100 subunits with 20 T at the plus end; length in subunits, time in model units, sampled every 1",
    "model time",
    [rate_setting(:plus_on, "plus-end addition u+", "1/time", 6.0),
     rate_setting(:plus_off_T, "plus-end loss of T w+T", "1/time", 0.2),
     rate_setting(:plus_off_D, "plus-end loss of D w+D", "1/time", 30.0),
     rate_setting(:minus_on, "minus-end addition u−", "1/time", 0.1),
     rate_setting(:minus_off_T, "minus-end loss of T w−T", "1/time", 1.0),
     rate_setting(:minus_off_D, "minus-end loss of D w−D", "1/time", 7.0),
     rate_setting(:hydrolysis, "hydrolysis h (per T)", "1/time", 0.2),
     Setting(:initial_length, "initial fragment length", "subunits", 100.0, collect(0.0:10.0:200.0), false),
     Setting(:rate_scale, "all rates × factor (time scale)", "×", 1.0, FACTORS, true)],
    Dict(:protected => 0.0),
    [Observable(:survived, "survived to the end (1 = yes, 0 = no)", (r, c) -> r.extinction_time === nothing ? 1.0 : 0.0),
     Observable(:mean_length, "mean length (subunits; extinct = 0)", (r, c) -> mean(r.length[in_window(r, c.omit)])),
     Observable(:J_plus, "plus-end flux J+ (subunits per time)", (r, c) -> end_currents(r; start=c.omit).J_plus),
     Observable(:J_minus, "minus-end flux J− (subunits per time)", (r, c) -> end_currents(r; start=c.omit).J_minus),
     Observable(:drift, "length drift J+ + J− (subunits per time)", (r, c) -> end_currents(r; start=c.omit).length_drift)],
    [Control(:protected, "protected minus end (same plus-end and hydrolysis rates)",
             "With a protected minus end the fragment can never disappear: every run survives and J− = 0.",
             s -> merge(s, Dict(:protected => 1.0))),
     Control(:empty, "initial length 0",
             "The empty state is absorbing: nothing survives, the length stays 0 and all fluxes are 0.",
             s -> merge(s, Dict(:initial_length => 0.0)))],
    [200, 400, 800], 400, 100)

const MODELS = [SWITCHING, SEEDED_CHAIN, TWO_END_CHAIN]

model_by_name(name) = only(filter(m -> m.name == name, MODELS))
setting(m::Model, name) = only(filter(s -> s.name == name, m.settings))
observable(m::Model, name) = only(filter(o -> o.name == name, m.observables))
control(m::Model, name) = only(filter(c -> c.name == name, m.controls))

baseline_inputs(m::Model) = merge(Dict(s.name => s.baseline for s in m.settings), m.fixed)

"Baseline inputs with one setting changed."
condition_inputs(m::Model, name, value) = merge(baseline_inputs(m), Dict(name => Float64(value)))

format_value(x) = isinteger(x) && abs(x) < 1e6 ? string(Int(x)) : string(round(x; sigdigits=3))

"""
    run_condition(model, inputs; runs, duration, seed_base)

Independent runs of one condition, with random seeds `seed_base + 1, …, seed_base + runs`.
"""
function run_condition(m::Model, inputs; runs, duration, seed_base)
    return [simulate(m, inputs, duration, seed_base + i) for i in 1:runs]
end

function simulate(m::Model, s, duration, seed)
    if m.name == :switching
        return simulate_switching(; vg=s[:vg], vs=s[:vs], catastrophe=s[:catastrophe],
                                  rescue=s[:rescue], t_end=duration, seed)
    elseif m.name == :seeded_chain
        p = ChainParameters(; plus_on=s[:plus_on], plus_off_T=s[:plus_off_T],
                            plus_off_D=s[:plus_off_D], hydrolysis=s[:hydrolysis])
        return simulate_chain(p; initial_length=10, initial_T=10, seeded=true, t_end=duration,
                              sample_dt=0.2, seed, record_snapshots=false)
    else
        k = s[:rate_scale]
        protected = s[:protected] == 1
        p = ChainParameters(; plus_on=k * s[:plus_on], plus_off_T=k * s[:plus_off_T],
                            plus_off_D=k * s[:plus_off_D],
                            minus_on=protected ? 0.0 : k * s[:minus_on],
                            minus_off_T=protected ? 0.0 : k * s[:minus_off_T],
                            minus_off_D=protected ? 0.0 : k * s[:minus_off_D],
                            hydrolysis=k * s[:hydrolysis])
        L0 = round(Int, s[:initial_length])
        return simulate_chain(p; initial_length=L0, initial_T=min(20, L0), seeded=protected,
                              t_end=duration, sample_dt=1.0, seed, record_snapshots=false)
    end
end

"""
    summarize(runs, observable, inputs; omit, duration, drop=5, window=1.0)

One number per run (`NaN` when the observable is undefined for that run).
"""
function summarize(runs, obs::Observable, inputs; omit, duration, drop=5, window=1.0)
    ctx = (; inputs, omit, duration, drop, window)
    return [Float64(obs.f(r, ctx)) for r in runs]
end

"""
    bootstrap_difference(a, b; repeats=2000, seed=1)

Difference of means `mean(b) − mean(a)` with an approximate 95 % percentile interval from
resampling the runs of each condition. `NaN` values (undefined for a run) are dropped.
"""
function bootstrap_difference(a, b; repeats=2000, seed=1)
    a, b = filter(!isnan, a), filter(!isnan, b)
    (length(a) >= 2 && length(b) >= 2) || return (; difference=NaN, lo=NaN, hi=NaN)
    rng = Xoshiro(seed)
    d = [mean(rand(rng, b, length(b))) - mean(rand(rng, a, length(a))) for _ in 1:repeats]
    return (; difference=mean(b) - mean(a), lo=quantile(d, 0.025), hi=quantile(d, 0.975))
end

"""
    EXAMPLES

The example questions of the manual, each with a feasible starting design. Choosing one only
pre-fills the menus: the question, prediction and interpretation remain the students'.
"""
const EXAMPLES = [
    (; label="Does changing hydrolysis affect the frequency of substantial collapses?",
     model=:seeded_chain, setting=:hydrolysis, values=(1.0, 0.5),
     observables=(:collapse_rate, :mean_length), control=:no_hydrolysis),
    (; label="Can similar mean lengths hide very different material turnover?",
     model=:two_end_chain, setting=:rate_scale, values=(1.0, 0.5),
     observables=(:mean_length, :J_plus), control=:protected),
    (; label="Does the initial fragment length affect survival over a fixed observation window?",
     model=:two_end_chain, setting=:initial_length, values=(100.0, 20.0),
     observables=(:survived, :mean_length), control=:empty),
    (; label="Does changing a minus-end loss rate preserve treadmilling, or lead to growth or disappearance?",
     model=:two_end_chain, setting=:minus_off_D, values=(7.0, 3.5),
     observables=(:drift, :survived), control=:protected),
    (; label="How does the observation interval affect the apparent duration of growth episodes?",
     model=:switching, setting=:observation, values=(3.0, 10.0),
     observables=(:apparent_growth, :none), control=:every_step),
]

"""
    methods_text(; model, setting, values, observables, control, runs, duration, omit,
                   drop, window, seed_bases)

A methods paragraph (Markdown) that records everything needed to regenerate the results.
"""
function methods_text(; model::Model, setting::Setting, values, observables, control, runs,
                      duration, omit, drop, window, seed_bases)
    io = IOBuffer()
    base = baseline_inputs(model)
    fixed = join(("$(s.label) = $(format_value(base[s.name])) $(s.unit)" for s in model.settings
                  if s.name != setting.name), "; ")
    letters = 'A':'Z'
    conditions = join(("$(letters[i]): $(format_value(v)) $(setting.unit)" for (i, v) in enumerate(values)), ", ")
    println(io, "**Model.** ", model.label, ": ", model.description, ".\n")
    println(io, "**Comparison.** We varied the ", setting.label, " (", conditions,
            "), keeping all other inputs at their baseline values: ", fixed, ".\n")
    println(io, "**Controls.** Null control: condition A repeated with independent random seeds.",
            control === nothing ? "" : " Predictable control: $(control.label). Expected: $(control.expectation)", "\n")
    seeds = join(("$(letters[i]) $(b + 1)–$(b + runs)" for (i, b) in enumerate(seed_bases)), ", ")
    println(io, "**Runs.** ", runs, " independent runs per condition, each lasting ", duration, " ",
            model.time_unit, "; observables measured after omitting the first ", omit, " ",
            model.time_unit, ". Random seeds: ", seeds, ".\n")
    obs_text = join((o.label for o in observables), "; ")
    collapse = any(o -> o.name == :collapse_rate, observables) ?
        " A collapse is a drop of at least $drop subunits below the last peak within $window time units." : ""
    println(io, "**Observables.** ", obs_text, ".", collapse, "\n")
    print(io, "**Statistics.** One summary per run; mean ± standard error across runs; differences ",
          "of means with approximate 95 % intervals from 2000 bootstrap resamples of the runs.")
    return String(take!(io))
end

end # module
