### A Pluto.jl notebook ###
# v1.0.4

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    #! format: off
    return quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
    #! format: on
end

# ╔═╡ 9cfb653e-3eae-4be4-9561-8857a8f3c660
# RUN: packages used in this notebook.
using PlutoUI, PlutoTeachingTools, Plots, Random, Statistics

# ╔═╡ 1bbd2ae2-a3cc-4c47-ae02-990f45ae097b
# RUN: load the course code from ../src. No editing needed.
begin
	include(joinpath(@__DIR__, "..", "src", "MTLab.jl"))
	include(joinpath(@__DIR__, "..", "src", "Schematics.jl"))
	include(joinpath(@__DIR__, "..", "src", "Experiment.jl"))
	using .Experiment: MODELS, EXAMPLES, model_by_name, setting, observable, control,
					   baseline_inputs, condition_inputs, run_condition, summarize,
					   bootstrap_difference, format_value, methods_text
	using .Schematics: notebook_link
end

# ╔═╡ 7a3916a4-f601-4776-8f8e-abcf64302316
md"""
# Afternoon 5 — Your small investigation

**Question:** what can you answer with **one** controlled comparison?

In pairs, choose one question and discuss its feasibility with the instructor within the first 20 minutes. Write a prediction before running. Specify the one input you change, the inputs you hold fixed, the observable and its window, the number of independent runs, and a control with a predictable outcome. This notebook runs, summarizes and documents the experiment: the question, the prediction and the interpretation are yours.

Plan roughly 40 minutes for the question and control, 75 minutes for simulations and analysis, a 15-minute break, 50 minutes for synthesis, and 30 minutes for short presentations.

**Minimum output:** two or three figures that answer your question, a short explanation of their uncertainty, and one limitation or alternative interpretation. Each pair should be ready to explain its question and one figure in a short oral discussion.
"""

# ╔═╡ 6eac874f-ab81-41ae-8489-cbfdd0768d87
TableOfContents(title="Afternoon 5")

# ╔═╡ 6fd80202-c13c-4cf7-9f72-c88b67756cd9
md"""
## 1. Choose one question

Start from one of the example questions of the manual, or from your own. Choosing an example only pre-fills the design menus below; you still write the question in your own words, make the prediction and interpret the result.

Starting point: $(@bind example_index Select([0 => "My own question"; [i => ex.label for (i, ex) in enumerate(EXAMPLES)]]; default=0))
"""

# ╔═╡ 614998f6-cd35-4b0f-b1fb-63375bcd44f1
example = example_index == 0 ? nothing : EXAMPLES[example_index]

# ╔═╡ 874955b8-2e53-42f8-b341-d7ed13c541cc
# ✏️ EDIT: write your question in your own words between the triple quotes, then Shift+Enter.
my_question = raw"""
My question is ...
"""

# ╔═╡ 43c0a2c8-cf5e-4962-8075-6eb4aabe4277
md"""
## 2. Design the comparison

Choose the model, the **one** input you change, the observable you measure, and a control. All other inputs stay at their baseline values (listed below the design).
"""

# ╔═╡ bf2a954d-ef32-4101-b426-371840995b83
md"""
Model: $(@bind model_name Select([m.name => m.label for m in MODELS]; default=example === nothing ? :switching : example.model))
"""

# ╔═╡ dd150d27-0964-4b40-a020-aac807f7dda3
model = model_by_name(model_name)

# ╔═╡ 9e8b8bc4-faa2-4922-a130-70536a1302f5
from_example = example !== nothing && example.model == model_name

# ╔═╡ 96d0aa5a-47fc-4172-a20a-f67ded615186
md"""
Input changed between conditions: $(@bind setting_name Select([s.name => s.label for s in model.settings]; default=from_example ? example.setting : first(model.settings).name))
"""

# ╔═╡ 083d1414-de47-4bed-89de-b07fe6fa082d
varied = setting(model, setting_name)

# ╔═╡ 47248afe-6256-42f3-aea6-6dea2a481fbf
@bind design let
	values = [v => "$(format_value(v)) $(varied.unit)" for v in varied.grid]
	base = findfirst(==(varied.baseline), varied.grid)
	use_example = from_example && example.setting == setting_name
	A, B = use_example ? example.values : (varied.baseline, varied.grid[min(end, base + 6)])
	observables = [o.name => o.label for o in model.observables]
	obs1 = from_example ? example.observables[1] : first(model.observables).name
	obs2 = from_example ? example.observables[2] : :none
	controls = [:none => "none"; [c.name => c.label for c in model.controls]]
	control_default = from_example ? example.control : first(model.controls).name
	confirm(PlutoUI.combine() do Child
		md"""
		| | |
		|:---|:---|
		| condition A: $(varied.label) | $(Child(:A, Select(values; default=A))) |
		| condition B: $(varied.label) | $(Child(:B, Select(values; default=B))) |
		| observable | $(Child(:obs1, Select(observables; default=obs1))) |
		| second observable (optional) | $(Child(:obs2, Select([:none => "none"; observables]; default=obs2))) |
		| predictable control | $(Child(:control, Select(controls; default=control_default))) |
		"""
	end; label="Use this design")
end

# ╔═╡ 47d27bcc-ef60-41a3-9dfc-52f655121b70
chosen_observables = unique([observable(model, design.obs1);
							 design.obs2 == :none ? [] : [observable(model, design.obs2)]])

# ╔═╡ fa22024f-238d-4caa-9337-ca032c2be478
chosen_control = design.control == :none ? nothing : control(model, design.control)

# ╔═╡ 1fc091de-40fe-4bde-b003-6a73d914a732
let
	base = baseline_inputs(model)
	fixed = ["| $(s.label) | $(format_value(base[s.name])) $(s.unit) |" for s in model.settings if s.name != setting_name]
	control_line = chosen_control === nothing ?
		"No predictable control chosen. Consider one: a control with a known outcome checks that the comparison measures what you think." :
		"**Predictable control:** $(chosen_control.label). Expected: $(chosen_control.expectation)"
	Markdown.parse("""
	**Model:** $(model.description).

	**Conditions:** A = $(format_value(design.A)) $(varied.unit) and B = $(format_value(design.B)) $(varied.unit) for the $(varied.label). **Null control** (always run): condition A repeated with new random seeds, to see how large a difference chance alone produces.

	$control_line

	| inputs held fixed | value |
	|:---|---:|
	$(join(fixed, "\n"))
	""")
end

# ╔═╡ 91b15282-ef1d-42ef-a3d5-34b363af0cb6
design.A == design.B ? warning_box(md"Conditions A and B are identical: choose two different values.") : md""

# ╔═╡ 54e89a12-5361-4902-b6cf-397d0a93fe1d
md"""
## 3. Write your prediction — before running

Which way will the observable move from A to B, and **why**? Base your reasoning on the model's rules or on what you saw in afternoons 1–4. Do not rewrite the prediction after seeing the results: if you change your mind, add a line starting with *Revised after the results:*.

The results stay hidden until your question (section 1) and your prediction are written.
"""

# ╔═╡ 70567cf5-b024-42f7-a226-63a31081f95d
# ✏️ EDIT: write your prediction between the triple quotes, then Shift+Enter.
my_prediction = raw"""
When the input goes from A to B, I expect the observable to ... because ...
"""

# ╔═╡ 3365966c-7198-4a8f-847c-5c238dbdd8c9
is_written(text) = length(strip(text)) >= 25 && !occursin("...", text)

# ╔═╡ 3bf1ae5b-3970-46c1-ae03-3aaa3e9324f9
ready = is_written(my_question) && is_written(my_prediction)

# ╔═╡ 2b43be6a-269b-4568-bfcd-3fbfe3cc3d05
ready ? correct(md"Question and prediction recorded: you can run the experiment.") :
	keep_working(md"🔒 Write your **question** (section 1) and your **prediction** (above) first: replace the `...` by your own words and press Shift+Enter. The results stay hidden until then.")

# ╔═╡ 194fca66-df73-44c3-a4a2-00aa8c25c60d
md"""
## 4. Run the experiment

Each condition is run independently, with its own random seeds. Each run is summarized by **one number** per observable, measured after omitting the initial interval. Start with about 6–12 runs per condition.
"""

# ╔═╡ 9c7f551c-229d-4d0d-bb04-dec33bfa6aad
@bind run_settings let
	longest_omit = minimum(model.durations) ÷ 2
	confirm(PlutoUI.combine() do Child
		md"""
		| | |
		|:---|:---|
		| independent runs per condition | $(Child(:runs, Slider(4:2:24; default=8, show_value=true))) |
		| duration ($(model.time_unit)) | $(Child(:duration, Select(model.durations; default=model.duration))) |
		| omit the first ($(model.time_unit)) | $(Child(:omit, Slider(0:longest_omit ÷ 10:longest_omit; default=model.omit, show_value=true))) |
		| collapse definition (T/D chain on a seed): a drop of at least | $(Child(:drop, Slider(2:30; default=5, show_value=true))) subunits |
		| … within | $(Child(:window, Slider([0.2, 0.5, 1.0, 2.0, 5.0]; default=1.0, show_value=true))) time units |
		"""
	end; label="▶ Run the experiment")
end

# ╔═╡ 42c442c9-eddb-4b5d-89b0-6ed4da397bff
conditions = let
	A = condition_inputs(model, setting_name, design.A)
	B = condition_inputs(model, setting_name, design.B)
	list = [(; name="A", label="A: $(format_value(design.A))", value=design.A, inputs=A, seed_base=1000, kind=:main),
			(; name="B", label="B: $(format_value(design.B))", value=design.B, inputs=B, seed_base=2000, kind=:main),
			(; name="A again", label="A again (null)", value=design.A, inputs=A, seed_base=5000, kind=:null)]
	if chosen_control !== nothing
		push!(list, (; name="control", label="control", value=NaN, inputs=chosen_control.apply(A),
					 seed_base=6000, kind=:control))
	end
	list
end

# ╔═╡ 2d6ea5cc-69fa-422b-af7b-f5b0e440a362
function measure(c; runs=run_settings.runs, omit=run_settings.omit, seed_shift=0)
	duration = run_settings.duration
	r = run_condition(model, c.inputs; runs, duration, seed_base=c.seed_base + seed_shift)
	values = Dict(o.name => summarize(r, o, c.inputs; omit, duration, drop=run_settings.drop,
									  window=run_settings.window)
				  for o in chosen_observables)
	return merge(c, (; runs=r, values, seed_base=c.seed_base + seed_shift))
end

# ╔═╡ f6cf60b4-5d1d-4f0d-a0c6-c180922d0f39
results = ready ? [measure(c) for c in conditions] : nothing

# ╔═╡ 087bc2c9-03cb-456e-9f43-e28a438bb488
locked = md"🔒 *The results appear here once your question and prediction are written (sections 1 and 3).*";

# ╔═╡ 25ec2047-bba7-4cfa-885e-b09a25ea317e
md"""
### Example trajectories

Three runs of each condition. Look at them before the summaries: do the summaries capture what you see?
"""

# ╔═╡ 708326c8-4bac-47bd-a7fa-ad8b418f1438
mean_se(x) = (v = filter(!isnan, x); isempty(v) ? (NaN, NaN) :
			  (mean(v), length(v) > 1 ? std(v) / sqrt(length(v)) : NaN))

# ╔═╡ e082b7bc-3699-400a-8401-7c114ed9f92a
y_label = model.name == :switching ? "Extension (µm)" : "Length (subunits)"

# ╔═╡ d430a19a-716c-4fb3-b499-a7978003cb29
md"""
### One summary per run

Each dot is one independent run; black bars are the mean ± standard error across runs. Compare **A** with **B**, and **A** with **A again**: the null control shows how different two identical conditions can look by chance.
"""

# ╔═╡ db2e81b0-3267-4dd8-bfc2-a24af172e994
md"""
### Differences with their uncertainty

Each difference of means comes with an approximate 95 % interval from resampling the runs (bootstrap). An interval that excludes zero indicates a difference larger than run-to-run variation; an interval that includes zero means **no detectable difference with this number of runs**, which is not proof of no effect.
"""

# ╔═╡ b623e9a5-8c9d-4867-b0c7-7c9aa67f2a0b
function difference_rows(list, reference)
	rows = String[]
	for o in chosen_observables, c in list
		c.kind == :control && continue
		c.name == reference.name && continue
		d = bootstrap_difference(reference.values[o.name], c.values[o.name])
		verdict = isnan(d.lo) ? "not enough defined runs" :
				  (d.lo > 0 || d.hi < 0) ? "**interval excludes 0**" : "includes 0: not detectable"
		f(x) = round(x; sigdigits=3)
		push!(rows, "| $(o.label) | $(c.label) − $(reference.label) | $(f(d.difference)) | $(f(d.lo)) to $(f(d.hi)) | $verdict |")
	end
	return rows
end

# ╔═╡ 8b9736c5-8447-4c5d-8e23-530a156a746a
md"""
## 5. Interpret

* What did you observe, including the variation between runs?
* Does the comparison support your prediction? How large is the difference compared with the null control?
* What alternative explanation or modeling assumption remains?
* Which extra measurement or simulation would best distinguish these explanations?
* Did the predictable control behave as expected?
"""

# ╔═╡ f863562d-69de-4c85-bf03-b8cd80b2464c
# ✏️ EDIT: your conclusion and one limitation (they go into the report summary and the slide).
my_conclusion = raw"""
...
"""

# ╔═╡ 905a3afe-fb5d-45b7-b7a3-dead7b7e30d1
my_limitation = raw"""
...
"""

# ╔═╡ ea2e9bc9-9276-4952-84c9-2e8eefc01ae3
md"""
## 6. Add conditions (after the first comparison)

Once the two-condition comparison is interpreted, you can add up to two more values of the same input, to see how the observable changes along a range of values (a dose–response). Each new condition gets its own random seeds.
"""

# ╔═╡ 17ef0231-c87f-44e0-950a-ba62130385ed
@bind extra let
	values = [nothing => "none"; [v => "$(format_value(v)) $(varied.unit)" for v in varied.grid]]
	confirm(PlutoUI.combine() do Child
		md"""
		| | |
		|:---|:---|
		| condition C: $(varied.label) | $(Child(:C, Select(values; default=nothing))) |
		| condition D: $(varied.label) | $(Child(:D, Select(values; default=nothing))) |
		"""
	end; label="Add these conditions")
end

# ╔═╡ 55c3668f-fd47-4c2f-99c8-a3cacae31c26
extra_results = if results === nothing
	[]
else
	added = [(name, v, base) for (name, v, base) in (("C", extra.C, 3000), ("D", extra.D, 4000)) if v !== nothing]
	[measure((; name, label="$name: $(format_value(v))", value=v,
			   inputs=condition_inputs(model, setting_name, v), seed_base=base, kind=:main))
	 for (name, v, base) in added]
end

# ╔═╡ f578d0de-aaed-4fbe-be74-796d724157b5
all_results = results === nothing ? nothing : vcat(results, extra_results)

# ╔═╡ caf2e8a1-a563-4f9f-a6a4-7c60106456ec
let
	if all_results === nothing
		locked
	else
		panels = map(all_results) do c
			p = plot(; title=c.label, titlefontsize=9, legend=false, xlabel="Time ($(model.time_unit))")
			for r in c.runs[1:min(3, end)]
				plot!(p, r.t, r.length; lw=0.8)
			end
			p
		end
		columns = min(3, length(panels))
		plot(panels...; layout=(cld(length(panels), columns), columns), link=:y, ylabel=y_label,
			 size=(780, 230 * cld(length(panels), columns)), margin=3Plots.mm)
	end
end

# ╔═╡ 368380b7-db67-4f00-b55c-653f02704dff
summary_figure = let
	if all_results === nothing
		locked
	else
		colors = Dict(:main => "#5d6875", :null => "#8f9cad", :control => "#1b9e77")
		panels = map(chosen_observables) do o
			p = plot(; xticks=(1:length(all_results), [c.label for c in all_results]), xrotation=20,
					 xlims=(0.5, length(all_results) + 0.5), ylabel=o.label, legend=false,
					 guidefontsize=9, tickfontsize=8)
			for (k, c) in enumerate(all_results)
				values = c.values[o.name]
				jitter = 0.08 .* range(-1, 1; length=length(values))
				scatter!(p, k .+ jitter, values; color=colors[c.kind], ms=4, msw=0, alpha=0.8)
				m, se = mean_se(values)
				scatter!(p, [k], [m]; yerror=[se], color=:black, marker=:hline, ms=8, msw=2)
			end
			p
		end
		plot(panels...; layout=(length(panels), 1), size=(780, 300 * length(panels)), margin=4Plots.mm,
			 plot_title="$(varied.label): $(run_settings.runs) runs per condition, $(run_settings.duration) $(model.time_unit), first $(run_settings.omit) omitted",
			 plot_titlefontsize=9)
	end
end

# ╔═╡ 3e1c7fd1-fce5-4dcf-8914-62b6002f6cf2
summary_figure isa Plots.Plot ? DownloadButton(repr(MIME("image/png"), summary_figure), "afternoon5_summaries.png") : md""

# ╔═╡ 3f84eec5-0d97-4ef0-bfa9-62697c9ab3c7
let
	if all_results === nothing
		locked
	else
		Markdown.parse("""
		| observable | comparison | difference | 95 % interval | |
		|:---|:---|---:|:---|:---|
		$(join(difference_rows(all_results, all_results[1]), "\n"))
		""")
	end
end

# ╔═╡ 32f76fb9-0162-4882-b000-05c137f39f92
let
	if all_results === nothing || chosen_control === nothing
		md""
	else
		c = only(filter(x -> x.kind == :control, all_results))
		f(x) = round(x; sigdigits=3)
		lines = ["| $(o.label) | $(f(mean_se(c.values[o.name])[1])) ± $(f(mean_se(c.values[o.name])[2])) |" for o in chosen_observables]
		Markdown.parse("""
		**Predictable control — $(chosen_control.label).** Expected: $(chosen_control.expectation)

		| observable | control: mean ± SE |
		|:---|---:|
		$(join(lines, "\n"))

		Does the control behave as expected? If not, check the design before interpreting A versus B.
		""")
	end
end

# ╔═╡ 06dafd53-0d90-4901-ab09-2d068da73938
let
	if results === nothing
		locked
	elseif isempty(extra_results)
		md"*No extra condition yet: choose C and/or D above, then press **Add these conditions**. The figures and tables above include them.*"
	else
		main = sort(filter(c -> c.kind == :main, all_results); by=c -> c.value)
		xs = [c.value for c in main]
		log_axis = varied.log_scale && all(>(0), xs)
		panels = map(chosen_observables) do o
			stats = [mean_se(c.values[o.name]) for c in main]
			plot(xs, first.(stats); yerror=last.(stats), marker=:circle, ms=5, color="#5d6875", lw=1.5,
				 xscale=log_axis ? :log10 : :identity, xticks=(xs, format_value.(xs)), legend=false,
				 xlabel="$(varied.label) ($(varied.unit))", ylabel=o.label, guidefontsize=9)
		end
		plot(panels...; layout=(1, length(panels)), size=(780, 300), margin=4Plots.mm,
			 plot_title="Mean ± SE over $(run_settings.runs) runs per value", plot_titlefontsize=9)
	end
end

# ╔═╡ f176a918-c417-43cc-9b56-50020f5f26f6
md"""
## 7. Robustness check

Does the conclusion survive a change that should not matter? Choose one check: new random seeds, twice as many runs, or omitting twice as long an initial interval. The A versus B comparison is run again and shown beside the original.
"""

# ╔═╡ 10451db0-8fef-4164-9197-e1e757f45a00
@bind check confirm(Select([:none => "choose a check", :new_seeds => "new random seeds",
							:more_runs => "twice as many runs",
							:later_window => "omit twice as long an initial interval"]; default=:none);
					label="Run the check")

# ╔═╡ 0c6b6e5a-c398-4127-b8d4-267c5554fc0d
let
	if results === nothing
		locked
	elseif check == :none
		md"*Choose a check, then press **Run the check**.*"
	else
		A, B = results[1], results[2]
		omit2 = min(2 * run_settings.omit + (run_settings.omit == 0 ? run_settings.duration ÷ 10 : 0), run_settings.duration ÷ 2)
		kwargs = check == :new_seeds ? (; seed_shift=100_000) :
				 check == :more_runs ? (; runs=2 * run_settings.runs, seed_shift=100_000) :
				 (; omit=omit2)
		A2, B2 = measure(A; kwargs...), measure(B; kwargs...)
		f(x) = round(x; sigdigits=3)
		rows = map(chosen_observables) do o
			d1 = bootstrap_difference(A.values[o.name], B.values[o.name])
			d2 = bootstrap_difference(A2.values[o.name], B2.values[o.name])
			"| $(o.label) | $(f(d1.difference)) ($(f(d1.lo)) to $(f(d1.hi))) | $(f(d2.difference)) ($(f(d2.lo)) to $(f(d2.hi))) |"
		end
		description = check == :new_seeds ? "new random seeds" :
					  check == :more_runs ? "$(2 * run_settings.runs) runs per condition" :
					  "first $omit2 $(model.time_unit) omitted"
		Markdown.parse("""
		| observable | B − A, original (95 % interval) | B − A, $description |
		|:---|:---|:---|
		$(join(rows, "\n"))

		Does your conclusion change?
		""")
	end
end

# ╔═╡ 1ef627c7-3c05-41d4-8d33-66cc71ae27bd
md"""
## 8. Report and presentation

The methods paragraph below is generated from your design: it records everything needed to regenerate your results. Copy it into your report and add your own reasoning; the download contains your question, prediction, methods, results, conclusion and limitation.
"""

# ╔═╡ 4005e735-14b2-4252-8b4a-fd0c6cf33321
methods = let
	main = all_results === nothing ? [] : filter(c -> c.kind == :main, all_results)
	values = isempty(main) ? [design.A, design.B] : [c.value for c in main]
	seeds = isempty(main) ? [1000, 2000] : [c.seed_base for c in main]
	methods_text(; model, setting=varied, values, observables=chosen_observables, control=chosen_control,
				 runs=run_settings.runs, duration=run_settings.duration, omit=run_settings.omit,
				 drop=run_settings.drop, window=run_settings.window, seed_bases=seeds)
end

# ╔═╡ 65b13cb1-d803-4113-a63a-45aad8fbb8d1
Markdown.parse(methods)

# ╔═╡ 628bf35b-befb-4324-8aa6-1861c4847f73
report = let
	results_table = all_results === nothing ? "(not run yet)" : join([
		"| observable | comparison | difference | 95 % interval | |",
		"|:---|:---|---:|:---|:---|",
		difference_rows(all_results, all_results[1])...], "\n")
	"""
	# Afternoon 5 — $(strip(my_question))

	## Prediction (written before running)

	$(strip(my_prediction))

	## Methods

	$methods

	## Results

	$results_table

	## Conclusion

	$(strip(my_conclusion))

	## Limitation

	$(strip(my_limitation))
	"""
end

# ╔═╡ a046cd9c-c5a4-49c1-8451-0ec50d748913
DownloadButton(report, "afternoon5_report_notes.md")

# ╔═╡ f8cbcbe2-b263-425a-bfce-122a6508002b
let
	if all_results === nothing
		md""
	else
		io = IOBuffer()
		println(io, "condition,", varied.name, ",run,random_seed,", join([o.name for o in chosen_observables], ","))
		for c in all_results, i in eachindex(c.runs)
			println(io, c.name, ",", isnan(c.value) ? "" : c.value, ",", i, ",", c.seed_base + i, ",",
					join([c.values[o.name][i] for o in chosen_observables], ","))
		end
		DownloadButton(String(take!(io)), "afternoon5_runs.csv")
	end
end

# ╔═╡ 6fed0761-26b4-464e-bbb4-4c5eb80d0d66
md"""
### Your slide

For the short presentation: press the button to switch to presentation mode, then use the arrow keys to reach this slide. It is assembled from your question, prediction, figure, results, conclusion and limitation.

$(present_button())
"""

# ╔═╡ 4abf4d5f-fbd9-45a3-acb5-797051453957
WideCell(let
	if all_results === nothing
		locked
	else
		f(x) = round(x; sigdigits=3)
		first_obs = first(chosen_observables)
		d = bootstrap_difference(all_results[1].values[first_obs.name], all_results[2].values[first_obs.name])
		null = bootstrap_difference(all_results[1].values[first_obs.name], all_results[3].values[first_obs.name])
		Markdown.MD([
			Markdown.parse("""
			## $(strip(my_question))

			**Prediction:** $(strip(my_prediction))

			**Design:** $(varied.label) A = $(format_value(design.A)) vs B = $(format_value(design.B)) $(varied.unit); $(run_settings.runs) runs each; null control$(chosen_control === nothing ? "" : " and predictable control ($(chosen_control.label))").
			"""),
			summary_figure,
			Markdown.parse("""
			**Result:** $(first_obs.label): B − A = $(f(d.difference)) (95 % interval $(f(d.lo)) to $(f(d.hi))); null control A again − A = $(f(null.difference)) ($(f(null.lo)) to $(f(null.hi))).

			**Conclusion:** $(strip(my_conclusion))

			**Limitation:** $(strip(my_limitation))
			""")])
	end
end)

# ╔═╡ 50bad3a2-098d-4aa1-ae67-89841d6f7b7c
md"""
## Optional: your own observable

If none of the observables fits your question, you can write your own: a short function that turns one run into one number. This is optional; ask for help if you try it. A run of the switching model has fields `t`, `length`, `growing` and `events`; a chain run has `t`, `length`, `cap`, `nT`, `plus_net`, `minus_net` and `extinction_time`.
"""

# ╔═╡ a09a1046-a8f0-4b0a-a46a-067b0ab5d020
# ✏️ OPTIONAL EDIT: one number per run. Examples:
#     my_observable(run) = maximum(run.length)            # largest length reached
#     my_observable(run) = run.length[end]                # final length
#     my_observable(run) = count(==(0), run.length) / length(run.length)   # fraction of time at zero
my_observable(run) = maximum(run.length)

# ╔═╡ e2291217-ec95-4e49-be01-19f14b186898
let
	if results === nothing
		locked
	else
		values = [[Float64(my_observable(r)) for r in c.runs] for c in all_results]
		f(x) = round(x; sigdigits=3)
		rows = ["| $(c.label) | $(f(mean_se(v)[1])) ± $(f(mean_se(v)[2])) |" for (c, v) in zip(all_results, values)]
		d = bootstrap_difference(values[1], values[2])
		Markdown.parse("""
		| condition | my observable: mean ± SE |
		|:---|---:|
		$(join(rows, "\n"))

		B − A = $(f(d.difference)) (95 % interval $(f(d.lo)) to $(f(d.hi))).
		""")
	end
end

# ╔═╡ 58bbcd1e-6437-4b2c-988d-4d62ed0747ac
let
	home = notebook_link(joinpath(@__DIR__, "..", "Notebook.pluto.jl"), "Back to the course home page")
	HTML("<hr>" * home.content)
end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
PlutoTeachingTools = "661c6b06-c737-4d37-b85c-46df65de6f69"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[compat]
Plots = "~1.41.6"
PlutoTeachingTools = "~0.5.0"
PlutoUI = "~0.7.83"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.13.3"
manifest_format = "2.1"
project_hash = "150e02fc0743730d2db42b028c6d7e9bdafebf2a"

[[deps.AbstractPlutoDingetjes]]
git-tree-sha1 = "e71ee7b4aa06b045259a7d6101e1cb45ad140bce"
registries = "General"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.4.1"

[[deps.AliasTables]]
deps = ["PtrArrays", "Random"]
git-tree-sha1 = "9876e1e164b144ca45e9e3198d0b689cadfed9ff"
registries = "General"
uuid = "66dad0bd-aa9a-41b7-9441-69ab47430ed8"
version = "1.1.3"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"
version = "1.11.0"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

[[deps.BitFlags]]
git-tree-sha1 = "bbe1079eecf9c9fbb52765193ad2bae27ae09bc8"
registries = "General"
uuid = "d1d4a3ce-64b1-5f1a-9ba4-7e7e69966f35"
version = "0.1.10"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1b96ea4a01afe0ea4090c5c8039690672dd13f2e"
registries = "General"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.9+0"

[[deps.Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "CompilerSupportLibraries_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "Libdl", "Pixman_jll", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "0cfb779e24fdced77a05df1dbe99200821a9f563"
registries = "General"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.18.8+1"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "970758a3d591a2a5c2a907c53f2e2f8c1b1d3537"
registries = "General"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.9"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "PrecompileTools", "Random"]
git-tree-sha1 = "b0fd3f56fa442f81e0a47815c92245acfaaa4e34"
registries = "General"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.31.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "a7cf827a79b378a381e31e5c7feca853ec19cb94"
registries = "General"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.12.4"
weakdeps = ["StyledStrings"]

    [deps.ColorTypes.extensions]
    StyledStringsExt = "StyledStrings"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "Requires", "Statistics", "TensorCore"]
git-tree-sha1 = "a4e53eb7a1779254f92c1cc1302c2bc6acdba560"
registries = "General"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.11.1"

    [deps.ColorVectorSpace.extensions]
    SpecialFunctionsExt = "SpecialFunctions"

    [deps.ColorVectorSpace.weakdeps]
    SpecialFunctions = "276daf66-3868-5448-9aa4-cd146d93841b"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "Reexport"]
git-tree-sha1 = "a633156e74096f90b3b5e833529292b651b5671a"
registries = "General"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.13.3"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.5.5+2"

[[deps.ConcurrentUtilities]]
deps = ["Serialization", "Sockets"]
git-tree-sha1 = "d5e5fa1f0d6ca517edbbcd734efa93c6639405b0"
registries = "General"
uuid = "f0e56b4a-5159-44fe-b623-3e5288b988bb"
version = "2.7.1"

[[deps.Contour]]
git-tree-sha1 = "439e35b0b36e2e5881738abc8857bd92ad6ff9a8"
registries = "General"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.6.3"

[[deps.DataAPI]]
git-tree-sha1 = "abe83f3a2f1b857aac70ef8b269080af17764bbe"
registries = "General"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.16.0"

[[deps.DataStructures]]
deps = ["OrderedCollections"]
git-tree-sha1 = "b0bc6d2cad1fed8b7fd59a1551a991cb3d2809e6"
registries = "General"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.19.6"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"
version = "1.11.0"

[[deps.Dbus_jll]]
deps = ["Artifacts", "Expat_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "473e9afc9cf30814eb67ffa5f2db7df82c3ad9fd"
registries = "General"
uuid = "ee1fde0b-3d02-5ea6-8484-8dfef6360eab"
version = "1.16.2+0"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
git-tree-sha1 = "9e2f36d3c96a820c678f2f1f1782582fcf685bae"
registries = "General"
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"
version = "1.9.1"

[[deps.DocStringExtensions]]
git-tree-sha1 = "7442a5dfe1ebb773c29cc2962a8980f47221d76c"
registries = "General"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.5"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.7.0"

[[deps.EpollShim_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "8a4be429317c42cfae6a7fc03c31bad1970c310d"
registries = "General"
uuid = "2702e6a9-849d-5ed8-8c21-79e8b8f9ee43"
version = "0.0.20230411+1"

[[deps.ExceptionUnwrapping]]
deps = ["Test"]
git-tree-sha1 = "4e468f521e1f9f86891cb07186de5df90360a666"
registries = "General"
uuid = "460bff9d-24e4-43bc-9d9f-a8973cb893f4"
version = "0.1.12"

[[deps.Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "d0f666deaf8099a7d7ac229a74402ada88898be1"
registries = "General"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.9.0+0"

[[deps.FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "95ecf07c2eea562b5adbd0696af6db62c0f52560"
registries = "General"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.5"

[[deps.FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "PCRE2_jll", "Zlib_jll", "libaom_jll", "libass_jll", "libfdk_aac_jll", "libva_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "7a58e45171b63ed4782f2d36fdee8713a469e6e0"
registries = "General"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "8.1.2+0"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"
version = "1.11.0"

[[deps.FixedPointNumbers]]
deps = ["Random", "Statistics"]
git-tree-sha1 = "59af96b98217c6ef4ae0dfe065ac7c20831d1a84"
registries = "General"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.6"

[[deps.Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Zlib_jll"]
git-tree-sha1 = "e1e9ba3a8f5d71e6ae698f138a1362aeabb42e9f"
registries = "General"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.18.3+0"

[[deps.Format]]
git-tree-sha1 = "9c68794ef81b08086aeb32eeaf33531668d5f5fc"
registries = "General"
uuid = "1fa38f19-a742-5d3f-a2b9-30dd87b9d5f8"
version = "1.3.7"

[[deps.FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "d95a7a3a7e0f2fffc6291bd33035830aab01310b"
registries = "General"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.15.0+0"

[[deps.FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "f3f50c8001bdfa84f312234fa86715b7c9243771"
registries = "General"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.18+0"

[[deps.GLFW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libglvnd_jll", "Xorg_libXcursor_jll", "Xorg_libXi_jll", "Xorg_libXinerama_jll", "Xorg_libXrandr_jll", "libdecor_jll", "xkbcommon_jll"]
git-tree-sha1 = "9e0fb9e54594c47f278d75063980e43066e26e20"
registries = "General"
uuid = "0656b61e-2033-5cc2-a64a-77c0f6c09b89"
version = "3.4.1+1"

[[deps.GR]]
deps = ["Artifacts", "Base64", "DelimitedFiles", "Downloads", "GR_jll", "HTTP", "JSON", "Libdl", "LinearAlgebra", "Preferences", "Printf", "Qt6Wayland_jll", "Random", "Serialization", "Sockets", "TOML", "Tar", "Test", "p7zip_jll"]
git-tree-sha1 = "f954322d5de03ec630d177cda203dcd92b6be399"
registries = "General"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.73.26"

    [deps.GR.extensions]
    IJuliaExt = "IJulia"

    [deps.GR.weakdeps]
    IJulia = "7073ff75-c697-5162-941a-fcdaad2a7d2a"

[[deps.GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "FreeType2_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Qt6Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "6fada551286ab6ea4ca1628cb2de9f166a2ec966"
registries = "General"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.73.26+0"

[[deps.GettextRuntime_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll"]
git-tree-sha1 = "45288942190db7c5f760f59c04495064eedf9340"
registries = "General"
uuid = "b0724c58-0f36-5564-988d-3bb0596ebc4a"
version = "0.22.4+0"

[[deps.Ghostscript_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Zlib_jll"]
git-tree-sha1 = "38044a04637976140074d0b0621c1edf0eb531fd"
registries = "General"
uuid = "61579ee1-b43e-5ca0-a5da-69d92c66a64b"
version = "9.55.1+0"

[[deps.Glib_jll]]
deps = ["Artifacts", "GettextRuntime_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE2_jll", "Zlib_jll"]
git-tree-sha1 = "ea9f1fb37ff10597353b56f3ba0ebd525acef6e0"
registries = "General"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.90.1+0"

[[deps.Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "69ffb934a5c5b7e086a0b4fee3427db2556fba6e"
registries = "General"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.16+0"

[[deps.Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
registries = "General"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[deps.HTTP]]
deps = ["Base64", "CodecZlib", "ConcurrentUtilities", "Dates", "ExceptionUnwrapping", "Logging", "LoggingExtras", "MbedTLS", "NetworkOptions", "OpenSSL", "PrecompileTools", "Random", "SimpleBufferStream", "Sockets", "URIs", "UUIDs"]
git-tree-sha1 = "51059d23c8bb67911a2e6fd5130229113735fc7e"
registries = "General"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "1.11.0"

[[deps.HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll"]
git-tree-sha1 = "f700c32c1e9e11b576592043f270e6b33868a56f"
registries = "General"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "100.15000.0+0"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "179267cfa5e712760cd43dcae385d7ea90cc25a4"
registries = "General"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.5"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "d1a86724f81bcd184a38fd284ce183ec067d71a0"
registries = "General"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "1.0.0"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "0ee181ec08df7d7c911901ea38baf16f755114dc"
registries = "General"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "1.0.0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
version = "1.11.0"

[[deps.IrrationalConstants]]
git-tree-sha1 = "d22e8bdb3f03c300a103ff23c0dd5a654c6701de"
registries = "General"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.7"

[[deps.JLFzf]]
deps = ["REPL", "Random", "fzf_jll"]
git-tree-sha1 = "82f7acdc599b65e0f8ccd270ffa1467c21cb647b"
registries = "General"
uuid = "1019f520-868f-41f5-a6de-eb00f4b6a39c"
version = "0.1.11"

[[deps.JLLWrappers]]
deps = ["Artifacts", "Preferences"]
git-tree-sha1 = "7204148362dafe5fe6a273f855b8ccbe4df8173e"
registries = "General"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.8.0"

[[deps.JSON]]
deps = ["Dates", "Logging", "Parsers", "PrecompileTools", "StructUtils", "UUIDs", "Unicode"]
git-tree-sha1 = "3a9b0da8237deffb70be5e8d2e9af7601e4a79b0"
registries = "General"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "1.13.0"

    [deps.JSON.extensions]
    JSONArrowExt = ["ArrowTypes"]
    JSONSerializationExt = ["Serialization"]

    [deps.JSON.weakdeps]
    ArrowTypes = "31f734f8-188a-4ce0-8406-c8a06bd891cd"
    Serialization = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "037babc10853eeb8e585418922246cb97b8e5b74"
registries = "General"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "3.2.0+1"

[[deps.JuliaSyntaxHighlighting]]
deps = ["StyledStrings"]
uuid = "ac6e5ff7-fb65-4e79-a425-ec3bc9c03011"
version = "1.12.0"

[[deps.LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "059aabebaa7c82ccb853dd4a0ee9d17796f7e1bc"
registries = "General"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.3+0"

[[deps.LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "39bca05343661c347aae0bca57a5994a0bf4f08d"
registries = "General"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "4.2.0+0"

[[deps.LLVMOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e5b100780d4d30d63b4618d7930d48af409c1772"
registries = "General"
uuid = "1d63c593-3942-5779-bab2-d838dc0a180e"
version = "23.1.1+0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "f88f3ccef05a6a72a0cf0ed417c8fd68530f4ab2"
registries = "General"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.4.1"

[[deps.Latexify]]
deps = ["Format", "Ghostscript_jll", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "OrderedCollections", "Requires"]
git-tree-sha1 = "df7566479bd64f20bd16b09960145e70160ffb3b"
registries = "General"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.16.12"

    [deps.Latexify.extensions]
    DataFramesExt = "DataFrames"
    SparseArraysExt = "SparseArrays"
    SymEngineExt = "SymEngine"
    TectonicExt = "tectonic_jll"

    [deps.Latexify.weakdeps]
    DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    SymEngine = "123dc426-2d89-5057-bbad-38513e3affd8"
    tectonic_jll = "d7dd28d6-a5e6-559c-9131-7eb760cdacc5"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "1.0.0"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "LibSSH2_jll", "Libdl", "OpenSSL_jll", "Zlib_jll", "Zstd_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.22.0+0"

[[deps.LibGit2]]
deps = ["LibGit2_jll", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"
version = "1.11.0"

[[deps.LibGit2_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "LibSSH2_jll", "Libdl", "OpenSSL_jll", "PCRE2_jll", "Zlib_jll"]
uuid = "e37daf67-58a4-590a-8e99-b0245dd2ffc5"
version = "1.9.7+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl", "OpenSSL_jll", "Zlib_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.104+0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"
version = "1.11.0"

[[deps.Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "c8da7e6a91781c41a863611c7e966098d783c57a"
registries = "General"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.4.7+0"

[[deps.Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "d36c21b9e7c172a44a10484125024495e2625ac0"
registries = "General"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.7.1+1"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "be484f5c92fad0bd8acfef35fe017900b0b73809"
registries = "General"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.18.0+0"

[[deps.Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "b8a91037379e1fd661e9b5ff3d7a770424b1f9f2"
registries = "General"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.42.4+0"

[[deps.Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "XZ_jll", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "aebd334d06cee9f24cea70bd19a39749daf73881"
registries = "General"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.7.3+0"

[[deps.Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "9e887184f306b28dbfcff88cefbb0ec80f1aa9e0"
registries = "General"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.42.4+0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.13.0"

[[deps.LogExpFunctions]]
deps = ["DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "28d620bcdb37a3fb02de9f521928ee453690f414"
registries = "General"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "1.0.3"

    [deps.LogExpFunctions.extensions]
    LogExpFunctionsChainRulesCoreExt = "ChainRulesCore"
    LogExpFunctionsChangesOfVariablesExt = "ChangesOfVariables"
    LogExpFunctionsInverseFunctionsExt = "InverseFunctions"

    [deps.LogExpFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ChangesOfVariables = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"
version = "1.11.0"

[[deps.LoggingExtras]]
deps = ["Dates", "Logging"]
git-tree-sha1 = "f00544d95982ea270145636c181ceda21c4e2575"
registries = "General"
uuid = "e6f89c97-d47a-5376-807f-9c37f3926c36"
version = "1.2.0"

[[deps.MIMEs]]
git-tree-sha1 = "c64d943587f7187e751162b3b84445bbbd79f691"
registries = "General"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "1.1.0"

[[deps.MacroTools]]
git-tree-sha1 = "1e0228a030642014fe5cfe68c2c0a818f9e3f522"
registries = "General"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.16"

[[deps.Markdown]]
deps = ["Base64", "JuliaSyntaxHighlighting", "StyledStrings"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"
version = "1.11.0"

[[deps.MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "MozillaCACerts_jll", "NetworkOptions", "Random", "Sockets"]
git-tree-sha1 = "8785729fa736197687541f7053f6d8ab7fc44f92"
registries = "General"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.1.10"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "ff69a2b1330bcb730b9ac1ab7dd680176f5896b8"
registries = "General"
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.1010+0"

[[deps.Measures]]
git-tree-sha1 = "b513cedd20d9c914783d8ad83d08120702bf2c77"
registries = "General"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.3"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "d9d20d6eb2a3290ba5c70a1c013b45305cc39c9e"
registries = "General"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.2.1"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"
version = "1.11.0"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2026.10.20"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "676c0f1c1c34224d6869675047a54b42fdc7b8c5"
registries = "General"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.1.5"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.3.0"

[[deps.Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "b6aa4566bb7ae78498a5e68943863fa8b5231b59"
registries = "General"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.6+0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.30+0"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.7+0"

[[deps.OpenSSL]]
deps = ["BitFlags", "Dates", "MozillaCACerts_jll", "NetworkOptions", "OpenSSL_jll", "Sockets"]
git-tree-sha1 = "5caab1056e0734b87f62ae3a3b520d47d3e994e8"
registries = "General"
uuid = "4d8831e6-92b7-49fb-bdf8-b643e874388c"
version = "1.7.0"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.5.8+0"

[[deps.Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e2bb57a313a74b8104064b7efd01406c0a50d2ff"
registries = "General"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.6.1+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "b079a6affebde167dad8ffe0d670b53917fbcb68"
registries = "General"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "2.0.3"

[[deps.PCRE2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "efcefdf7-47ab-520b-bdef-62a2eaa19f15"
version = "10.47.0+0"

[[deps.Pango_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "FriBidi_jll", "Glib_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1912a9f1b9ca55005b03ba075f8e19993583e237"
registries = "General"
uuid = "36c8627f-9965-5494-a995-c6b170f724f3"
version = "1.58.2+0"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools"]
git-tree-sha1 = "fcc7b3df63440dc881e5d28d6f8169036e485641"
registries = "General"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "3.0.1"

[[deps.Pixman_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "LLVMOpenMP_jll", "Libdl"]
git-tree-sha1 = "e4a6721aa89e62e5d4217c0b21bd714263779dda"
registries = "General"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.46.4+0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "Random", "SHA", "TOML", "Tar", "UUIDs", "Zstd_jll", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.13.0"
weakdeps = ["REPL"]

    [deps.Pkg.extensions]
    REPLExt = "REPL"

[[deps.PlotThemes]]
deps = ["PlotUtils", "Statistics"]
git-tree-sha1 = "41031ef3a1be6f5bbbf3e8073f210556daeae5ca"
registries = "General"
uuid = "ccf2f8ad-2431-5c83-bf29-c5338b663b6a"
version = "3.3.0"

[[deps.PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "PrecompileTools", "Printf", "Reexport", "Statistics"]
git-tree-sha1 = "ddcc36fd83fb4cd459a53c891981697bde0d3de6"
registries = "General"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.5.1"

[[deps.Plots]]
deps = ["Base64", "Contour", "Dates", "Downloads", "FFMPEG", "FixedPointNumbers", "GR", "JLFzf", "JSON", "LaTeXStrings", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "Pkg", "PlotThemes", "PlotUtils", "PrecompileTools", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "RelocatableFolders", "Requires", "Scratch", "Showoff", "SparseArrays", "Statistics", "StatsBase", "TOML", "UUIDs", "UnicodeFun", "Unzip"]
git-tree-sha1 = "cb20a4eacda080e517e4deb9cfb6c7c518131265"
registries = "General"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.41.6"

    [deps.Plots.extensions]
    FileIOExt = "FileIO"
    GeometryBasicsExt = "GeometryBasics"
    IJuliaExt = "IJulia"
    ImageInTerminalExt = "ImageInTerminal"
    UnitfulExt = "Unitful"

    [deps.Plots.weakdeps]
    FileIO = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
    GeometryBasics = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
    IJulia = "7073ff75-c697-5162-941a-fcdaad2a7d2a"
    ImageInTerminal = "d8c32880-2388-543b-8c61-d9f865259254"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.PlutoTeachingTools]]
deps = ["Downloads", "HypertextLiteral", "Latexify", "Markdown", "PlutoUI"]
git-tree-sha1 = "5d103af2482cccf2d9737c365a2d53af0597df95"
registries = "General"
uuid = "661c6b06-c737-4d37-b85c-46df65de6f69"
version = "0.5.0"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "Downloads", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "e189d0623e7ce9c37389bac17e80aac3b0302e75"
registries = "General"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.83"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "edbeefc7a4889f528644251bdb5fc9ab5348bc2c"
registries = "General"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.3.4"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "aef1987d90dcc2e2cbd919ad10b2d25bcce4f418"
registries = "General"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.6.1"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"
version = "1.11.0"

[[deps.PtrArrays]]
git-tree-sha1 = "4fbbafbc6251b883f4d2705356f3641f3652a7fe"
registries = "General"
uuid = "43287f4e-b6f4-7ad1-bb20-aadabca52c3d"
version = "1.4.0"

[[deps.Qt6Base_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "OpenSSL_jll", "Vulkan_Loader_jll", "Xorg_libSM_jll", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Xorg_libxcb_jll", "Xorg_xcb_util_cursor_jll", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_keysyms_jll", "Xorg_xcb_util_renderutil_jll", "Xorg_xcb_util_wm_jll", "Zlib_jll", "libinput_jll", "xkbcommon_jll"]
git-tree-sha1 = "144895f6166994730ee7ff8113b981fc360638f1"
registries = "General"
uuid = "c0090381-4147-56d7-9ebc-da0b1113ec56"
version = "6.10.2+2"

[[deps.Qt6Declarative_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Qt6Base_jll", "Qt6ShaderTools_jll", "Qt6Svg_jll"]
git-tree-sha1 = "159d253ab126d5b29230cf53521899bea4ef4648"
registries = "General"
uuid = "629bc702-f1f5-5709-abd5-49b8460ea067"
version = "6.10.2+2"

[[deps.Qt6ShaderTools_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Qt6Base_jll"]
git-tree-sha1 = "4d85eedf69d875982c46643f6b4f66919d7e157b"
registries = "General"
uuid = "ce943373-25bb-56aa-8eca-768745ed7b5a"
version = "6.10.2+1"

[[deps.Qt6Svg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Qt6Base_jll"]
git-tree-sha1 = "81587ff5ff25a4e1115ce191e36285ede0334c9d"
registries = "General"
uuid = "6de9746b-f93d-5813-b365-ba18ad4a9cf3"
version = "6.10.2+0"

[[deps.Qt6Wayland_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Qt6Base_jll", "Qt6Declarative_jll"]
git-tree-sha1 = "672c938b4b4e3e0169a07a5f227029d4905456f2"
registries = "General"
uuid = "e99dba38-086e-5de3-a5b1-6e4c66e897c3"
version = "6.10.2+1"

[[deps.REPL]]
deps = ["Base64", "Dates", "FileWatching", "InteractiveUtils", "JuliaSyntaxHighlighting", "Markdown", "Sockets", "StyledStrings", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"
version = "1.11.0"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
version = "1.11.0"

[[deps.RecipesBase]]
deps = ["PrecompileTools"]
git-tree-sha1 = "0c0dcffc464cda2ff33fc8ffc1dd1bdd53cd98be"
registries = "General"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.4.0"

[[deps.RecipesPipeline]]
deps = ["Dates", "NaNMath", "PlotUtils", "PrecompileTools", "RecipesBase"]
git-tree-sha1 = "45cf9fd0ca5839d06ef333c8201714e888486342"
registries = "General"
uuid = "01d81517-befc-4cb6-b9ec-a95719d0359c"
version = "0.6.12"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
registries = "General"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.RelocatableFolders]]
deps = ["SHA", "Scratch"]
git-tree-sha1 = "ffdaf70d81cf6ff22c2b6e733c900c3321cab864"
registries = "General"
uuid = "05181044-ff0b-4ac5-8273-598c1e38db00"
version = "1.0.1"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "62389eeff14780bfe55195b7204c0d8738436d64"
registries = "General"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.1"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "1.0.0"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "9b81b8393e50b7d4e6d0a9f14e192294d3b7c109"
registries = "General"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.3.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
version = "1.11.0"

[[deps.Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
registries = "General"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[deps.SimpleBufferStream]]
git-tree-sha1 = "f305871d2f381d21527c770d4788c06c097c9bc1"
registries = "General"
uuid = "777ac1f9-54b0-4bf8-805c-2214025038e7"
version = "1.2.0"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"
version = "1.11.0"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "13cd91cc9be159e3f4d95b857fa2aa383b53772a"
registries = "General"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.2.3"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.13.0"

[[deps.Statistics]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "e2b53ce13a53367e96601081e33d34746b571bad"
registries = "General"
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.11.5"
weakdeps = ["SparseArrays"]

    [deps.Statistics.extensions]
    SparseArraysExt = ["SparseArrays"]

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "178ed29fd5b2a2cfc3bd31c13375ae925623ff36"
registries = "General"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.8.0"

[[deps.StatsBase]]
deps = ["AliasTables", "DataAPI", "DataStructures", "IrrationalConstants", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "adb9da019510162e67a4493fc235c23203d8b09e"
registries = "General"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.34.13"

[[deps.StructUtils]]
deps = ["Dates", "UUIDs"]
git-tree-sha1 = "96cf0c4f535157787dc4089eca1cbed62d124d5f"
registries = "General"
uuid = "ec057cc2-7a8d-4b58-b3b3-92acb9f63b42"
version = "2.11.2"

    [deps.StructUtils.extensions]
    StructUtilsDataFramesExt = ["DataFrames"]
    StructUtilsLazilyInitializedFieldsExt = ["LazilyInitializedFields"]
    StructUtilsMeasurementsExt = ["Measurements"]
    StructUtilsStaticArraysCoreExt = ["StaticArraysCore"]
    StructUtilsTablesExt = ["Tables"]

    [deps.StructUtils.weakdeps]
    DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
    LazilyInitializedFields = "0e77f7df-68c5-4e49-93ce-4cd80f5598bf"
    Measurements = "eff96d63-e80a-5855-80a2-b1b0885c5ab7"
    StaticArraysCore = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
    Tables = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"

[[deps.StyledStrings]]
uuid = "f489334b-da3d-4c2e-b8f0-e476e12c162b"
version = "1.11.0"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.10.1+0"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
registries = "General"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
version = "1.11.0"

[[deps.TranscodingStreams]]
git-tree-sha1 = "0c45878dcfdcfa8480052b6ab162cdd138781742"
registries = "General"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.11.3"

[[deps.Tricks]]
git-tree-sha1 = "311349fd1c93a31f783f977a71e8b062a57d4101"
registries = "General"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.13"

[[deps.URIs]]
deps = ["Serialization"]
git-tree-sha1 = "50eda8011f098869a76da69a524ff59e0298711a"
registries = "General"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.7.2"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"
version = "1.11.0"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"
version = "1.11.0"

[[deps.UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
registries = "General"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[deps.Unzip]]
git-tree-sha1 = "ca0969166a028236229f63514992fc073799bb78"
registries = "General"
uuid = "41fe7b60-77ed-43a1-b4f0-825fd5a5650d"
version = "0.2.0"

[[deps.Vulkan_Loader_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Wayland_jll", "Xorg_libX11_jll", "Xorg_libXrandr_jll", "xkbcommon_jll"]
git-tree-sha1 = "2f0486047a07670caad3a81a075d2e518acc5c59"
registries = "General"
uuid = "a44049a8-05dd-5a78-86c9-5fde0876e88c"
version = "1.3.243+0"

[[deps.Wayland_jll]]
deps = ["Artifacts", "EpollShim_jll", "Expat_jll", "JLLWrappers", "Libdl", "Libffi_jll"]
git-tree-sha1 = "96478df35bbc2f3e1e791bc7a3d0eeee559e60e9"
registries = "General"
uuid = "a2964d1f-97da-50d4-b82a-358c7fce9d89"
version = "1.24.0+0"

[[deps.XZ_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e52eca002a11c30a858185efdfb15311e1c7a6bf"
registries = "General"
uuid = "ffd25f8a-64ca-5728-b0f7-c24cf3aae800"
version = "5.8.4+0"

[[deps.Xorg_libICE_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "a3ea76ee3f4facd7a64684f9af25310825ee3668"
registries = "General"
uuid = "f67eecfb-183a-506d-b269-f58e52b52d7c"
version = "1.1.2+0"

[[deps.Xorg_libSM_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libICE_jll"]
git-tree-sha1 = "9c7ad99c629a44f81e7799eb05ec2746abb5d588"
registries = "General"
uuid = "c834827a-8449-5923-a945-d239c165b7dd"
version = "1.2.6+0"

[[deps.Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "ce91b54a5f90c4f27df6950706234b34e49cf79e"
registries = "General"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.8.14+0"

[[deps.Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "aa1261ebbac3ccc8d16558ae6799524c450ed16b"
registries = "General"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.13+0"

[[deps.Xorg_libXcursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libXfixes_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "6c74ca84bbabc18c4547014765d194ff0b4dc9da"
registries = "General"
uuid = "935fb764-8cf2-53bf-bb30-45bb1f8bf724"
version = "1.2.4+0"

[[deps.Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "52858d64353db33a56e13c341d7bf44cd0d7b309"
registries = "General"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.6+0"

[[deps.Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "1a4a26870bf1e5d26cd585e38038d399d7e65706"
registries = "General"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.8+0"

[[deps.Xorg_libXfixes_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "75e00946e43621e09d431d9b95818ee751e6b2ef"
registries = "General"
uuid = "d091e8ba-531a-589c-9de9-94069b037ed8"
version = "6.0.2+0"

[[deps.Xorg_libXi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libXext_jll", "Xorg_libXfixes_jll"]
git-tree-sha1 = "a376af5c7ae60d29825164db40787f15c80c7c54"
registries = "General"
uuid = "a51aa0fd-4e3c-5386-b890-e753decda492"
version = "1.8.3+0"

[[deps.Xorg_libXinerama_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libXext_jll"]
git-tree-sha1 = "0ba01bc7396896a4ace8aab67db31403c71628f4"
registries = "General"
uuid = "d1454406-59df-5ea1-beac-c340f2130bc3"
version = "1.1.7+0"

[[deps.Xorg_libXrandr_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libXext_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "6c174ef70c96c76f4c3f4d3cfbe09d018bcd1b53"
registries = "General"
uuid = "ec84b674-ba8e-5d96-8ba1-2a689ba10484"
version = "1.5.6+0"

[[deps.Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "a54cf54677c9f6eac0d97e9d757c233b56bc21b9"
registries = "General"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.13+0"

[[deps.Xorg_libpciaccess_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "58972370b81423fc546c56a60ed1a009450177c3"
registries = "General"
uuid = "a65dc6b1-eb27-53a1-bb3e-dea574b5389e"
version = "0.19.0+0"

[[deps.Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libXau_jll", "Xorg_libXdmcp_jll"]
git-tree-sha1 = "bfcaf7ec088eaba362093393fe11aa141fa15422"
registries = "General"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.17.1+0"

[[deps.Xorg_libxkbfile_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "ed756a03e95fff88d8f738ebc2849431bdd4fd1a"
registries = "General"
uuid = "cc61e674-0454-545c-8b26-ed2c68acab7a"
version = "1.2.0+0"

[[deps.Xorg_xcb_util_cursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_jll", "Xorg_xcb_util_renderutil_jll"]
git-tree-sha1 = "9750dc53819eba4e9a20be42349a6d3b86c7cdf8"
registries = "General"
uuid = "e920d4aa-a673-5f3a-b3d7-f755a4d47c43"
version = "0.1.6+0"

[[deps.Xorg_xcb_util_image_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xcb_util_jll"]
git-tree-sha1 = "f4fc02e384b74418679983a97385644b67e1263b"
registries = "General"
uuid = "12413925-8142-5f55-bb0e-6d7ca50bb09b"
version = "0.4.1+0"

[[deps.Xorg_xcb_util_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxcb_jll"]
git-tree-sha1 = "68da27247e7d8d8dafd1fcf0c3654ad6506f5f97"
registries = "General"
uuid = "2def613f-5ad1-5310-b15b-b15d46f528f5"
version = "0.4.1+0"

[[deps.Xorg_xcb_util_keysyms_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xcb_util_jll"]
git-tree-sha1 = "44ec54b0e2acd408b0fb361e1e9244c60c9c3dd4"
registries = "General"
uuid = "975044d2-76e6-5fbe-bf08-97ce7c6574c7"
version = "0.4.1+0"

[[deps.Xorg_xcb_util_renderutil_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xcb_util_jll"]
git-tree-sha1 = "5b0263b6d080716a02544c55fdff2c8d7f9a16a0"
registries = "General"
uuid = "0d47668e-0667-5a69-a72c-f761630bfb7e"
version = "0.3.10+0"

[[deps.Xorg_xcb_util_wm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xcb_util_jll"]
git-tree-sha1 = "f233c83cad1fa0e70b7771e0e21b061a116f2763"
registries = "General"
uuid = "c22f9ab0-d5fe-5066-847c-f4bb1cd4e361"
version = "0.4.2+0"

[[deps.Xorg_xkbcomp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxkbfile_jll"]
git-tree-sha1 = "801a858fc9fb90c11ffddee1801bb06a738bda9b"
registries = "General"
uuid = "35661453-b289-5fab-8a00-3d9160c6a3a4"
version = "1.4.7+0"

[[deps.Xorg_xkeyboard_config_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xkbcomp_jll"]
git-tree-sha1 = "ed349d26affcacafbc7fc2941ace1fb98f71e715"
registries = "General"
uuid = "33bec58e-1273-512f-9401-5d533626f822"
version = "2.47.0+1"

[[deps.Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "a63799ff68005991f9d9491b6e95bd3478d783cb"
registries = "General"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.6.0+0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.3.2+0"

[[deps.Zstd_jll]]
deps = ["CompilerSupportLibraries_jll", "Libdl"]
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.7+1"

[[deps.eudev_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "c3b0e6196d50eab0c5ed34021aaa0bb463489510"
registries = "General"
uuid = "35ca27e7-8b34-5b7f-bca9-bdc33f59eb06"
version = "3.2.14+0"

[[deps.fzf_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "b6a34e0e0960190ac2a4363a1bd003504772d631"
registries = "General"
uuid = "214eeab7-80f7-51ab-84ad-2988db7cef09"
version = "0.61.1+0"

[[deps.libaom_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "0343a4dc329ca4dd71bf5c5b3fc1a8c2f6e0692d"
registries = "General"
uuid = "a4ae2306-e953-59d6-aa16-d00cac43593b"
version = "3.15.2+0"

[[deps.libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "cb007192783c56d8249db4cf0e3495001edfe414"
registries = "General"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.17.5+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.15.0+0"

[[deps.libdecor_jll]]
deps = ["Artifacts", "Dbus_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "Pango_jll", "Wayland_jll", "xkbcommon_jll"]
git-tree-sha1 = "9bf7903af251d2050b467f76bdbe57ce541f7f4f"
registries = "General"
uuid = "1183f4f0-6f2a-5f1a-908b-139f9cdfea6f"
version = "0.2.2+0"

[[deps.libdrm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libpciaccess_jll"]
git-tree-sha1 = "28e57478e8a160d346a19c28b3fffb9273bcc9c2"
registries = "General"
uuid = "8e53e030-5e6c-5a89-a30b-be5b7263a166"
version = "2.4.134+0"

[[deps.libevdev_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "56d643b57b188d30cccc25e331d416d3d358e557"
registries = "General"
uuid = "2db6ffa8-e38f-5e21-84af-90c45d0032cc"
version = "1.13.4+0"

[[deps.libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "646634dd19587a56ee2f1199563ec056c5f228df"
registries = "General"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.4+0"

[[deps.libinput_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "eudev_jll", "libevdev_jll", "mtdev_jll"]
git-tree-sha1 = "91d05d7f4a9f67205bd6cf395e488009fe85b499"
registries = "General"
uuid = "36db933b-70db-51c0-b978-0f229ee0e533"
version = "1.28.1+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "1fcd6cf05d23adab0b5ffc496d020537215751dc"
registries = "General"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.59+1"

[[deps.libva_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll", "Xorg_libXext_jll", "Xorg_libXfixes_jll", "libdrm_jll"]
git-tree-sha1 = "21cbc8fc2ac0bb182ed461e556d9c062ae6a3164"
registries = "General"
uuid = "9a156e7d-b971-5f62-b2c9-67348b8fb97c"
version = "2.24.1+0"

[[deps.libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll"]
git-tree-sha1 = "11e1772e7f3cc987e9d3de991dd4f6b2602663a5"
registries = "General"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.8+0"

[[deps.mtdev_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "b4d631fd51f2e9cdd93724ae25b2efc198b059b1"
registries = "General"
uuid = "009596ad-96f7-51b1-9f1b-5ce2d5e8a71e"
version = "1.1.7+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.70.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.8.3+0"

[[deps.x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "14cc7083fc6dff3cc44f2bc435ee96d06ed79aa7"
registries = "General"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "10164.0.1+0"

[[deps.x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e7b67590c14d487e734dcb925924c5dc43ec85f3"
registries = "General"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "4.1.0+0"

[[deps.xkbcommon_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxcb_jll", "Xorg_xkeyboard_config_jll"]
git-tree-sha1 = "a1fc6507a40bf504527d0d4067d718f8e179b2b8"
registries = "General"
uuid = "d8fb68d0-12a3-5cfd-a85a-d49703b185fd"
version = "1.13.0+0"

[registries.General]
url = "https://github.com/JuliaRegistries/General.git"
uuid = "23338594-aafe-5451-b93e-139f81909106"
"""

# ╔═╡ Cell order:
# ╟─7a3916a4-f601-4776-8f8e-abcf64302316
# ╟─6eac874f-ab81-41ae-8489-cbfdd0768d87
# ╠═9cfb653e-3eae-4be4-9561-8857a8f3c660
# ╠═1bbd2ae2-a3cc-4c47-ae02-990f45ae097b
# ╟─6fd80202-c13c-4cf7-9f72-c88b67756cd9
# ╟─614998f6-cd35-4b0f-b1fb-63375bcd44f1
# ╠═874955b8-2e53-42f8-b341-d7ed13c541cc
# ╟─43c0a2c8-cf5e-4962-8075-6eb4aabe4277
# ╟─bf2a954d-ef32-4101-b426-371840995b83
# ╟─dd150d27-0964-4b40-a020-aac807f7dda3
# ╟─9e8b8bc4-faa2-4922-a130-70536a1302f5
# ╟─96d0aa5a-47fc-4172-a20a-f67ded615186
# ╟─083d1414-de47-4bed-89de-b07fe6fa082d
# ╟─47248afe-6256-42f3-aea6-6dea2a481fbf
# ╟─47d27bcc-ef60-41a3-9dfc-52f655121b70
# ╟─fa22024f-238d-4caa-9337-ca032c2be478
# ╟─1fc091de-40fe-4bde-b003-6a73d914a732
# ╟─91b15282-ef1d-42ef-a3d5-34b363af0cb6
# ╟─54e89a12-5361-4902-b6cf-397d0a93fe1d
# ╠═70567cf5-b024-42f7-a226-63a31081f95d
# ╟─3365966c-7198-4a8f-847c-5c238dbdd8c9
# ╟─3bf1ae5b-3970-46c1-ae03-3aaa3e9324f9
# ╟─2b43be6a-269b-4568-bfcd-3fbfe3cc3d05
# ╟─194fca66-df73-44c3-a4a2-00aa8c25c60d
# ╟─9c7f551c-229d-4d0d-bb04-dec33bfa6aad
# ╟─42c442c9-eddb-4b5d-89b0-6ed4da397bff
# ╟─2d6ea5cc-69fa-422b-af7b-f5b0e440a362
# ╟─f6cf60b4-5d1d-4f0d-a0c6-c180922d0f39
# ╟─087bc2c9-03cb-456e-9f43-e28a438bb488
# ╟─25ec2047-bba7-4cfa-885e-b09a25ea317e
# ╟─708326c8-4bac-47bd-a7fa-ad8b418f1438
# ╟─e082b7bc-3699-400a-8401-7c114ed9f92a
# ╟─f578d0de-aaed-4fbe-be74-796d724157b5
# ╟─caf2e8a1-a563-4f9f-a6a4-7c60106456ec
# ╟─d430a19a-716c-4fb3-b499-a7978003cb29
# ╟─368380b7-db67-4f00-b55c-653f02704dff
# ╟─3e1c7fd1-fce5-4dcf-8914-62b6002f6cf2
# ╟─db2e81b0-3267-4dd8-bfc2-a24af172e994
# ╟─b623e9a5-8c9d-4867-b0c7-7c9aa67f2a0b
# ╟─3f84eec5-0d97-4ef0-bfa9-62697c9ab3c7
# ╟─32f76fb9-0162-4882-b000-05c137f39f92
# ╟─8b9736c5-8447-4c5d-8e23-530a156a746a
# ╠═f863562d-69de-4c85-bf03-b8cd80b2464c
# ╠═905a3afe-fb5d-45b7-b7a3-dead7b7e30d1
# ╟─ea2e9bc9-9276-4952-84c9-2e8eefc01ae3
# ╟─17ef0231-c87f-44e0-950a-ba62130385ed
# ╟─55c3668f-fd47-4c2f-99c8-a3cacae31c26
# ╟─06dafd53-0d90-4901-ab09-2d068da73938
# ╟─f176a918-c417-43cc-9b56-50020f5f26f6
# ╟─10451db0-8fef-4164-9197-e1e757f45a00
# ╟─0c6b6e5a-c398-4127-b8d4-267c5554fc0d
# ╟─1ef627c7-3c05-41d4-8d33-66cc71ae27bd
# ╟─4005e735-14b2-4252-8b4a-fd0c6cf33321
# ╟─65b13cb1-d803-4113-a63a-45aad8fbb8d1
# ╟─628bf35b-befb-4324-8aa6-1861c4847f73
# ╟─a046cd9c-c5a4-49c1-8451-0ec50d748913
# ╟─f8cbcbe2-b263-425a-bfce-122a6508002b
# ╟─6fed0761-26b4-464e-bbb4-4c5eb80d0d66
# ╟─4abf4d5f-fbd9-45a3-acb5-797051453957
# ╟─50bad3a2-098d-4aa1-ae67-89841d6f7b7c
# ╠═a09a1046-a8f0-4b0a-a46a-067b0ab5d020
# ╟─e2291217-ec95-4e49-be01-19f14b186898
# ╟─58bbcd1e-6437-4b2c-988d-4d62ed0747ac
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
