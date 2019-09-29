module MicroscopyLabels

using FreeTypeAbstraction
using FreeType
using Unitful
using SimpleTraits
using ImageMetadata
using AxisArrays
using ImageAxes
using ImageMorphology

export timestamp!, scalebar!, label_particles!

const fontface = Array{Ptr{FreeType.FT_FaceRec}}(undef, 1)

function __init__()
    fontface[1] = newface(normpath(@__DIR__, "..", "assets",
                                   "ubuntu-font-family-0.83", "Ubuntu-R.ttf"))[1]
end

"""
    timestamp!(img; units)

Writes the timestamp in the upper left corner of a multidimensional image `img`
with the units `units`. Images are required to have at least the `x`, `y`, and
`time` axes labeled, i.e. `img` should be or contain an `AxisArray` object with
xyt axes. If additional axes are present, the timestamp will be written to all
of them.

### Simple example

```jldoctest ex; output = false
using AxisArrays
using MicroscopyLabels

tmp = AxisArray(zeros(200, 200, 5), Axis{:x}(1:200), Axis{:y}(1:200), Axis{:time}(1:5))
timestamp!(tmp)

# output


```

### Unitful example

We can also add units to the time axis and have these be embedded in the image

```jldoctest ex; output=false
using Unitful: s, minute

tmp = AxisArray(zeros(200, 200, 5), Axis{:x}(1:200), Axis{:y}(1:200),
                Axis{:time}(0s:45.0s:180s))
# convert the units to minutes
timestamp!(tmp, units=minute)

# output


```
"""
timestamp!(img::ImageMeta; units::Unitful.TimeUnits=u"s") = timestamp!(data(img), units=units)


@traitfn function timestamp!(img::AA; units::Unitful.TimeUnits=u"s") where {AA <: AxisArray; HasTimeAxis{AA}}
    all_axs = Set(axisnames(img))
    pop!(all_axs, :x)
    pop!(all_axs, :y)
    pop!(all_axs, :time)
    axs = collect(all_axs)

    # text will be 4% the size of the smaller spatial axis
    minsz = min(size(img, Axis{:y}), size(img, Axis{:x}))
    sz = round(Int, 0.04*minsz)

    for timepoint in timeaxis(img)

        slice = view(img, Axis{:time}(timepoint))

        tp = timepoint
        if isa(tp, Unitful.Time)
            tp = round(units, timepoint, sigdigits=3)
        end

        # fix minutes
        pretty = replace(string(tp), "minute"=>"mins")

        for I in CartesianIndices(Tuple(size(img, Axis{ax}) for ax in axs))

            if length(I) > 0
                subslice = view(slice, (Axis{ax}(I[i]) for (i, ax) in enumerate(axs))...)
            else # if there are only 3 axes than we don't need to take further subslices
                subslice = slice
            end

            renderstring!(subslice,
                          "t=$pretty",
                          fontface,
                          (sz, sz),
                          10, 10,
                          halign=:hleft,
                          valign=:vtop,
                          fcolor=oneunit(eltype(subslice)),
                          bcolor=nothing
            )
        end
    end
end

@traitfn function timestamp!(img::AA; units::Unitful.TimeUnits=u"s") where {AA <: AxisArray; !HasTimeAxis{AA}}
    @info "No time axis detected!"
    return nothing
end


scalebar!(img::ImageMeta, length::Unitful.Length; fontsize=0.04) = scalebar!(img.data, length, fontsize=fontsize)

"""
    scalebar!(img, len; fontsize)

Add a scalebar `len` long in the bottom left of `img` along the x axis with
text of size `fontsize` given as a fraction of the smallest spatial axis.

## Example

```jldoctest; output=false
using Unitful: μm
using AxisArrays
using MicroscopyLabels

tmp = AxisArray(zeros(200, 200), Axis{:y}(1μm:1μm:200μm), Axis{:x}(1μm:1μm:200μm));

scalebar!(tmp, 25μm, fontsize=0.06)

# output


```
"""
function scalebar!(img::AxisArray, len::Unitful.Length; fontsize=0.04)

    all_axs = Set(axisnames(img))
    pop!(all_axs, :x)
    pop!(all_axs, :y)
    axs = collect(all_axs)

    offset = 20
    imgh = size(img, Axis{:y})
    imgw = size(img, Axis{:x})

    pixelw = step(AxisArrays.axes(img, Axis{:x}).val)

    # make the bar height 1% of the image height and set the correct length
    barh = round(Int, 0.01*imgh)
    barw = round(Int, len / pixelw)

    minsz = min(size(img, Axis{:y}), size(img, Axis{:x}))
    sz = round(Int, fontsize*minsz)

    for I in CartesianIndices(Tuple(size(img, Axis{ax}) for ax in axs))
        if length(I) > 0
            slice = view(img, (Axis{ax}(I[i]) for (i, ax) in enumerate(axs))...)
        else
            slice = img
        end

        view(slice, Axis{:y}(imgh-offset-barh:imgh-offset),
                    Axis{:x}(imgw-offset-barw:imgw-offset)) .= oneunit(eltype(img))

        renderstring!(slice,
                      "$len",
                      MicroscopyLabels.fontface,
                      (sz, sz),
                      imgh-offset-barh÷2, imgw-offset-barw-offset÷2,
                      halign=:hright,
                      valign=:vcenter,
                      fcolor=oneunit(eltype(slice)),
                      bcolor=nothing
            )
    end
end

"""
    label_particles!(img, labels)

Writes text labels generated by `ImageMorphology.label_components` into `img`.
Writes one text label per centroid identified by
`ImageMorphology.component_centroids`. Ignores the background pixels,
i.e. anything labeled with 0.

### Example

```jldoctest; output=false
using MicroscopyLabels
using AxisArrays
using ImageMorphology

# create a 50x50x1 YXT image with one spot
img = AxisArray(zeros(50, 50, 1), Axis{:y}(1:50), Axis{:x}(1:50), Axis{:time}(1:1));
img[10:12, 10:12, 1:1] .= 1.0;

# assign labels using ImageMorphology.label_components
labels = AxisArray(label_components(img .!== 0.0), AxisArrays.axes(img));

label_particles!(img, labels)

# output

```

"""
@traitfn function label_particles!(img::AA, labels::AxisArray{Int, 3}) where {AA <: AxisArray; HasTimeAxis{AA}}

    for timepoint in timeaxis(img)

        slice = view(img, Axis{:time}(timepoint))
        labels_slice = view(labels, Axis{:time}(timepoint))

        label_particles!(slice, labels_slice)
    end
end


@traitfn function label_particles!(img::AA, labels::AxisArray{Int, 2}) where {AA <: AxisArray; !HasTimeAxis{AA}}
    all_axs = Set(axisnames(img))
    pop!(all_axs, :x)
    pop!(all_axs, :y)

    axs = collect(all_axs)
    offset = 10
    sz = 20

    centroids = component_centroids(labels)[2:end]

    for I in CartesianIndices(Tuple(size(img, Axis{ax}) for ax in axs))

            if length(I) > 0
                subslice = view(img, (Axis{ax}(I[i]) for (i, ax) in enumerate(axs))...)
            else # if there are only 3 axes than we don't need to take further subslices
                subslice = img
            end

            for (idx, centroid) in enumerate(centroids)
                if any(isnan.(centroid))
                   continue
                end
                positions = round.(Int, centroid .+ offset)
                # don't label centroids that fall outside the bounds
                if any(positions .- size(subslice) .>= 0)
                   continue
                end
                renderstring!(subslice,
                              "$idx",
                              fontface,
                              (sz, sz),
                              positions[1], positions[2],
                              halign=:hleft,
                              valign=:vtop,
                              fcolor=oneunit(eltype(subslice)),
                              bcolor=nothing
                )
            end
        end
end

end #module