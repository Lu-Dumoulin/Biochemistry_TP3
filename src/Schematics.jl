"""
    Schematics

Inline SVG schematics and navigation links for the notebooks. Each function returns an
`HTML` object that Pluto displays directly. Text and lines follow Pluto's light/dark
theme; the accent colors are mid-tones that read on both.
"""
module Schematics

export levels_schematic, kymograph_schematic, two_state_schematic, decision_schematic,
       course_map_schematic, notebook_link, segments_schematic, chain_events_schematic,
       gillespie_schematic, pulse_schematic, chain_schematic, rescue_models_schematic

# Percent-encodes a file path for a URL query, so that links survive spaces and accents
# (e.g. a folder under "OneDrive - Université de Genève").
function encode_path(path)
    unreserved(b) = UInt8('A') <= b <= UInt8('Z') || UInt8('a') <= b <= UInt8('z') ||
                    UInt8('0') <= b <= UInt8('9') || b in codeunits("/-_.~")
    return join(unreserved(b) ? string(Char(b)) : "%" * uppercase(string(b; base=16, pad=2))
                for b in codeunits(path))
end

"""
    notebook_link(path, label)

A link that opens the Pluto notebook at `path` in the running Pluto session, or a note
that the notebook is not available yet.
"""
function notebook_link(path, label)
    isfile(path) || return HTML("""<p style="opacity:0.7"><em>$label: in preparation.</em></p>""")
    return HTML("""<p>👉 <a href="./open?path=$(encode_path(path))"><strong>$label</strong></a></p>""")
end

const STYLE = """
<style>
.mt-fig { max-width: 100%; height: auto; font-family: system-ui, -apple-system, sans-serif; }
.mt-fig text { fill: var(--pluto-output-color, #1f2328); font-size: 13px; }
.mt-fig .small { font-size: 11px; }
.mt-fig .title { font-size: 14px; font-weight: 600; }
.mt-fig .muted { fill: #868e99; }
.mt-fig .ink { stroke: var(--pluto-output-color, #1f2328); fill: none; }
.mt-fig .axis { stroke: #868e99; stroke-width: 1; fill: none; }
.mt-fig .G { stroke: #1b9e77; } .mt-fig .S { stroke: #d95f02; }
.mt-fig .fG { fill: #1b9e77; }  .mt-fig .fS { fill: #d95f02; }
.mt-fig .T { fill: #e6a117; }   .mt-fig .D { fill: #8f9cad; }
.mt-fig .seed { fill: #5d6875; }
.mt-fig .mtfill { fill: #8f9cad; fill-opacity: 0.35; }
</style>
"""

# Arrowhead markers, one per color, prefixed so several figures can share a page.
markers(prefix) = """
<defs>
  <marker id="$(prefix)-ink" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
    <path d="M0,0 L10,5 L0,10 z" fill="#868e99"/></marker>
  <marker id="$(prefix)-G" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
    <path d="M0,0 L10,5 L0,10 z" fill="#1b9e77"/></marker>
  <marker id="$(prefix)-S" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
    <path d="M0,0 L10,5 L0,10 z" fill="#d95f02"/></marker>
</defs>
"""

svg(width, height, body; label) = HTML("""
$STYLE
<svg class="mt-fig" viewBox="0 0 $width $height" width="$width" role="img" aria-label="$label">
$body
</svg>
""")

fmt(x) = string(round(x; digits=1))

"""
    levels_schematic()

The same filament at three levels of description: the real lattice, the T/D chain of
afternoons 3–4, and the length-plus-state description of afternoons 1–2.
"""
function levels_schematic()
    b = IOBuffer()
    # Panel 1: side view of a few protofilaments on a seed, ragged plus end with a GTP cap.
    print(b, """<text class="title" x="20" y="24">Microtubule</text>
    <text class="small muted" x="20" y="40">13 protofilaments: not simulated here</text>
    <rect class="seed" x="20" y="62" width="34" height="88" rx="3"/>
    <text class="small" x="22" y="168">seed</text>
    <text class="small" x="8" y="110">−</text>""")
    row_lengths = (11, 13, 12, 10, 12)
    for (r, nr) in enumerate(row_lengths), c in 1:nr
        x = 58 + (c - 1) * 15 + (isodd(r) ? 0 : 6)
        y = 64 + (r - 1) * 17
        state = c > nr - 3 ? "T" : "D"
        print(b, """<rect class="$state" x="$x" y="$y" width="13" height="14" rx="3"/>""")
    end
    print(b, """<text class="small" x="262" y="110">+</text>
    <text class="small" x="196" y="168">GTP cap</text>""")

    # Panel 2: one-dimensional T/D chain on a seed.
    chain = "DDDDDTDDTTT"
    print(b, """<text class="title" x="300" y="24">T/D chain</text>
    <text class="small muted" x="300" y="40">afternoons 3–4: subunit events</text>
    <rect class="seed" x="300" y="98" width="24" height="22" rx="3"/>""")
    for (i, s) in enumerate(chain)
        print(b, """<rect class="$s" x="$(326 + (i - 1) * 18)" y="98" width="16" height="22" rx="3"/>""")
    end
    print(b, """<text class="small" x="300" y="80">+ end: add T, or lose the end subunit</text>
    <text class="small" x="300" y="146">hydrolysis T → D, rate h per T</text>
    <rect class="T" x="300" y="160" width="10" height="10" rx="2"/><text class="small" x="314" y="169">T (GTP-like)</text>
    <rect class="D" x="400" y="160" width="10" height="10" rx="2"/><text class="small" x="414" y="169">D (GDP-like)</text>""")

    # Panel 3: length and a growing/shrinking label.
    print(b, """<text class="title" x="560" y="24">Length + state</text>
    <text class="small muted" x="560" y="40">afternoons 1–2: speeds and switches</text>
    <rect class="seed" x="560" y="98" width="24" height="22" rx="3"/>
    <line class="ink" x1="584" y1="109" x2="700" y2="109" stroke-width="6" stroke-linecap="round"/>
    <path class="axis" d="M584,130 v6 h116 v-6"/>
    <text x="636" y="152">L</text>
    <line class="G" x1="708" y1="100" x2="738" y2="100" stroke-width="2" marker-end="url(#lv-G)"/>
    <text class="small" x="706" y="90">G: +v_g</text>
    <line class="S" x1="738" y1="120" x2="708" y2="120" stroke-width="2" marker-end="url(#lv-S)"/>
    <text class="small" x="706" y="136">S: −v_s</text>""")

    # "Less detail" arrows between panels.
    print(b, """<line class="axis" x1="20" y1="200" x2="760" y2="200" marker-end="url(#lv-ink)"/>
    <text class="small muted" x="390" y="192" text-anchor="middle">keep less detail</text>""")
    return svg(780, 220, markers("lv") * String(take!(b));
               label="Three levels of description of a microtubule")
end

# Deterministic example trajectory used by the kymograph schematic:
# (state, duration in s) with vg = 0.03 µm/s and vs = 0.18 µm/s, starting at 1 µm.
function example_trajectory()
    vg, vs = 0.03, 0.18
    segments = [(:G, 80.0), (:S, 10.0), (:G, 37.0), (:S, Inf), (:G, 83.0), (:S, 11.5), (:G, 45.0)]
    ends = [:catastrophe, :rescue, :catastrophe, :seed_restart, :catastrophe, :rescue, :none]
    t, L = 0.0, 1.0
    points = [(t, L)]
    pieces = Tuple{Symbol,Float64,Float64,Float64,Float64}[]   # state, t0, L0, t1, L1
    events = Tuple{Symbol,Float64,Float64}[]
    for ((state, duration), kind) in zip(segments, ends)
        d = state == :S ? min(duration, L / vs) : duration
        t1, L1 = t + d, max(0.0, L + (state == :G ? vg : -vs) * d)
        push!(pieces, (state, t, L, t1, L1)); push!(points, (t1, L1))
        kind == :none || push!(events, (kind, t1, L1))
        t, L = t1, L1
    end
    return (; points, pieces, events)
end

"""
    kymograph_schematic()

From a kymograph (position across, time down) to a length trace with the four inputs
of the switching model: v_g, v_s, catastrophe and rescue frequencies.
"""
function kymograph_schematic()
    traj = example_trajectory()
    tmax = traj.points[end][1]; Lmax = 3.6
    b = IOBuffer()

    # Left: kymograph. Position x → right, time t ↓.
    kx(L) = 78 + L / Lmax * 160
    ky(t) = 58 + t / tmax * 210
    print(b, """<text class="title" x="20" y="24">Kymograph</text>
    <text class="small muted" x="20" y="40">one microtubule, last week</text>
    <rect class="seed" x="58" y="58" width="20" height="210"/>
    <text class="small" x="44" y="286">seed</text>""")
    edge = join(("$(fmt(kx(L))),$(fmt(ky(t)))" for (t, L) in traj.points), " ")
    print(b, """<polygon class="mtfill" points="$(fmt(kx(0))),$(fmt(ky(0))) $edge $(fmt(kx(0))),$(fmt(ky(tmax)))"/>""")
    for (state, t0, L0, t1, L1) in traj.pieces
        print(b, """<line class="$state" x1="$(fmt(kx(L0)))" y1="$(fmt(ky(t0)))" x2="$(fmt(kx(L1)))" y2="$(fmt(ky(t1)))" stroke-width="2.5"/>""")
    end
    print(b, """<line class="axis" x1="90" y1="282" x2="230" y2="282" marker-end="url(#ky-ink)"/>
    <text class="small muted" x="140" y="298">position</text>
    <line class="axis" x1="256" y1="60" x2="256" y2="262" marker-end="url(#ky-ink)"/>
    <text class="small muted" x="256" y="280" text-anchor="middle">time</text>
    <line class="axis" x1="286" y1="160" x2="334" y2="160" marker-end="url(#ky-ink)"/>
    <text class="small muted" x="310" y="150" text-anchor="middle">measure</text>""")

    # Right: extracted length trace with annotated inputs.
    tx(t) = 350 + t / tmax * 390
    ly(L) = 250 - L / Lmax * 190
    print(b, """<text class="title" x="350" y="24">Length trace → four inputs</text>
    <path class="axis" d="M350,58 V250 H748"/>
    <text class="small muted" x="700" y="268">time (s)</text>
    <text class="small muted" x="300" y="66">length</text>
    <text class="small muted" x="314" y="80">(µm)</text>
    <line class="seed" x1="350" y1="250" x2="748" y2="250" stroke="#5d6875" stroke-width="4"/>""")
    for (state, t0, L0, t1, L1) in traj.pieces
        print(b, """<line class="$state" x1="$(fmt(tx(t0)))" y1="$(fmt(ly(L0)))" x2="$(fmt(tx(t1)))" y2="$(fmt(ly(L1)))" stroke-width="2.5"/>""")
    end
    for (kind, t, L) in traj.events
        x, y = tx(t), ly(L)
        if kind == :catastrophe
            print(b, """<path class="fS" d="M$(fmt(x - 6)),$(fmt(y - 14)) h12 l-6,9 z"/>""")
        elseif kind == :rescue
            print(b, """<circle class="fG" cx="$(fmt(x))" cy="$(fmt(y))" r="5"/>""")
        else
            print(b, """<path fill="#868e99" d="M$(fmt(x)),$(fmt(y - 7)) l6,7 l-6,7 l-6,-7 z"/>""")
        end
    end
    # Slope labels on the first growth and first shrink segment.
    _, t0, L0, t1, L1 = traj.pieces[1]
    print(b, """<text class="small" x="$(fmt(tx((t0 + t1) / 2) - 10))" y="$(fmt(ly((L0 + L1) / 2) - 12))" text-anchor="end">slope +v_g</text>""")
    _, t0, L0, t1, L1 = traj.pieces[4]
    t_label = t0 + (L0 - 2.0) / (L0 - L1) * (t1 - t0)   # where this shrink passes L = 2 µm
    print(b, """<text class="small" x="$(fmt(tx(t_label) + 8))" y="$(fmt(ly(2.0)))">slope −v_s</text>""")
    # Legend.
    print(b, """<path class="fS" d="M360,290 h12 l-6,9 z"/><text class="small" x="378" y="299">catastrophe: count / time growing = k_c</text>
    <circle class="fG" cx="366" cy="314" r="5"/><text class="small" x="378" y="318">rescue: count / time shrinking = k_r</text>
    <path fill="#868e99" d="M366,326 l6,7 l-6,7 l-6,-7 z"/><text class="small" x="378" y="337">reaches the seed: restart, NOT a rescue</text>""")
    return svg(780, 350, markers("ky") * String(take!(b));
               label="Kymograph and the length trace measured from it, with catastrophes and rescues marked")
end

"""
    two_state_schematic()

State diagram of the effective model: growing (G) and shrinking (S), the two switching
rates, and the seed boundary restart.
"""
function two_state_schematic()
    body = """
    <circle cx="150" cy="105" r="52" fill="none" class="G" stroke-width="3"/>
    <text x="150" y="98" text-anchor="middle" style="font-size:22px;font-weight:700">G</text>
    <text class="small" x="150" y="116" text-anchor="middle">growing</text>
    <text class="small" x="150" y="132" text-anchor="middle">dL/dt = +v_g</text>
    <circle cx="450" cy="105" r="52" fill="none" class="S" stroke-width="3"/>
    <text x="450" y="98" text-anchor="middle" style="font-size:22px;font-weight:700">S</text>
    <text class="small" x="450" y="116" text-anchor="middle">shrinking</text>
    <text class="small" x="450" y="132" text-anchor="middle">dL/dt = −v_s</text>
    <path class="S" d="M196,80 Q300,20 404,80" fill="none" stroke-width="2" marker-end="url(#ts-S)"/>
    <text x="300" y="36" text-anchor="middle">catastrophe, rate k_c</text>
    <path class="G" d="M404,130 Q300,190 196,130" fill="none" stroke-width="2" marker-end="url(#ts-G)"/>
    <text x="300" y="182" text-anchor="middle">rescue, rate k_r</text>
    <rect x="215" y="210" width="170" height="40" rx="6" fill="none" stroke="#868e99" stroke-dasharray="4 3"/>
    <text class="small" x="300" y="226" text-anchor="middle">L reaches 0 at the seed</text>
    <text class="small" x="300" y="242" text-anchor="middle">→ restart growing</text>
    <path d="M440,158 Q430,228 388,230" fill="none" stroke="#868e99" stroke-dasharray="4 3" marker-end="url(#ts-ink)"/>
    <path d="M212,230 Q170,228 160,160" fill="none" stroke="#868e99" stroke-dasharray="4 3" marker-end="url(#ts-ink)"/>
    <text class="small muted" x="300" y="268" text-anchor="middle">a boundary rule, not a rescue: it is not counted in k_r</text>
    """
    return svg(600, 280, markers("ts") * body;
               label="Two-state diagram: growing and shrinking states with catastrophe and rescue rates")
end

"""
    course_map_schematic()

The five afternoons in order, each tagged with the model it uses.
"""
function course_map_schematic()
    afternoons = [
        ("Randomness", "and switching", "switching model", "fG"),
        ("Connect to", "experiments", "switching + data", "fG"),
        ("Subunits and", "hydrolysis", "T/D chain, 1 end", "T"),
        ("Two ends and", "treadmilling", "T/D chain, 2 ends", "T"),
        ("Your own", "investigation", "your choice", "D"),
    ]
    b = IOBuffer()
    for (i, (line1, line2, model, color)) in enumerate(afternoons)
        x = 10 + (i - 1) * 154
        print(b, """<rect x="$x" y="10" width="138" height="112" rx="10" fill="none" stroke="#868e99"/>
        <circle class="$color" cx="$(x + 22)" cy="34" r="13"/>
        <text x="$(x + 22)" y="39" text-anchor="middle" style="font-weight:700;fill:#fff">$i</text>
        <text class="small muted" x="$(x + 42)" y="38">afternoon</text>
        <text class="title" x="$(x + 12)" y="68">$line1</text>
        <text class="title" x="$(x + 12)" y="86">$line2</text>
        <rect class="$color" x="$(x + 10)" y="98" width="118" height="16" rx="8" fill-opacity="0.25"/>
        <text class="small" x="$(x + 69)" y="110" text-anchor="middle">$model</text>""")
        i < length(afternoons) &&
            print(b, """<line class="axis" x1="$(x + 140)" y1="66" x2="$(x + 152)" y2="66" marker-end="url(#cm-ink)"/>""")
    end
    return svg(780, 132, markers("cm") * String(take!(b));
               label="Course map: five afternoons and the model used in each")
end

"""
    decision_schematic(threshold, draws)

The unit interval split at `threshold` (= k·Δt): a uniform draw U below it triggers the
event. `draws` are shown as dots above the bar.
"""
function decision_schematic(threshold, draws)
    x(u) = 40 + clamp(u, 0, 1) * 520
    hits = count(<(threshold), draws)
    b = IOBuffer()
    print(b, """<rect class="fG" x="40" y="70" width="$(fmt(x(threshold) - 40))" height="18" fill-opacity="0.45"/>
    <rect class="D" x="$(fmt(x(threshold)))" y="70" width="$(fmt(560 - x(threshold)))" height="18" fill-opacity="0.35"/>
    <path class="axis" d="M40,70 v28 M560,70 v28"/>
    <line x1="$(fmt(x(threshold)))" y1="62" x2="$(fmt(x(threshold)))" y2="98" stroke="#1b9e77" stroke-width="2"/>
    <text class="small" x="40" y="112" text-anchor="middle">0</text>
    <text class="small" x="560" y="112" text-anchor="middle">1</text>
    <text class="small" x="$(fmt(x(threshold)))" y="112" text-anchor="middle">k·Δt = $(round(threshold; digits=3))</text>
    <text class="small" x="$(fmt((40 + x(threshold)) / 2))" y="83" text-anchor="middle">$(threshold > 0.12 ? "event" : "")</text>
    <text class="small" x="$(fmt((x(threshold) + 560) / 2))" y="83" text-anchor="middle">$(threshold < 0.88 ? "no event" : "")</text>""")
    for (i, u) in enumerate(draws)
        y = 30 + 26 * ((i - 1) % 2) / 2   # two staggered rows so close draws stay visible
        cls = u < threshold ? "fG" : "D"
        print(b, """<circle class="$cls" cx="$(fmt(x(u)))" cy="$(fmt(y))" r="4.5" stroke="#868e99" stroke-width="0.5"/>""")
    end
    print(b, """<text class="small" x="40" y="16">Each dot is one draw U. Event when U &lt; k·Δt: $hits of the $(length(draws)) draws shown.</text>""")
    return svg(600, 122, String(take!(b)); label="Unit interval split at k times dt, with random draws")
end

"""
    segments_schematic()

One measured track cut into the rows of a segment table, and the time at risk used for
each switching rate.
"""
function segments_schematic()
    traj = example_trajectory()
    tmax = traj.points[end][1]; Lmax = 3.6
    tx(t) = 60 + t / tmax * 660
    ly(L) = 150 - L / Lmax * 110
    b = IOBuffer()
    print(b, """<path class="axis" d="M60,40 V150 H730"/>
    <text class="small muted" x="680" y="166">time (s)</text>
    <text class="small muted" x="8" y="48">length</text>""")
    ending(i) = i <= length(traj.events) ? string(traj.events[i][1]) : "censored"
    rows = []
    for (i, (state, t0, L0, t1, L1)) in enumerate(traj.pieces)
        print(b, """<rect class="$(state == :G ? "fG" : "fS")" x="$(fmt(tx(t0)))" y="40" width="$(fmt(tx(t1) - tx(t0)))" height="110" fill-opacity="0.08"/>
        <line class="$state" x1="$(fmt(tx(t0)))" y1="$(fmt(ly(L0)))" x2="$(fmt(tx(t1)))" y2="$(fmt(ly(L1)))" stroke-width="2.5"/>
        <text class="small" x="$(fmt((tx(t0) + tx(t1)) / 2))" y="34" text-anchor="middle">$i</text>""")
        push!(rows, (i, state, t1 - t0, L1 - L0, ending(i)))
    end
    print(b, """<line x1="$(fmt(tx(tmax)))" y1="36" x2="$(fmt(tx(tmax)))" y2="154" stroke="#868e99" stroke-dasharray="4 3"/>
    <text class="small muted" x="$(fmt(tx(tmax) - 4))" y="62" text-anchor="end">end of movie</text>""")
    # The table, one row per segment.
    cols = (60, 110, 160, 260, 380)
    y = 196
    for (x, h) in zip(cols, ("#", "state", "duration_s", "delta_length_um", "end_event"))
        print(b, """<text class="small" x="$x" y="$y" style="font-weight:600">$h</text>""")
    end
    for (i, state, d, dL, e) in rows
        y += 18
        cells = (string(i), string(state), string(round(d; digits=1)), string(round(dL; digits=2)), e)
        for (x, c) in zip(cols, cells)
            print(b, """<text class="small" x="$x" y="$y">$c</text>""")
        end
    end
    # Time at risk.
    tg = sum(r[3] for r in rows if r[2] == :G); ts = sum(r[3] for r in rows if r[2] == :S)
    nc = count(r -> r[5] == "catastrophe", rows); nr = count(r -> r[5] == "rescue", rows)
    print(b, """<text class="small" x="500" y="214"><tspan class="fS" style="font-weight:600">k_c</tspan> = $nc catastrophes / $(round(Int, tg)) s growing</text>
    <text class="small muted" x="500" y="232">growing time includes the censored segment 7</text>
    <text class="small" x="500" y="262"><tspan class="fG" style="font-weight:600">k_r</tspan> = $nr rescues / $(round(Int, ts)) s shrinking</text>
    <text class="small muted" x="500" y="280">segment 4 reaches the seed: not a rescue</text>""")
    return svg(780, 340, String(take!(b));
               label="A length trace cut into growth and shrinkage segments, listed as rows of a segment table")
end

"""
    chain_events_schematic(; two_ends=false)

The events of the T/D chain model: addition of T, loss of the terminal subunit at a rate
that depends on its state, and hydrolysis of any T. With `two_ends`, the minus end is
dynamic too; otherwise it sits on a protected seed.
"""
function chain_events_schematic(; two_ends=false)
    chain = "DDDTDDDTDTTT"
    x0 = two_ends ? 234 : 190
    w = 26
    b = IOBuffer()
    if !two_ends
        print(b, """<rect class="seed" x="$(x0 - 40)" y="80" width="36" height="30" rx="4"/>
        <text class="small" x="$(x0 - 22)" y="128" text-anchor="middle">seed</text>""")
    end
    for (i, c) in enumerate(chain)
        print(b, """<rect class="$c" x="$(x0 + (i - 1) * w)" y="80" width="$(w - 3)" height="30" rx="4"/>
        <text class="small" x="$(x0 + (i - 1) * w + 11)" y="100" text-anchor="middle" style="fill:#fff;font-weight:600">$c</text>""")
    end
    xe = x0 + length(chain) * w
    # Plus end: addition and loss.
    print(b, """<text class="small" x="$(xe - 3)" y="128" text-anchor="end">+ end</text>
    <path class="G" d="M$(xe + 90),60 Q$(xe + 40),50 $(xe + 6),78" fill="none" stroke-width="2" marker-end="url(#ce-G)"/>
    <rect class="T" x="$(xe + 92)" y="48" width="20" height="20" rx="3"/>
    <text class="small" x="$(xe + 118)" y="62">add T, rate u₊</text>
    <path class="S" d="M$(xe - 8),114 Q$(xe + 30),150 $(xe + 86),140" fill="none" stroke-width="2" marker-end="url(#ce-S)"/>
    <text class="small" x="$(xe + 92)" y="144">lose end: w₊T or w₊D</text>""")
    # Hydrolysis on an internal T.
    xh = x0 + 7 * w + 11
    print(b, """<path d="M$xh,78 q0,-34 26,-40" fill="none" stroke="#868e99" stroke-width="1.5" marker-end="url(#ce-ink)"/>
    <text class="small" x="$(xh + 30)" y="34">hydrolysis T → D</text>
    <text class="small muted" x="$(xh + 30)" y="50">rate h for each T</text>""")
    if two_ends
        print(b, """<text class="small" x="$x0" y="128">− end</text>
        <path class="G" d="M$(x0 - 96),60 Q$(x0 - 46),50 $(x0 - 8),78" fill="none" stroke-width="2" marker-end="url(#ce-G)"/>
        <rect class="T" x="$(x0 - 118)" y="48" width="20" height="20" rx="3"/>
        <text class="small" x="$(x0 - 124)" y="62" text-anchor="end">add T, u₋</text>
        <path class="S" d="M$(x0 + 6),114 Q$(x0 - 30),150 $(x0 - 86),140" fill="none" stroke-width="2" marker-end="url(#ce-S)"/>
        <text class="small" x="$(x0 - 92)" y="144" text-anchor="end">lose end: w₋T or w₋D</text>""")
    else
        print(b, """<text class="small muted" x="$(x0 - 40)" y="146">minus end protected: no events</text>""")
    end
    print(b, """<text class="small muted" x="$(x0 + length(chain) * w / 2)" y="166" text-anchor="middle">the loss rate depends on whether the end subunit is T or D</text>""")
    width = two_ends ? 780 : 720
    return svg(width, 170, markers("ce") * String(take!(b));
               label="Events of the T/D chain model: addition, loss of the end subunit, and hydrolysis")
end

const EVENT_LABELS = ("add at +", "lose at +", "add at −", "lose at −", "hydrolysis")
const EVENT_COLORS = ("#1b9e77", "#d95f02", "#66c2a5", "#fc8d62", "#e6a117")

"""
    gillespie_schematic(rates; chosen=nothing)

The Gillespie choice as a bar of total length R = sum of the rates: each event occupies a
share proportional to its rate, and a uniform random point on the bar picks the event.
`rates` is a collection of five rates in the order of `EVENT_LABELS`; `chosen` (1–5)
highlights the event that was picked.
"""
function gillespie_schematic(rates; chosen=nothing)
    r = collect(Float64, rates)
    total = sum(r)
    b = IOBuffer()
    x = 40.0
    for (i, ri) in enumerate(r)
        ri > 0 || continue
        w = ri / total * 520
        stroke = i == chosen ? """ stroke="var(--pluto-output-color, #1f2328)" stroke-width="2.5" """ : ""
        print(b, """<rect x="$(fmt(x))" y="40" width="$(fmt(w))" height="26" fill="$(EVENT_COLORS[i])" fill-opacity="0.75"$stroke/>""")
        w > 60 && print(b, """<text class="small" x="$(fmt(x + w / 2))" y="58" text-anchor="middle">$(EVENT_LABELS[i])</text>""")
        print(b, """<text class="small muted" x="$(fmt(x + w / 2))" y="84" text-anchor="middle">$(round(ri / total; digits=2))</text>""")
        x += w
    end
    lx = 40
    for (i, ri) in enumerate(r)
        ri > 0 || continue
        print(b, """<rect x="$lx" y="98" width="10" height="10" fill="$(EVENT_COLORS[i])" fill-opacity="0.75"/>
        <text class="small" x="$(lx + 14)" y="107">$(EVENT_LABELS[i])</text>""")
        lx += 110
    end
    print(b, """<text class="small" x="40" y="24">Total rate R = $(round(total; digits=3)): mean waiting time 1/R = $(round(1 / total; digits=3)). Numbers below: probability of each event.</text>""")
    return svg(600, 116, String(take!(b)); label="Bar split in proportion to the event rates")
end

"""
    pulse_schematic()

A pulse-labeled band in a treadmilling chain at three times. Coordinates are lattice
sites: the band stays where it was incorporated while the plus end adds new material and
the minus end removes old material, until the band itself is removed.
"""
function pulse_schematic()
    w = 22
    b = IOBuffer()
    rows = ((0, "just after the pulse"), (6, "later"), (12, "much later"))
    band = 9:11
    for (k, (shift, label)) in enumerate(rows)
        y = 26 + (k - 1) * 44
        print(b, """<text class="small muted" x="10" y="$(y + 16)">$label</text>""")
        for site in (1 + shift):(12 + shift)
            cls = site in band ? "fS" : "D"
            print(b, """<rect class="$cls" x="$(130 + (site - 1) * w)" y="$y" width="$(w - 3)" height="22" rx="3"/>""")
        end
    end
    print(b, """<line x1="$(130 + 8 * w - 2)" y1="18" x2="$(130 + 8 * w - 2)" y2="160" stroke="#d95f02" stroke-dasharray="3 3"/>
    <line x1="$(130 + 11 * w - 1)" y1="18" x2="$(130 + 11 * w - 1)" y2="160" stroke="#d95f02" stroke-dasharray="3 3"/>
    <line class="axis" x1="130" y1="168" x2="760" y2="168" marker-end="url(#pu-ink)"/>
    <text class="small muted" x="445" y="186" text-anchor="middle">the − end removes old material and the + end adds new: both ends move along the lattice, the band does not</text>
    <text class="small" x="$(130 + 8 * w + 33)" y="14" text-anchor="middle">labeled band: fixed lattice sites</text>""")
    return svg(780, 192, markers("pu") * String(take!(b));
               label="A pulse-labeled band stays at fixed lattice sites while both ends advance, until it is removed")
end

"""
    chain_schematic(chain; seeded=true)

A T/D chain drawn as boxes (`chain` is a vector with `true` for T), on a protected seed if
`seeded`. Long chains are cut after 30 subunits, keeping the plus end.
"""
function chain_schematic(chain; seeded=true)
    shown = length(chain) > 30 ? chain[end-29:end] : chain
    w = 22
    b = IOBuffer()
    x = 10
    if seeded
        print(b, """<rect class="seed" x="$x" y="8" width="30" height="24" rx="4"/>""")
        x += 34
    end
    if length(chain) > 30
        print(b, """<text class="small muted" x="$x" y="25">…</text>""")
        x += 16
    end
    for v in shown
        c = v ? "T" : "D"
        print(b, """<rect class="$c" x="$x" y="8" width="$(w - 3)" height="24" rx="3"/>
        <text class="small" x="$(x + 9.5)" y="24" text-anchor="middle" style="fill:#fff;font-weight:600">$c</text>""")
        x += w
    end
    isempty(chain) && print(b, """<text class="small muted" x="$x" y="25">empty</text>""")
    print(b, """<text class="small muted" x="$(x + 6)" y="25">+ end</text>""")
    return svg(max(x + 50, 200), 40, String(take!(b)); label="T/D chain with $(length(chain)) subunits")
end

"""
    rescue_models_schematic()

The two descriptions of rescue compared in afternoon 5b: a constant rescue rate anywhere
(Dogterom–Leibler, afternoons 1–2) versus rescue only at exchanged sites along the shaft
(Schaer et al. 2023), which kinesin-1 creates by damaging the lattice.
"""
function rescue_models_schematic()
    w = 19
    b = IOBuffer()
    x0 = 205
    lattice(y, chain) = for (i, c) in enumerate(chain)
        cls = c == 'T' ? "T" : c == 'X' ? "X" : "D"
        fill = cls == "X" ? "#1b9e77" : ""
        print(b, cls == "X" ? """<rect x="$(x0 + (i - 1) * w)" y="$y" width="$(w - 3)" height="22" rx="3" fill="#1b9e77"/>""" :
                 """<rect class="$cls" x="$(x0 + (i - 1) * w)" y="$y" width="$(w - 3)" height="22" rx="3"/>""")
    end
    # Model A
    print(b, """<text class="title" x="10" y="30">A · constant rate</text>
    <text class="small muted" x="10" y="48">afternoons 1–2</text>
    <rect class="seed" x="$(x0 - 34)" y="22" width="30" height="22" rx="3"/>""")
    lattice(22, "DDDDDDDDDDDDDDDDDDDD")
    print(b, """<path class="S" d="M$(x0 + 20 * w + 30),33 h-40" fill="none" stroke-width="2" marker-end="url(#rm-S)"/>
    <text class="small" x="$(x0 + 20 * w + 40)" y="38">shrinking</text>
    <text class="small" x="$x0" y="70">a rescue can happen anywhere, at rate k_res</text>""")
    for i in (4, 9, 14)
        print(b, """<line x1="$(x0 + (i - 1) * w + 8)" y1="16" x2="$(x0 + (i - 1) * w + 8)" y2="50" stroke="#868e99" stroke-dasharray="3 3"/>""")
    end
    # Model B
    yB = 110
    print(b, """<text class="title" x="10" y="$(yB + 8)">B · exchange sites</text>
    <text class="small muted" x="10" y="$(yB + 26)">Schaer et al. 2023</text>
    <rect class="seed" x="$(x0 - 34)" y="$yB" width="30" height="22" rx="3"/>""")
    lattice(yB, "DDXDDDDDDXDDDDDDDDDD")
    print(b, """<path class="S" d="M$(x0 + 20 * w + 30),$(yB + 11) h-40" fill="none" stroke-width="2" marker-end="url(#rm-S)"/>
    <text class="small" x="$(x0 + 20 * w + 40)" y="$(yB + 16)">shrinking</text>
    <ellipse cx="$(x0 + 6 * w + 8)" cy="$(yB - 12)" rx="16" ry="9" fill="#e6a117"/>
    <path d="M$(x0 + 6 * w + 24),$(yB - 12) h34" stroke="#e6a117" stroke-width="2" marker-end="url(#rm-T)"/>
    <text class="small" x="$(x0 + 6 * w + 66)" y="$(yB - 8)">kinesin-1 walks to the + end and damages the lattice</text>
    <text class="small" x="$x0" y="$(yB + 48)">repair inserts GTP-tubulin (exchanged site, green): only there</text>
    <text class="small" x="$x0" y="$(yB + 66)">can a shrinking microtubule be rescued, with probability p_res</text>""")
    print(b, """<defs><marker id="rm-T" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="#e6a117"/></marker></defs>""")
    return svg(780, 190, markers("rm") * String(take!(b));
               label="Two models of rescue: a constant rate anywhere, or only at exchanged sites created by kinesin damage")
end

end # module
