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

# ╔═╡ cd5a9620-6a79-4748-8e24-479037d97b27
# RUN: packages used in this notebook.
using PlutoUI, PlutoTeachingTools, Plots, Random, Statistics, AbstractPlutoDingetjes, Base64

# ╔═╡ 211ef6d9-d20f-4d01-9ecb-ab7cc0925fac
# RUN: load the course code from ../src. No editing needed.
begin
	include(joinpath(@__DIR__, "..", "src", "MTLab.jl"))
	include(joinpath(@__DIR__, "..", "src", "Schematics.jl"))
	include(joinpath(@__DIR__, "..", "src", "Widgets.jl"))
	include(joinpath(@__DIR__, "..", "src", "Movies.jl"))
	using .MTLab: simulate_switching, simulate_res, summarize_segments, simulated_segments,
				  phase_segments, kymograph_segments, poisson_interval, dl_prediction,
				  growth_shrink_pairs, pair_correlation, switching_rescue_fraction
	using .Schematics: rescue_models_schematic, notebook_link
	using .Widgets: KymoTracer, png_size
	using .Movies: read_movie, max_projection, mean_projection, detect_lines, orient_line,
				   estimate_seed, kymograph, extend_line, gray8, png_bytes, line_key, read_table, write_table
end

# ╔═╡ edb895ef-b25e-4f0b-8fce-b4f696a43897
md"""
# Afternoon 5b — Real microtubules: from a movie to a model

**Question:** do real microtubules behave like the model of afternoons 1–2 (model A: growth, shrinkage, and random switching at constant rates)? You start from a microscope movie, build kymographs, measure the rates, and test model A with them. Then you compare with what two papers of the University of Geneva found when a motor protein, kinesin-1, walks on the microtubules.

* **Part I — Mireia's movies.** 1. From a movie to kymographs. 2. Rates and model A. 3. All 46 kymographs of three movies. 4. Your own movies.
* **Part II — The papers.** 5. The papers in plain words. 6. Their kymographs, analysed in the same way.
* **Part III — A second model.** Rescue at a constant rate, or at a place on the shaft?

Choose what you explore, and how far: the parts build on each other, but you do not need to do them all.

**Minimum output:** your rates table (part 2 or 3) with the number of events; model A's predictions next to the measurements; one figure; and an answer: where does model A work, and where does it fail?

*Movies: Mireia Andreu-Carbó, University of Geneva (2020), CC BY 4.0. Paper kymographs: cropped from the published figures (course data, not on GitHub).*
"""

# ╔═╡ 66cd5e7e-ad3b-485d-a8ed-c8c335ac39f3
TableOfContents(title="Afternoon 5b")

# ╔═╡ c0fecf3e-5199-41ce-9246-ca579dd2f252
# A wide notebook: kymographs, tables and figures side by side.
html"""<style>
main { max-width: min(1400px, 92vw) !important; margin-right: auto; }
</style>"""

# ╔═╡ 0eaa9a3b-c8f6-4d7a-9f7a-6e71d3f9125d
md"""
# Part I — Mireia's movies

## 1. From a movie to kymographs

**Mireia Andreu-Carbó** (Department of Biochemistry, University of Geneva) recorded these movies on 23 July 2020: microtubules growing from seeds attached to the glass, with 6 µM fluorescent tubulin and 100 mM KCl, **without motors**; one image every 3 s for about 14 min; 0.11 µm per pixel.

A **kymograph** is a picture of one microtubule over time: take the intensity along a line drawn on the microtubule, in every frame, and stack these lines from top to bottom. Growth then appears as a slanted edge, a shrinkage as an almost horizontal one.

1. **Choose a movie.** The test movie has a few microtubules; the crop of movie B has more.
2. **Check the calibration** (read from the file).
3. **Lines.** One line per microtubule is proposed automatically: correct them.
4. **Trace 2 or 3 kymographs by hand**, then go on to part 2.
"""

# ╔═╡ 18b58ecf-0d11-4625-91b4-cca974fca62f
movie_dir = mkpath(joinpath(@__DIR__, "..", "data", "movies"));

# ╔═╡ a607940b-82f7-4f0c-a4eb-0d7c210bace4
public_movie_dir = joinpath(@__DIR__, "..", "data", "test_movie");

# ╔═╡ c3e71451-a4dc-4e3e-95a4-e8045d5a8121
md"""
**Lines.** This is the brightest value of each pixel over the whole movie: each microtubule appears at its longest. The proposed lines are a first guess (microtubules that slide or touch another one are left out). Click a pair of points per microtubule: **first at the end that does not grow** (the seed, green square), **then past the furthest tip**. Leave out microtubules that cross another one, touch another one, or leave the image. *Undo last click* and *Clear* correct the lines.
"""

# ╔═╡ 908048b0-6aa4-4ae1-af13-d0687b1b87df
md"""
### What a kymograph cannot tell

* **The seed is hardly visible** in these movies: the dashed line is your choice of where it ends. Where does a shrinkage stop on the seed, and where is it rescued just before? You also have to choose a limit: a shrinkage that ends closer to the seed than $(@bind seed_threshold Slider(0.0:0.1:1.0; default=0.5, show_value=true)) µm counts as a return to the seed, not as a rescue. The image is blurred over about 0.3 µm. This limit is used everywhere in this notebook: move it later, and watch your rescue counts.
* **One image every 3 s:** a shrinkage (about 30 µm/min) lasts only a few rows, so its speed is uncertain.
* **Photobleaching:** old lattice fades. A fading microtubule is not a shrinking one.
* **Crossing microtubules** mix two edges: leave them out.
* **The end of the movie** cuts the last phase: it has no end event (censored), but its time counts.
* **The line is your choice:** a line that misses the tip, or follows a neighbour, changes everything.
"""

# ╔═╡ 6513f105-ad60-44b2-8867-bc7dd189baf0
question_box(md"""
**Before going on.** Which of your corners are you least sure of? Which of the four rates (growth, shrinkage, catastrophe, rescue) will be the least precise with 2 or 3 kymographs, and why?
""")

# ╔═╡ 4d8bd3fe-67de-488f-b233-0d72bc22ef01
md"""
✏️ **Part 1 notes.** Kymographs traced: ... Least certain corners: ... Least precise rate, and why: ...
"""

# ╔═╡ 0248ddaf-fc17-429d-9db1-bdf34f042c87
md"""
## 2. Rates and model A

The same analysis as afternoon 2: a speed is a length change divided by the time in that state; a rate is a number of events divided by the time at risk (growing time for catastrophes, shrinking time for rescues). The intervals come from the number of events: with few events, they are wide.
"""

# ╔═╡ a43fdb96-551a-4b52-8a3b-bdca9d248b40
"""
Time-weighted mean length of traced kymographs, from their corners (time in s, length in µm),
without the waiting time at the seed after a complete shrinkage (model A regrows at once).
"""
function mean_traced_length(traced; at_seed=0.3)
	num = 0.0; den = 0.0
	for t in traced, k in 1:length(t.points) - 1
		(t1, L1), (t2, L2) = t.points[k], t.points[k + 1]
		max(L1, L2) <= at_seed && continue
		num += (L1 + L2) / 2 * (t2 - t1); den += t2 - t1
	end
	den > 0 ? num / den : NaN
end;

# ╔═╡ cbdf0875-9727-4c5d-b350-807584af396b
"Rates table: one line per group (label => traced kymographs)."
function rates_table(groups)
	f(x) = isfinite(x) ? string(round(x; sigdigits=2)) : "–"
	iv(k, T) = T > 0 ? "$(f(poisson_interval(k)[1] / T * 60)) – $(f(poisson_interval(k)[2] / T * 60))" : "–"
	lines = map(groups) do (label, traced)
		label = replace(label, "_" => "\\_")
		rows = reduce(vcat, [t.rows for t in traced]; init=NamedTuple[])
		isempty(rows) && return "| $label | 0 | – | – | – | – | – |"
		s = summarize_segments(rows)
		n_seed = count(r -> r.end_event == "seed_restart", rows)
		"| $label | $(length(traced)) | $(f(s.vg * 60)) | $(f(s.vs * 60)) | $(f(s.catastrophe * 60)) ($(s.n_catastrophes); $(iv(s.n_catastrophes, s.growing_time))) | $(f(s.rescue * 60)) ($(s.n_rescues); $(iv(s.n_rescues, s.shrinking_time))) | $(s.n_rescues) of $(s.n_rescues + n_seed) |"
	end
	Markdown.parse("""
	| | kymographs | growth speed (µm/min) | shrinkage speed (µm/min) | catastrophes per min (count; 95 % interval) | rescues per min (count; 95 % interval) | shrinkages rescued |
	|:---|---:|---:|---:|:---|:---|:---|
	$(join(lines, "\n"))
	""")
end;

# ╔═╡ 18bace15-fe02-43f7-b828-1357855b2285
"Model A with the measured rates, next to the measurements: one line per group."
function modelA_table(groups)
	f(x) = isfinite(x) ? string(round(x; sigdigits=2)) : "–"
	pc(x) = isfinite(x) ? "$(round(Int, 100x)) %" : "–"
	lines = map(groups) do (label, traced)
		label = replace(label, "_" => "\\_")
		rows = reduce(vcat, [t.rows for t in traced]; init=NamedTuple[])
		isempty(rows) && return "| $label | – | – | – | – | – | – | – |"
		s = summarize_segments(rows)
		n_seed = count(r -> r.end_event == "seed_restart", rows)
		rescued = s.n_rescues + n_seed > 0 ? s.n_rescues / (s.n_rescues + n_seed) : NaN
		p = growth_shrink_pairs(rows)
		C = length(p.growth) >= 3 ? pair_correlation(p.growth, p.shrink) : NaN
		ok = all(isfinite, (s.vg, s.vs, s.catastrophe, s.rescue)) && s.vs > 0 && s.catastrophe > 0
		ok || return "| $label | – | $(pc(rescued)) | – | $(f(C)) ($(length(p.growth))) | – | $(f(mean_traced_length(traced))) | – |"
		d = dl_prediction(; vg=s.vg, vs=s.vs, catastrophe=s.catastrophe, rescue=s.rescue)
		"| $label | $(f(d.r)) | $(pc(rescued)) | $(pc(1 - d.p_complete)) | $(f(C)) ($(length(p.growth)) pairs) | $(f(d.correlation)) | $(f(mean_traced_length(traced))) | $(d.bounded ? f(d.mean_length) : "grows") |"
	end
	Markdown.parse("""
	| | ``r`` | shrinkages rescued: measured | model A | correlation ``C_{gs}``: measured | model A | mean length (µm): during the movie | model A, long times |
	|:---|---:|---:|---:|---:|---:|---:|---:|
	$(join(lines, "\n"))
	""")
end;

# ╔═╡ 30774495-5626-4a9c-9ff8-2a0d5f43fb2b
md"""
**Model A with your rates.** Model A has four numbers: ``v_g``, ``v_s``, ``k_\text{cat}`` and ``k_\text{res}``. With them it predicts, through ``r = v_g\,k_\text{res} / (v_s\,k_\text{cat})``:

* how often a shrinkage is rescued before it reaches the seed: a fraction ``r`` (if ``r < 1``);
* how much a long growth is followed by a long shrinkage: the correlation ``C_{gs} = (1-r)/(1+r)``;
* the mean length at long times, ``\langle L\rangle = \dfrac{v_g}{k_\text{cat}}\,\dfrac{1}{1-r}``, if ``r < 1``; if ``r > 1``, growth without limit.

These are predictions: the measured columns do not use them. The measured mean length leaves out the waiting time at the seed after a complete shrinkage: model A regrows at once.
"""

# ╔═╡ b4770758-1660-411f-b5f7-c815ffda534a
md"""
**Does it look the same?** Your microtubules (left) and microtubules simulated by model A with your rates (right), over the same time. $(@bind sim_runs CounterButton("New model A runs"))
"""

# ╔═╡ aae881a0-4022-48ec-abfc-17d8fe70e917
md"""
✏️ **Part 2 notes.** Which predictions of model A agree with your measurements, which do not? Which differences could come from too few events?

...
"""

# ╔═╡ 56da606e-a7b1-43e7-ae7b-26dff3386883
md"""
## 3. All 46 kymographs of three movies

We extracted one kymograph per isolated microtubule from three complete movies of Mireia (same conditions), and kept 46 clean ones. Each kymograph opens with an **automatic tracing** of its right edge (red line). **Check a few of them** against the image, as in part 1: click on a wrong corner to remove it, click where a corner is missing to add it (corners stay in time order). *↺ Automatic tracing* restores it. 9 kymographs have no automatic tracing, because it failed on them: trace them if you have time.

The tables below use your corrections where you made some, and the automatic tracing everywhere else. The dashed blue line marks the end of the seed, as assumed by the automatic tracing (31 px from the left): move it with the *seed* slider under the image and press **Set seed** if the image says otherwise. *Data: M. Andreu-Carbó, University of Geneva, CC BY 4.0.*
"""

# ╔═╡ cd0bc73a-da5d-40ee-95ab-f65973b0b56e
ready_dir = joinpath(@__DIR__, "..", "data", "kymographs_movies");

# ╔═╡ 7efbd237-9f39-4914-9709-9bafc73cffde
ready_kymographs = [r for r in read_table(joinpath(ready_dir, "kymographs.csv")) if length(r) >= 10 && isfile(joinpath(ready_dir, r[1]))];

# ╔═╡ 896eb951-473a-46bc-a404-c5ff08407b58
ready_reference = let
	out = Dict{String,Vector{Tuple{Int,Int}}}()
	file = joinpath(ready_dir, "reference_traces.csv")
	for l in (isfile(file) ? readlines(file) : String[])
		(startswith(l, "#") || startswith(l, "file,") || isempty(strip(l))) && continue
		f = split(l, ",")
		push!(get!(out, String(f[1]), Tuple{Int,Int}[]), (parse(Int, f[2]), parse(Int, f[3])))
	end
	out
end;

# ╔═╡ 188410e3-71ff-4a4f-945b-f033b84aa48a
md"""
Kymograph: $(@bind ready_file Select(isempty(ready_kymographs) ? ["(none)" => "none found: ask the instructor for the folder data/kymographs_movies"] : [r[1] => string(r[2], ", microtubule ", r[3], haskey(ready_reference, r[1]) ? "" : " (no automatic tracing)") for r in ready_kymographs]; default=something(findfirst(r -> haskey(ready_reference, r[1]), ready_kymographs) |> (i -> i === nothing ? nothing : ready_kymographs[i][1]), ready_kymographs[1][1]))) $(@bind ready_reset CounterButton("↺ Automatic tracing"))
"""

# ╔═╡ 6c37f3a3-e546-4be7-9c21-05ce9e9dcc4b
ready_info = let
	i = findfirst(r -> r[1] == ready_file, ready_kymographs)
	i === nothing ? nothing : (file=ready_file, label="$(ready_kymographs[i][2]), microtubule $(ready_kymographs[i][3])",
							   um_per_px=parse(Float64, ready_kymographs[i][8]), s_per_frame=parse(Float64, ready_kymographs[i][9]),
							   condition=ready_kymographs[i][10],
							   seed_col=length(ready_kymographs[i]) >= 11 ? parse(Int, ready_kymographs[i][11]) : 11,
							   reference=get(ready_reference, ready_file, Tuple{Int,Int}[]))
end;

# ╔═╡ 77730803-121d-4f89-83a2-1f1fd4604e3f
ready_reset_seen = Ref(0);

# ╔═╡ f952d596-4b4b-4f09-a68f-00bc458dae8e
ready_reset_done = let
	# ↺ forgets your corrections of this kymograph (only when the button was pressed)
	if ready_reset > ready_reset_seen[] && ready_info !== nothing
		ready_reset_seen[] = ready_reset
		file = joinpath(movie_dir, "traces.csv")
		write_table(file, "movie,line,row,col", [r for r in read_table(file) if !(r[1] == "ready" && r[2] == ready_info.file)])
		sfile = joinpath(movie_dir, "seeds.csv")
		write_table(sfile, "movie,line,seed_col", [r for r in read_table(sfile) if !(r[1] == "ready" && r[2] == ready_info.file)])
	end
	time()
end;

# ╔═╡ 0d704100-65c7-4ccc-9ff9-00875828ecc2
@bind ready_tool let
	ready_reset_done
	if ready_info === nothing
		KymoTracer(png_bytes(zeros(UInt8, 1, 1)); scale=1)
	else
		saved = [(parse(Int, r[3]), parse(Int, r[4])) for r in read_table(joinpath(movie_dir, "traces.csv")) if r[1] == "ready" && r[2] == ready_info.file]
		seeds = [v for r in read_table(joinpath(movie_dir, "seeds.csv")) if r[1] == "ready" && r[2] == ready_info.file for v in (tryparse(Int, r[3]),) if v !== nothing]
		KymoTracer(read(joinpath(ready_dir, ready_info.file)); scale=2, corners=isempty(saved) ? ready_info.reference : saved, margin=4,
				   seed=isempty(seeds) ? ready_info.seed_col : seeds[end])
	end
end

# ╔═╡ 4a4ff030-72f5-4b85-98e7-06292c6dadcd
ready_trace, ready_seed = ready_tool isa NamedTuple ? (ready_tool.corners, ready_tool.seed) : (ready_tool, nothing);

# ╔═╡ bec0e730-a6ab-4ee8-9094-98a63de4976e
ready_saved = let
	if ready_info !== nothing
		file = joinpath(movie_dir, "traces.csv")
		rows = [r for r in read_table(file) if !(r[1] == "ready" && r[2] == ready_info.file)]
		# only a correction is saved: an unchanged automatic tracing is read from the reference
		ready_trace == ready_info.reference ||
			append!(rows, [["ready", ready_info.file, string(r), string(c)] for (r, c) in ready_trace])
		write_table(file, "movie,line,row,col", rows)
	end
	time()
end;

# ╔═╡ 3fe14482-4640-4d3e-9b96-191e396735d7
ready_seed_saved = let
	if ready_info !== nothing
		file = joinpath(movie_dir, "seeds.csv")
		rows = [r for r in read_table(file) if !(r[1] == "ready" && r[2] == ready_info.file)]
		ready_seed == ready_info.seed_col || push!(rows, ["ready", ready_info.file, string(ready_seed)])
		write_table(file, "movie,line,seed_col", rows)
	end
	time()
end;

# ╔═╡ 8b8df017-5118-4aeb-ae58-dfa8aa6f098f
if ready_info === nothing
	md""
else
	let
	cal = (; px_per_um=1 / ready_info.um_per_px, px_per_min=60 / ready_info.s_per_frame, seed_um=seed_threshold, seed_col=ready_seed)
	t = kymograph_segments(ready_trace; cal...)
	mine = ready_trace != ready_info.reference
	p = plot(; xlabel="time (min)", ylabel="length from the seed (µm)", legend=:topleft, size=(640, 260), margin=4Plots.mm,
			 title="$(ready_info.label): $(length(t.rows)) segments, $(mine ? "your tracing" : "automatic tracing")", titlefontsize=9)
	if mine && !isempty(ready_info.reference)
		r = kymograph_segments(ready_info.reference; cal...)
		plot!(p, first.(r.points) ./ 60, last.(r.points); color="#c8cfd6", lw=3, label="automatic")
	end
	isempty(t.points) || plot!(p, first.(t.points) ./ 60, last.(t.points); color="#5d6875", marker=:circle, ms=2, msw=0, label=mine ? "yours" : "automatic")
	isempty(t.warnings) ? p : PlutoUI.ExperimentalLayout.vbox([p, warning_box(Markdown.parse(join(t.warnings, " ")))])
	end
end

# ╔═╡ 483adc8a-f76c-4bb5-a06a-0cddb722132c
"The 46 kymographs: your corrections where you made some, the automatic tracing elsewhere."
ready_traced = let
	ready_saved; ready_seed_saved                      # recompute after every save
	traces = read_table(joinpath(movie_dir, "traces.csv"))
	seeds = Dict(r[2] => v for r in read_table(joinpath(movie_dir, "seeds.csv")) if length(r) >= 3 && r[1] == "ready" for v in (tryparse(Int, r[3]),) if v !== nothing)
	out = Any[]
	for k in ready_kymographs
		mine = [(parse(Int, t[3]), parse(Int, t[4])) for t in traces if t[1] == "ready" && t[2] == k[1]]
		corners = isempty(mine) ? get(ready_reference, k[1], Tuple{Int,Int}[]) : mine
		length(corners) >= 2 || continue
		push!(out, kymograph_segments(corners; px_per_um=1 / parse(Float64, k[8]), px_per_min=60 / parse(Float64, k[9]),
									  seed_um=seed_threshold, seed_col=get(seeds, k[1], length(k) >= 11 ? parse(Int, k[11]) : 11),
									  condition=k[10], track="$(k[2]) microtubule $(k[3])",
									  source=isempty(mine) ? "automatic tracing" : "my tracing"))
	end
	out
end;

# ╔═╡ f7682db7-7b44-4834-be19-95d142f1086a
md"""
**A few kymographs, or many?** Your own traces (part 2) next to all the kymographs of the three movies. Compare the numbers of events and the widths of the intervals.
"""

# ╔═╡ 46b42a51-a407-49fb-9a63-a1d85b5e99a6
question_box(md"""
**Where does model A work, and where does it fail?** With many events, which of its predictions agree with the movies? Look at the correlation ``C_{gs}`` between a growth and the next shrinkage: what would make a long growth be followed by a long shrinkage, more often than model A predicts?
""")

# ╔═╡ fcb74759-7c25-4eeb-9559-b2acc40d7b12
md"""
✏️ **Part 3 notes.** What changed with many kymographs? Where does model A work, where does it fail?

...
"""

# ╔═╡ fe12e052-d42d-414f-acb9-a13b200a3415
md"""
## 4. Your own movies

If you recorded movies in the experimental practical, analyse them with the tools of part 1. The movie must be an **uncompressed TIFF stack** (in Fiji: *File > Save As > Tiff...*). Upload it below, or copy it into the folder `data/movies/` of the course folder (better above about 100 MB) and press *Refresh the list*. It then appears in the movie menu of part 1: choose it there, check its calibration, give it a condition label, draw the lines and trace. Its rates appear in the table of part 2, under its label.

Upload a movie: $(@bind movie_upload FilePicker()) $(@bind movie_refresh CounterButton("Refresh the list"))
"""

# ╔═╡ 6c819691-4042-4e0a-8123-93be47945d50
uploaded_movie = let
	if movie_upload === nothing
		nothing
	else
		name = replace(basename(movie_upload["name"]), r"[,|/\\]" => "_")
		occursin(r"\.tiff?$"i, name) || (name *= ".tif")
		path = joinpath(movie_dir, name)
		(isfile(path) && filesize(path) == length(movie_upload["data"])) || write(path, movie_upload["data"])
		name
	end
end;

# ╔═╡ cd17aee4-da21-48e5-a8ce-03fb3bc5bcd8
movie_paths = (movie_refresh; uploaded_movie; let
	paths = Dict{String,String}()
	for dir in (public_movie_dir, movie_dir), f in (isdir(dir) ? readdir(dir) : String[])
		occursin(r"\.tiff?$"i, f) && (paths[f] = joinpath(dir, f))
	end
	paths
end);

# ╔═╡ d651bae7-8e3f-469c-babd-be11284a87b1
movie_choices = let
	known = ["movie_A_test.tif" => "Mireia's test movie (few microtubules)",
			 "movie_B_crop.tif" => "Mireia's movie B, cropped (more microtubules)"]
	public = [p for p in known if haskey(movie_paths, p.first)]
	own = [n => "$n (your movie)" for n in sort(collect(keys(movie_paths))) if !any(p -> p.first == n, known)]
	choices = [public; own]
	isempty(choices) ? ["(no movie)" => "no movie found: ask the instructor"] : choices
end;

# ╔═╡ fb24eaaa-a121-4806-b2f6-4a3305e0d313
md"""
Movie: $(@bind movie_name Select(movie_choices))
"""

# ╔═╡ 4bbf0c5d-83b1-430a-94c4-01d080b833d7
movie = let
	path = get(movie_paths, movie_name, "")
	if !isfile(path)
		nothing
	else
		try
			read_movie(path)
		catch e
			e isa ArgumentError ? e.msg : sprint(showerror, e)
		end
	end
end;

# ╔═╡ c529b6c7-830f-474f-81da-61c462b2cde2
if movie === nothing
	md"*No movie found.*"
elseif movie isa String
	danger(Markdown.parse(movie))
else
	let m = movie
		notes = isempty(m.notes) ? "" : "\n\n" * join(("* " * n for n in m.notes), "\n")
		Markdown.parse("""
		**$(m.name):** $(size(m.data, 2)) × $(size(m.data, 1)) pixels, $(m.channels) channel(s), $(m.frames) frames$(isfinite(m.s_per_frame) ? ", $(round(m.frames * m.s_per_frame / 60; digits=1)) min" : "").$(notes)
		""")
	end
end

# ╔═╡ cc62299f-3552-47c8-a428-2efec54a5255
@bind movie_settings let
	m = movie isa NamedTuple ? movie : (; name=movie_name, channels=1, um_per_px=NaN, s_per_frame=NaN)
	saved = Dict(r[1] => r for r in read_table(joinpath(movie_dir, "settings.csv")) if length(r) >= 6)
	s = get(saved, m.name, nothing)
	mireia = m.name in ("movie_A_test.tif", "movie_B_crop.tif")
	channel = s === nothing ? 1 : clamp(something(tryparse(Int, s[2]), 1), 1, m.channels)
	um = s === nothing ? (isfinite(m.um_per_px) ? round(m.um_per_px; digits=4) : 0.1) : parse(Float64, s[3])
	dt = s === nothing ? (isfinite(m.s_per_frame) ? round(m.s_per_frame; digits=2) : 1.0) : parse(Float64, s[4])
	condition = s !== nothing ? s[5] : mireia ? "6 µM tubulin 100 mM KCl" : replace(m.name, r"\.tiff?$"i => "")
	use = s === nothing || s[6] == "true"
	PlutoUI.combine() do Child
		md"""
		| | |
		|:---|:---|
		| channel with the microtubules | $(Child(:channel, Select(collect(1:m.channels); default=channel))) |
		| pixel size (µm per pixel) | $(Child(:um_per_px, NumberField(0.0001:0.0001:10; default=um))) |
		| time between frames (s) | $(Child(:s_per_frame, NumberField(0.01:0.01:600; default=dt))) |
		| condition (movies with the same label are pooled) | $(Child(:condition, TextField(; default=condition))) |
		| use this movie in the rates table | $(Child(:include, CheckBox(; default=use))) |
		"""
	end
end

# ╔═╡ cfa130b1-e9c2-48f4-8722-6cf4432c6eb1
settings_saved = let
	if movie isa NamedTuple
		file = joinpath(movie_dir, "settings.csv")
		rows = [r for r in read_table(file) if r[1] != movie.name]
		s = movie_settings
		push!(rows, [movie.name, string(s.channel), string(s.um_per_px), string(s.s_per_frame),
					 strip(s.condition), string(s.include)])
		write_table(file, "movie,channel,um_per_px,s_per_frame,condition,include", rows)
	end
	time()
end;

# ╔═╡ e60fb77c-a10a-4933-a04d-a55fe21a1e35
movie_projection = movie isa NamedTuple ? max_projection(movie, movie_settings.channel) : zeros(Float32, 2, 2);

# ╔═╡ fed8f352-6cbf-4485-9520-82c61287dd3a
@bind movie_lines let
	img = movie_projection
	saved = [r for r in read_table(joinpath(movie_dir, "lines.csv")) if r[1] == movie_name]
	lines = if !isempty(saved)
		[Tuple(parse.(Int, r[2:5])) for r in saved]
	elseif movie isa NamedTuple
		# seed end first, judged on each kymograph; lines without a fixed seed are left out
		filter(!isnothing, [orient_line(l, movie, movie_settings.channel) for l in detect_lines(img)])
	else
		NTuple{4,Int}[]
	end
	corners = reduce(vcat, [[(l[1], l[2]), (l[3], l[4])] for l in lines]; init=Tuple{Int,Int}[])
	KymoTracer(png_bytes(gray8(img)); scale=clamp(680 / size(img, 2), 0.5, 3), corners, pairs=true)
end

# ╔═╡ c7696898-d484-41c4-9b9e-d73716f19afe
current_lines = [(movie_lines[2i - 1]..., movie_lines[2i]...) for i in 1:length(movie_lines) ÷ 2
				 if hypot(movie_lines[2i][1] - movie_lines[2i - 1][1], movie_lines[2i][2] - movie_lines[2i - 1][2]) >= 5];

# ╔═╡ 64722cbd-00e1-4e2b-9f83-65a621350515
md"""
**Trace a kymograph.** Above are the kymographs of all your lines, with 2 µm of image beyond each end of the line: the seed is on the left, time runs down (one row per frame). Choose one with clear edges, and click the corners of its **right edge**, the growing end, from top to bottom:

0. **the seed**: move the *seed* slider under the image until the dashed line sits at the end of the seed, then press **Set seed** (the line is orange until then, and nothing is recomputed), where every growth starts (the seed itself is dim in these movies). It is placed automatically: check it.
1. where growth starts (on the seed, or at the top of the image),
2. the tip of each growth phase (the catastrophe),
3. the end of each shrinkage: back on the seed, or a rescue if the microtubule grows again before reaching the seed,
4. the last row of the image.

The edge between two corners must be a straight line: add a corner wherever it changes direction. Click on a corner to remove it. Your traces are saved; trace 2 or 3 kymographs.

Kymograph: $(@bind kymo_index Select(isempty(current_lines) ? [0 => "no line yet"] : [i => "line $i" for i in eachindex(current_lines)]))
"""

# ╔═╡ 9882ca60-56eb-4afd-990e-31c836681892
lines_saved = let
	if movie isa NamedTuple
		file = joinpath(movie_dir, "lines.csv")
		rows = [r for r in read_table(file) if r[1] != movie.name]
		append!(rows, [[movie.name, string.(l)...] for l in current_lines])
		write_table(file, "movie,row1,col1,row2,col2", rows)
	end
	time()
end;

# ╔═╡ c262eab9-3acf-4bcc-9726-579dc9c95e49
"Each line, lengthened by 20 px of image at both ends, and the shift of the kymograph columns."
movie_extended = movie isa NamedTuple ? [extend_line(l, 20, size(movie.data)[1:2]) for l in current_lines] : Any[];

# ╔═╡ 3d14008c-894b-44c4-892d-8d3c558fe495
movie_kymographs = movie isa NamedTuple ?
	[kymograph(movie, movie_settings.channel, first(e)) for e in movie_extended] : Matrix{Float32}[];

# ╔═╡ 5b894f17-9285-42a6-a051-5c9fc39e93e5
if isempty(movie_kymographs)
	md"*No line yet.*"
else
	let
		items = map(enumerate(movie_kymographs)) do (i, k)
			data = Base64.base64encode(png_bytes(gray8(k; lo=0.02, hi=0.995)))
			"""<figure style="margin:0; text-align:center"><img src="data:image/png;base64,$data" style="height:240px; image-rendering:pixelated"><figcaption>line $i</figcaption></figure>"""
		end
		PlutoUI.WideCell(HTML("""<div style="display:flex; flex-wrap:wrap; gap:12px">$(join(items))</div>"""); max_width=1200)
	end
end

# ╔═╡ 5c657633-1e7c-4a11-ab10-c3e0914786e6
@bind movie_tool let
	if kymo_index == 0 || kymo_index > length(movie_kymographs)
		KymoTracer(png_bytes(zeros(UInt8, 1, 1)); scale=1)
	else
		k = movie_kymographs[kymo_index]
		key = line_key(movie_name, current_lines[kymo_index])
		saved = [(parse(Int, r[3]), parse(Int, r[4])) for r in read_table(joinpath(movie_dir, "traces.csv")) if r[1] == movie_name && r[2] == key]
		# seed: the saved one, or where every growth starts
		seeds = [v for r in read_table(joinpath(movie_dir, "seeds.csv")) if r[1] == movie_name && r[2] == key for v in (tryparse(Int, r[3]),) if v !== nothing]
		start = movie_extended[kymo_index][2] + 1          # first column of the drawn line
		seed = isempty(seeds) ? estimate_seed(k; from=start, fallback=start) : seeds[end]
		KymoTracer(png_bytes(gray8(k; lo=0.02, hi=0.995)); scale=clamp(700 / size(k, 1), 1, 3), corners=saved, margin=4,
				   seed=clamp(seed, 1, size(k, 2)))
	end
end

# ╔═╡ 3d6287a2-b8d7-490c-bd13-e3685619d91e
movie_trace, movie_seed = movie_tool isa NamedTuple ? (movie_tool.corners, movie_tool.seed) : (movie_tool, nothing);

# ╔═╡ 979c8539-d367-4908-8aad-7dc8814d7fee
traces_saved = let
	if movie isa NamedTuple && 1 <= kymo_index <= length(current_lines)
		file = joinpath(movie_dir, "traces.csv")
		key = line_key(movie.name, current_lines[kymo_index])
		rows = [r for r in read_table(file) if !(r[1] == movie.name && r[2] == key)]
		append!(rows, [[movie.name, key, string(r), string(c)] for (r, c) in movie_trace])
		write_table(file, "movie,line,row,col", rows)
	end
	time()
end;

# ╔═╡ c0f19650-6203-4354-97c6-ed40ee0c0d42
movie_seed_saved = let
	if movie isa NamedTuple && 1 <= kymo_index <= length(current_lines)
		file = joinpath(movie_dir, "seeds.csv")
		key = line_key(movie.name, current_lines[kymo_index])
		rows = [r for r in read_table(file) if !(r[1] == movie.name && r[2] == key)]
		push!(rows, [movie.name, key, string(movie_seed)])
		write_table(file, "movie,line,seed_col", rows)
	end
	time()
end;

# ╔═╡ eee3b87c-ecba-4d26-86aa-f6891184d409
if kymo_index == 0 || !(movie isa NamedTuple)
	md""
else
	let
	s = movie_settings
	t = kymograph_segments(movie_trace; px_per_um=1 / s.um_per_px, px_per_min=60 / s.s_per_frame, seed_um=seed_threshold, seed_col=movie_seed)
	p = plot(; xlabel="time (min)", ylabel="length from the seed (µm)", legend=false,
			 size=(640, 240), margin=4Plots.mm, title="line $(kymo_index): $(length(t.rows)) segments", titlefontsize=9)
	isempty(t.points) || plot!(p, first.(t.points) ./ 60, last.(t.points); color="#5d6875", marker=:circle, ms=2, msw=0)
	isempty(t.warnings) ? p : PlutoUI.ExperimentalLayout.vbox([p, warning_box(Markdown.parse(join(t.warnings, " ")))])
	end
end

# ╔═╡ 06797c4e-8bdc-4f49-8134-d09c923d9f92
"Traced kymographs of every movie of part 1 (and part 4) marked *use this movie*, grouped by condition."
my_traced = let
	settings_saved; lines_saved; traces_saved; movie_seed_saved          # recompute after every save
	seeds = Dict((r[1], r[2]) => tryparse(Int, r[3]) for r in read_table(joinpath(movie_dir, "seeds.csv")) if length(r) >= 3)
	settings = Dict(r[1] => r for r in read_table(joinpath(movie_dir, "settings.csv")) if length(r) >= 6)
	traces = read_table(joinpath(movie_dir, "traces.csv"))
	groups = Dict{String,Vector{Any}}()
	numbers = Dict{String,Int}()                       # line number within its movie
	for r in read_table(joinpath(movie_dir, "lines.csv"))
		number = numbers[r[1]] = get(numbers, r[1], 0) + 1
		s = get(settings, r[1], nothing)
		(s === nothing || s[6] != "true" || !haskey(movie_paths, r[1])) && continue
		key = line_key(r[1], Tuple(parse.(Int, r[2:5])))
		corners = [(parse(Int, t[3]), parse(Int, t[4])) for t in traces if t[1] == r[1] && t[2] == key]
		length(corners) >= 2 || continue
		out = kymograph_segments(corners; px_per_um=1 / parse(Float64, s[3]), px_per_min=60 / parse(Float64, s[4]), seed_um=seed_threshold,
								 seed_col=get(seeds, (r[1], key), nothing), condition=s[5], track="$(replace(r[1], r"\.tiff?$"i => "")) line $number", source=r[1])
		push!(get!(groups, s[5], Any[]), out)
	end
	sort([k => v for (k, v) in groups]; by=first)
end;

# ╔═╡ ca40e0a1-1a12-496d-8acc-2fc42d95ea54
(isempty(my_traced) ? md"*No traced kymograph yet: trace at least one in part 1.*" : rates_table(my_traced)) |> PlutoUI.WideCell(; max_width=1200)

# ╔═╡ c8168f17-29fd-4106-aaae-2136cda1ed7d
(isempty(my_traced) ? md"" : modelA_table(my_traced)) |> PlutoUI.WideCell(; max_width=1200)

# ╔═╡ 20391854-bd19-4874-9724-1926fcb66e57
if isempty(my_traced)
	md""
else
	let
	label, traced = argmax(g -> length(g.second), my_traced)
	rows = reduce(vcat, [t.rows for t in traced])
	s = summarize_segments(rows)
	T = maximum(t.points[end][1] for t in traced)
	left = plot(; xlabel="time (min)", ylabel="length (µm)", legend=false, title="your microtubules", titlefontsize=9)
	for t in traced[1:min(end, 4)]
		plot!(left, first.(t.points) ./ 60, last.(t.points); lw=2)
	end
	right = plot(; xlabel="time (min)", legend=false, title="model A with your rates", titlefontsize=9)
	if all(isfinite, (s.vg, s.vs, s.catastrophe, s.rescue)) && s.vg > 0 && s.vs > 0
		for i in 1:4
			r = simulate_switching(; vg=s.vg, vs=s.vs, catastrophe=s.catastrophe, rescue=s.rescue,
								   t_end=T, dt=min(0.5, 0.1 / max(s.catastrophe, s.rescue)), initial_length=0.0, seed=100 * sim_runs + i)
			plot!(right, r.t ./ 60, r.length; lw=2)
		end
	end
	plot(left, right; layout=(1, 2), size=(1150, 340), margin=5Plots.mm, link=:y) |> PlutoUI.WideCell(; max_width=1200)
	end
end

# ╔═╡ f29c9c12-80c9-4b43-9047-febe6af16cb3
let
	mine = isempty(my_traced) ? Any[] : argmax(g -> length(g.second), my_traced).second
	rates_table(["your traces (part 1)" => mine, "the movies, $(length(ready_traced)) kymographs" => ready_traced]) |> PlutoUI.WideCell(; max_width=1200)
end

# ╔═╡ cd08e6e0-d5c6-40a7-a613-e6d872463c75
let
	mine = isempty(my_traced) ? Any[] : argmax(g -> length(g.second), my_traced).second
	modelA_table(["your traces (part 1)" => mine, "the movies, $(length(ready_traced)) kymographs" => ready_traced]) |> PlutoUI.WideCell(; max_width=1200)
end

# ╔═╡ 13ff71e4-2b29-4370-a76b-d6021114c40d
md"""
# Part II — The papers

## 5. The papers in plain words

Two papers of the University of Geneva studied what happens when the motor protein **kinesin-1** walks on microtubules. You do not need to read them: here are their main points.

* J. Schaer, M. Andreu-Carbó, K. Kruse and C. Aumeier, *The effect of motor-induced shaft dynamics on microtubule stability and length*, Biophys. J. 122, 346–359 (2023). [Article](https://doi.org/10.1016/j.bpj.2022.12.010)
* M. Andreu-Carbó, S. Fernandes, M.-C. Velluz, K. Kruse and C. Aumeier, *Motor usage imprints microtubule stability along the shaft*, Dev. Cell 57, 5–18 (2022). [Article](https://doi.org/10.1016/j.devcel.2021.11.019)

1. **The experiment.** Microtubules grow from seeds in vitro for 45 min (8 µM tubulin, 37 °C), with 0, 1 or 2 nM kinesin-1 (up to 5 nM in the second paper). Without kinesin-1, a shrinking microtubule is rarely rescued: it usually shrinks back to the seed.
2. **What the motors change.** With kinesin-1, rescues become more frequent. Growth speed, shrinkage speed and catastrophe rate do not change.
3. **Longer microtubules.** The mean length after 45 min rises from 7.3 ± 5.1 µm (0 nM) to 13.5 ± 8.1 µm (1 nM) and 19 ± 11.6 µm (2 nM). At 2 nM it is still rising after 45 min: near 2 nM, microtubules may stop having a typical length and grow without limit.
4. **Why.** Walking motors damage the shaft, and fresh GTP-tubulin is built into the damaged places: **exchange sites**. A shrinking microtubule can be rescued where it reaches such a site.
5. **Model and experiment.** A model of this mechanism reproduces the kymographs and the rise of the length with kinesin-1, but its mean lengths are **shorter than the measured ones**: microtubules shorter than about 1 µm are hard to see, and the lengths include the growth at both ends of the seed.
6. **Shrinkages rescued:** 22 % without kinesin-1 (85 of 384), 61 % with 2 nM (188 of 309). The seeds have their own color in these experiments, so a rescue is easy to tell from a return to the seed.
7. **Same averages, different microtubules.** A constant rescue rate can give the right average length, but not the right individual microtubules: with exchange sites, a long growth is followed by a long shrinkage. *(Part III.)*
"""

# ╔═╡ 42f3bedc-203b-41c9-a990-8eb1185d99bf
md"""
## 6. Their kymographs, analysed in the same way

These are the six kymographs of Fig. 2A–C of the first paper: two for each kinesin-1 concentration. Position runs to the right (seed on the left), time runs down. They are cropped from the published figure: they come with the course data (`data/kymographs_paper/`), not from GitHub.

Each kymograph opens with a **reference tracing** (automatic edge detection, red line). It is often wrong on these small images: **check it and correct it**, as in part 3. Click on a wrong corner to remove it, click where a corner is missing to add it; The dashed blue line marks the end of the seed: move it with the *seed* slider under the image and press **Set seed** if the image says otherwise. *↺ Reference tracing* restores both. The tables below use your corrections where you made some, and the reference tracing elsewhere.
"""

# ╔═╡ eea700b3-d6aa-4c3f-9bd2-be762521a666
kymo_dir = joinpath(@__DIR__, "..", "data", "kymographs_paper");

# ╔═╡ c2657fe2-e2f7-4fc9-976b-91f1ed6d90d3
paper_calibration = let
	file = joinpath(kymo_dir, "calibration.csv")
	rows = isfile(file) ? [split(l, ",") for l in readlines(file)[2:end] if startswith(l, "kymograph_")] : []
	Dict(String(f[1]) => (nM=parse(Int, f[2]), px_per_um=parse(Float64, f[3]) / 2, px_per_min=parse(Float64, f[4]) / 2,
						  figure=String(f[5])) for f in rows)
end;

# ╔═╡ 7e300fce-3121-45b0-8ec3-a9bcfb251517
paper_names = sort([n for n in keys(paper_calibration) if isfile(joinpath(kymo_dir, n * ".png"))]);

# ╔═╡ d9ea88ae-603a-490a-adbe-ae345e204997
length(paper_names) == 6 ? md"" : danger(md"The kymographs of the papers are missing: install the course data (`data/kymographs_paper/`) given by the instructor.")

# ╔═╡ e1fab095-657b-4ae5-9a5c-4f8922afa706
paper_reference = let
	file = joinpath(kymo_dir, "reference_traces.csv")
	out = Dict(n => Tuple{Int,Int}[] for n in paper_names)
	for l in (isfile(file) ? readlines(file) : String[])
		(startswith(l, "#") || startswith(l, "kymograph,") || isempty(strip(l))) && continue
		f = split(l, ",")
		haskey(out, f[1]) && push!(out[String(f[1])], (parse(Int, f[2]), parse(Int, f[3])))
	end
	out
end;

# ╔═╡ 8aaa21d4-fc15-4d5c-b8b5-caa2b3309c5c
paper_seed = Dict(n => (isempty(paper_reference[n]) ? 1 : minimum(last, paper_reference[n])) for n in paper_names);

# ╔═╡ 83381c78-db82-476a-8b59-866fe2464b40
paper_reset_seen = Ref(0);

# ╔═╡ 970fe899-da9e-4527-acc0-24e09ae466c7
md"""
Kymograph: $(@bind paper_file Select(isempty(paper_names) ? ["(none)" => "none found"] : [n => string(paper_calibration[n].nM, " nM, ", replace(paper_calibration[n].figure, "Schaer et al. 2023 " => "")) for n in paper_names])) $(@bind paper_reset CounterButton("↺ Reference tracing"))
"""

# ╔═╡ feaee9e6-015e-4ad5-ba57-f814f15fd447
paper_reset_done = let
	# ↺ forgets your corrections of this kymograph (only when the button was pressed)
	if paper_reset > paper_reset_seen[] && haskey(paper_calibration, paper_file)
		paper_reset_seen[] = paper_reset
		file = joinpath(movie_dir, "traces.csv")
		write_table(file, "movie,line,row,col", [r for r in read_table(file) if !(r[1] == "paper" && r[2] == paper_file)])
		sfile = joinpath(movie_dir, "seeds.csv")
		write_table(sfile, "movie,line,seed_col", [r for r in read_table(sfile) if !(r[1] == "paper" && r[2] == paper_file)])
	end
	time()
end;

# ╔═╡ 96012b93-adbc-4278-8782-03902ca11da0
@bind paper_tool let
	paper_reset_done
	if !haskey(paper_calibration, paper_file)
		KymoTracer(png_bytes(zeros(UInt8, 1, 1)); scale=1)
	else
		saved = [(parse(Int, r[3]), parse(Int, r[4])) for r in read_table(joinpath(movie_dir, "traces.csv")) if r[1] == "paper" && r[2] == paper_file]
		seeds = [v for r in read_table(joinpath(movie_dir, "seeds.csv")) if r[1] == "paper" && r[2] == paper_file for v in (tryparse(Int, r[3]),) if v !== nothing]
		KymoTracer(read(joinpath(kymo_dir, paper_file * ".png")); scale=1.5, margin=8,
				   corners=isempty(saved) ? paper_reference[paper_file] : saved,
				   seed=isempty(seeds) ? paper_seed[paper_file] : seeds[end])
	end
end

# ╔═╡ 97a52e3a-d30f-48b4-ac6b-23ba7bb9731e
paper_trace, paper_seed_col = paper_tool isa NamedTuple ? (paper_tool.corners, paper_tool.seed) : (paper_tool, nothing);

# ╔═╡ 952a79d9-4cc4-42cb-b483-108e36fbff4d
paper_saved = let
	if haskey(paper_calibration, paper_file)
		file = joinpath(movie_dir, "traces.csv")
		rows = [r for r in read_table(file) if !(r[1] == "paper" && r[2] == paper_file)]
		# only a correction is saved: an unchanged reference tracing is read from the reference
		paper_trace == paper_reference[paper_file] ||
			append!(rows, [["paper", paper_file, string(r), string(c)] for (r, c) in paper_trace])
		write_table(file, "movie,line,row,col", rows)
	end
	time()
end;

# ╔═╡ d943a609-adf3-4689-8ecb-a8f7098f842c
paper_seed_saved = let
	if haskey(paper_calibration, paper_file)
		file = joinpath(movie_dir, "seeds.csv")
		rows = [r for r in read_table(file) if !(r[1] == "paper" && r[2] == paper_file)]
		paper_seed_col == paper_seed[paper_file] || push!(rows, ["paper", paper_file, string(paper_seed_col)])
		write_table(file, "movie,line,seed_col", rows)
	end
	time()
end;

# ╔═╡ 9642c12e-2331-49c6-b03f-a0f2146bba4f
if !haskey(paper_calibration, paper_file)
	md""
else
	let
	c = paper_calibration[paper_file]
	cal = (; px_per_um=c.px_per_um, px_per_min=c.px_per_min, seed_um=seed_threshold, seed_col=paper_seed_col)
	t = kymograph_segments(paper_trace; cal...)
	mine = paper_trace != paper_reference[paper_file]
	p = plot(; xlabel="time (min)", ylabel="length from the seed (µm)", legend=:topleft, size=(640, 260), margin=4Plots.mm,
			 title="$(c.nM) nM: $(length(t.rows)) segments, $(mine ? "your tracing" : "reference tracing")", titlefontsize=9)
	if mine
		r = kymograph_segments(paper_reference[paper_file]; cal...)
		plot!(p, first.(r.points) ./ 60, last.(r.points); color="#c8cfd6", lw=3, label="reference")
	end
	isempty(t.points) || plot!(p, first.(t.points) ./ 60, last.(t.points); color="#5d6875", marker=:circle, ms=2, msw=0, label=mine ? "yours" : "reference")
	isempty(t.warnings) ? p : PlutoUI.ExperimentalLayout.vbox([p, warning_box(Markdown.parse(join(t.warnings, " ")))])
	end
end

# ╔═╡ ff7446ea-7970-49f5-9ee4-54b0d4df10f4
paper_traced = let
	paper_saved; paper_seed_saved                      # recompute after every save
	traces = read_table(joinpath(movie_dir, "traces.csv"))
	seeds = Dict(r[2] => v for r in read_table(joinpath(movie_dir, "seeds.csv")) if length(r) >= 3 && r[1] == "paper" for v in (tryparse(Int, r[3]),) if v !== nothing)
	out = Dict{String,Any}()
	for n in paper_names
		mine = [(parse(Int, t[3]), parse(Int, t[4])) for t in traces if t[1] == "paper" && t[2] == n]
		out[n] = kymograph_segments(isempty(mine) ? paper_reference[n] : mine;
									px_per_um=paper_calibration[n].px_per_um, px_per_min=paper_calibration[n].px_per_min,
									seed_um=seed_threshold, seed_col=get(seeds, n, paper_seed[n]), condition="$(paper_calibration[n].nM) nM", track=n,
									source=isempty(mine) ? "reference tracing" : "my tracing")
	end
	out
end;

# ╔═╡ 93d19f90-07ff-4254-bc87-6ffbe96a037b
if isempty(paper_names)
	md""
else
	let
	panels = map(paper_names) do n
		pts = paper_traced[n].points
		p = plot(; title=replace(n, "kymograph_" => ""), titlefontsize=9, legend=false,
				 xlabel="time (min)", ylabel="length (µm)", guidefontsize=8, tickfontsize=7)
		isempty(pts) || plot!(p, first.(pts) ./ 60, last.(pts); color="#5d6875", marker=:circle, ms=2, msw=0)
		p
	end
	plot(panels...; layout=(1, length(panels)), size=(1180, 260), margin=3Plots.mm) |> PlutoUI.WideCell(; max_width=1200)
	end
end

# ╔═╡ d348e194-e32d-4ec3-89b8-f83b715c1649
md"""
*The traces as length versus time. The second paper shows eight more kymographs (Fig. 2A, up to 5 nM), below: the yellow arrowheads of the published figure mark their rescues. Do you see the same trend?*
"""

# ╔═╡ 07b93c40-2e4a-40d9-b62b-88a1fc6387b6
let
	names = ["devcell_$(c)nM_$(s)" for c in (0, 1, 2, 5) for s in ("a", "b")]
	items = [n for n in names if isfile(joinpath(kymo_dir, n * ".png"))]
	if isempty(items)
		md""
	else
		html = map(items) do n
			data = Base64.base64encode(read(joinpath(kymo_dir, n * ".png")))
			"""<figure style="margin:0; text-align:center"><img src="data:image/png;base64,$data" style="height:300px; image-rendering:pixelated"><figcaption>$(replace(replace(n, "devcell_" => ""), "_" => " "))</figcaption></figure>"""
		end
		PlutoUI.WideCell(HTML("""<div style="display:flex; flex-wrap:wrap; gap:12px">$(join(html))</div>"""); max_width=1200)
	end
end

# ╔═╡ 609c5df1-5829-4882-8c6c-fca3f2c723d0
paper_measured = Dict(nM => reduce(vcat, [paper_traced[n].rows for n in paper_names if paper_calibration[n].nM == nM]; init=NamedTuple[])
					  for nM in (0, 1, 2));

# ╔═╡ 6705082f-5052-486c-b83d-af8a835e9d7e
paper_rates = Dict(nM => (isempty(paper_measured[nM]) ? nothing : summarize_segments(paper_measured[nM])) for nM in (0, 1, 2));

# ╔═╡ 7908a869-8dae-41de-a180-14b2d3430935
rates_table(["$nM nM kinesin-1" => [paper_traced[n] for n in paper_names if paper_calibration[n].nM == nM] for nM in (0, 1, 2)]) |> PlutoUI.WideCell(; max_width=1200)

# ╔═╡ 75b207b0-4a5c-4ad3-9ce6-ed6d4cddcada
md"""
*The papers report, with many more microtubules: growth 0.96 µm/min, shrinkage 13 µm/min and 0.30 catastrophes per min at all concentrations; about 0.5 rescue per min of shrinkage without kinesin-1, rising with it; 22 % of the shrinkages rescued at 0 nM, 61 % at 2 nM.*
"""

# ╔═╡ de17c141-b4f6-4de2-9c86-72878bc94b83
md"""
**Model A with these rates.** As in part 2, model A predicts a bounded length if ``r < 1``, with mean ``\langle L\rangle = \dfrac{v_g}{k_\text{cat}}\,\dfrac{1}{1-r}``, and growth without limit if ``r > 1``. The paper finds the transition near 2 nM kinesin-1. Simulate model A for 45 min, as in the experiment, and compare with the measured mean lengths.
"""

# ╔═╡ 92fd59d6-399f-452c-8b04-8622a1716750
let
	f(x) = isfinite(x) ? string(round(x; sigdigits=3)) : "–"
	paper_L = Dict(0 => "7.3 ± 5.1", 1 => "13.5 ± 8.1", 2 => "19 ± 11.6")
	lines = map((0, 1, 2)) do nM
		s = paper_rates[nM]
		(s === nothing || !isfinite(s.rescue) || !isfinite(s.vs) || s.catastrophe == 0) && return "| $nM nM | – | – | – | $(paper_L[nM]) |"
		d = dl_prediction(; vg=s.vg, vs=s.vs, catastrophe=s.catastrophe, rescue=s.rescue)
		"| $nM nM | $(f(d.r)) | $(d.bounded ? "bounded" : "unbounded") | $(d.bounded ? f(d.mean_length) : "grows") | $(paper_L[nM]) |"
	end
	Markdown.parse("""
	| kinesin-1 | r | regime | long-time mean length (µm) | measured after 45 min (µm) |
	|:---|---:|:---|---:|:---|
	$(join(lines, "\n"))
	""")
end

# ╔═╡ 7c2c5ddd-01b1-4c63-b746-b49e21df4ead
@bind task3 confirm(PlutoUI.combine() do Child
	md"""
	Model A runs per condition: $(Child(:runs, Slider(20:20:200; default=100, show_value=true))) — duration 45 min, starting from the seed.
	"""
end; label="Run model A")

# ╔═╡ dd6dd7f9-753c-4236-8de5-f9a520a64740
modelA = Dict(nM => begin
	s = paper_rates[nM]
	ok = s !== nothing && all(isfinite, (s.vg, s.vs, s.catastrophe, s.rescue)) && s.vg > 0 && s.vs > 0
	ok ? [simulate_switching(; vg=s.vg, vs=s.vs, catastrophe=s.catastrophe, rescue=s.rescue,
							 t_end=45 * 60, dt=0.05, initial_length=0.0, seed=1000 + i)
		  for i in 1:task3.runs] : nothing
end for nM in (0, 1, 2))

# ╔═╡ fb8448d9-728f-4ba1-a0f5-187b373daeea
modelA_figure = let
	colors = Dict(0 => "#8f9cad", 1 => "#1b9e77", 2 => "#d95f02")
	paper = Dict(0 => (7.3, 5.1), 1 => (13.5, 8.1), 2 => (19.0, 11.6))
	fig = plot(; xlabel="time (min)", ylabel="mean length (µm)", legend=:topleft, size=(1000, 380),
			   margin=4Plots.mm, title="Model A with the rates of the paper kymographs, $(task3.runs) runs per condition", titlefontsize=9)
	for nM in (0, 1, 2)
		runs = modelA[nM]
		runs === nothing && continue
		t = runs[1].t
		meanL = [mean(r.length[j] for r in runs) for j in eachindex(t)]
		plot!(fig, t[1:60:end] ./ 60, meanL[1:60:end]; color=colors[nM], lw=2, label="model A, $nM nM")
		scatter!(fig, [45], [paper[nM][1]]; yerror=[paper[nM][2]], color=colors[nM], marker=:diamond, ms=6,
				 label="measured, $nM nM (± SD)")
	end
	fig
end;

# ╔═╡ 9905da5d-0557-400a-9734-e86e6955df42
PlutoUI.WideCell(modelA_figure; max_width=1200)

# ╔═╡ 360a7486-81bc-48dc-aa62-c0b5c0872181
DownloadButton(repr(MIME("image/png"), modelA_figure), "afternoon5b_modelA.png")

# ╔═╡ 982adfe4-b7f5-40d8-89fa-ed257c9e9a92
md"""
✏️ **Part 6 notes.** Do your rates agree with the papers? Which rate changes with kinesin-1? Does model A reproduce the measured lengths? If not, look at point 5 of the summary: which lengths should model A be compared with?

...
"""

# ╔═╡ 7f3b66d7-79da-40ee-9ba6-0b64e1809b0d
md"""
# Part III — Rescue at a constant rate, or at a place on the shaft?

Model A rescues a shrinking microtubule at a constant rate, wherever its tip is. The papers propose that rescues happen at **exchange sites**, places where motors damaged the shaft and fresh GTP-tubulin was built in. This is model B.
"""

# ╔═╡ e5c403bc-f4f4-40c2-b398-b3cbb61b8691
rescue_models_schematic()

# ╔═╡ 0652e2de-f7c2-4490-8d84-e0f92f2fb3d7
md"""
Model B is not a new kind of model: it is **the chain of afternoon 3, with three changes**.

| | afternoon 3 chain | model B (the paper) |
|:---|:---|:---|
| sites | T or D | T, D, and **Tx**: GTP-tubulin put back into old lattice by exchange |
| growth and hydrolysis | T added at the plus end; each T becomes D at rate ``h`` | the same (``k_a``, ``k_\text{hyd}``); a Tx becomes D a thousand times more slowly, so Tx sites last |
| **change 1:** catastrophe | emerges when the terminal T cap is lost | imposed: a constant rate ``k_\text{cat}``, whatever the tip (the experiment cannot see the cap) |
| shrinkage | D subunits leave fast | sites leave one by one at rate ``k_d`` |
| **change 2:** rescue | the shrinking tip uncovers an internal T island | the shrinking tip reaches a Tx site, and is rescued with probability ``p_\text{res}`` |
| **change 3:** exchange | none: a D stays D | any D can become Tx at rate ``k_\times``; **the motors increase ``k_\times``** |
| units | model units | seconds and 8 nm sites, measured in the experiment |
"""

# ╔═╡ 6e84e237-96f3-4436-b71b-2c456cfde91d
md"""
### Model B with the parameters of the paper

Model B runs with the parameters of the paper (Table 1): ``k_a = 2`` s⁻¹ (8 nm per site, so 0.96 µm/min), ``k_d = 27`` s⁻¹ (13 µm/min), ``k_\text{cat} = 0.005`` s⁻¹, ``p_\text{res} = 0.15``, hydrolysis 0.125 s⁻¹. The motors are represented by the **exchange rate** ``k_\times``: without motors, the paper uses ``k_\times = 10^{-5}`` s⁻¹; motors increase it.

Measure the effective rescue rate of model B exactly as on a kymograph: rescues divided by the time spent shrinking. Which exchange rate reproduces the rescue rate of the paper kymographs at 1 nM? At 2 nM?
"""

# ╔═╡ c7c16b38-61f3-4881-86fe-fc3a1e946720
@bind task4 confirm(PlutoUI.combine() do Child
	md"""
	| | |
	|:---|:---|
	| exchange rate ``k_\times`` (per s) | $(Child(:kx, Select([0.0 => "0 (no exchange)", 0.5e-5 => "0.5 × 10⁻⁵", 1e-5 => "1 × 10⁻⁵ (paper, no motors)", 1.5e-5 => "1.5 × 10⁻⁵", 2e-5 => "2 × 10⁻⁵", 3e-5 => "3 × 10⁻⁵", 4e-5 => "4 × 10⁻⁵", 5e-5 => "5 × 10⁻⁵", 6e-5 => "6 × 10⁻⁵"]; default=1e-5))) |
	| runs | $(Child(:runs, Slider(20:20:200; default=80, show_value=true))) |
	| duration | 45 min, starting from the seed |
	"""
end; label="Run model B")

# ╔═╡ 6a41b023-0030-40b8-9713-dce878f78dbf
modelB = [simulate_res(; kx=task4.kx, t_end=45 * 60, seed=2000 + i) for i in 1:task4.runs]

# ╔═╡ e3b03b06-c92a-4747-baff-867d18fb7d69
modelB_rows = reduce(vcat, [phase_segments(r; track=i) for (i, r) in enumerate(modelB)])

# ╔═╡ 7b002f8e-5b5d-4382-bb87-974a9a0d3f40
modelB_stats = summarize_segments(modelB_rows)

# ╔═╡ f04562e5-73eb-45d7-8610-4b10bb1ce56a
modelB_kymograph = simulate_res(; kx=task4.kx, t_end=45 * 60, seed=2001, record_lattice=true)

# ╔═╡ d7174b1b-a3bb-48b7-b389-1ec78a2a5943
let
	r = modelB_kymograph
	width = max(1, maximum(length.(r.lattice)))
	image = zeros(Int, length(r.lattice), width)
	for (j, sites) in enumerate(r.lattice)
		image[j, 1:length(sites)] .= sites .+ 1          # 1 = D, 2 = T, 3 = Tx
	end
	x = (1:width) .* r.parameters.site_nm ./ 1000
	heatmap(x, r.t ./ 60, image; color=cgrad(["#ffffff", "#8f9cad", "#e6a117", "#1b9e77"]; categorical=true),
			clims=(0, 3), colorbar=false, yflip=true, xlabel="position from the seed (µm)", ylabel="time (min)",
			title="Model B, one run — gray: D, yellow: T, green: exchanged (Tx)", titlefontsize=9,
			size=(1100, 460), margin=4Plots.mm) |> PlutoUI.WideCell(; max_width=1200)
end

# ╔═╡ eeec5781-85e4-4de0-b58e-e40d40fb7bc6
let
	f(x) = round(x; sigdigits=3)
	s = modelB_stats
	lo, hi = poisson_interval(s.n_rescues)
	measured_lines = join(["| $nM nM (paper kymographs) | $(paper_rates[nM] === nothing ? "–" : f(paper_rates[nM].rescue * 60)) |" for nM in (0, 1, 2)], "\n")
	Markdown.parse("""
	| | rescues per min |
	|:---|---:|
	| **model B**, ``k_\\times`` = $(task4.kx) s⁻¹ ($(s.n_rescues) rescues in $(f(s.shrinking_time / 60)) min of shrinkage) | **$(f(s.rescue * 60))** ($(f(lo / s.shrinking_time * 60)) – $(f(hi / s.shrinking_time * 60))) |
	$measured_lines
	""")
end

# ╔═╡ c66bf5f0-3280-465f-bd97-a0ea5ce912bd
md"""
### Same averages, different microtubules?

Now give model A **exactly the effective rates of model B**: the same speeds, the same catastrophe rate, and model B's effective rescue rate. If rescue only mattered on average, the two models would be indistinguishable. Compare:

1. **the mean length** after 45 min, and **how often a shrinkage reaches the seed**;
2. **the correlation between a growth and the next shrinkage** (``C_{gs}``);
3. **where rescues happen**, as a fraction of the length at the preceding catastrophe.
"""

# ╔═╡ 4f5d6dfa-c5e3-4a64-aab0-bc70eae6a994
modelA_matched = let
	p = modelB[1].parameters
	vg = p.ka * p.site_nm / 1000; vs = p.kd * p.site_nm / 1000
	[simulate_switching(; vg, vs, catastrophe=p.kcat, rescue=modelB_stats.rescue, t_end=45 * 60,
						dt=0.05, initial_length=0.0, seed=3000 + i) for i in 1:task4.runs]
end

# ╔═╡ ca2c8560-f070-4cda-b2fa-d53dc0d55fee
modelA_rows = reduce(vcat, [simulated_segments(r; track=i) for (i, r) in enumerate(modelA_matched)])

# ╔═╡ d324be23-bb51-453c-90ad-d2266e10bbc9
comparison = let
	complete(rows) = (n = count(r -> r.end_event == "seed_restart", rows);
					  n / max(n + count(r -> r.end_event == "rescue", rows), 1))
	pa = growth_shrink_pairs(modelA_rows); pb = growth_shrink_pairs(modelB_rows)
	p = modelB[1].parameters
	dl = dl_prediction(; vg=p.ka * p.site_nm / 1000, vs=p.kd * p.site_nm / 1000,
					   catastrophe=p.kcat, rescue=modelB_stats.rescue)
	(; dl,
	   L=(A=mean(r.length[end] for r in modelA_matched), B=mean(r.length[end] for r in modelB)),
	   seed=(A=complete(modelA_rows), B=complete(modelB_rows)),
	   pairs=(A=pa, B=pb),
	   C=(A=pair_correlation(pa.growth, pa.shrink), B=pair_correlation(pb.growth, pb.shrink)),
	   rescue_at=(A=reduce(vcat, switching_rescue_fraction.(modelA_matched); init=Float64[]),
				  B=reduce(vcat, [r.rescue_fraction for r in modelB]; init=Float64[])))
end

# ╔═╡ a21a80d6-3f2f-4406-bca7-d258d17c5e15
let
	f(x) = isfinite(x) ? string(round(x; sigdigits=2)) : "–"
	c = comparison
	Markdown.parse("""
	| observable | model A (constant rate) | model B (exchange sites) | Dogterom–Leibler theory |
	|:---|---:|---:|---:|
	| mean length after 45 min (µm) | $(f(c.L.A)) | $(f(c.L.B)) | (long-time: $(c.dl.bounded ? f(c.dl.mean_length) : "grows")) |
	| fraction of shrinkages reaching the seed | $(f(c.seed.A)) | $(f(c.seed.B)) | $(f(c.dl.p_complete)) |
	| correlation ``C_{gs}`` (growth vs next shrinkage) | $(f(c.C.A)) ($(length(c.pairs.A.growth)) pairs) | $(f(c.C.B)) ($(length(c.pairs.B.growth)) pairs) | $(f(c.dl.correlation)) |

	*Both models: $(task4.runs) runs of 45 min, exchange rate ``k_\\times`` = $(task4.kx) s⁻¹ for model B, effective rescue rate $(f(modelB_stats.rescue * 60)) per min given to model A; r = $(f(c.dl.r)).*
	""")
end

# ╔═╡ 57084ebf-f9b4-4b8e-9e61-683543e9f5fd
comparison_figure = let
	c = comparison
	m = max(maximum(vcat(c.pairs.A.growth, c.pairs.B.growth, [1.0])), maximum(vcat(c.pairs.A.shrink, c.pairs.B.shrink, [1.0])))
	sA = scatter(c.pairs.A.growth, c.pairs.A.shrink; ms=2, msw=0, alpha=0.4, color="#5d6875", legend=false,
				 xlims=(0, m), ylims=(0, m), xlabel="growth length (µm)", ylabel="next shrinkage (µm)",
				 title="A: constant rate", titlefontsize=9)
	sB = scatter(c.pairs.B.growth, c.pairs.B.shrink; ms=2, msw=0, alpha=0.4, color="#1b9e77", legend=false,
				 xlims=(0, m), ylims=(0, m), xlabel="growth length (µm)", title="B: exchange sites", titlefontsize=9)
	h = histogram(c.rescue_at.A; bins=0:0.05:1, normalize=:probability, alpha=0.5, color="#5d6875", label="A",
				  xlabel="rescue position / length at catastrophe", ylabel="fraction of rescues",
				  title="Where rescues happen (0 = seed, 1 = tip)", titlefontsize=9)
	histogram!(h, c.rescue_at.B; bins=0:0.05:1, normalize=:probability, alpha=0.5, color="#1b9e77", label="B")
	plot(sA, sB, h; layout=(1, 3), size=(1180, 400), margin=5Plots.mm)
end;

# ╔═╡ a8328fbd-c907-4295-8d1e-66a28cea44d9
PlutoUI.WideCell(comparison_figure; max_width=1200)

# ╔═╡ 0c9c30f6-93f4-43cf-862c-b68a10faa214
DownloadButton(repr(MIME("image/png"), comparison_figure), "afternoon5b_comparison.png")

# ╔═╡ 0d423844-37e4-415f-bc80-3c3150575182
question_box(md"""
**Back to the movies.** In part 3, the measured ``C_{gs}`` was higher than model A predicts. Which model does that resemble? How many growth–shrinkage pairs would you need to be sure, and which other measurement on a kymograph could help (think about where rescues happen)?
""")

# ╔═╡ 78e20c15-f70c-4d1f-ae3e-d98772d98f90
md"""
✏️ **Part III notes**

* What the two models share: ...
* What differs: ...
* What I would need to measure to tell them apart: ...
"""

# ╔═╡ cc116b13-1de0-47bc-950c-44aa7b1aa66a
md"""
# Discuss

* Model A has four numbers. Which of its predictions did the movies confirm, and which not? Could the failures come from the measurement (part 1) rather than from the model?
* After a return to the seed, real microtubules wait before they grow again. Model A has no such waiting time: does it matter for the rates? For the mean length?
* Why do a few kymographs give such wide intervals? How many events would you need to measure a rescue rate to ±20 %?
* The papers measured lengths that model A cannot reproduce. Is model A wrong, or are the lengths not the same quantity?
* *(Part III)* Both models agree on the averages when model A is given the effective rescue rate. Why is that useful, and why is it also a trap?
* *(Part III)* In afternoon 3, a shrinking chain was rescued when it uncovered a T subunit left behind by hydrolysis. Where along the microtubule do such rescues happen? Which of models A and B does that resemble?

## Minimum output

* Your rates table (part 2 or 3), with the number of events.
* Model A's predictions next to the measurements (part 2 or 3), and your answer: where does model A work, where does it fail?
* One figure (part 2, 3 or 6).
* **AI log:** substantive prompt, suggestion used, check made, remaining uncertainty.
"""

# ╔═╡ c8f9dee0-176f-4e5a-b8d5-02ee395a0adc
md"""
**For afternoon 2.** All your traced kymographs (parts 1 and 4), the 46 kymographs of the movies (part 3) and the paper kymographs (part 6), as a segment table: open `02_connect_to_experiments`, choose *my own CSV file*, and redo its analysis on real data.
"""

# ╔═╡ 73f8d20a-04b1-4641-9a6a-324b318adbfd
let
	io = IOBuffer()
	println(io, "condition,track,state,duration_s,delta_length_um,end_event,source")
	groups = [["my traces: $k" => v for (k, v) in my_traced];
			  "Mireia's movies (46 kymographs)" => ready_traced;
			  ["Schaer 2023: $(paper_calibration[n].nM) nM" => [paper_traced[n]] for n in paper_names]]
	for (cond, traced) in groups, t in traced, r in t.rows
		println(io, join((replace(string(v), "," => " ") for v in
						  (cond, r.track, r.state, round(r.duration_s; digits=2), round(r.delta_length_um; digits=3), r.end_event, r.source)), ","))
	end
	DownloadButton(take!(io), "afternoon5b_segments.csv")
end

# ╔═╡ e8ee54b4-b00f-4d21-a491-c23793fae91d
let
	home = notebook_link(joinpath(@__DIR__, "..", "Notebook.pluto.jl"), "Back to the course home page")
	HTML("<hr>" * home.content)
end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
AbstractPlutoDingetjes = "6e696c72-6542-2067-7265-42206c756150"
Base64 = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
PlutoTeachingTools = "661c6b06-c737-4d37-b85c-46df65de6f69"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[compat]
AbstractPlutoDingetjes = "~1.4.1"
Plots = "~1.41.6"
PlutoTeachingTools = "~0.5.0"
PlutoUI = "~0.7.83"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.13.3"
manifest_format = "2.1"
project_hash = "65ee0c38fc2d65accdaa5d721b88ccd1e39dee1d"

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
git-tree-sha1 = "af523e59de94de05b9b367a2ca4d63233aacd222"
registries = "General"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.12.5"
weakdeps = ["StyledStrings"]

    [deps.ColorTypes.extensions]
    StyledStringsExt = "StyledStrings"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "Requires", "Statistics", "TensorCore"]
git-tree-sha1 = "96fce5c80e0834e96ab6d24fb384fd945c9cb2d4"
registries = "General"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.11.2"

    [deps.ColorVectorSpace.extensions]
    SpecialFunctionsExt = "SpecialFunctions"

    [deps.ColorVectorSpace.weakdeps]
    SpecialFunctions = "276daf66-3868-5448-9aa4-cd146d93841b"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "Reexport"]
git-tree-sha1 = "0737a3e59f9d94957f5b177fa2ca40901636b85b"
registries = "General"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.13.4"

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
git-tree-sha1 = "1e697ad6f68af89cd3651bbe9b4a7b5d800adf5a"
registries = "General"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.4.0"

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
git-tree-sha1 = "eb3b85ca904a1d1647b15acc091b113b8874b648"
registries = "General"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.7.3"

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
# ╟─edb895ef-b25e-4f0b-8fce-b4f696a43897
# ╟─66cd5e7e-ad3b-485d-a8ed-c8c335ac39f3
# ╟─c0fecf3e-5199-41ce-9246-ca579dd2f252
# ╠═cd5a9620-6a79-4748-8e24-479037d97b27
# ╠═211ef6d9-d20f-4d01-9ecb-ab7cc0925fac
# ╟─0eaa9a3b-c8f6-4d7a-9f7a-6e71d3f9125d
# ╟─18b58ecf-0d11-4625-91b4-cca974fca62f
# ╟─a607940b-82f7-4f0c-a4eb-0d7c210bace4
# ╟─cd17aee4-da21-48e5-a8ce-03fb3bc5bcd8
# ╟─d651bae7-8e3f-469c-babd-be11284a87b1
# ╟─fb24eaaa-a121-4806-b2f6-4a3305e0d313
# ╟─4bbf0c5d-83b1-430a-94c4-01d080b833d7
# ╟─c529b6c7-830f-474f-81da-61c462b2cde2
# ╟─cc62299f-3552-47c8-a428-2efec54a5255
# ╟─cfa130b1-e9c2-48f4-8722-6cf4432c6eb1
# ╟─e60fb77c-a10a-4933-a04d-a55fe21a1e35
# ╟─c3e71451-a4dc-4e3e-95a4-e8045d5a8121
# ╟─fed8f352-6cbf-4485-9520-82c61287dd3a
# ╟─c7696898-d484-41c4-9b9e-d73716f19afe
# ╟─9882ca60-56eb-4afd-990e-31c836681892
# ╟─c262eab9-3acf-4bcc-9726-579dc9c95e49
# ╟─3d14008c-894b-44c4-892d-8d3c558fe495
# ╟─5b894f17-9285-42a6-a051-5c9fc39e93e5
# ╟─64722cbd-00e1-4e2b-9f83-65a621350515
# ╟─3d6287a2-b8d7-490c-bd13-e3685619d91e
# ╟─5c657633-1e7c-4a11-ab10-c3e0914786e6
# ╟─979c8539-d367-4908-8aad-7dc8814d7fee
# ╟─c0f19650-6203-4354-97c6-ed40ee0c0d42
# ╟─eee3b87c-ecba-4d26-86aa-f6891184d409
# ╟─908048b0-6aa4-4ae1-af13-d0687b1b87df
# ╟─6513f105-ad60-44b2-8867-bc7dd189baf0
# ╠═4d8bd3fe-67de-488f-b233-0d72bc22ef01
# ╟─0248ddaf-fc17-429d-9db1-bdf34f042c87
# ╟─a43fdb96-551a-4b52-8a3b-bdca9d248b40
# ╟─cbdf0875-9727-4c5d-b350-807584af396b
# ╟─18bace15-fe02-43f7-b828-1357855b2285
# ╟─06797c4e-8bdc-4f49-8134-d09c923d9f92
# ╟─ca40e0a1-1a12-496d-8acc-2fc42d95ea54
# ╟─30774495-5626-4a9c-9ff8-2a0d5f43fb2b
# ╟─c8168f17-29fd-4106-aaae-2136cda1ed7d
# ╟─b4770758-1660-411f-b5f7-c815ffda534a
# ╟─20391854-bd19-4874-9724-1926fcb66e57
# ╠═aae881a0-4022-48ec-abfc-17d8fe70e917
# ╟─56da606e-a7b1-43e7-ae7b-26dff3386883
# ╟─cd0bc73a-da5d-40ee-95ab-f65973b0b56e
# ╟─7efbd237-9f39-4914-9709-9bafc73cffde
# ╟─896eb951-473a-46bc-a404-c5ff08407b58
# ╟─188410e3-71ff-4a4f-945b-f033b84aa48a
# ╟─6c37f3a3-e546-4be7-9c21-05ce9e9dcc4b
# ╟─77730803-121d-4f89-83a2-1f1fd4604e3f
# ╟─f952d596-4b4b-4f09-a68f-00bc458dae8e
# ╟─4a4ff030-72f5-4b85-98e7-06292c6dadcd
# ╟─0d704100-65c7-4ccc-9ff9-00875828ecc2
# ╟─bec0e730-a6ab-4ee8-9094-98a63de4976e
# ╟─3fe14482-4640-4d3e-9b96-191e396735d7
# ╟─8b8df017-5118-4aeb-ae58-dfa8aa6f098f
# ╟─483adc8a-f76c-4bb5-a06a-0cddb722132c
# ╟─f7682db7-7b44-4834-be19-95d142f1086a
# ╟─f29c9c12-80c9-4b43-9047-febe6af16cb3
# ╟─cd08e6e0-d5c6-40a7-a613-e6d872463c75
# ╟─46b42a51-a407-49fb-9a63-a1d85b5e99a6
# ╠═fcb74759-7c25-4eeb-9559-b2acc40d7b12
# ╟─fe12e052-d42d-414f-acb9-a13b200a3415
# ╟─6c819691-4042-4e0a-8123-93be47945d50
# ╟─13ff71e4-2b29-4370-a76b-d6021114c40d
# ╟─42f3bedc-203b-41c9-a990-8eb1185d99bf
# ╟─eea700b3-d6aa-4c3f-9bd2-be762521a666
# ╟─c2657fe2-e2f7-4fc9-976b-91f1ed6d90d3
# ╟─7e300fce-3121-45b0-8ec3-a9bcfb251517
# ╟─d9ea88ae-603a-490a-adbe-ae345e204997
# ╟─e1fab095-657b-4ae5-9a5c-4f8922afa706
# ╟─8aaa21d4-fc15-4d5c-b8b5-caa2b3309c5c
# ╟─83381c78-db82-476a-8b59-866fe2464b40
# ╟─970fe899-da9e-4527-acc0-24e09ae466c7
# ╟─feaee9e6-015e-4ad5-ba57-f814f15fd447
# ╟─97a52e3a-d30f-48b4-ac6b-23ba7bb9731e
# ╟─96012b93-adbc-4278-8782-03902ca11da0
# ╟─952a79d9-4cc4-42cb-b483-108e36fbff4d
# ╟─d943a609-adf3-4689-8ecb-a8f7098f842c
# ╟─9642c12e-2331-49c6-b03f-a0f2146bba4f
# ╟─ff7446ea-7970-49f5-9ee4-54b0d4df10f4
# ╟─93d19f90-07ff-4254-bc87-6ffbe96a037b
# ╟─d348e194-e32d-4ec3-89b8-f83b715c1649
# ╟─07b93c40-2e4a-40d9-b62b-88a1fc6387b6
# ╟─609c5df1-5829-4882-8c6c-fca3f2c723d0
# ╟─6705082f-5052-486c-b83d-af8a835e9d7e
# ╟─7908a869-8dae-41de-a180-14b2d3430935
# ╟─75b207b0-4a5c-4ad3-9ce6-ed6d4cddcada
# ╟─de17c141-b4f6-4de2-9c86-72878bc94b83
# ╟─92fd59d6-399f-452c-8b04-8622a1716750
# ╟─7c2c5ddd-01b1-4c63-b746-b49e21df4ead
# ╟─dd6dd7f9-753c-4236-8de5-f9a520a64740
# ╟─fb8448d9-728f-4ba1-a0f5-187b373daeea
# ╟─9905da5d-0557-400a-9734-e86e6955df42
# ╟─360a7486-81bc-48dc-aa62-c0b5c0872181
# ╠═982adfe4-b7f5-40d8-89fa-ed257c9e9a92
# ╟─7f3b66d7-79da-40ee-9ba6-0b64e1809b0d
# ╟─e5c403bc-f4f4-40c2-b398-b3cbb61b8691
# ╟─0652e2de-f7c2-4490-8d84-e0f92f2fb3d7
# ╟─6e84e237-96f3-4436-b71b-2c456cfde91d
# ╟─c7c16b38-61f3-4881-86fe-fc3a1e946720
# ╟─6a41b023-0030-40b8-9713-dce878f78dbf
# ╟─e3b03b06-c92a-4747-baff-867d18fb7d69
# ╟─7b002f8e-5b5d-4382-bb87-974a9a0d3f40
# ╟─f04562e5-73eb-45d7-8610-4b10bb1ce56a
# ╟─d7174b1b-a3bb-48b7-b389-1ec78a2a5943
# ╟─eeec5781-85e4-4de0-b58e-e40d40fb7bc6
# ╟─c66bf5f0-3280-465f-bd97-a0ea5ce912bd
# ╟─4f5d6dfa-c5e3-4a64-aab0-bc70eae6a994
# ╟─ca2c8560-f070-4cda-b2fa-d53dc0d55fee
# ╟─d324be23-bb51-453c-90ad-d2266e10bbc9
# ╟─a21a80d6-3f2f-4406-bca7-d258d17c5e15
# ╟─57084ebf-f9b4-4b8e-9e61-683543e9f5fd
# ╟─a8328fbd-c907-4295-8d1e-66a28cea44d9
# ╟─0c9c30f6-93f4-43cf-862c-b68a10faa214
# ╟─0d423844-37e4-415f-bc80-3c3150575182
# ╠═78e20c15-f70c-4d1f-ae3e-d98772d98f90
# ╟─cc116b13-1de0-47bc-950c-44aa7b1aa66a
# ╟─c8f9dee0-176f-4e5a-b8d5-02ee395a0adc
# ╟─73f8d20a-04b1-4641-9a6a-324b318adbfd
# ╟─e8ee54b4-b00f-4d21-a491-c23793fae91d
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
