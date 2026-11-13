"""
    Widgets

Small interactive inputs for the notebooks that PlutoUI does not provide.
"""
module Widgets

import AbstractPlutoDingetjes
import Base64

export Stepper, KymoTracer, png_size

"""
    Stepper(values; default=first(values))

An integer input with ◀ previous / next ▶ buttons around a slider, all controlling the
same value: `@bind n Stepper(0:40)`. The value stays within `values`.
"""
struct Stepper
    values::UnitRange{Int}
    default::Int
    function Stepper(values::AbstractUnitRange{<:Integer}; default=first(values))
        default in values || throw(ArgumentError("default $default is outside $values"))
        return new(values, default)
    end
end

function Base.show(io::IO, ::MIME"text/html", s::Stepper)
    print(io, """
    <span style="display:inline-flex; align-items:center; gap:0.4em">
    <button type="button">◀ previous</button>
    <input type="range" min="$(first(s.values))" max="$(last(s.values))" step="1" value="$(s.default)">
    <button type="button">next ▶</button>
    <output style="min-width:2em; font-variant-numeric:tabular-nums">$(s.default)</output>
    <script>
    const span = currentScript.parentElement
    const [previous, next] = span.querySelectorAll("button")
    const range = span.querySelector("input")
    const shown = span.querySelector("output")
    // The range input clamps to [min, max]; one "input" event per change reaches Pluto.
    const set = (v) => {
        range.value = v
        shown.value = range.value
        span.value = Number(range.value)
        span.dispatchEvent(new CustomEvent("input"))
    }
    span.value = Number(range.value)
    range.addEventListener("input", (e) => { e.stopPropagation(); set(range.value) })
    previous.addEventListener("click", () => set(Number(range.value) - 1))
    next.addEventListener("click", () => set(Number(range.value) + 1))
    </script>
    </span>""")
end

AbstractPlutoDingetjes.Bonds.initial_value(s::Stepper) = s.default
AbstractPlutoDingetjes.Bonds.possible_values(s::Stepper) = s.values
AbstractPlutoDingetjes.Bonds.transform_value(::Stepper, v) = round(Int, v)
AbstractPlutoDingetjes.Bonds.validate_value(s::Stepper, v) = v isa Real && isinteger(v) && v in s.values


"Width and height of a PNG file, read from its header."
function png_size(bytes::AbstractVector{UInt8})
    length(bytes) >= 24 && bytes[2:4] == UInt8['P', 'N', 'G'] ||
        throw(ArgumentError("Not a PNG file."))
    be(i) = (Int(bytes[i]) << 24) | (Int(bytes[i + 1]) << 16) | (Int(bytes[i + 2]) << 8) | Int(bytes[i + 3])
    return (width=be(17), height=be(21))
end

"""
    KymoTracer(png_bytes; scale=2, corners=[], pairs=false, margin=0, seed=nothing)

Click on a kymograph image to mark the corners of its edge, in time order:
`@bind corners KymoTracer(read("kymograph.png"))`. The value is a vector of `(row, col)` pairs
in image pixels (row 1 = top, col 1 = left). "Undo last corner" and "Clear" edit the list.
Corners are kept in time order, so a missing corner can be added afterwards; clicking on a
corner removes it. The image is shown `scale` times larger; `corners` sets the starting list.
With `pairs=true`, clicks 1–2, 3–4, ... draw separate numbered lines (start marked green).
`margin` adds that many image pixels of empty space on each side, to click near the edges
(columns there are ≤ 0 or > the image width). `seed` draws a dashed vertical line at the right
edge of that column, the end of the seed, with a slider to move it: the line moves at once, but
the new seed is only sent when "Set seed" is pressed. With `seed`, the value is
`(corners=..., seed=...)` instead of the corners alone.
"""
struct KymoTracer
    data::String
    width::Int
    height::Int
    scale::Float64
    corners::Vector{Tuple{Int,Int}}
    pairs::Bool
    margin::Int
    seed::Int                  # 0: no seed line
end
KymoTracer(bytes::AbstractVector{UInt8}; scale=2, corners=Tuple{Int,Int}[], pairs=false, margin=0, seed=nothing) =
    KymoTracer(Base64.base64encode(bytes), png_size(bytes)..., Float64(scale),
               [(Int(r), Int(c)) for (r, c) in corners], pairs, Int(margin), seed === nothing ? 0 : Int(seed))

function Base.show(io::IO, ::MIME"text/html", k::KymoTracer)
    w = round(Int, k.width * k.scale); h = round(Int, k.height * k.scale)
    m = round(Int, k.margin * k.scale); W = w + 2m
    initial = "[" * join(("[$r,$c]" for (r, c) in k.corners), ",") * "]"
    print(io, """
    <span style="display:inline-flex; flex-direction:column; gap:6px">
    <span style="position:relative; display:inline-block; width:$(W)px; height:$(h)px; background:#2a2d31">
    <img src="data:image/png;base64,$(k.data)" width="$w" height="$h"
         style="position:absolute; left:$(m)px; top:0; image-rendering:pixelated; width:$(w)px; height:$(h)px; max-width:none">
    <canvas width="$W" height="$h" style="position:absolute; left:0; top:0; cursor:crosshair"></canvas>
    </span>
    <span style="display:inline-flex; gap:6px; align-items:center; font-size:0.85em">
    <button type="button">Undo last $(k.pairs ? "click" : "corner")</button><button type="button">Clear</button>
    <output></output>
    </span>
    $(k.seed > 0 ? """<span style="display:inline-flex; gap:6px; align-items:center; font-size:0.85em">
    seed <input type="range" min="1" max="$(k.width)" step="1" value="$(k.seed)" style="width:$(max(W - 160, 80))px">
    <button type="button">Set seed</button>
    </span>""" : "")
    <script>
    const span = currentScript.parentElement
    const canvas = span.querySelector("canvas")
    const ctx = canvas.getContext("2d")
    const [undo, clear, setSeed] = span.querySelectorAll("button")
    const seedRange = span.querySelector("input[type=range]")
    const info = span.querySelector("output")
    const scale = $(k.scale)
    const pairs = $(k.pairs)
    const margin = $(k.margin)
    const seed = $(k.seed)              // 0: no seed line
    let seedSet = seed, seedShown = seed  // sent to Julia / drawn
    let corners = $initial
    let history = []          // clicked corners, most recent last, for "Undo"
    // corners are [row, col] in image pixels, 1-based
    const xy = ([r, c]) => [(c - 0.5 + margin) * scale, (r - 0.5) * scale]
    const drawPairs = () => {
        ctx.clearRect(0, 0, canvas.width, canvas.height)
        ctx.lineWidth = 2
        ctx.font = "bold 13px sans-serif"
        for (let i = 0; i < corners.length; i += 2) {
            const [x1, y1] = xy(corners[i])
            if (i + 1 < corners.length) {
                const [x2, y2] = xy(corners[i + 1])
                ctx.strokeStyle = "#e4572e"
                ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke()
                ctx.fillStyle = "#e4572e"; ctx.fillRect(x2 - 3, y2 - 3, 6, 6)
            }
            ctx.fillStyle = "#1b9e77"; ctx.fillRect(x1 - 4, y1 - 4, 8, 8)
            ctx.fillStyle = "#ffd23f"; ctx.fillText(String(i / 2 + 1), x1 + 6, y1 - 6)
        }
        const n = Math.floor(corners.length / 2)
        info.value = n + (n === 1 ? " line" : " lines") + (corners.length % 2 ? ", click the other end" : "")
    }
    const draw = () => {
        if (pairs) return drawPairs()
        ctx.clearRect(0, 0, canvas.width, canvas.height)
        if (seed > 0) {           // end of the seed: dashed line at the right edge of its column
            const x = (seedShown + margin) * scale
            ctx.save(); ctx.setLineDash([6, 4]); ctx.lineWidth = 2
            ctx.strokeStyle = seedShown === seedSet ? "#3aa0ff" : "#ff9f1c"   // orange: not set yet
            ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, canvas.height); ctx.stroke(); ctx.restore()
        }
        ctx.lineWidth = 2
        ctx.strokeStyle = "#e4572e"
        ctx.beginPath()
        corners.forEach(([r, c], i) => {
            const x = (c - 0.5 + margin) * scale, y = (r - 0.5) * scale
            i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
        })
        ctx.stroke()
        ctx.fillStyle = "#1b9e77"
        corners.forEach(([r, c]) => ctx.fillRect((c - 0.5 + margin) * scale - 4, (r - 0.5) * scale - 4, 8, 8))
        info.value = corners.length + (corners.length === 1 ? " corner" : " corners")
    }
    const value = () => {
        const c = corners.map(p => [p[0], p[1]])
        return seed > 0 ? {corners: c, seed: seedSet} : c
    }
    const send = () => {
        span.value = value()
        span.dispatchEvent(new CustomEvent("input"))
    }
    if (seed > 0) {
        seedRange.addEventListener("input", (e) => {
            e.stopPropagation()                    // the line moves, nothing is sent
            seedShown = Number(seedRange.value)
            setSeed.textContent = seedShown === seedSet ? "Set seed" : "Set seed ←"
            draw()
        })
        setSeed.addEventListener("click", () => {
            seedSet = seedShown; setSeed.textContent = "Set seed"; draw(); send()
        })
    }
    canvas.addEventListener("click", (e) => {
        const box = canvas.getBoundingClientRect()
        const x = (e.clientX - box.left) * (canvas.width / box.width), y = (e.clientY - box.top) * (canvas.height / box.height)
        const col = Math.round(x / scale - margin + 0.5), row = Math.round(y / scale + 0.5)
        if (pairs) {
            corners.push([row, col])
        } else {
            // a click on a corner removes it; otherwise the corner is inserted in time order
            const near = corners.findIndex(([r, c]) => Math.hypot((c - 0.5 + margin) * scale - x, (r - 0.5) * scale - y) <= 6)
            if (near >= 0) {
                corners.splice(near, 1)
            } else {
                const p = [row, col]
                const i = corners.findIndex(([r]) => r > row)
                i < 0 ? corners.push(p) : corners.splice(i, 0, p)
                history.push(p)
            }
        }
        draw(); send()
    })
    undo.addEventListener("click", () => {
        if (pairs) { corners.pop() } else {
            const p = history.pop()
            const i = p ? corners.indexOf(p) : corners.length - 1
            i >= 0 && corners.splice(i, 1)
        }
        draw(); send()
    })
    clear.addEventListener("click", () => { corners = []; history = []; draw(); send() })
    span.value = value()
    draw()
    </script>
    </span>""")
end

to_corners(v) = v === nothing ? Tuple{Int,Int}[] : Tuple{Int,Int}[(round(Int, p[1]), round(Int, p[2])) for p in v]
valid_corners(v) = v === nothing || (v isa AbstractVector && all(p -> length(p) == 2 && all(x -> x isa Real, p), v))

AbstractPlutoDingetjes.Bonds.initial_value(k::KymoTracer) =
    k.seed > 0 ? (corners=copy(k.corners), seed=k.seed) : copy(k.corners)
function AbstractPlutoDingetjes.Bonds.transform_value(k::KymoTracer, v)
    k.seed > 0 || return to_corners(v)
    v isa AbstractDict || return (corners=copy(k.corners), seed=k.seed)
    return (corners=to_corners(get(v, "corners", nothing)), seed=round(Int, get(v, "seed", k.seed)))
end
AbstractPlutoDingetjes.Bonds.validate_value(k::KymoTracer, v) =
    k.seed > 0 ? (v === nothing || (v isa AbstractDict && valid_corners(get(v, "corners", nothing)) && get(v, "seed", 0) isa Real)) :
                 valid_corners(v)

end # module
