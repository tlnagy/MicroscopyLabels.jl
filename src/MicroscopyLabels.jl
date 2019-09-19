module MicroscopyLabels

using FreeTypeAbstraction
using FreeType
using Unitful
using SimpleTraits
using ImageMetadata
using AxisArrays
using ImageAxes

export timestamp!

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

### Example

```jldoctest; output = false
using AxisArrays
using MicroscopyLabels

tmp = AxisArray(zeros(200, 200, 5), Axis{:x}(1:200), Axis{:y}(1:200), Axis{:time}(1:5))
timestamp!(tmp)

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


end #module