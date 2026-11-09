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
