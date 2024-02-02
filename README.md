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

WIP:
- StepMode
- Full variable support

TBD:
- Procesing of Metadata (attributes...)
- PDF output
- Moire/Thermal (included, but not tested)
- Full compatibility with Gerber RS-274X/Gerber X3
