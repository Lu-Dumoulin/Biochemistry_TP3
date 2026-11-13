### A Pluto.jl notebook ###
# v1.0.4

using Markdown
using InteractiveUtils

# ╔═╡ e8b7dd8b-9349-4ad9-9556-f0eeafc33b20
using PlutoUI, PlutoTeachingTools

# ╔═╡ a538286d-85fb-4992-a41a-0cf7ff710e3c
begin
	include(joinpath(@__DIR__, "src", "Schematics.jl"))
	using .Schematics: course_map_schematic, levels_schematic, notebook_link
end

# ╔═╡ 67f86546-925a-424c-b111-3c5e8e56ee0a
TableOfContents()

# ╔═╡ 0f0270f6-96d2-4224-bcf1-f7a6a5dad9a2
WideCell(md"""
# From microtubule experiments to stochastic models

**Biochemistry practical course for 3rd-year Bachelor students — University of Geneva — November 2026**

Last week you observed microtubules grow and shrink. This week you will ask how much of that behavior can be understood with a simplified computer model. You will first describe growth and shrinkage through measured speeds and switching frequencies. You will then replace those prescribed switches by the addition, loss and chemical aging of individual subunits. Finally, you will allow both ends to exchange subunits and investigate how a filament can maintain approximately the same length while its material turns over.

The goal is to learn how to **formulate, simulate and question a model**. This is not a programming course: no previous Julia or Gillespie-algorithm knowledge is assumed, and code length earns no credit. A carefully interpreted negative result can be excellent work.

This page is the entry point of the course. Each section below summarizes one afternoon and links to its notebook.
""")

# ╔═╡ 04fd0cef-7ad8-4362-8343-78a9cfbf4045
WideCell(md"""
## 0. Course overview

Five afternoons of about 3.5 hours, in pairs; one short individual report at the end. Each afternoon asks one question and uses one level of description. The model becomes more detailed from afternoon 1 to 4; on afternoon 5 you choose.

$(course_map_schematic())

The two models describe the same filament with different detail. The *switching model* keeps only the length and a growing/shrinking label; the *T/D chain* keeps individual GTP-like (T) and GDP-like (D) subunits. Neither simulates the thirteen protofilaments of a real microtubule.

$(levels_schematic())
""")

# ╔═╡ df81a72d-d43b-4956-aafa-766237a57dec
WideCell(md"""
## Start here: course guide

How Pluto works, a short bridge from MATLAB to Julia, the biological background, the permitted use of AI, and the analysis habits and rubric used for the report. Read it on afternoon 1 (at most 25 minutes), and come back to its last sections when you write your report.
""")

# ╔═╡ dc77bb30-b045-48b4-9a9a-f8706eb1d943
notebook_link(joinpath(@__DIR__, "notebooks", "00_start_here.pluto.jl"), "Open the course guide (notebook 00)")

# ╔═╡ 082da703-5260-4369-8b17-97d4d63205f9
WideCell(md"""
## Afternoon 1 — Randomness and the growing/shrinking model

**Question:** can measured growth and shortening speeds, plus random switching, produce plausible microtubule trajectories?

A kymograph is reduced to four inputs: growth speed ``v_g``, shrinkage speed ``v_s``, catastrophe rate ``k_c`` and rescue rate ``k_r``. You see how a computer makes a random decision with probability ``k\,\Delta t``, simulate several filaments with identical inputs, change one input, and check a deterministic limit.

* **Key ideas:** a rate (per second) is not a probability; identical parameters do not give identical trajectories; a random seed is not a microtubule seed; a restart at the seed is not a rescue.
* **Minimum output:** one overlay of trajectories, and a short explanation of what each input means, what randomness changes, and what is missing from this model.
""")

# ╔═╡ 800b7f91-745c-448c-b372-a551687720e1
notebook_link(joinpath(@__DIR__, "notebooks", "01_randomness_and_switching.pluto.jl"), "Open afternoon 1 (notebook 01)")

# ╔═╡ 01312d44-d757-4052-961f-0742e58fb065
WideCell(md"""
## Afternoon 2 — Connect simulations to experiments

**Question:** how well does the four-input description summarize last week's measurements?

You enter growth and shrinkage segments from last week's kymographs (about 30 minutes at most), or use the clearly labeled synthetic fallback dataset. You estimate speeds and switching frequencies, with uncertainty from resampling whole tracks, then compare experiment and simulation on the same observables. Two controls: a smaller numerical time step, and the 3-second sampling of the microscope.

* **Key ideas:** a frequency is a number of events divided by the time *at risk* (growing time for catastrophes, shrinking time for rescues); zero observed rescues does not mean ``k_r = 0``; a parameter change that mimics a drug does not identify its molecular mechanism.
* **Bring:** your segment measurements from last week (Fiji), if available.
* **Minimum output:** a parameter summary, a comparison figure, and one thing the effective model can and cannot tell you.
""")

# ╔═╡ 35f2ef3a-bed8-4220-8abb-bcb19510df91
notebook_link(joinpath(@__DIR__, "notebooks", "02_connect_to_experiments.pluto.jl"), "Afternoon 2 (notebook 02)")

# ╔═╡ fac2eb03-f029-4aa5-9702-4808adadd4aa
WideCell(md"""
## Afternoon 3 — Addition, loss and hydrolysis

**Question:** can switching between growth and collapse *emerge* from subunit chemistry, without an imposed catastrophe rate?

The filament becomes an ordered chain of T and D subunits on a protected seed. T subunits add at the plus end, the terminal subunit detaches at a rate that depends on whether it is T or D, and each T hydrolyzes to D at random. An exact event-by-event (Gillespie) simulation, supplied and explained, produces growth and collapse episodes. You compare hydrolysis rates and run a no-hydrolysis control.

* **Key ideas:** emergent versus imposed switching; the terminal T cap is not the total number of T; a momentary cap loss is not necessarily a catastrophe; lengths are in subunits and times in model units.
* **Minimum output:** a length/cap figure, a controlled comparison, and the new question made accessible by keeping subunit chemistry.
""")

# ╔═╡ 8dfe2e4c-7c7d-482f-a5eb-8b4c94d14786
notebook_link(joinpath(@__DIR__, "notebooks", "03_subunits_and_hydrolysis.pluto.jl"), "Afternoon 3 (notebook 03)")

# ╔═╡ 44367414-77e8-4e2e-adda-a192fb8f100b
WideCell(md"""
## Afternoon 4 — Two dynamic ends and treadmilling

**Question:** can a nearly constant length coexist with a continuous flow of material through the filament?

The seed is removed: both ends add and lose subunits with their own rates, and a fragment that disappears stays gone. You measure the signed fluxes at each end, follow a virtual pulse label of subunits incorporated during a short window, and compare with a control whose minus end is protected.

* **Key ideas:** length and material turnover are different observables; the change of length equals net plus-end additions plus net minus-end additions; constant length alone does not prove treadmilling (a frozen filament also has constant length); include extinct fragments in averages.
* **Minimum output:** evidence for end-specific material flow, its relation to length, and the protected-end control.
""")

# ╔═╡ 296f3952-c3c1-44d4-943d-c7c2a1a194fa
notebook_link(joinpath(@__DIR__, "notebooks", "04_two_ends_and_treadmilling.pluto.jl"), "Afternoon 4 (notebook 04)")

# ╔═╡ acad59ec-e4f4-4e46-8ac7-8640d7fc4fc2
WideCell(md"""
## Afternoon 5 — Your small investigation

**Question:** what can you answer with **one** controlled comparison?

In pairs, choose one question and discuss its feasibility with the instructor within the first 20 minutes. Examples: does hydrolysis affect the frequency of substantial collapses? Can similar mean lengths hide very different turnover? Does the initial fragment length affect survival? How does the observation interval change the apparent duration of growth episodes?

Write a prediction before running. State the one input you change, the inputs you hold fixed, the observable and its window, the number of independent runs, and a control with a predictable outcome. The afternoon ends with short presentations.

* **Minimum output:** two or three figures that answer your question, a short explanation of their uncertainty, and one limitation or alternative interpretation.
""")

# ╔═╡ 0edd324f-4721-4462-9f51-50bd01f99929
notebook_link(joinpath(@__DIR__, "notebooks", "05_your_investigation.pluto.jl"), "Afternoon 5 (notebook 05)")

# ╔═╡ 0f37b6ff-af2a-46f6-b7bc-579c8e690677
WideCell(md"""
### Afternoon 5b — Real microtubules: from a movie to a model

Build kymographs from microscope movies of Mireia Andreu-Carbó (University of Geneva), measure the rates as in afternoon 2, and test model A on real microtubules: first with a few kymographs traced by hand, then with 46. Then compare with two papers of the University of Geneva on the motor kinesin-1, and, optionally, with their model of rescue at exchange sites along the shaft.
""")

# ╔═╡ ac8949ee-d8d6-48e9-9532-6f31d5dd28b9
notebook_link(joinpath(@__DIR__, "notebooks", "05b_rescue_rate_or_place.pluto.jl"), "Afternoon 5b (notebook 05b)")

# ╔═╡ 2a168fea-2bc7-4575-adc4-9eade3d9c3e1
WideCell(md"""
## Report

Submit an individual report of about 3–4 pages (English or French), the notebook that generates its main figures, and a brief AI-use log. Explain the purpose, model assumptions, main comparison, results and interpretation; do not copy the protocol or every line of code. The analysis habits and the rubric are in section 4 of the course guide.

| Criterion | Weight |
|:---|---:|
| Question, prediction and choice of simplified model | 25 % |
| Depth of analysis, controls and uncertainty | 35 % |
| Interpretation, limits and connection to experiments | 25 % |
| Clear figures, reproducibility and transparent AI use | 15 % |
""")

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
PlutoTeachingTools = "661c6b06-c737-4d37-b85c-46df65de6f69"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"

[compat]
PlutoTeachingTools = "~0.5.0"
PlutoUI = "~0.7.83"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.13.3"
manifest_format = "2.1"
project_hash = "fa0b80b9ef5d4fb168114e8c54f0e4effdb3184e"

[[deps.AbstractPlutoDingetjes]]
git-tree-sha1 = "e71ee7b4aa06b045259a7d6101e1cb45ad140bce"
registries = "General"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.4.1"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"
version = "1.11.0"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "a7cf827a79b378a381e31e5c7feca853ec19cb94"
registries = "General"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.12.4"
weakdeps = ["StyledStrings"]

    [deps.ColorTypes.extensions]
    StyledStringsExt = "StyledStrings"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.5.5+2"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"
version = "1.11.0"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.7.0"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"
version = "1.11.0"

[[deps.FixedPointNumbers]]
deps = ["Random", "Statistics"]
git-tree-sha1 = "59af96b98217c6ef4ae0dfe065ac7c20831d1a84"
registries = "General"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.6"

[[deps.Format]]
git-tree-sha1 = "9c68794ef81b08086aeb32eeaf33531668d5f5fc"
registries = "General"
uuid = "1fa38f19-a742-5d3f-a2b9-30dd87b9d5f8"
version = "1.3.7"

[[deps.Ghostscript_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Zlib_jll"]
git-tree-sha1 = "38044a04637976140074d0b0621c1edf0eb531fd"
registries = "General"
uuid = "61579ee1-b43e-5ca0-a5da-69d92c66a64b"
version = "9.55.1+0"

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

[[deps.JLLWrappers]]
deps = ["Artifacts", "Preferences"]
git-tree-sha1 = "7204148362dafe5fe6a273f855b8ccbe4df8173e"
registries = "General"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.8.0"

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

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl", "OpenSSL_jll", "Zlib_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.104+0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"
version = "1.11.0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.13.0"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"
version = "1.11.0"

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

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2026.10.20"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.3.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.30+0"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.5.8+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "b079a6affebde167dad8ffe0d670b53917fbcb68"
registries = "General"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "2.0.3"

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

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
version = "1.11.0"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
registries = "General"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "62389eeff14780bfe55195b7204c0d8738436d64"
registries = "General"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.1"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "1.0.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
version = "1.11.0"

[[deps.Statistics]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "e2b53ce13a53367e96601081e33d34746b571bad"
registries = "General"
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.11.5"

    [deps.Statistics.extensions]
    SparseArraysExt = ["SparseArrays"]

    [deps.Statistics.weakdeps]
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.StyledStrings]]
uuid = "f489334b-da3d-4c2e-b8f0-e476e12c162b"
version = "1.11.0"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
version = "1.11.0"

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

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.3.2+0"

[[deps.Zstd_jll]]
deps = ["CompilerSupportLibraries_jll", "Libdl"]
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.7+1"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.15.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.70.0+0"

[registries.General]
url = "https://github.com/JuliaRegistries/General.git"
uuid = "23338594-aafe-5451-b93e-139f81909106"
"""

# ╔═╡ Cell order:
# ╟─e8b7dd8b-9349-4ad9-9556-f0eeafc33b20
# ╟─67f86546-925a-424c-b111-3c5e8e56ee0a
# ╟─a538286d-85fb-4992-a41a-0cf7ff710e3c
# ╟─0f0270f6-96d2-4224-bcf1-f7a6a5dad9a2
# ╟─04fd0cef-7ad8-4362-8343-78a9cfbf4045
# ╟─df81a72d-d43b-4956-aafa-766237a57dec
# ╟─dc77bb30-b045-48b4-9a9a-f8706eb1d943
# ╟─082da703-5260-4369-8b17-97d4d63205f9
# ╟─800b7f91-745c-448c-b372-a551687720e1
# ╟─01312d44-d757-4052-961f-0742e58fb065
# ╟─35f2ef3a-bed8-4220-8abb-bcb19510df91
# ╟─fac2eb03-f029-4aa5-9702-4808adadd4aa
# ╟─8dfe2e4c-7c7d-482f-a5eb-8b4c94d14786
# ╟─44367414-77e8-4e2e-adda-a192fb8f100b
# ╟─296f3952-c3c1-44d4-943d-c7c2a1a194fa
# ╟─acad59ec-e4f4-4e46-8ac7-8640d7fc4fc2
# ╟─0edd324f-4721-4462-9f51-50bd01f99929
# ╟─0f37b6ff-af2a-46f6-b7bc-579c8e690677
# ╟─ac8949ee-d8d6-48e9-9532-6f31d5dd28b9
# ╟─2a168fea-2bc7-4575-adc4-9eade3d9c3e1
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
