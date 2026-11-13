using Test
import AbstractPlutoDingetjes
include(joinpath(@__DIR__, "..", "support", "load.jl"))

const Bonds = AbstractPlutoDingetjes.Bonds

@testset "Widgets" begin

@testset "a stepper starts at its default, also without a browser" begin
    # Arrange
    s = Stepper(0:40; default=3)

    # Act
    value = Bonds.initial_value(s)

    # Assert
    @test value == 3
end

@testset "a stepper refuses a default outside its range" begin
    # Arrange
    values = 0:40

    # Act & Assert
    @test_throws ArgumentError Stepper(values; default=41)
end

@testset "a stepper only accepts integers within its range" begin
    # Arrange
    s = Stepper(0:40)

    # Act & Assert
    @test Bonds.validate_value(s, 12)
    @test !Bonds.validate_value(s, 41)
    @test !Bonds.validate_value(s, 2.5)
    @test Bonds.transform_value(s, 7.0) === 7
end

@testset "a stepper draws previous and next buttons around a slider" begin
    # Arrange
    s = Stepper(0:40; default=5)

    # Act
    html = repr(MIME("text/html"), s)

    # Assert
    @test occursin("◀ previous", html) && occursin("next ▶", html)
    @test occursin("""type="range" min="0" max="40" step="1" value="5\"""", html)
end

end

@testset "Kymograph tracer" begin

@testset "png_size reads the width and height from the header" begin
    # Arrange: a 1×1 PNG.
    png = UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0x0d, 0x49, 0x48, 0x44, 0x52,
                0, 0, 0, 3, 0, 0, 0, 7, 8, 0, 0, 0, 0]

    # Act
    s = png_size(png)

    # Assert
    @test s == (width=3, height=7)
end

@testset "the tracer starts from its given corners, also without a browser" begin
    # Arrange
    png = UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0x0d, 0x49, 0x48, 0x44, 0x52,
                0, 0, 0, 3, 0, 0, 0, 7, 8, 0, 0, 0, 0]
    t = KymoTracer(png; corners=[(1, 2), (5, 3)])

    # Act
    v = Bonds.initial_value(t)
    html = repr(MIME("text/html"), t)

    # Assert
    @test v == [(1, 2), (5, 3)]
    @test occursin("Undo last corner", html) && occursin("[[1,2],[5,3]]", html)
end

@testset "in pairs mode, the tracer draws separate lines" begin
    # Arrange
    png = UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0x0d, 0x49, 0x48, 0x44, 0x52,
                0, 0, 0, 3, 0, 0, 0, 7, 8, 0, 0, 0, 0]

    # Act
    html = repr(MIME("text/html"), KymoTracer(png; pairs=true, corners=[(1, 1), (2, 3)]))

    # Assert
    @test occursin("const pairs = true", html) && occursin("Undo last click", html)
end

@testset "the tracer can draw the end of the seed" begin
    png = UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0x0d, 0x49, 0x48, 0x44, 0x52,
                0, 0, 0, 3, 0, 0, 0, 7, 8, 0, 0, 0, 0]
    @test occursin("const seed = 2", repr(MIME("text/html"), KymoTracer(png; seed=2)))
    @test occursin("const seed = 0", repr(MIME("text/html"), KymoTracer(png)))
end

@testset "with a seed, the tracer gives corners and the set seed" begin
    png = UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0x0d, 0x49, 0x48, 0x44, 0x52,
                0, 0, 0, 3, 0, 0, 0, 7, 8, 0, 0, 0, 0]
    t = KymoTracer(png; corners=[(1, 2)], seed=2)

    # Act & Assert
    @test Bonds.initial_value(t) == (corners=[(1, 2)], seed=2)
    @test Bonds.transform_value(t, Dict("corners" => Any[Any[3, 4.0]], "seed" => 3)) == (corners=[(3, 4)], seed=3)
    @test Bonds.validate_value(t, Dict("corners" => Any[], "seed" => 1))
    @test occursin("Set seed", repr(MIME("text/html"), t))
end

@testset "clicked corners arrive as integer (row, col) pairs" begin
    # Arrange
    png = UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0x0d, 0x49, 0x48, 0x44, 0x52,
                0, 0, 0, 3, 0, 0, 0, 7, 8, 0, 0, 0, 0]
    t = KymoTracer(png)

    # Act & Assert
    @test Bonds.transform_value(t, Any[Any[3, 4.0], Any[10, 2]]) == [(3, 4), (10, 2)]
    @test Bonds.transform_value(t, nothing) == Tuple{Int,Int}[]
    @test Bonds.validate_value(t, Any[Any[3, 4]])
end

end
