# amdgpu-diagram-output
## Requirements

 * AMD GPU
 * RadeonSI Driver ([mesa](https://gitlab.freedesktop.org/mesa/mesa))
 * glxinfo (mesa-utils)

## Result Example

```

Driver Version:		Mesa 21.0.0-devel (git-eec9d67e44)

GPU ASIC:		POLARIS11
Marketing Name:		Radeon RX 560 Series
GPU Type:		Discrete GPU

Compute Units:		16 CU
Peak GFX Clock:		1196 MHz
GFX Clock Range:	214 - 1080 MHz

Peak FP32:			 2.44 TFlops

RBs (Render Backends):		4 RB (16 ROP)
Peak Pixel Fill-Rate:		19.13 GP/s
TMUs (Texture Mapping Units):	64 TMU
Peak Texture Fill-Rate:		76.54 GT/s

VRAM Type:		GDDR5
VRAM Size:		4096 MB
VRAM Bit Width:		128-bit
Peak Memory Clock:	1750 MHz
Peak VRAM Bandwidth:	112 GB/s
Memory Clock Range:	300 - 1750 MHz

L2 Cache Blocks:	4 Block
L2 Cache Size:		1 MB (1024 KB)

AMD Smart Access Memory


## AMD GPU Diagram

 +- ShaderEngine(0) ---------------------+
 |                                       | 
 | +- ShaderArray(0) ------------------+ |
 | |   ====  ====  CU(0)  ====  ====   | |
 | |   ====  ====  CU(1)  ====  ====   | |
 | |   ====  ====  CU(2)  ====  ====   | |
 | |   ====  ====  CU(3)  ====  ====   | |
 | |   ====  ====  CU(4)  ====  ====   | |
 | |   ====  ====  CU(5)  ====  ====   | |
 | |   ====  ====  CU(6)  ====  ====   | |
 | |   ====  ====  CU(7)  ====  ====   | |
 | |   [ RB ]  [ RB ]                  | |
 | |  [- Rasterizer /Primitive Unit -] | |
 | +-----------------------------------+ |
 |        [- Geometry Processor -]       |
 +---------------------------------------+

 +- ShaderEngine(1) ---------------------+
 |                                       | 
 | +- ShaderArray(0) ------------------+ |
 | |   ====  ====  CU(0)  ====  ====   | |
 | |   ====  ====  CU(1)  ====  ====   | |
 | |   ====  ====  CU(2)  ====  ====   | |
 | |   ====  ====  CU(3)  ====  ====   | |
 | |   ====  ====  CU(4)  ====  ====   | |
 | |   ====  ====  CU(5)  ====  ====   | |
 | |   ====  ====  CU(6)  ====  ====   | |
 | |   ====  ====  CU(7)  ====  ====   | |
 | |   [ RB ]  [ RB ]                  | |
 | |  [- Rasterizer /Primitive Unit -] | |
 | +-----------------------------------+ |
 |        [- Geometry Processor -]       |
 +---------------------------------------+

[L2$ 256K] [L2$ 256K] [L2$ 256K] [L2$ 256K] 

```
