using Test, Pluto

# Opens every notebook in a headless Pluto session and runs all cells with their
# default slider values. Files are not rewritten.
@testset "Notebooks run without errors" begin
    session = Pluto.ServerSession()
    session.options.server.disable_writing_notebook_files = true
    root = joinpath(@__DIR__, "..", "..")
    notebooks = [joinpath(root, "Notebook.pluto.jl");
                 filter(endswith(".pluto.jl"), readdir(joinpath(root, "notebooks"); join=true))]

    for path in notebooks
        @testset "$(basename(path)) runs every cell" begin
            # Arrange
            nb = Pluto.SessionActions.open(session, path; run_async=false)

            # Act
            errored = [first(c.code, 80) for c in nb.cells if c.errored]
            # A failed md interpolation does not error: the literal `$(` stays in the
            # output, where Pluto reads `$...$` as LaTeX. Bold around interpolated values
            # triggers it; use Markdown.parse("... $(x) ...") for such sentences.
            uninterpolated = [first(c.code, 80) for c in nb.cells
                              if c.output.body isa AbstractString &&
                                 occursin(r"(\$|&#36;)&#40;", c.output.body)]
            Pluto.SessionActions.shutdown(session, nb; keep_in_session=false)

            # Assert
            @test isempty(errored)
            @test isempty(uninterpolated)
        end
    end
end

# Notebook 05 hides its results until a question and a prediction are written, so the
# default run above only checks the locked state. Here, filled-in copies exercise every
# starting point, an extra condition and a robustness check.
@testset "Notebook 05 runs every example once a prediction is written" begin
    session = Pluto.ServerSession()
    session.options.server.disable_writing_notebook_files = true
    notebooks_dir = joinpath(@__DIR__, "..", "..", "notebooks")
    source = read(joinpath(notebooks_dir, "05_your_investigation.pluto.jl"), String)
    replacements = [
        "My question is ...\n" => "Does this input change the observable of the filaments?\n",
        "When the input goes from A to B, I expect the observable to ... because ...\n" =>
            "I expect the observable to change when the input changes, because the rates differ.\n",
        "Child(:C, Select(values; default=nothing))" => "Child(:C, Select(values; default=last(varied.grid)))",
        "default=:none);" => "default=:more_runs);",
    ]
    for (from, _) in replacements
        @test occursin(from, source)
    end
    filled = replace(source, replacements...)

    for example in 0:5
        @testset "starting point $example runs every cell" begin
            # Arrange
            path = joinpath(notebooks_dir, "_e2e_filled_05_$example.pluto.jl")
            write(path, replace(filled, "default=0))" => "default=$example))"))

            # Act
            errored, uninterpolated, locked = try
                nb = Pluto.SessionActions.open(session, path; run_async=false)
                outputs = [c.output.body for c in nb.cells if c.output.body isa AbstractString]
                result = ([first(c.code, 80) for c in nb.cells if c.errored],
                          count(b -> occursin(r"(\$|&#36;)&#40;", b), outputs),
                          count(b -> occursin("🔒", b), outputs))
                Pluto.SessionActions.shutdown(session, nb; keep_in_session=false)
                result
            finally
                rm(path; force=true)
            end

            # Assert
            @test isempty(errored)
            @test uninterpolated == 0
            @test locked == 0
        end
    end
end

# Part I of 05b reads and writes `data/movies/`. This test runs it in a temporary copy of the
# course folder, with a synthetic movie and a saved trace, and a ready-made kymograph with an
# automatic tracing, so that the movie tools, the rates tables and model A all run on them.
@testset "Notebook 05b turns a saved movie trace into rates" begin
    include(joinpath(@__DIR__, "..", "support", "load.jl"))
    # Arrange
    root = joinpath(@__DIR__, "..", "..")
    tmp = mktempdir()
    cp(joinpath(root, "src"), joinpath(tmp, "src"))
    mkpath(joinpath(tmp, "notebooks"))
    cp(joinpath(root, "notebooks", "05b_rescue_rate_or_place.pluto.jl"), joinpath(tmp, "notebooks", "05b.pluto.jl"))
    cp(joinpath(root, "Notebook.pluto.jl"), joinpath(tmp, "Notebook.pluto.jl"))
    movies = mkpath(joinpath(tmp, "data", "movies"))
    write_test_tiff(joinpath(movies, "test_movie.tif"), growing_microtubule(; frames=40, width=80))
    key = line_key("test_movie.tif", (15, 10, 15, 70))
    write_table(joinpath(movies, "settings.csv"), "movie,channel,um_per_px,s_per_frame,condition,include",
                [["test_movie.tif", 1, 0.1, 2.0, "growing", true]])
    write_table(joinpath(movies, "lines.csv"), "movie,row1,col1,row2,col2", [["test_movie.tif", 15, 10, 15, 70]])
    write_table(joinpath(movies, "traces.csv"), "movie,line,row,col",
                [["test_movie.tif", key, r, c] for (r, c) in [(1, 10), (25, 35), (27, 10), (40, 23)]])
    # a ready-made kymograph with only an automatic (reference) tracing, used for the rates
    ready = mkpath(joinpath(tmp, "data", "kymographs_movies"))
    write(joinpath(ready, "k1.png"), png_bytes(gray8(Float32[t <= 20 + c ? 1 : 0 for t in 1:40, c in 1:30])))
    write_table(joinpath(ready, "kymographs.csv"), "file,movie,line,row1,col1,row2,col2,um_per_px,s_per_frame,condition,seed_col",
                [["k1.png", "movie Z", 1, 1, 1, 1, 30, 0.1, 3.0, "ready", 1]])
    write_table(joinpath(ready, "reference_traces.csv"), "file,row,col",
                [["k1.png", r, c] for (r, c) in [(1, 1), (20, 20), (22, 1), (40, 10)]])
    session = Pluto.ServerSession()
    session.options.server.disable_writing_notebook_files = true

    # Act
    nb = Pluto.SessionActions.open(session, joinpath(tmp, "notebooks", "05b.pluto.jl"); run_async=false)
    errored = [first(c.code, 80) for c in nb.cells if c.errored]
    outputs = [string(c.output.body) for c in nb.cells]          # wide cells hold their HTML inside
    Pluto.SessionActions.shutdown(session, nb; keep_in_session=false)

    # Assert: one kymograph, one catastrophe, in the rates table; the saved line was kept.
    @test isempty(errored)
    @test any(b -> occursin("growing", b) && occursin("shrinkage speed", b), outputs)
    @test any(b -> occursin("the movies, 1 kymographs", b) && occursin("shrinkage speed", b), outputs)
    @test read_table(joinpath(movies, "lines.csv")) == [["test_movie.tif", "15", "10", "15", "70"]]
    rm(tmp; recursive=true)
end
