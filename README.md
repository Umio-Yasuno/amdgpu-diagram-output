# amdgpu-diagram-output
## Requirements

 * AMD GPU
 * RadeonSI Driver ([mesa](https://gitlab.freedesktop.org/mesa/mesa))
 * glxinfo (mesa-utils)

## Option

```
Usage:
  amdgpu-diagram-output.sh [FLAGS] [OPTION]...

FLAGS:
  -ni, -noinfo			do not display spec list
  -nd, -nodia			do not display diagram
  -ng, -nogfx			do not display gfx block (for diagram)
  				  (RB, Rasterizer/Primitive, Geometry)
  -rbplus			RB+ (for override)
  				  (RB == 4-ROP, RB+ == 8-ROP) 
  -h, --help			display this help and exit

OPTIONS:
  --col=NUM			setting number of diagram column (default: 2)
  --arch=gfx(9|10|10.3)		override GFX IP/Architecture
  --se=NUM			override number of ShaderEngine
  --sa-per-se=NUM, --sps=NUM	override number of ShaderArray per ShaderEngine
  --cu-per-sa=NUM, --cps=NUM	override number of CU per ShaderArray
  --min-cu-per-sa=NUM, --mcps=NUM
  				override number of min CU per ShaderArray
  --rb=NUM			override number of RenderBackend
  --l2c-block=NUM, --l2cb=NUM	override number of L2cache block
  --l2c-size=NUM, --l2cs=NUM	override L2cache size (KiB)
  
  -image			output image of diagram
  				  output to: /tmp/<GPU_NAME>-diagram.png
  				  requirement: imagemagick, "Dejavu Sans Mono" font

```

## Result Example

```

Driver Version:		Mesa 21.1.0-devel (git-23100f3b65)

GPU ASIC:		POLARIS11
Chip class:		GFX8
Marketing Name:		Radeon RX 560 Series
GPU Type:		Discrete GPU
DeviceID:		0x67ff:0xcf

Compute Units:		  16 CU
GFX Clock Range:	 214 MHz - 1080 MHz
Peak GFX Clock:		1196 MHz

Peak FP16:		 2.44 TFlops
Peak FP32:		 2.44 TFlops

RBs (Render Backends):		  4 RB (16 ROP)
Peak Pixel Fill-Rate:		 19.13 GP/s
TMUs (Texture Mapping Units):	 64 TMU
Peak Texture Fill-Rate:		 76.54 GT/s

VRAM Type:		    GDDR5
VRAM Size:		  4096 MB
VRAM Bit Width:		   128-bit
Memory Clock Range:	   300 MHz - 1750 MHz
Peak Memory Clock:	  1750 MHz
Peak VRAM Bandwidth:	   112.00 GB/s

L2 Cache Blocks:	  4 Block
L2 Cache Size:		  1 MB (1024 KB)

Power cap:		 48 W

Card Interface:		PCIe Gen3x8 

AMD Smart Access Memory


## POLARIS11 Diagram

 +- ShaderEngine(00) -----------------+  +- ShaderEngine(01) -----------------+ 
 | +- ShaderArray(00) --------------+ |  | +- ShaderArray(00) --------------+ | 
 | |  ==== ====  CU (00) ==== ====  | |  | |  ==== ====  CU (00) ==== ====  | | 
 | |  ==== ====  CU (01) ==== ====  | |  | |  ==== ====  CU (01) ==== ====  | | 
 | |  ==== ====  CU (02) ==== ====  | |  | |  ==== ====  CU (02) ==== ====  | | 
 | |  ==== ====  CU (03) ==== ====  | |  | |  ==== ====  CU (03) ==== ====  | | 
 | |  ==== ====  CU (04) ==== ====  | |  | |  ==== ====  CU (04) ==== ====  | | 
 | |  ==== ====  CU (05) ==== ====  | |  | |  ==== ====  CU (05) ==== ====  | | 
 | |  ==== ====  CU (06) ==== ====  | |  | |  ==== ====  CU (06) ==== ====  | | 
 | |  ==== ====  CU (07) ==== ====  | |  | |  ==== ====  CU (07) ==== ====  | | 
 | |  [ RB ] [ RB ]                 | |  | |  [ RB ] [ RB ]                 | | 
 | |  [ Rasterizer/Primitive Unit ] | |  | |  [ Rasterizer/Primitive Unit ] | | 
 | +--------------------------------+ |  | +--------------------------------+ | 
 |      [- Geometry Processor -]      |  |      [- Geometry Processor -]      | 
 +------------------------------------+  +------------------------------------+ 

    [L2$ 256K]    [L2$ 256K]    [L2$ 256K]    [L2$ 256K]

```
