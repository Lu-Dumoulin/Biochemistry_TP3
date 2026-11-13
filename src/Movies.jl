"""
    Movies

From a microscope movie (an uncompressed TIFF stack, as saved by ImageJ/Fiji) to kymographs:
read the stack and its calibration, project it, find straight microtubules, sample the
intensity along a line in every frame, and encode images as PNG for the click tools.
Plain Julia, standard library only.
"""
module Movies

using Statistics

export read_movie, max_projection, mean_projection, detect_lines, orient_line, seed_side, estimate_seed, extend_line, kymograph,
       gray8, png_bytes, line_key, read_table, write_table

# ---------------------------------------------------------------------------
# TIFF reading
# ---------------------------------------------------------------------------

const TIFF_TYPE_SIZE = Dict(1 => 1, 2 => 1, 3 => 2, 4 => 4, 5 => 8, 6 => 1, 7 => 1, 8 => 2,
                            9 => 4, 10 => 8, 11 => 4, 12 => 8)

struct TiffReader
    bytes::Vector{UInt8}
    big::Bool                                   # big-endian ("MM") file
end

function getint(r::TiffReader, ::Type{T}, pos::Integer) where {T<:Unsigned}
    n = sizeof(T)
    pos + n - 1 <= length(r.bytes) || throw(ArgumentError("The TIFF file is truncated."))
    v = zero(T)
    if r.big
        for i in 0:n-1; v = (v << 8) | T(r.bytes[pos + i]); end
    else
        for i in n-1:-1:0; v = (v << 8) | T(r.bytes[pos + i]); end
    end
    return v
end

"Values of one IFD entry: numbers, or a String for ASCII entries."
function entry_values(r::TiffReader, pos::Integer)
    type = Int(getint(r, UInt16, pos + 2))
    count = Int(getint(r, UInt32, pos + 4))
    size = get(TIFF_TYPE_SIZE, type, 1) * count
    data = size <= 4 ? pos + 8 : Int(getint(r, UInt32, pos + 8)) + 1
    if type == 2
        return String(r.bytes[data:data+count-1]) |> s -> rstrip(s, '\0')
    elseif type in (1, 6, 7)
        return [Int(r.bytes[data + i]) for i in 0:count-1]
    elseif type in (3, 8)
        return [Int(getint(r, UInt16, data + 2i)) for i in 0:count-1]
    elseif type in (4, 9)
        return [Int(getint(r, UInt32, data + 4i)) for i in 0:count-1]
    elseif type in (5, 10)
        return [Int(getint(r, UInt32, data + 8i)) / Int(getint(r, UInt32, data + 8i + 4)) for i in 0:count-1]
    elseif type == 11
        return [Float64(reinterpret(Float32, getint(r, UInt32, data + 4i))) for i in 0:count-1]
    elseif type == 12
        return [reinterpret(Float64, getint(r, UInt64, data + 8i)) for i in 0:count-1]
    end
    return Int[]
end

"All image file directories (IFDs) of the file, as Dicts tag => values."
function read_ifds(r::TiffReader; max_ifds=100_000)
    ifds = Dict{Int,Any}[]
    offset = Int(getint(r, UInt32, 5))
    while offset != 0 && length(ifds) < max_ifds
        pos = offset + 1
        n = Int(getint(r, UInt16, pos))
        ifd = Dict{Int,Any}()
        for k in 0:n-1
            e = pos + 2 + 12k
            ifd[Int(getint(r, UInt16, e))] = entry_values(r, e)
        end
        push!(ifds, ifd)
        offset = Int(getint(r, UInt32, pos + 2 + 12n))
    end
    return ifds
end

"ImageJ writes `key=value` lines in the image description."
function imagej_info(description)
    info = Dict{String,String}()
    description isa AbstractString || return info
    for line in split(description, '\n')
        k, sep, v = partition(line, '=')
        isempty(sep) || (info[strip(k)] = strip(v))
    end
    return info
end
partition(s, c) = (i = findfirst(==(c), s); i === nothing ? (s, "", "") : (s[1:prevind(s, i)], "=", s[nextind(s, i):end]))

intinfo(info, key, default) = (v = tryparse(Int, get(info, key, "")); v === nothing ? default : v)

"""
    read_movie(path) -> (; name, data, channels, frames, um_per_px, s_per_frame, notes)

Read an uncompressed grayscale TIFF stack (8, 16 or 32 bits), as saved by ImageJ/Fiji.
`data[row, col, channel, frame]` holds the pixel values. The ImageJ description gives the
number of channels and frames (channel varies fastest; z-slices are max-projected) and the
frame interval; the TIFF resolution gives the pixel size. `notes` explains every guess.
"""
function read_movie(path::AbstractString)
    bytes = read(path)
    length(bytes) >= 8 || throw(ArgumentError("$(basename(path)) is not a TIFF file."))
    order = String(bytes[1:2])
    order in ("II", "MM") || throw(ArgumentError("$(basename(path)) is not a TIFF file."))
    r = TiffReader(bytes, order == "MM")
    magic = getint(r, UInt16, 3)
    magic == 43 && throw(ArgumentError("$(basename(path)) is a BigTIFF file (over 4 GB). In Fiji, crop it or save fewer frames."))
    magic == 42 || throw(ArgumentError("$(basename(path)) is not a TIFF file."))
    ifds = read_ifds(r)
    first_ifd = ifds[1]
    get(first_ifd, 259, [1])[1] == 1 ||
        throw(ArgumentError("$(basename(path)) is compressed. In Fiji: File > Save As > Tiff... saves it uncompressed."))
    get(first_ifd, 277, [1])[1] == 1 ||
        throw(ArgumentError("$(basename(path)) is a color (RGB) image. In Fiji: Image > Type > 16-bit, then save again."))
    width = first_ifd[256][1]; height = first_ifd[257][1]
    bits = get(first_ifd, 258, [8])[1]
    float = get(first_ifd, 339, [1])[1] == 3
    T = bits == 8 ? UInt8 : bits == 16 ? UInt16 : (bits == 32 && float) ? Float32 : bits == 32 ? UInt32 :
        throw(ArgumentError("$(basename(path)) has $bits-bit pixels; only 8, 16 and 32 bits are read."))
    info = imagej_info(get(first_ifd, 270, nothing))
    notes = String[]

    # Where each image starts: one IFD per image, or (ImageJ, large files) one IFD and
    # all images stored one after the other.
    nimages = intinfo(info, "images", length(ifds))
    image_bytes = width * height * sizeof(T)
    starts = if length(ifds) >= nimages
        [ifd[273][1] + 1 for ifd in ifds[1:nimages]]
    else
        [first_ifd[273][1] + 1 + (k - 1) * image_bytes for k in 1:nimages]
    end
    if starts[end] + image_bytes - 1 > length(bytes)
        nimages = count(s -> s + image_bytes - 1 <= length(bytes), starts)
        starts = starts[1:nimages]
        push!(notes, "The file is shorter than announced: only $nimages images are read.")
    end
    # Several strips per image are contiguous for files written by ImageJ; check it.
    if length(get(first_ifd, 273, [])) > 1
        offs = first_ifd[273]; counts = first_ifd[279]
        all(offs[i] + counts[i] == offs[i + 1] for i in 1:length(offs)-1) ||
            throw(ArgumentError("$(basename(path)): this TIFF layout is not supported. Save it again with Fiji."))
    end

    channels = intinfo(info, "channels", 1)
    slices = intinfo(info, "slices", 1)
    frames = intinfo(info, "frames", 1)
    if frames == 1 && slices > 1          # a plain stack: ImageJ calls its frames "slices"
        frames, slices = slices, 1
    end
    if channels * slices * frames != nimages
        channels, slices, frames = 1, 1, nimages
        push!(notes, "The number of channels and frames is not in the file: every image is read as one frame.")
    end
    slices > 1 && push!(notes, "The movie has $slices z-slices: each frame is their maximum projection.")

    data = zeros(T, height, width, channels, frames)
    swap = r.big != (ENDIAN_BOM == 0x01020304)
    buffer = Vector{T}(undef, width * height)
    for t in 1:frames, z in 1:slices, c in 1:channels
        k = c + (z - 1) * channels + (t - 1) * channels * slices
        copyto!(buffer, reinterpret(T, view(bytes, starts[k]:starts[k]+image_bytes-1)))
        swap && (buffer .= bswap.(buffer))
        img = permutedims(reshape(buffer, width, height))
        z == 1 ? (data[:, :, c, t] = img) : (data[:, :, c, t] .= max.(view(data, :, :, c, t), img))
    end
    get(first_ifd, 262, [1])[1] == 0 && push!(notes, "The file stores dark as bright (WhiteIsZero).")

    # Calibration. ImageJ stores pixels per unit in XResolution.
    um_per_px = NaN
    unit = lowercase(get(info, "unit", ""))
    xres = get(first_ifd, 282, [0.0])[1]
    to_um = unit in ("micron", "microns", "um", "µm", "\\u00b5m", "μm") ? 1.0 : unit == "nm" ? 1e-3 :
            unit == "mm" ? 1e3 : isempty(unit) && get(first_ifd, 296, [2])[1] == 3 ? 1e4 : NaN
    if xres > 0 && isfinite(to_um)
        um_per_px = to_um / xres
        if um_per_px > 1 && 0.02 <= 1 / um_per_px <= 1
            push!(notes, "The file says $(round(um_per_px; sigdigits=3)) µm per pixel, too large for a microscope image: " *
                         "it is probably inverted, so $(round(1 / um_per_px; sigdigits=3)) µm per pixel is used. Check it.")
            um_per_px = 1 / um_per_px
        end
    else
        push!(notes, "The pixel size is not in the file: set it by hand (typically 0.06–0.2 µm per pixel).")
    end
    s_per_frame = NaN
    finterval = tryparse(Float64, get(info, "finterval", ""))
    if finterval !== nothing && finterval > 0
        tunit = lowercase(get(info, "tunit", "sec"))
        s_per_frame = finterval * (startswith(tunit, "min") ? 60 : startswith(tunit, "ms") ? 1e-3 : 1)
    else
        push!(notes, "The time between frames is not in the file: set it by hand.")
    end
    return (; name=basename(path), data, channels, frames, um_per_px, s_per_frame, notes)
end

# ---------------------------------------------------------------------------
# Projections and microtubule detection
# ---------------------------------------------------------------------------

"Brightest value of each pixel over the movie, for one channel."
max_projection(movie, channel=1) = Float32.(dropdims(maximum(view(movie.data, :, :, channel, :); dims=3); dims=3))
"Mean value of each pixel over the movie: the seeds, present in every frame, stand out."
mean_projection(movie, channel=1) = Float32.(dropdims(mean(view(movie.data, :, :, channel, :); dims=3); dims=3))

"Connected regions (8 neighbours) of a Boolean image: a label image and the number of regions."
function components(mask)
    labels = zeros(Int, size(mask)); n = 0
    for idx in CartesianIndices(mask)
        (mask[idx] && labels[idx] == 0) || continue
        n += 1; stack = [idx]; labels[idx] = n
        while !isempty(stack)
            p = pop!(stack)
            for d in CartesianIndices((-1:1, -1:1))
                q = p + d
                checkbounds(Bool, mask, q) && mask[q] && labels[q] == 0 && (labels[q] = n; push!(stack, q))
            end
        end
    end
    return labels, n
end

"Average over a 3×3 neighbourhood."
function smooth3(img)
    out = similar(img, Float32)
    for i in axes(img, 1), j in axes(img, 2)
        out[i, j] = mean(view(img, max(1, i - 1):min(size(img, 1), i + 1), max(1, j - 1):min(size(img, 2), j + 1)))
    end
    return out
end

"Long axis of a set of points: centre and unit direction (row, col)."
function principal_axis(y, x)
    cy, cx = mean(y), mean(x)
    syy = mean((y .- cy) .^ 2); sxx = mean((x .- cx) .^ 2); sxy = mean((y .- cy) .* (x .- cx))
    θ = 0.5 * atan(2sxy, syy - sxx)                     # angle from the row axis
    return cy, cx, cos(θ), sin(θ)
end

"""
    straight_pieces(y, x; tol=1.5, band=3.5, max_gap=3, min_area=60, min_length=40, min_split=40)

Split a bright region (pixel coordinates `y`, `x`) into straight pieces, one microtubule
each, so that two microtubules that touch or cross are not merged: the line through two
of the region's pixels that passes within `tol` of the most pixels is refined on those
pixels and kept as one piece (its longest stretch without gaps over `max_gap`); the pixels
within `band` of it are removed, and the search repeats on what is left. Later pieces must
be at least `min_split` long: shorter ones are the blurred edges of thick seeds. Returns
`(cy, cx, uy, ux, lo, hi)`: centre, direction, and extent along it.
"""
function straight_pieces(y, x; tol=1.5, band=3.5, max_gap=3, min_area=60, min_length=40, min_split=40)
    pieces = NTuple{6,Float64}[]
    left = collect(eachindex(y))
    while length(left) >= min_area
        sample = left[unique(round.(Int, range(1, length(left); length=min(length(left), 80))))]
        best, line = 0, (0.0, 0.0, 0.0, 0.0)
        for a in eachindex(sample), b in a+1:length(sample)
            i, j = sample[a], sample[b]
            L = hypot(y[j] - y[i], x[j] - x[i])
            L < 5 && continue
            uy, ux = (y[j] - y[i]) / L, (x[j] - x[i]) / L
            n = count(k -> abs((y[k] - y[i]) * ux - (x[k] - x[i]) * uy) <= tol, left)
            n > best && ((best, line) = (n, (y[i], x[i], uy, ux)))
        end
        best < min_area && break
        # refine the line on its pixels, then keep its longest stretch without gaps
        on = filter(k -> abs((y[k] - line[1]) * line[4] - (x[k] - line[2]) * line[3]) <= tol, left)
        cy, cx, uy, ux = principal_axis(y[on], x[on])
        dist(k) = abs((y[k] - cy) * ux - (x[k] - cx) * uy)
        along(k) = (y[k] - cy) * uy + (x[k] - cx) * ux
        on = sort(filter(k -> dist(k) <= band, left); by=along)
        t = along.(on)
        breaks = [0; findall(>(max_gap), diff(t)); length(t)]
        run = argmax(r -> breaks[r + 1] - breaks[r], 1:length(breaks) - 1)
        members = on[breaks[run] + 1:breaks[run + 1]]
        lo, hi = t[breaks[run] + 1], t[breaks[run + 1]]
        length(members) >= min_area && hi - lo >= (isempty(pieces) ? min_length : max(min_length, min_split)) &&
            push!(pieces, (cy, cx, uy, ux, lo, hi))
        removed = Set(members)
        isempty(removed) && break
        filter!(k -> !(k in removed), left)
    end
    return pieces
end

"Mean over a (2radius+1)² square around each pixel (clipped at the borders), from cumulative sums."
function box_mean(img, radius)
    h, w = size(img)
    S = zeros(Float64, h + 1, w + 1)
    for j in 1:w, i in 1:h
        S[i + 1, j + 1] = img[i, j] + S[i, j + 1] + S[i + 1, j] - S[i, j]
    end
    out = similar(img, Float32)
    for j in 1:w, i in 1:h
        a, b = max(1, i - radius), min(h, i + radius)
        c, d = max(1, j - radius), min(w, j + radius)
        out[i, j] = (S[b + 1, d + 1] - S[a, d + 1] - S[b + 1, c] + S[a, c]) / ((b - a + 1) * (d - c + 1))
    end
    return out
end

"""
    detect_lines(projection; level=0.45, min_area=60, min_length=40, extend=10, background=25)

Straight microtubules in a maximum projection. Uneven illumination is removed first, by
subtracting the mean over squares of `2background + 1` pixels (0: no correction). Then bright
regions (above `level` between the median and the brightest pixels) of at least `min_area`
pixels are split into straight pieces (see `straight_pieces`), each extended by `extend`
pixels at both ends. Pieces shorter than `min_length` pixels are dropped.
Returns `[(r1, c1, r2, c2), ...]` in pixels.
"""
function detect_lines(projection; level=0.45, min_area=60, min_length=40, extend=10, background=25)
    flat = background > 0 ? projection .- box_mean(projection, background) : projection
    sm = smooth3(flat)
    med = quantile(vec(sm), 0.5); top = quantile(vec(sm), 0.999)
    labels, n = components(sm .> med + level * (top - med))
    nrow, ncol = size(projection)
    clampr(v) = clamp(round(Int, v), 1, nrow); clampc(v) = clamp(round(Int, v), 1, ncol)
    lines = NTuple{4,Int}[]
    for k in 1:n
        pts = findall(==(k), labels)
        length(pts) < min_area && continue
        y = [Float64(p[1]) for p in pts]; x = [Float64(p[2]) for p in pts]
        for (cy, cx, uy, ux, lo, hi) in straight_pieces(y, x; min_area, min_length=min_length - 2extend)
            lo -= extend; hi += extend
            push!(lines, (clampr(cy + lo * uy), clampc(cx + lo * ux), clampr(cy + hi * uy), clampc(cx + hi * ux)))
        end
    end
    return lines
end

"""
    seed_side(kymo; still=8)

Where the seed of a kymograph is: `:left`, `:right`, or `:unclear`. The microtubule always
starts from the seed, so the end of its bright region that stays put over time is the seed end,
and the other end moves. If both ends move by more than `still` pixels and by similar amounts,
the microtubule slides or drifts, or the line crosses something else: `:unclear`.
"""
function seed_side(kymo; still=8)
    sm = smooth3(kymo)
    bg, fg = quantile(vec(sm), (0.2, 0.9))
    left = Int[]; right = Int[]
    for t in axes(sm, 1)
        bright = sm[t, :] .> (bg + fg) / 2
        best = (0, 0, 0); s = 0                          # longest bright run of this row
        for j in 1:length(bright) + 1
            on = j <= length(bright) && bright[j]
            if on && s == 0
                s = j
            elseif !on && s > 0
                j - s > best[1] && (best = (j - s, s, j - 1)); s = 0
            end
        end
        best[1] >= 5 && (push!(left, best[2]); push!(right, best[3]))
    end
    length(left) < 10 && return :unclear
    spread(x) = quantile(x, 0.9) - quantile(x, 0.1)
    l, r = spread(left), spread(right)
    min(l, r) > still && max(l, r) < 2 * min(l, r) && return :unclear
    return l <= r ? :left : :right
end

"""
    estimate_seed(kymo; presence=0.1, run=5, from=1, fallback=1)

Column where the seed ends on a kymograph whose seed is on the left. The seed is often dim (only
the new tubulin is bright), but every growth starts from it: the seed end is just left of the
first run of `run` columns where the microtubule is present in at least a fraction `presence`
of the frames, searching from column `from` (the start of the line, before which the image may
show other objects). Returns `fallback` if there is no such run in the left half.
"""
function estimate_seed(kymo; presence=0.1, run=5, from=1, fallback=1)
    sm = smooth3(kymo)
    bg, fg = quantile(vec(sm), (0.2, 0.9))
    bright = sm .> (bg + fg) / 2
    present = [mean(view(bright, :, c)) for c in axes(bright, 2)]
    half = max(from + run, size(kymo, 2) ÷ 2)
    for c in from:min(half, size(kymo, 2)) - run + 1
        all(>=(presence), view(present, c:c + run - 1)) && return max(c - 1, 1)
    end
    return fallback
end

"""
    orient_line(line, movie, channel=1)

The line with its seed end first, judged on its kymograph (see `seed_side`), or `nothing` when
the kymograph shows no fixed seed.
"""
function orient_line(line, movie::NamedTuple, channel=1)
    side = seed_side(kymograph(movie, channel, line))
    side == :left ? line : side == :right ? (line[3], line[4], line[1], line[2]) : nothing
end

"Put the seed end first: the end where the mean projection is brightest."
function orient_line(line, mean_proj)
    r1, c1, r2, c2 = line
    n = max(2, round(Int, hypot(r2 - r1, c2 - c1)))
    profile = [bilinear(mean_proj, r1 + (r2 - r1) * s, c1 + (c2 - c1) * s) for s in range(0, 1; length=n)]
    return argmax(profile) <= n / 2 ? line : (r2, c2, r1, c1)
end

function bilinear(img, y, x)
    y0 = clamp(floor(Int, y), 1, size(img, 1) - 1); x0 = clamp(floor(Int, x), 1, size(img, 2) - 1)
    dy = clamp(y - y0, 0, 1); dx = clamp(x - x0, 0, 1)
    return (1 - dy) * (1 - dx) * img[y0, x0] + dy * (1 - dx) * img[y0 + 1, x0] +
           (1 - dy) * dx * img[y0, x0 + 1] + dy * dx * img[y0 + 1, x0 + 1]
end

"""
    kymograph(movie, channel, (r1, c1, r2, c2); width=3)

Intensity along the line from (r1, c1) to (r2, c2), one row per frame and one column per
pixel of length (column 1 at (r1, c1)), averaged over `width` pixels across the line.
"""
function kymograph(movie, channel, line; width=3)
    r1, c1, r2, c2 = Float64.(line)
    L = hypot(r2 - r1, c2 - c1)
    L >= 1 || throw(ArgumentError("The line is too short."))
    n = floor(Int, L) + 1
    uy, ux = (r2 - r1) / L, (c2 - c1) / L
    offsets = (1:width) .- (width + 1) / 2
    kymo = zeros(Float32, movie.frames, n)
    for t in 1:movie.frames
        img = view(movie.data, :, :, channel, t)
        for s in 1:n, o in offsets
            kymo[t, s] += bilinear(img, r1 + (s - 1) * uy - o * ux, c1 + (s - 1) * ux + o * uy) / width
        end
    end
    return kymo
end

"""
    extend_line((r1, c1, r2, c2), px, (rows, cols))

The line lengthened by `px` pixels at both ends, as far as the image of size `(rows, cols)`
allows, so that a kymograph shows the image around the microtubule. Returns the new line and how
many pixels were added before the start (the shift of the kymograph columns).
"""
function extend_line(line, px, imsize)
    r1, c1, r2, c2 = Float64.(line)
    L = hypot(r2 - r1, c2 - c1)
    L > 0 || return (line, 0)
    ur, uc = (r2 - r1) / L, (c2 - c1) / L
    # largest step along -u (start) and +u (end) that stays inside the image
    room(r, c, sr, sc) = minimum((sr > 0 ? (imsize[1] - r) / sr : sr < 0 ? (1 - r) / sr : Inf,
                                  sc > 0 ? (imsize[2] - c) / sc : sc < 0 ? (1 - c) / sc : Inf))
    a = floor(Int, clamp(room(r1, c1, -ur, -uc), 0, px))
    b = floor(Int, clamp(room(r2, c2, ur, uc), 0, px))
    new = (r1 - a * ur, c1 - a * uc, r2 + b * ur, c2 + b * uc)
    return (new, a)
end

"Key that identifies a line of a movie in the saved tables."
line_key(movie_name, line) = string(replace(movie_name, "," => " "), "|", join(line, " "))

# ---------------------------------------------------------------------------
# PNG encoding (8-bit grayscale, uncompressed deflate blocks)
# ---------------------------------------------------------------------------

"Scale an image to 0–255, from the `lo` to the `hi` quantile of its values."
function gray8(img; lo=0.01, hi=0.999)
    a, b = quantile(vec(Float64.(img)), (lo, hi))
    b > a || (b = a + 1)
    return [round(UInt8, 255 * clamp((v - a) / (b - a), 0, 1)) for v in img]
end

const CRC_TABLE = let
    t = zeros(UInt32, 256)
    for n in 0:255
        c = UInt32(n)
        for _ in 1:8
            c = isodd(c) ? 0xedb88320 ⊻ (c >> 1) : c >> 1
        end
        t[n + 1] = c
    end
    t
end
function crc32(data)
    c = 0xffffffff
    for b in data
        c = CRC_TABLE[((c ⊻ b) & 0xff) + 1] ⊻ (c >> 8)
    end
    return c ⊻ 0xffffffff
end
function adler32(data)
    a, b = UInt32(1), UInt32(0)
    for x in data
        a = (a + x) % 65521; b = (b + a) % 65521
    end
    return (b << 16) | a
end
be32(x) = UInt8[(x >> 24) & 0xff, (x >> 16) & 0xff, (x >> 8) & 0xff, x & 0xff]

"PNG file of an 8-bit grayscale image (rows top to bottom)."
function png_bytes(img::AbstractMatrix{UInt8})
    h, w = size(img)
    raw = UInt8[]
    sizehint!(raw, h * (w + 1))
    for i in 1:h
        push!(raw, 0x00)                                  # filter: none
        append!(raw, view(img, i, :))
    end
    z = UInt8[0x78, 0x01]                                 # zlib header, no compression
    nblocks = max(1, cld(length(raw), 65535))
    for k in 1:nblocks
        block = view(raw, (k - 1) * 65535 + 1:min(k * 65535, length(raw)))
        n = length(block)
        push!(z, k == nblocks ? 0x01 : 0x00, n & 0xff, n >> 8, ~n & 0xff, (~n >> 8) & 0xff)
        append!(z, block)
    end
    append!(z, be32(adler32(raw)))
    chunk(type, data) = (td = [codeunits(type); data]; [be32(UInt32(length(data))); td; be32(crc32(td))])
    return [UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
            chunk("IHDR", [be32(UInt32(w)); be32(UInt32(h)); UInt8[8, 0, 0, 0, 0]]);
            chunk("IDAT", z); chunk("IEND", UInt8[])]
end

# ---------------------------------------------------------------------------
# Small comma-separated tables, to keep the student's choices between sessions
# ---------------------------------------------------------------------------

"Rows of a comma-separated file with a header line, as Vectors of Strings (empty if no file)."
read_table(path) = isfile(path) ?
    [String.(split(l, ",")) for l in readlines(path)[2:end] if !isempty(strip(l))] : Vector{String}[]

"Write rows (iterables of values) under `header`; commas inside values become spaces."
function write_table(path, header, rows)
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, header)
        for r in rows
            println(io, join((replace(string(v), "," => " ") for v in r), ","))
        end
    end
    return path
end

end # module
