# From microtubule experiments to stochastic models

Computational practical of the 3rd-year Biochemistry Bachelor, University of Geneva.

Last week you watched microtubules grow and shrink under the microscope. This week you will ask how much of that behavior a simple computer model can explain. The course runs over five afternoons, in pairs, in interactive [Pluto](https://plutojl.org/) notebooks. **No previous Julia or programming knowledge is needed:** you move sliders, press buttons, write predictions and interpret figures.

| Afternoon | Question | Notebook |
|:---:|:---|:---|
| 1 | Can measured speeds and random switching produce plausible trajectories? | `00_start_here`, then `01_randomness_and_switching` |
| 2 | How well does this description summarize the experimental data? | `02_connect_to_experiments` |
| 3 | Can switching emerge from subunit chemistry? | `03_subunits_and_hydrolysis` |
| 4 | Can nearly constant length coexist with material flow? | `04_two_ends_and_treadmilling` |
| 5 | What question can we answer with one controlled comparison? | `05_your_investigation` |

All notebooks are reachable from the course home page, `Notebook.pluto.jl`.

---

## 1. Install Julia (once)

Julia is installed with **juliaup**, the official installer. It takes a few minutes.

**macOS or Linux** — open the *Terminal* app and paste:

```sh
curl -fsSL https://install.julialang.org | sh
```

Answer the questions with the default choice (press Enter), then **close and reopen the terminal**.

If `julia` is then not found, add it to your PATH yourself (on Linux, replace `~/.zshrc` by `~/.bashrc`), and reopen the terminal:

```sh
echo 'export PATH="$HOME/.juliaup/bin:$PATH"' >> ~/.zshrc
```

**Windows** — open *PowerShell* and paste:

```powershell
winget install --name Julia --id 9NJNWW8PVKMN -e -s msstore
```

(Or install "Julia" from the Microsoft Store.) Then **close and reopen PowerShell**.

**Check:** type `julia` in the terminal and press Enter. You should see the Julia logo and a `julia>` prompt. Type `exit()` to leave.

## 2. Install Pluto (once)

Start Julia (`julia` in the terminal), then paste at the `julia>` prompt:

```julia
import Pkg; Pkg.add("Pluto")
```

This takes a minute or two. Leave Julia with `exit()`.

## 3. Download the course

On this GitHub page, click the green **Code** button, then **Download ZIP**. Unzip it somewhere easy to find, for example in your *Documents* folder.

Keep the whole folder together: the notebooks load the course code from `src/` and the data from `data/`.

*(If you know git, you can instead run `git clone` with the address shown under **Code**.)*

## 4. Open the course

1. Open a terminal **in the course folder**:
   * macOS: in Finder, right-click the folder → *New Terminal at Folder* (or type `cd ` in the terminal, drag the folder onto the window, press Enter).
   * Windows: open the folder in the File Explorer, click the address bar, type `powershell` and press Enter.
2. Start Julia by typing `julia`, then paste:

   ```julia
   import Pluto; Pluto.run(notebook="Notebook.pluto.jl")
   ```

3. Your browser opens the course home page. Each afternoon has a link to its notebook.

To open one afternoon directly, give its path instead, for example:

```julia
import Pluto; Pluto.run(notebook="notebooks/03_subunits_and_hydrolysis.pluto.jl")
```

To stop Pluto, go back to the terminal and press `Ctrl+C`.

> **The first time you open a notebook takes a few minutes.** Pluto downloads and prepares the plotting packages, at the exact versions recorded in the notebook. This needs an internet connection and happens only once: afterwards, notebooks open in about 15 seconds and work offline. If possible, open `Notebook.pluto.jl` and the course guide at home before the first afternoon.

## 5. Working in the notebooks

* **Sliders and menus** change the inputs. Panels with a **Run** button only recompute when you press it; **↺** returns a panel to its starting values.
* **Shift+Enter** runs a cell after you edit it. Every cell that depends on it updates automatically.
* Cells starting with ✏️ are **your notes**: write your predictions and answers there. They are saved in the notebook file and help you write the report.
* **Pluto saves the notebook file each time you run a cell.** Your work stays in your copy of the folder. To start a notebook again from scratch, download it again from this page.
* Figures have a **download button** below them, for your report.

The notebook `00_start_here` explains Pluto in more detail, with a short bridge from MATLAB to Julia, the background, the rules for using AI tools, and the report rubric.

## 6. If something does not work

| Problem | What to do |
|:---|:---|
| `julia` is not recognized | Close and reopen the terminal after installing. On macOS/Linux, add Julia to your PATH (section 1). On Windows, restart the computer if needed. |
| `MethodError` when starting Pluto | Write `Pluto.run(notebook="...")` with `notebook=`, not `Pluto.run("...")`. |
| `No such file` / the notebook is not found | The terminal is not in the course folder: see step 4.1, or give the full path to the notebook. |
| The first opening seems stuck | The packages are being prepared: wait a few minutes, with an internet connection. The progress is shown in the terminal. |
| A cell shows an error after you edited it | Read the last line of the message. Undo your change, or ask the instructor. Do not spend more than five minutes on it. |
| The browser did not open | Copy the address printed in the terminal (starting with `http://localhost:1234/`) into your browser. |

---

## For the teaching team

Folder contents:

* `Notebook.pluto.jl` — course home page.
* `notebooks/` — course guide (`00`) and the five afternoons (`01`–`05`); the student manual is merged into them.
* `src/MTLab.jl` — the two teaching models (effective switching model; exact Gillespie T/D chain) and the analysis helpers. Plain Julia, standard library only.
* `src/Schematics.jl` — SVG schematics; `src/Widgets.jl` — the ◀ previous / next ▶ stepper; `src/Experiment.jl` — the experiment designer of afternoon 5.
* `data/` — the synthetic fallback segment table (clearly labeled, not experimental) and the empty template for students' own kymograph measurements.
* `figures/` — Figure 1 of the original manual.
* `test/` — test suite.

**Modeling conventions.** The switching model measures extension in µm and time in seconds; switching uses probabilities `k·dt`; a restart at zero extension is not a rescue. The chain model uses exact Gillespie events, lengths in subunits and model time units; its sampling interval is an observation interval, not an integration step. All rate sets are teaching examples, not fits to experiments. Random sequences use `Xoshiro(seed)`: a seed reproduces a run on a given Julia version.

**Tests.** From this folder:

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate()'   # first time only
julia --project=. test/runtests.jl unit               # models, analysis, schematics (~5 s)
julia --project=. test/runtests.jl e2e                # runs every notebook headlessly (~2.5 min)
```

The unit tests check deterministic limits, exact length/end-count bookkeeping, seeded regrowth and absorbing extinction, Poisson addition and exponential hydrolysis statistics, the Dogterom–Leibler mean length, the treadmilling fluxes and synthetic-data estimates of the instructor guide, and the predictable controls of afternoon 5. The end-to-end tests open every notebook (and afternoon 5 from each starting point with a written prediction) and fail on any cell error or failed text interpolation.

**Editing notebooks.** Close a notebook in Pluto before editing its file with another tool: Pluto rewrites the file when it saves.

Tested with Julia 1.13 and Pluto 1.0.4.

## Licence

[MIT](LICENSE) © 2026 Ludovic Dumoulin.
