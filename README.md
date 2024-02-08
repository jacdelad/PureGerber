# PureGerber
Processing Gerber data in PureBasic

This project aims to process Gerber data (stored in Gerber files) in PureBasic.
Therefor it offers a parser, which processes ther Gerber files.
It also has its own, proprietary Gerber format which is processed much faster.
It is still in development and some Gerber features are still missing.

Done:
- Basic Gerber rendering
- BlockMode
- Filled and Skeleton view
- Own, optimized Gerber format (PureGerber, *.pgr, read and write)
- Standard apertures in case of missing apertures
- Export to SVG
- GerberGadget based on a CanvasGadget with zoom, movement, rotation
- All available OS, ASM and C backend (tested on Windows)
- Simple variable support (no term calculation yet)
- G74 support (thanks to Karel Tavernier himself!)

WIP:
- StepMode

Needs testing:
- Moire/Thermal/Polygon
- Formula calculation

TBD:
- Procesing of Metadata (attributes...)
- Full compatibility with Gerber RS-274X/Gerber X3
- PDF output

Currently known bugs:
- Wrong center point for zooming in the GerberGadget when using 90°/270° rotation
