# Loads the course modules the same way the notebooks do: by path, not as a package.
const SRC = joinpath(@__DIR__, "..", "..", "src")
isdefined(Main, :MTLab) || include(joinpath(SRC, "MTLab.jl"))
isdefined(Main, :Schematics) || include(joinpath(SRC, "Schematics.jl"))
isdefined(Main, :Widgets) || include(joinpath(SRC, "Widgets.jl"))
using .MTLab, .Schematics, .Widgets

# Pooled per-run summaries over independent seeds.
pooled(f, seeds) = [f(seed) for seed in seeds]
standard_error(x) = std(x) / sqrt(length(x))

isdefined(Main, :Movies) || include(joinpath(SRC, "Movies.jl"))
using .Movies

"""
    write_test_tiff(path, stack; channels=1, um_per_px=0.1, s_per_frame=2.0, big_endian=false)

Write `stack[row, col, image]` (UInt8 or UInt16) as an uncompressed ImageJ hyperstack, images
in ImageJ order (channel fastest), with its pixel size and frame interval, one IFD per image.
"""
function write_test_tiff(path, stack::AbstractArray{T,3}; channels=1, um_per_px=0.1, s_per_frame=2.0,
                         big_endian=false) where {T<:Union{UInt8,UInt16}}
    h, w, n = size(stack)
    enc(x) = big_endian ? hton(x) : htol(x)
    bytes(x) = reinterpret(UInt8, [enc(x)])
    desc = "ImageJ=1.54\nimages=$n\nchannels=$channels\nframes=$(n ÷ channels)\nhyperstack=true\nunit=micron\nfinterval=$s_per_frame\n\0"
    io = IOBuffer()
    write(io, big_endian ? b"MM" : b"II", bytes(UInt16(42)), bytes(UInt32(0)))
    desc_at = position(io); write(io, desc)
    res_at = position(io); write(io, bytes(UInt32(round(1e6 / um_per_px))), bytes(UInt32(1_000_000)))
    data_at = position(io)
    for k in 1:n
        write(io, enc.(vec(permutedims(stack[:, :, k]))))
    end
    image_bytes = w * h * sizeof(T)
    first_ifd = position(io)
    for k in 1:n
        entries = [(256, 4, 1, w), (257, 4, 1, h), (258, 3, 1, 8sizeof(T)), (259, 3, 1, 1), (262, 3, 1, 1),
                   (270, 2, length(desc), desc_at), (273, 4, 1, data_at + (k - 1) * image_bytes),
                   (277, 3, 1, 1), (278, 4, 1, h), (279, 4, 1, image_bytes), (282, 5, 1, res_at), (296, 3, 1, 1)]
        write(io, bytes(UInt16(length(entries))))
        for (tag, type, count, value) in entries
            write(io, bytes(UInt16(tag)), bytes(UInt16(type)), bytes(UInt32(count)))
            # a SHORT stored inline sits in the first two bytes of the value field
            type == 3 ? write(io, bytes(UInt16(value)), UInt16(0)) : write(io, bytes(UInt32(value)))
        end
        write(io, bytes(UInt32(k < n ? position(io) + 4 : 0)))
    end
    out = take!(io)
    out[5:8] = bytes(UInt32(first_ifd))
    write(path, out)
    return path
end

"A movie of one horizontal microtubule: a bright seed (cols 10–19) and a tip growing one pixel per frame."
function growing_microtubule(; frames=20, height=30, width=60, row=15)
    stack = fill(UInt16(100), height, width, frames)
    for t in 1:frames
        stack[row, 10:19, t] .= 1000
        stack[row, 20:19+t, t] .= 600
    end
    return stack
end
