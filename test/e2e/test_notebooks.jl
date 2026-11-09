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
