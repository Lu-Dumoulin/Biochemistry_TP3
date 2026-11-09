"""
    MTLab

Two teaching models of microtubule dynamics. Rates and boundary rules are explicit.

* `simulate_switching`: effective growing/shrinking model. Length in µm, time in s.
* `simulate_chain`: chain of T (GTP-like) and D (GDP-like) subunits, simulated event by
  event (Gillespie). Length in subunits, time in model units. It is not a structural
  13-protofilament model.

Only the standard library is used, so the module loads inside any Pluto notebook.
"""
module MTLab

using Random, Statistics

export switch_decision, simulate_switching, switching_statistics, switching_regime,
       ChainParameters, with, simulate_chain, trace_events, end_currents,
       DYNAMIC_INSTABILITY, TREADMILLING,
       count_collapses, material_image, chain_csv,
       read_segments, summarize_segments, bootstrap_tracks, simulated_segments

check_rates(values...) = all(x -> isfinite(x) && x >= 0, values) ||
    throw(ArgumentError("Rates must be finite and non-negative."))

# Regular grid from 0 to t_end; the last step is shortened so that t_end is included.
function time_grid(t_end, step)
    (isfinite(t_end) && t_end > 0 && isfinite(step) && step > 0) ||
        throw(ArgumentError("Durations and time steps must be positive and finite."))
    t = collect(0.0:step:t_end)
    last(t) < t_end && push!(t, t_end)
    return t
end

# --- Effective switching model -------------------------------------------------

"""
    switch_decision(rng, rate, dt)

Small-time-step rule: switch with probability `rate * dt`. Notebook 01 lets students
replace it with their own one-line version.
"""
switch_decision(rng, rate, dt) = rand(rng) < rate * dt

"""
    simulate_switching(; t_end=600, dt=0.05, vg=0.03, vs=0.18, catastrophe=0.015,
                         rescue=0.03, seed=1, initial_length=1, decision=switch_decision)

Seeded two-state model: length is the extension beyond a protected seed (µm), time in s.
Each step evolves the current state for `dt`, then attempts a switch with probability
`k * dt`. When shrinking reaches zero extension the filament restarts growing; this
boundary restart is NOT a rescue. Boundary timing is accurate to O(dt).

Returns a named tuple with fields `t`, `length`, `growing`, `events` (a vector of
`(time, :catastrophe | :rescue | :seed_restart)`), `exposure` (time spent growing `G`
and shrinking `S`), `seed` and `parameters`.
"""
function simulate_switching(; t_end=600.0, dt=0.05, vg=0.03, vs=0.18,
                            catastrophe=0.015, rescue=0.03, seed=1,
                            initial_length=1.0, decision=switch_decision)
    check_rates(vg, vs, catastrophe, rescue, initial_length)
    t = time_grid(t_end, dt)
    max(catastrophe, rescue) * dt <= 0.1 + 1e-12 ||
        throw(ArgumentError("Use a smaller dt: max(switching rates) * dt must be ≤ 0.1."))
    rng = Xoshiro(seed)
    n = length(t)
    L = zeros(n); L[1] = initial_length
    growing = trues(n)
    events = Tuple{Float64,Symbol}[]
    time_G = 0.0; time_S = 0.0
    for i in 2:n
        step = t[i] - t[i-1]
        g = growing[i-1]
        g ? (time_G += step) : (time_S += step)
        L[i] = max(0.0, L[i-1] + (g ? vg : -vs) * step)
        if !g && L[i] == 0
            growing[i] = true
            push!(events, (t[i], :seed_restart))
        elseif decision(rng, g ? catastrophe : rescue, step)
            growing[i] = !g
            push!(events, (t[i], g ? :catastrophe : :rescue))
        else
            growing[i] = g
        end
    end
    return (; t, length=L, growing, events, exposure=(G=time_G, S=time_S), seed,
            parameters=(; vg, vs, catastrophe, rescue, dt, t_end))
end

"""
    switching_statistics(result)

Event counts and rates from the simulator's internal state labels. These are exact for
the simulation, not estimates from a coarsely sampled kymograph.
"""
function switching_statistics(result)
    count_of(kind) = count(e -> e[2] == kind, result.events)
    nc, nr = count_of(:catastrophe), count_of(:rescue)
    tg, ts = result.exposure.G, result.exposure.S
    return (; catastrophes=nc, rescues=nr, seed_restarts=count_of(:seed_restart),
            growing_time=tg, shrinking_time=ts,
            catastrophe_rate=tg > 0 ? nc / tg : NaN,
            rescue_rate=ts > 0 ? nr / ts : NaN)
end

"""
    switching_regime(; vg, vs, catastrophe, rescue)

Long-time behavior of the two-state model without a seed boundary (Dogterom–Leibler).
`drift` is the average velocity (µm/s). If it is negative the length stays bounded
near the seed and `mean_length` is the mean of its exponential distribution;
otherwise `mean_length` is `Inf` (unbounded growth).
"""
function switching_regime(; vg, vs, catastrophe, rescue)
    check_rates(vg, vs, catastrophe, rescue)
    total = catastrophe + rescue
    drift = total > 0 ? (vg * rescue - vs * catastrophe) / total : vg
    mean_length = drift < 0 ? vg * vs / (vs * catastrophe - vg * rescue) : Inf
    return (; drift, mean_length, bounded=drift < 0)
end

# --- T/D chain model -------------------------------------------------------------

"""
    ChainParameters(; plus_on, plus_off_T, plus_off_D, minus_on, minus_off_T,
                      minus_off_D, hydrolysis)

Rates in inverse model time. On-rates are event rates per end (not concentrations);
off-rates depend on the state (T or D) of the terminal subunit; `hydrolysis` is per T.
"""
Base.@kwdef struct ChainParameters
    plus_on::Float64 = 3.0
    plus_off_T::Float64 = 0.2
    plus_off_D::Float64 = 30.0
    minus_on::Float64 = 0.0
    minus_off_T::Float64 = 0.0
    minus_off_D::Float64 = 0.0
    hydrolysis::Float64 = 0.3
end

"""
    with(params; kwargs...)

Copy of `params` with some rates changed, e.g. `with(DYNAMIC_INSTABILITY; hydrolysis=0)`.
"""
function with(p::ChainParameters; kwargs...)
    names = fieldnames(ChainParameters)
    current = NamedTuple{names}(getfield.(Ref(p), names))
    return ChainParameters(; merge(current, values(kwargs))...)
end

"Tested teaching example, not a fit to experimental tubulin rates."
const DYNAMIC_INSTABILITY = ChainParameters(plus_on=2.0, plus_off_T=0.2, plus_off_D=20.0,
                                            hydrolysis=1.0)
"Tested teaching example, not a fit to experimental tubulin rates."
const TREADMILLING = ChainParameters(plus_on=6.0, plus_off_T=0.2, plus_off_D=30.0,
                                     minus_on=0.1, minus_off_T=1.0, minus_off_D=7.0,
                                     hydrolysis=0.2)

# The chain engine is split into small steps (rates, event choice, event effect) so that
# `simulate_chain` and the step-by-step `trace_events` share exactly the same rules.

const EVENT_NAMES = (:plus_on, :plus_off, :minus_on, :minus_off, :hydrolysis)

mutable struct ChainState
    seq::Vector{Bool}          # true = T, false = D; minus end first, plus end last
    births::Vector{Float64}    # incorporation time of each subunit (-Inf if initial)
    nT::Int
    t::Float64
    xminus::Int                # lattice coordinate of the minus end
    xplus::Int
    counts::Vector{Int}        # number of events of each kind, in EVENT_NAMES order
end

function ChainState(initial_length, initial_T)
    (isinteger(initial_length) && isinteger(initial_T) && 0 <= initial_T <= initial_length) ||
        throw(ArgumentError("Require integers 0 ≤ initial_T ≤ initial_length."))
    n0, nT0 = Int(initial_length), Int(initial_T)
    return ChainState(vcat(fill(false, n0 - nT0), fill(true, nT0)), fill(-Inf, n0), nT0,
                      0.0, 0, n0, zeros(Int, 5))
end

function check_chain(p::ChainParameters, seeded)
    check_rates((getfield(p, f) for f in fieldnames(ChainParameters))...)
    seeded && any(>(0), (p.minus_on, p.minus_off_T, p.minus_off_D)) &&
        throw(ArgumentError("For a seeded chain, set all minus-end rates to zero."))
end

# Rates of the five possible events in the current state. An empty unseeded chain has
# no possible event: disappearance is absorbing.
function event_rates!(rates, s::ChainState, p::ChainParameters, seeded)
    if isempty(s.seq) && !seeded
        fill!(rates, 0.0)
    else
        rates[1] = p.plus_on
        rates[2] = isempty(s.seq) ? 0.0 : (last(s.seq) ? p.plus_off_T : p.plus_off_D)
        rates[3] = seeded ? 0.0 : p.minus_on
        rates[4] = (seeded || isempty(s.seq)) ? 0.0 : (first(s.seq) ? p.minus_off_T : p.minus_off_D)
        rates[5] = p.hydrolysis * s.nT
    end
    return rates
end

# Choose an event with probability proportional to its rate.
function choose_event(rng, rates, total)
    r = rand(rng) * total
    e = findfirst(>(r), cumsum(rates))
    return something(e, findlast(>(0), rates))   # guards float round-off at r ≈ total
end

function apply_event!(s::ChainState, e, rng)
    if e == 1
        push!(s.seq, true); push!(s.births, s.t); s.xplus += 1; s.nT += 1
    elseif e == 2
        s.nT -= pop!(s.seq); pop!(s.births); s.xplus -= 1
    elseif e == 3
        pushfirst!(s.seq, true); pushfirst!(s.births, s.t); s.xminus -= 1; s.nT += 1
    elseif e == 4
        s.nT -= popfirst!(s.seq); popfirst!(s.births); s.xminus += 1
    else
        # Each T is equally likely to hydrolyze: pick the k-th T along the chain.
        k = rand(rng, 1:s.nT)
        i = 0
        while k > 0
            i += 1
            k -= s.seq[i]
        end
        s.seq[i] = false; s.nT -= 1
    end
    s.counts[e] += 1
    return s
end

# Number of consecutive T subunits at the plus end.
function terminal_cap(seq)
    last_D = findlast(!, seq)
    return length(seq) - something(last_D, 0)
end

"""
    simulate_chain(params=ChainParameters(); t_end=300, sample_dt=0.5, seed=1,
                   initial_length=40, initial_T=5, seeded=true,
                   record_snapshots=true, max_events=2_000_000)

Exact T/D chain. The plus end is the end of the vector, the minus end its start.
The initial chain is D except for the `initial_T` subunits nearest the plus end.

* Seeded: the minus end is inert; the protected seed lies OUTSIDE the recorded chain,
  and zero extension can regrow by plus-end addition.
* Unseeded: both ends use the supplied rates; complete disappearance is absorbing
  (no spontaneous nucleation).

All additions are T; hydrolysis is independent per T. The state is recorded on a regular
observation grid `sample_dt`, which does not affect event times. Snapshots keep birth
times for pulse-label displays. No rigid-body motion or bending is modeled.
"""
function simulate_chain(p::ChainParameters=ChainParameters(); t_end=300.0, sample_dt=0.5,
                        seed=1, initial_length=40, initial_T=5, seeded=true,
                        record_snapshots=true, max_events=2_000_000)
    check_chain(p, seeded)
    t_samples = time_grid(t_end, sample_dt)
    s = ChainState(initial_length, initial_T)
    rng = Xoshiro(seed)
    n = length(t_samples)
    columns = Dict(k => zeros(Int, n) for k in
                   (:length, :cap, :nT, :plus_net, :minus_net, :xminus, :xplus))
    snapshots = Tuple{Int,Vector{Bool},Vector{Float64}}[]
    extinction_time = (isempty(s.seq) && !seeded) ? 0.0 : nothing
    sample = 1

    function record(j)
        columns[:length][j] = length(s.seq); columns[:cap][j] = terminal_cap(s.seq)
        columns[:nT][j] = s.nT
        columns[:plus_net][j] = s.counts[1] - s.counts[2]
        columns[:minus_net][j] = s.counts[3] - s.counts[4]
        columns[:xminus][j] = s.xminus; columns[:xplus][j] = s.xplus
        record_snapshots && push!(snapshots, (s.xminus, copy(s.seq), copy(s.births)))
    end

    rates = zeros(5)
    finished = false
    for _ in 1:max_events
        total = sum(event_rates!(rates, s, p, seeded))
        next_t = total > 0 ? s.t + randexp(rng) / total : Inf
        while sample <= n && t_samples[sample] < min(next_t, t_end)
            record(sample); sample += 1
        end
        if next_t > t_end
            while sample <= n
                record(sample); sample += 1
            end
            finished = true
            break
        end
        s.t = next_t
        apply_event!(s, choose_event(rng, rates, total), rng)
        isempty(s.seq) && !seeded && extinction_time === nothing && (extinction_time = s.t)
    end
    finished || error("Event limit reached. Reduce duration or rates; results were not truncated silently.")

    return (; t=t_samples, length=columns[:length], cap=columns[:cap], nT=columns[:nT],
            plus_net=columns[:plus_net], minus_net=columns[:minus_net],
            xminus=columns[:xminus], xplus=columns[:xplus], snapshots,
            counts=NamedTuple{EVENT_NAMES}(Tuple(s.counts)),
            extinction_time, parameters=p, seeded, seed)
end

"""
    trace_events(params; n_events=10, seed=1, initial_length=4, initial_T=2, seeded=true)

The first `n_events` Gillespie steps, one by one: for each step, the rates of the five
possible events in the state before it, the waiting time drawn, the event chosen and the
chain after it. The first entry is the initial chain (`event = :start`).
"""
function trace_events(p::ChainParameters; n_events=10, seed=1, initial_length=4,
                      initial_T=2, seeded=true)
    check_chain(p, seeded)
    s = ChainState(initial_length, initial_T)
    rng = Xoshiro(seed)
    rates = zeros(5)
    steps = [(; t=0.0, wait=0.0, event=:start, rates=NamedTuple{EVENT_NAMES}(Tuple(rates)),
              total=0.0, chain=copy(s.seq))]
    for _ in 1:n_events
        total = sum(event_rates!(rates, s, p, seeded))
        total > 0 || break
        wait = randexp(rng) / total
        s.t += wait
        e = choose_event(rng, rates, total)
        before = NamedTuple{EVENT_NAMES}(Tuple(rates))
        apply_event!(s, e, rng)
        push!(steps, (; t=s.t, wait, event=EVENT_NAMES[e], rates=before, total, chain=copy(s.seq)))
    end
    return steps
end

"""
    end_currents(result; start=0)

Average signed end fluxes over the sampled interval [start, end]: J₊ and J₋ are net
additions per unit time at each end, and J₊ + J₋ is the length drift.
"""
function end_currents(result; start=0.0)
    i = searchsortedfirst(result.t, start)
    i >= length(result.t) && throw(ArgumentError("start must precede the final sample."))
    duration = result.t[end] - result.t[i]
    jp = (result.plus_net[end] - result.plus_net[i]) / duration
    jm = (result.minus_net[end] - result.minus_net[i]) / duration
    return (; J_plus=jp, J_minus=jm, length_drift=jp + jm, duration,
            extinct=result.extinction_time !== nothing)
end

# --- Displays, observables and export for the chain model --------------------------

"""
    count_collapses(result; drop=5, window=2.0)

An explicit, adjustable definition of a substantial collapse: the length falls by at least
`drop` subunits below its last peak within `window` time units. After a collapse, the next
one can only be counted once the length has recovered by `drop / 2` from the trough, so a
single long collapse is counted once. Returns the time and length of each peak.
"""
function count_collapses(result; drop=5, window=2.0)
    t, L = result.t, result.length
    collapses = Tuple{Float64,Int}[]
    peak, t_peak = L[1], t[1]
    armed, trough = true, L[1]
    for j in eachindex(L)
        if !armed
            trough = min(trough, L[j])
            if L[j] >= trough + drop / 2
                armed = true
                peak, t_peak = L[j], t[j]
            end
        elseif L[j] >= peak
            peak, t_peak = L[j], t[j]
        elseif peak - L[j] >= drop
            if t[j] - t_peak <= window
                push!(collapses, (t_peak, peak))
                armed, trough = false, L[j]
            else
                peak, t_peak = L[j], t[j]   # a slow decline is not a collapse
            end
        end
    end
    return collapses
end

"""
    material_image(result; mode=:nucleotide, pulse=(50, 60), frame=:lattice)

Kymograph-like image of a chain run with `record_snapshots=true`: one row per sample time,
one column per site. Values: 0 = empty site, 1 = D (or unlabeled), 2 = T (or
incorporated during the `pulse` window when `mode = :pulse`).

With `frame = :lattice`, columns are lattice sites: there is no rigid-body motion, so a
subunit keeps its column while the ends move. With `frame = :minus_end`, column 0 is the
current minus end: the display follows the filament. Returns `(; image, sites, t)`.
"""
function material_image(result; mode=:nucleotide, pulse=(50.0, 60.0), frame=:lattice)
    isempty(result.snapshots) && throw(ArgumentError("Run simulate_chain with record_snapshots=true."))
    follow = frame == :minus_end
    lo = follow ? 0 : minimum(s[1] for s in result.snapshots)
    hi = follow ? maximum(length(s[2]) for s in result.snapshots) :
                  maximum(s[1] + length(s[2]) for s in result.snapshots)
    image = zeros(Int, length(result.t), max(1, hi - lo))
    for (j, (left, seq, births)) in enumerate(result.snapshots)
        marked = mode == :pulse ? (pulse[1] .<= births .< pulse[2]) : seq
        offset = follow ? 0 : left - lo
        image[j, offset .+ (1:length(seq))] .= 1 .+ marked
    end
    return (; image, sites=lo:(hi - 1), t=result.t)
end

"""
    chain_csv(result)

The regular-time observations of a chain run as CSV text, preceded by comment lines with
the rates, boundary convention and random seed needed to regenerate it.
"""
function chain_csv(result)
    p = result.parameters
    io = IOBuffer()
    println(io, "# T/D chain simulation (lengths in subunits, time in model units)")
    println(io, "# rates: ", join(("$f=$(getfield(p, f))" for f in fieldnames(ChainParameters)), ", "))
    println(io, "# seeded=", result.seeded, ", random seed=", result.seed,
            ", extinction_time=", something(result.extinction_time, "none"))
    keys = (:t, :length, :cap, :nT, :plus_net, :minus_net, :xminus, :xplus)
    println(io, join(keys, ","))
    for j in eachindex(result.t)
        println(io, join((result[k][j] for k in keys), ","))
    end
    return String(take!(io))
end

# --- Segment tables (afternoon 2) ---------------------------------------------------

const SEGMENT_COLUMNS = ("condition", "track", "state", "duration_s", "delta_length_um",
                         "end_event", "source")
const ALLOWED_END = Dict("G" => ("catastrophe", "censored"),
                         "S" => ("rescue", "seed_restart", "censored"))

"""
    read_segments(source)

Read a segment table (a file path or an `IO`): one row per observed growth (G) or
shrinkage (S) segment, with columns `condition, track, state, duration_s,
delta_length_um, end_event, source`. Length changes are signed (positive for growth).
End events: catastrophe or censored after G; rescue, seed_restart or censored after S.
Fields must not contain commas. Errors name the offending line.
"""
read_segments(path::AbstractString) = open(read_segments, path)

function read_segments(io::IO)
    lines = [strip(l) for l in eachline(io)]
    filter!(!isempty, lines)
    isempty(lines) && throw(ArgumentError("The file is empty."))
    header = strip.(split(lines[1], ","))
    missing_columns = setdiff(SEGMENT_COLUMNS, header)
    isempty(missing_columns) || throw(ArgumentError("Missing columns: $(join(missing_columns, ", ")). Required: $(join(SEGMENT_COLUMNS, ","))"))
    length(lines) > 1 || throw(ArgumentError("No rows: fill the template or use the synthetic fallback."))
    col = Dict(name => i for (i, name) in enumerate(header))
    rows = map(enumerate(lines[2:end])) do (k, line)
        line_number = k + 1
        f = strip.(split(line, ","))
        length(f) == length(header) ||
            throw(ArgumentError("Line $line_number has $(length(f)) fields instead of $(length(header)) (no commas inside fields)."))
        get_field(name) = f[col[name]]
        duration = tryparse(Float64, get_field("duration_s"))
        delta = tryparse(Float64, get_field("delta_length_um"))
        state, end_event = get_field("state"), get_field("end_event")
        state in ("G", "S") || throw(ArgumentError("Line $line_number: state must be G or S."))
        (duration !== nothing && isfinite(duration) && duration > 0) ||
            throw(ArgumentError("Line $line_number: duration_s must be a positive number."))
        (delta !== nothing && isfinite(delta)) ||
            throw(ArgumentError("Line $line_number: delta_length_um must be a number."))
        (state == "G" ? delta >= 0 : delta <= 0) ||
            throw(ArgumentError("Line $line_number: use a signed length change, positive for growth and negative for shrinkage."))
        end_event in ALLOWED_END[state] ||
            throw(ArgumentError("Line $line_number: a $state segment cannot end with \"$end_event\" (allowed: $(join(ALLOWED_END[state], ", ")))."))
        (; condition=get_field("condition"), track=get_field("track"), state, duration_s=duration,
         delta_length_um=delta, end_event, source=get_field("source"))
    end
    return rows
end

"""
    summarize_segments(rows)

Pooled estimates: speeds are total length change / total time in the state; switching
rates are event counts / time at risk (growing time for catastrophes, shrinking time for
rescues). Censored segments contribute time but no event; seed restarts are not rescues.
"""
function summarize_segments(rows)
    g = filter(r -> r.state == "G", rows)
    s = filter(r -> r.state == "S", rows)
    tg = sum(r -> r.duration_s, g; init=0.0)
    ts = sum(r -> r.duration_s, s; init=0.0)
    nc = count(r -> r.end_event == "catastrophe", g)
    nr = count(r -> r.end_event == "rescue", s)
    ratio(a, b) = b > 0 ? a / b : NaN
    return (; vg=ratio(sum(r -> r.delta_length_um, g; init=0.0), tg),
            vs=ratio(-sum(r -> r.delta_length_um, s; init=0.0), ts),
            catastrophe=ratio(nc, tg), rescue=ratio(nr, ts),
            growing_time=tg, shrinking_time=ts, n_catastrophes=nc, n_rescues=nr,
            n_tracks=length(unique((r.condition, r.track) for r in rows)), n_segments=length(rows))
end

"""
    bootstrap_tracks(rows; repeats=200, seed=10)

Approximate 95 % percentile intervals for `vg, vs, catastrophe, rescue`, from resampling
whole tracks (not segments or time samples). With few tracks or zero events, intervals can
be misleading: inspect the counts.
"""
function bootstrap_tracks(rows; repeats=200, seed=10)
    ids = unique((r.condition, r.track) for r in rows)
    length(ids) >= 2 || throw(ArgumentError("Need at least two independent tracks for this bootstrap."))
    groups = [filter(r -> (r.condition, r.track) == id, rows) for id in ids]
    rng = Xoshiro(seed)
    keys = (:vg, :vs, :catastrophe, :rescue)
    samples = [summarize_segments(reduce(vcat, groups[rand(rng, 1:length(ids), length(ids))]))
               for _ in 1:repeats]
    interval(k) = (v = filter(!isnan, [x[k] for x in samples]);
                   isempty(v) ? (NaN, NaN) : (quantile(v, 0.025), quantile(v, 0.975)))
    return NamedTuple{keys}(map(interval, keys))
end

"""
    simulated_segments(result; track="sim", condition="simulation")

Converts a switching-model run into rows of the same segment table as the experiments, so
that both go through the same analysis. The last segment is censored by the end of the run.
"""
function simulated_segments(result; track="sim", condition="simulation")
    change_kind = Dict(t => kind for (t, kind) in result.events)
    rows = NamedTuple[]
    start = 1
    n = length(result.t)
    for j in 2:n
        if result.growing[j] != result.growing[j-1] || j == n
            state = result.growing[j-1] ? "G" : "S"
            ending = j == n && result.growing[j] == result.growing[j-1] ? "censored" :
                     string(change_kind[result.t[j]])
            push!(rows, (; condition, track=string(track), state,
                         duration_s=result.t[j] - result.t[start],
                         delta_length_um=result.length[j] - result.length[start],
                         end_event=ending, source="SIMULATION"))
            start = j
        end
    end
    return rows
end

end # module
