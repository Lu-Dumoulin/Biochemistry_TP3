"""
    Widgets

Small interactive inputs for the notebooks that PlutoUI does not provide.
"""
module Widgets

import AbstractPlutoDingetjes

export Stepper

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

end # module
