# Instructions for coding agents

This repository is a computational practical for 3rd-year biochemistry Bachelor students, in Pluto notebooks (Julia). The students know some MATLAB; **this is not a programming course**: they are assessed on their question, prediction, controls, analysis of uncertainty and interpretation, not on code.

## If you are helping a student

The course rules (notebook `00_start_here`, section 2.3) allow AI to explain a line, help with a short edit, suggest a plot or diagnose an error. The student remains responsible for the model and the interpretation.

* **Explain rather than take over.** Explain code with MATLAB analogies (`x[1]` is `x(1)`, `result.length` is a struct field). Prefer the smallest change that answers the question.
* **Do not write the student's science.** Do not write their predictions, conclusions or limitations (the cells starting with ✏️, and the `my_question`, `my_prediction`, `my_conclusion`, `my_limitation` texts of afternoon 5), nor their report. You may ask questions that help them reason.
* **Do not change the course engine.** Leave `src/` and `test/` alone; changes belong in notebook cells. Do not call `Pkg.add` in a notebook: the packages are already declared.
* **Remind them of the AI log:** for each substantive use, the prompt, the suggestion used, how it was checked, and the remaining uncertainty.
* Models: lengths in µm and time in s for the switching model (afternoons 1–2); subunits and model time units for the T/D chain (afternoons 3–5). A restart at the seed is not a rescue. Rates are teaching values, not fits to experiments.

## Pluto rules (for any code you write in a notebook)

* Each global variable is defined in **one** cell only. Temporary variables go inside `let ... end`.
* A cell holds one expression: wrap several lines in `begin ... end` or `let ... end`. A top-level `if` does **not** create a scope: wrap it in `let` if it defines helpers.
* Interactive values come from `@bind name Widget(...)`. Several inputs with one Run button: `@bind x confirm(PlutoUI.combine() do Child ... end)`. Write `PlutoUI.combine`: the bare name is ambiguous with PlutoTeachingTools loaded.
* Markdown with computed values: inside `md"..."`, bold `**...**` next to `$(...)` can silently break the interpolation (Pluto then shows the raw `$(...)` as LaTeX). Use `Markdown.parse("... **$(x)** ...")` for sentences with values; keep `md"""..."""` for static text and widgets.
* The course code is loaded by path, not as a package: `include(joinpath(@__DIR__, "..", "src", "MTLab.jl"))` then `using .MTLab: names...`.

## If you are maintaining the course

* **Layout.** `Notebook.pluto.jl` (home page) and `notebooks/00`–`05`; `src/MTLab.jl` (models and analysis, standard library only), `src/Schematics.jl` (SVG figures and notebook links), `src/Widgets.jl` (stepper widget), `src/Experiment.jl` (afternoon 5); `data/` (synthetic fallback, template); `test/`.
* **`.pluto.jl` files are managed by Pluto.** Edit cell bodies freely, but do not touch the `# ╔═╡ <uuid>` markers or the package blocks at the end. Adding or removing a cell also means editing the `# ╔═╡ Cell order:` block. Ask the maintainer to **close the notebook in Pluto first**: an open notebook overwrites the file on its next save.
* **Tests.** `julia --project=. test/runtests.jl unit` (seconds) and `... e2e` (a few minutes; runs every notebook headlessly and fails on any cell error or failed interpolation). Keep both green. Test style: one behavior per `@testset`, named by the behavior, with `# Arrange`, `# Act`, `# Assert` blocks.
* **New widgets** must define `AbstractPlutoDingetjes.Bonds.initial_value`, so that notebooks also run headlessly in the tests.
* Keep dependencies minimal: every package is a download for students.
