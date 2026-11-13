using Test, Statistics
include(joinpath(@__DIR__, "..", "support", "load.jl"))

@testset "Afternoon 5b: movies and kymographs" begin

@testset "an ImageJ stack is read with its frames, channels and calibration" begin
    for big_endian in (false, true)
        # Arrange: two channels, the second one dimmer; 3 frames
        stack = zeros(UInt16, 4, 5, 6)
        for k in 1:6
            stack[:, :, k] .= UInt16(10k)
            stack[2, 3, k] = UInt16(1000 + k)
        end
        path = write_test_tiff(tempname() * ".tif", stack; channels=2, um_per_px=0.11, s_per_frame=3.0, big_endian)

        # Act
        m = read_movie(path)

        # Assert
        @test size(m.data) == (4, 5, 2, 3)
        @test m.data[2, 3, 1, 1] == 1001 && m.data[2, 3, 2, 1] == 1002 && m.data[2, 3, 1, 3] == 1005
        @test m.data[1, 1, 2, 3] == 60
        @test m.um_per_px ≈ 0.11 atol = 1e-6
        @test m.s_per_frame ≈ 3.0
        @test isempty(m.notes)
        rm(path)
    end
end

@testset "8-bit stacks are read too" begin
    # Arrange
    stack = rand(UInt8, 3, 4, 2)
    path = write_test_tiff(tempname() * ".tif", stack)

    # Act
    m = read_movie(path)

    # Assert
    @test m.data[:, :, 1, :] == stack
    rm(path)
end

@testset "a file that is not a TIFF gives a clear message" begin
    # Arrange
    path = tempname() * ".tif"; write(path, "hello, world")

    # Act & Assert
    @test_throws ArgumentError read_movie(path)
    rm(path)
end

@testset "the kymograph of a growing microtubule shows the tip advancing one pixel per frame" begin
    # Arrange
    path = write_test_tiff(tempname() * ".tif", growing_microtubule())
    m = read_movie(path)

    # Act: a line along the microtubule, from the seed to past the tip
    k = kymograph(m, 1, (15, 10, 15, 50); width=1)

    # Assert: column 1 is pixel col 10, so the tip (last bright column) of frame t is col 10 + t
    tips = [findlast(>(300), k[t, :]) for t in 1:m.frames]
    @test tips == [10 + t for t in 1:m.frames]
    rm(path)
end

@testset "detection finds the microtubule and puts the seed first" begin
    # Arrange
    path = write_test_tiff(tempname() * ".tif", growing_microtubule(; frames=30, width=80))
    m = read_movie(path)

    # Act
    lines = [orient_line(l, mean_projection(m)) for l in detect_lines(max_projection(m); min_area=10, min_length=20)]

    # Assert
    @test length(lines) == 1
    r1, c1, r2, c2 = lines[1]
    @test r1 == r2 == 15
    @test c1 < 15 && c2 > 45
    rm(path)
end

@testset "two microtubules that touch give two lines, not one" begin
    # Arrange: a horizontal bar and a slanted bar, 3 px wide, joined at their left ends (a V)
    img = fill(100f0, 60, 90)
    for c in 10:80
        img[14:16, c] .= 1000
        r = round(Int, 15 + (c - 10) * 0.5)
        img[r-1:r+1, c] .= 1000
    end

    # Act
    lines = detect_lines(img)

    # Assert: one line stays on row 15, the other ends near row 50
    @test length(lines) == 2
    ends = sort([max(l[1], l[3]) for l in lines])
    @test ends[1] <= 16 && ends[2] >= 45
end

@testset "the seed is the end of the kymograph that does not move" begin
    # Arrange: 60 frames; the microtubule spans columns 10..tip(t), the tip moves right
    tip(t) = 15 + t ÷ 2
    grows_right = Float32[10 <= c <= tip(t) ? 1 : 0 for t in 1:60, c in 1:60]
    sliding = Float32[5 + t ÷ 3 <= c <= 20 + t ÷ 3 ? 1 : 0 for t in 1:60, c in 1:60]

    # Act & Assert
    @test seed_side(grows_right) == :left
    @test seed_side(grows_right[:, end:-1:1]) == :right
    @test seed_side(sliding) == :unclear
end

@testset "a lengthened line stays inside the image" begin
    # Act
    (r1, c1, r2, c2), shift = extend_line((10, 5, 10, 50), 20, (30, 60))

    # Assert: 4 px of room before the start, 10 px after the end
    @test shift == 4
    @test (r1, c1, r2, c2) == (10.0, 1.0, 10.0, 60.0)
end

@testset "the seed is where every growth starts" begin
    # Arrange: dark seed up to column 20; growths start at column 21 and reach various lengths
    k = Float32[21 <= c <= 21 + (t % 30) ? 1 : 0 for t in 1:120, c in 1:80]

    # Act & Assert
    @test estimate_seed(k) == 20
    @test estimate_seed(zeros(Float32, 50, 40); fallback=7) == 7
end

@testset "PNG images have a valid header and size" begin
    # Arrange
    img = gray8(Float32[1 2 3; 4 5 6])

    # Act
    png = png_bytes(img)

    # Assert
    @test png_size(png) == (width=3, height=2)
    @test img[1, 1] == 0 && img[2, 3] == 255
    @test png[end-7:end-4] == UInt8['I', 'E', 'N', 'D']
end

@testset "saved tables round-trip, with commas removed from values" begin
    # Arrange
    path = joinpath(mktempdir(), "sub", "t.csv")

    # Act
    write_table(path, "a,b", [["x, y", 1], ["z", 2.5]])

    # Assert
    @test read_table(path) == [["x  y", "1"], ["z", "2.5"]]
    @test read_table(path * ".missing") == Vector{String}[]
end

@testset "line keys do not depend on commas in the movie name" begin
    @test line_key("a,b.tif", (1, 2, 3, 4)) == "a b.tif|1 2 3 4"
end

end
