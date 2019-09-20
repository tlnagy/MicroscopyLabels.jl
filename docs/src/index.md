# Sane microscopy image labeling in Julia

This is collection of simple labeling functions specifically suited for quickly
embedding labels in microscopy images. I'm hoping to cover common use-cases like
adding timestamps, scalebars, transitions, and extra image details.

```@meta
CurrentModule=MicroscopyLabels
```

## Example

Say you have a OME-TIFF with lots of useful metadata exposed via
[`OMETIFF.jl`](https://github.com/tlnagy/OMETIFF.jl):



```@example ex1
using FileIO, ImageShow, AxisArrays
using Unitful: μm
using MicroscopyLabels

img = load(normpath(@__DIR__, "assets", "example.ome.tif"))
```

!!! note

    Any fully annotated `AxisArray` object should work here, including 
    the output from `NRRD.jl`, not just `OMETIFF.jl`

`MicroscopyLabels.jl` lets you rapidly and accurately annotate the image by
reading the internal metadata directly:

```@example ex1
scalebar!(img, 50μm)
timestamp!(img)

# lets look at the 30th frame real quick:
view(img, Axis{:time}(30))
```

## Reference

```@autodocs
Modules = [MicroscopyLabels]
Order   = [:function, :type]
```