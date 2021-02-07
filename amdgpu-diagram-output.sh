#!/bin/sh
#
#  MIT License
#
#  amdgpu-diagram-output.sh
#  
#  Copyright (c) 2020-2021 Umio-Yasuno
#  
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#  
#  The above copyright notice and this permission notice shall be included in all
#  copies or substantial portions of the Software.
#  
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#  SOFTWARE.
#

IFS=''
GPUINFO="$(env AMD_DEBUG=info glxinfo -B)"
PCIBUS="/sys/bus/pci/devices/$(echo ${GPUINFO} | grep "pci (domain:bus:dev.func)" | sed -e "s/^.*func):\ //g")"
MESA_DRIVER_VER="$(echo ${GPUINFO} | grep "OpenGL core profile version" | sed -e "s/^.*Core\ Profile)\ //g")"

_repeat_printf () {
  i=0
  while [ "${i}" -lt "${2}" ]; do
    printf -- "${1}"
    i=$(( ${i} + 1 ))
  done
}

_arg_judge () {
  NUM="$(echo ${1} | grep -c "[^0-9]")"
  if [ "${NUM}" -gt 0 ]; then
    printf -- "\n  Error option: ${2}\n"
    _option_help
    exit 1
  fi
}

_debug_spec_func () {
  GPU_ASIC="NAVI10"
  CARD_NAME="Navi10 Card"
#   export GPU_FAMILY="74"
  CHIP_CLASS="12"
  MAX_SE="2"
  SA_PER_SE="2"

  CU_PER_SA="10"
  MIN_CU_PER_SA="8"

  MAX_SHADER_CLOCK="2000"
  NUM_RB="16"
  L2_CACHE="$(( 4096 * 1024 ))"
  NUM_L2_CACHE_BLOCK="16"
  VRAM_BIT_WIDTH="256"
  VRAM_TYPE="9"
  MEMORY_CLOCK="875"

  RB_PLUS="0"
}

_option_help () {

printf -- "\nUsage:\n  $(basename ${0}) [FLAGS] [OPTION]...
\nFLAGS:
  -ni, -noinfo\t\t\tdo not display spec list
  -nd, -nodia\t\t\tdo not display diagram
  -nogfx\t\t\tdo not display gfx block (for diagram)
  \t\t\t\t  (RB, Rasterizer/Primitive, Geometry)
  -rbplus\t\t\tRB+ force-enable (for override)
  \t\t\t\t  (RB = 4ROP, RB+ = 8ROP) 
  -h, --help\t\t\tdisplay this help and exit
\nOPTIONS:
  --col=NUM\t\t\tsetting number of diagram column (default: 2)
  --arch=gfx(9|10|10.3)\t\toverride GFX IP/Architecture
  --se=NUM\t\t\toverride number of ShaderEngine
  --sa-per-se=NUM\t\toverride number of ShaderArray per ShaderEngine
  --cu-per-sa=NUM\t\toverride number of CU per ShaderArray
  --min-cu-per-sa=NUM\t\toverride number of min CU per ShaderArray
  --rb=NUM\t\t\toverride number of RenderBackend
  --l2c-block=NUM\t\toverride number of L2cache block
  --l2c-cache=NUM\t\toverride L2cache size (MB)
\n"
#  \n  -image\t\t\toutput image of diagram
#  \t\t\t\t  output to: /tmp/<GPU_NAME>-diagram.png
#  \t\t\t\t  requirement: imagemagick, \"Dejavu Sans Mono\" font
}

amdgpu_var () {
  export ${1}=0
  export ${1}="$( echo ${GPUINFO} | grep " ${2} =" | sed -e "s/^.*${2}\ \=\ //g" )"
  # export ${1}="$( echo ${GPUINFO} | grep " ${2} =" | cut -d " " -f7 )"
  #   debug
  #   eval echo "${1} : "'$'${1}""
}

amdgpu_var "GPU_ASIC" "name"
amdgpu_var "CARD_NAME" "marketing_name"
amdgpu_var "GPU_FAMILY" "family"
amdgpu_var "CHIP_CLASS" "chip_class"

amdgpu_var "MAX_SE" "max_se"
amdgpu_var "CU_PER_SA" "max_good_cu_per_sa"
amdgpu_var "MIN_CU_PER_SA" "min_good_cu_per_sa"
amdgpu_var "MAX_SHADER_CLOCK" "max_shader_clock"

amdgpu_var "L2_CACHE" "l2_cache_size"
amdgpu_var "NUM_L2_CACHE_BLOCK" "num_tcc_blocks"

amdgpu_var "VRAM_TYPE" "vram_type"
amdgpu_var "VRAM_BIT_WIDTH" "vram_bit_width"
amdgpu_var "VRAM_MAX_SIZE" "vram_size"
amdgpu_var "MEMORY_CLOCK" "max_memory_clock"
amdgpu_var "VRAM_VIS_SIZE" "vram_vis_size"
amdgpu_var "VRAM_ALL_VIS" "all_vram_visible"
amdgpu_var "DEDICATED_VRAM" "has_dedicated_vram"

VRAM_MAX_SIZE="${VRAM_MAX_SIZE%\ MB}"
VRAM_VIS_SIZE="${VRAM_VIS_SIZE%\ MB}"

amdgpu_var "RB_PLUS" "rbplus_allowed"
amdgpu_var "HAS_GFX" "has_graphics"

if [ $(echo ${GPUINFO} | grep -c "max_sa_per_se") = 1 ]; then
  amdgpu_var "SA_PER_SE" "max_sa_per_se"
else
  amdgpu_var "SA_PER_SE" "max_sh_per_se"
fi

if [ $(echo ${GPUINFO} | grep -c "max_render_backends") = 1 ]; then
  amdgpu_var "NUM_RB" "max_render_backends"
else
  amdgpu_var "NUM_RB" "num_render_backends"
fi

DEBUG_SPEC=0
NO_INFO=0
NO_DIAGRAM=0
# HAS_GFX="0"
COL=2
IMAGE=0

for opt in ${@}; do
  case ${opt} in
  "-d")
    DEBUG_SPEC="1"
    _debug_spec_func ;;
  "--col="*)
    _arg_judge ${opt#--col=} ${opt}
    COL="${opt#--col=}" ;;
  "-ni"|"-noinfo")
    NO_INFO="1" ;;
  "-nd"|"-nodia")
    NO_DIAGRAM="1" ;;
  "-nogfx")
    HAS_GFX="0" ;;
  "--arch="*)
    if [ "${opt#--arch=}" = "gfx9" ]; then
      GPU_ASIC="VEGA10 pseudo"
      CHIP_CLASS="11"
    elif [ "${opt#--arch=}" = "gfx10" ]; then
      GPU_ASIC="NAVI10 pseudo"
      CHIP_CLASS="12"
    elif [ "${opt#--arch=}" = "gfx10.3" ]; then
      GPU_ASIC="SIENNA_CICHLID pseudo"
      CHIP_CLASS="13"
      RB_PLUS="1"
    else
      printf -- "\n Error: ${opt}\n"
      exit 1
    fi
      NUM_L2_CACHE_BLOCK="16"
      L2_CACHE="$(( 4096 * 1024 ))"
    ;;
  "--se="*)
    _arg_judge ${opt#--se=} ${opt}
    MAX_SE="${opt#--se=}" ;;
  "--sa-per-se="*)
    _arg_judge ${opt#--sa-per-se=} ${opt}
    SA_PER_SE="${opt#--sa-per-se=}" ;;
  "--cu-per-sa="*)
    _arg_judge ${opt#--cu-per-sa=} ${opt}
    CU_PER_SA="${opt#--cu-per-sa=}" 
    MIN_CU_PER_SA="${opt#--cu-per-sa=}" ;;
  "--min-cu-per-sa="*)
    _arg_judge ${opt#--min-cu-per-sa=} ${opt}
    MIN_CU_PER_SA="${opt#--min-cu-per-sa=}" ;;
  "--rb="*)
    _arg_judge ${opt#--rb=} ${opt}
    NUM_RB="${opt#--rb=}" ;;
  "-rbplus")
    RB_PLUS="1" ;;
  "--l2c-block="*)
    _arg_judge ${opt#--l2c-block=} ${opt}
    NUM_L2_CACHE_BLOCK="${opt#--l2c-block=}" ;;
  "--l2c-size="*)
    _arg_judge ${opt#--l2c-size=} ${opt}
    L2_CACHE="$(( ${opt#--l2c-size=} * 1024 * 1024))" ;;
  "-image")
    IMAGE=1 ;;
  "-h"|"--help")
    _option_help
    exit 0 ;;
  *)
    printf -- "\n Error option: ${opt}\n"
    _option_help
    exit 1 ;;
  esac
done

_info_list_func () {

if [ "${DEDICATED_VRAM}" = "1" ]; then
  GPU_TYPE="Discrete GPU"
else
  GPU_TYPE="APU"
fi

#  https://gitlab.freedesktop.org/mesa/mesa/-/blob/master/src/amd/common/amd_family.h
case "${CHIP_CLASS}" in
  1)    DEC_CHIP_CLASS="R300" ;;
  2)    DEC_CHIP_CLASS="R400" ;;
  3)    DEC_CHIP_CLASS="R500" ;;
  4)    DEC_CHIP_CLASS="R600" ;;
  5)    DEC_CHIP_CLASS="R700" ;;
  6)    DEC_CHIP_CLASS="EVERGREEN" ;;
  7)    DEC_CHIP_CLASS="CAYMAN" ;;
  8)    DEC_CHIP_CLASS="GFX6" ;;
  9)    DEC_CHIP_CLASS="GFX7" ;;
  10)   DEC_CHIP_CLASS="GFX8" ;;
  11)   DEC_CHIP_CLASS="GFX9" ;;
  12)   DEC_CHIP_CLASS="GFX10" ;;
  13)   DEC_CHIP_CLASS="GFX10_3" ;;
  0|*)  DEC_CHIP_CLASS="Unknown" ;;
esac

printf "\n\
Driver Version:\t\t${MESA_DRIVER_VER}\n
GPU ASIC:\t\t${GPU_ASIC}
Chip class:\t\t${DEC_CHIP_CLASS}
Marketing Name:\t\t${CARD_NAME}
GPU Type:\t\t${GPU_TYPE}
\n"

if [ "${CHIP_CLASS}" -ge 12 ] && [ "${CU_PER_SA}" != "${MIN_CU_PER_SA}" ]; then
  NUM_CU="$(( ${MAX_SE} * ( ${CU_PER_SA} + ${MIN_CU_PER_SA} ) ))"
else
  NUM_CU="$(( ${MAX_SE} * ${SA_PER_SE} * ${CU_PER_SA} ))"
fi

if [ "${CHIP_CLASS}" -ge 12 ]; then
  printf "WorkGroup Processors:\t %3d WGP (%d CU)\n" $(( ${NUM_CU} / 2)) ${NUM_CU}
else 
  printf "Compute Units:\t\t%4d CU\n" ${NUM_CU}
fi

MIN_SCLK="$(head -n1 ${PCIBUS}/pp_dpm_sclk | sed -E "s/(^0:\ |Mhz.*$)//g")"
MAX_SCLK="$(tail -n1 ${PCIBUS}/pp_dpm_sclk | sed -E "s/(^.*:\ |Mhz.*$)//g")"
printf "\
GFX Clock Range:\t%4d MHz - %4d MHz
Peak GFX Clock:\t\t%4d MHz
\n" \
${MIN_SCLK} ${MAX_SCLK} \
${MAX_SHADER_CLOCK}

PEAK_FP32="$(echo "scale=2;${NUM_CU} * 64 * ${MAX_SHADER_CLOCK} * 2 / 1000 / 1000" | bc )"
if [ "${CHIP_CLASS}" -ge 11 ]; then
  PEAK_FP16="$(echo "scale=2; ${PEAK_FP32} * 2" | bc )"
else
  PEAK_FP16="${PEAK_FP32}"
fi

printf "\
Peak FP16:\t\t%5.2f TFlops
Peak FP32:\t\t%5.2f TFlops
\n" \
${PEAK_FP16} \
${PEAK_FP32}

if [ "${RB_PLUS}" = 0 ]; then
  NUM_ROP="$(( ${NUM_RB} * 4 ))"
else
  NUM_ROP="$(( ${NUM_RB} * 8 ))"
fi

printf "\
RBs (Render Backends):\t\t%3d RB (%d ROP)
Peak Pixel Fill-Rate:\t\t%6.2f GP/s
TMUs (Texture Mapping Units):\t%3d TMU
Peak Texture Fill-Rate:\t\t%6.2f GT/s
\n" \
${NUM_RB} ${NUM_ROP} \
$(echo "scale=2;${NUM_ROP} * ${MAX_SHADER_CLOCK} / 1000" | bc ) \
$(( ${NUM_CU} * 4 )) \
$(echo "scale=2;${NUM_CU} * 4 * ${MAX_SHADER_CLOCK} / 1000" | bc) \

#  https://gitlab.freedesktop.org/mesa/drm/-/blob/2420768d023e0c257d2752a5c212d5dd3528a249/include/drm/amdgpu_drm.h#L938
#  https://cgit.freedesktop.org/~agd5f/linux/commit/drivers/gpu/drm/amd?h=amd-staging-drm-next&id=a01dd4fe8e62b18a16edccda840361c022940125
case "${VRAM_TYPE}" in
  1) #  GDDR1
    VRAM_MODULE="GDDR1" ;;
  2) #  DDR2
    VRAM_MODULE="DDR2" ;;
  3) #  GDDR3
    VRAM_MODULE="GDDR3"
    DATA_RATE="$(( ${MEMORY_CLOCK} * 2 ))" ;;
  4)
    VRAM_MODULE="GDDR4" ;;
  5) #  GDDR5
    VRAM_MODULE="GDDR5"
    DATA_RATE="$(( ${MEMORY_CLOCK} * 4 ))" ;;
  6) #  HBM/2
    VRAM_MODULE="HBM"
    DATA_RATE="$(( ${MEMORY_CLOCK} * 2 ))" ;;
  9) #  GDDR6
    VRAM_MODULE="GDDR6"
    DATA_RATE="$(( ${MEMORY_CLOCK} * 2 * 8 ))" ;;
  7) #  DDR3/4
    VRAM_MODULE="DDR3"
    DATA_RATE="$(( ${MEMORY_CLOCK} ))" ;;
  8) #  DDR3/4
    VRAM_MODULE="DDR4"
    DATA_RATE="$(( ${MEMORY_CLOCK} ))" ;;
  0|*)
    VRAM_MODULE="Unknown" ;;
esac

if [ "${VRAM_TYPE}" -le 2 ] || [ "${VRAM_TYPE}" = 4 ]; then
  VRAM_MBW="Unknown"
else
  VRAM_MBW="$(( ${VRAM_BIT_WIDTH} / 8 * ${DATA_RATE} / 1000 ))"
fi

MIN_MCLK="$(head -n1 ${PCIBUS}/pp_dpm_mclk | sed -E "s/(^0:\ |Mhz.*$)//g")"
MAX_MCLK="$(tail -n1 ${PCIBUS}/pp_dpm_mclk | sed -E "s/(^.*:\ |Mhz.*$)//g")"
printf "\
VRAM Type:\t\t%9s
VRAM Size:\t\t%6d MB
VRAM Bit Width:\t\t%6d-bit
Memory Clock Range:\t%6d MHz - %4d MHz
Peak Memory Clock:\t%6d MHz
Peak VRAM Bandwidth:\t%9.2f GB/s
\n" \
${VRAM_MODULE} \
${VRAM_MAX_SIZE} \
${VRAM_BIT_WIDTH} \
${MIN_MCLK} ${MAX_MCLK} \
${MEMORY_CLOCK} \
${VRAM_MBW}

#  correct AMDGPU L2cache Size, maybe (GFX9+)
#  https://gitlab.freedesktop.org/mesa/mesa/-/blob/master/src/amd/common/ac_gpu_info.c

case "${GPU_ASIC}" in
  RAVEN2)
    L2_CACHE="$((  512 * 1024 ))" ;;
  RAVEN|RENOIR)
    L2_CACHE="$(( 1024 * 1024 ))" ;;
  VEGA12|NAVI14)
    L2_CACHE="$(( 2048 * 1024 ))" ;;
esac

printf "\
L2 Cache Blocks:\t%3d Block
L2 Cache Size:\t\t%3d MB (%d KB)
\n" ${NUM_L2_CACHE_BLOCK} $(( ${L2_CACHE} / 1024 / 1024 )) $(( ${L2_CACHE} / 1024 ))

POWER_CAP="$(( $(cat ${PCIBUS}/hwmon/hwmon0/power1_cap) / 1000 / 1000 ))"
printf -- "Power cap:\t\t%3d W\n\n" ${POWER_CAP}

PCIE_SPEED="$(cat ${PCIBUS}/current_link_speed | sed -e "s/\ GT\/s\ PCIe//g")"
case "${PCIE_SPEED}" in
  "2.5")    PCIE_GEN="1" ;;
  "5.0")    PCIE_GEN="2" ;;
  "8.0")    PCIE_GEN="3" ;;
  "16.0")   PCIE_GEN="4" ;;
esac

printf -- "\
Card Interface:\t\tPCIe Gen%1d x%-2d
\n" \
${PCIE_GEN} $(cat ${PCIBUS}/current_link_width)

if [ ${VRAM_MAX_SIZE} = ${VRAM_VIS_SIZE} ] || [ ${VRAM_ALL_VIS} = 1 ]; then
  printf "AMD Smart Access Memory\n"
fi
}

_draw_cu_wgp () {
  if [ "${CHIP_CLASS}" -ge 12 ]; then
    UNIT_NAME="WGP"
    tmp_unit_count="$(( ${CU_PER_SA} / 2 ))"
  else
    UNIT_NAME="CU"
    tmp_unit_count="${CU_PER_SA}"
  fi

  if [ "${sh}" = 0 ] && [ "${CU_PER_SA}" != "${MIN_CU_PER_SA}" ]; then
    tmp_unit_count="$(( ${MIN_CU_PER_SA} / 2 ))"
  fi

  unit_count=0
  while [ "${unit_count}" -lt "${tmp_unit_count}" ]; do
    c=0
    while [ "${c}" -lt "${COL}" ]; do
      printf " | |  "
      printf "==== ===="
      printf "  %-3s(%02d) " "${UNIT_NAME}" "${unit_count}"
      printf "==== ===="
      printf "  | | "
      c=$(( ${c} + 1 ))
        if [ "$(( ${c} + ${se} ))" -ge "${MAX_SE}" ]; then
          break
        fi
    done
      printf "\n"
      unit_count=$(( ${unit_count} + 1 ))
  done
}

_draw_rb () {
  RBF="${RB_PER_SE}"

  if [ "${RB_PLUS}" = 1 ]; then
    RB_TYPE="[ RB+ ]"
  else
    RB_TYPE="[ RB ]"
  fi

  while [ "${RB_PER_SA}" -gt 0 ]; do
    c=0
    while [ "${c}" -lt "${COL}" ]; do
      printf " | |  "
  
      if [ "${RB_PER_SA}" -gt 4 ]; then
        rb_tmp="4"
      else
        rb_tmp="${RB_PER_SA}"
      fi
  
    rbcount=0
    while [ "${rbcount}" -lt "${rb_tmp}" ]; do
      printf "%-7s" ${RB_TYPE}
      rbcount=$(( ${rbcount} + 1 ))
    done
  
    fill=${rb_tmp}
    while [ "${fill}" -lt 4 ]; do
      _repeat_printf " " "7"
      fill=$(( ${fill} + 1 ))
    done
  
    printf "  | | "
  
    c=$(( ${c} + 1 ))
      if [ "$(( ${c} + ${se} ))" -ge "${MAX_SE}" ]; then
        break
      fi
    done
    printf "\n"
  
    RB_PER_SA=$(( ${RB_PER_SA} - 4))
  done # RB end
}

_draw_rdna_l1c () {
  RDNA_L1C_SIZE="128"
  c=0
  while [ "${c}" -lt "${COL}" ]; do
    printf " | |"
    _repeat_printf " " "8"
    printf "[- L1$ ${RDNA_L1C_SIZE}KB -]"
    _repeat_printf " " "9"
    printf "| | "
    c=$(( ${c} + 1 ))
      if [ "$(( ${c} + ${se} ))" -ge "${MAX_SE}" ]; then
        break
      fi
  done
  printf "\n"
}

_draw_raster_prim () {
  c=0
  while [ "${c}" -lt "${COL}" ]; do
    printf " | |  [ Rasterizer/Primitive Unit ] | | "
    c=$(( ${c} + 1 ))
      if [ "$(( ${c} + ${se} ))" -ge "${MAX_SE}" ]; then
        break
      fi
  done
  printf "\n"
}

_draw_geometry () {
  c=0
  while [ "${c}" -lt "${COL}" ]; do
    printf " |"
    _repeat_printf " " "6"
    printf "[- Geometry Processor -]"
    _repeat_printf " " "6"
    printf "| "
    c=$(( ${c} + 1 ))
    if [ "$(( ${c} + ${se} ))" -ge "${MAX_SE}" ]; then
      break
    fi
  done
  printf "\n"
}

_draw_l2c () {
  L2C_SIZE="$(( ${L2_CACHE} / ${NUM_L2_CACHE_BLOCK} / 1024 ))"
  L2CBF="${NUM_L2_CACHE_BLOCK}"
  L2C_COL="4"
  while [ "${L2CBF}" -gt 0 ]; do
  
    if [ "${L2CBF}" -gt "${L2C_COL}" ]; then
      l2cb_tmp="${L2C_COL}"
    else
      l2cb_tmp="${L2CBF}"
    fi
  
    l2c=0
    while [ "${l2c}" -lt "${l2cb_tmp}" ]; do
      _repeat_printf " " "$( echo "${COL}^3" | bc )"
      printf "[L2$ %3dK]" ${L2C_SIZE}
      l2c=$(( ${l2c} + 1 ))
    done
    printf "\n"
  
    L2CBF="$(( ${L2CBF} - ${L2C_COL} ))"
  
  done # L2cache end
}

_diagram_draw_func () {

printf "\n\n## ${GPU_ASIC} Diagram\n"

# ShaderEngine
se=0
while [ "${se}" -lt "${MAX_SE}" ]; do

  printf "\n"
  c=0
  while [ "${c}" -lt "${COL}" ]; do
    printf " +- ShaderEngine(%02d) " $(( ${c} + ${se} ))
    _repeat_printf "-" "17"
    printf "+ "
    c=$(( ${c} + 1 ))
    if [ "$(( ${c} + ${se} ))" -ge "${MAX_SE}" ]; then
      break
    fi
  done
  printf "\n"
 
  # ShderArray
  sh=0
  while [ "${sh}" -lt "${SA_PER_SE}" ]; do

  c=0
  while [ "${c}" -lt "${COL}" ]; do
    printf -- " | +- ShaderArray(%02d) " ${sh}
    _repeat_printf "-" "14"
    printf "+ | "
    c=$(( ${c} + 1 ))
      if [ "$(( ${c} + ${se} ))" -ge "${MAX_SE}" ]; then
        break
      fi
  done
  printf "\n"

  _draw_cu_wgp

  RB_PER_SA="$(( ${NUM_RB} / ${MAX_SE} / ${SA_PER_SE} ))"

  if [ "${RB_PER_SA}" -ge 1 ] && \
     [ "${HAS_GFX}" = 1 ] && \
     [ "$(( ${NUM_RB} % (${MAX_SE} * ${SA_PER_SE}) ))" -lt 1 ]; then
    _draw_rb
  fi

  if [ "${CHIP_CLASS}" -ge 12 ]; then
    _draw_rdna_l1c
  fi

  if [ "${HAS_GFX}" = 1 ]; then
    _draw_raster_prim
  fi

  # ShaderArray last line
  c=0
  while [ "${c}" -lt "${COL}" ]; do
    printf " | +"
    _repeat_printf "-" "32"
    printf "+ | "
    c=$(( ${c} +  1 ))
      if [ "$(( ${c} + ${se} ))" -ge "${MAX_SE}" ]; then
        break
      fi
  done
  printf "\n"

  sh=$(( ${sh} + 1 ))
  done # ShaderArray end

  if [ "${HAS_GFX}" = 1 ]; then
    _draw_geometry
  fi

  # ShadeEngine last line
  c=0
  while [ "${c}" -lt "${COL}" ]; do
    printf " +"
    _repeat_printf "-" "36"
    printf "+ "
    c=$(( ${c} +  1 ))
      if [ "$(( ${c} + ${se} ))" -ge "${MAX_SE}" ]; then
        break
      fi
  done
  printf "\n"

  se=$(( ${se} + ${COL} ))
done # ShaderEngine end

  _draw_l2c

  printf "\n"
}

# not work with ImageMagick 6.9.11-24
<<TOIMAGE
if [ ${IMAGE} = 1 ]; then
#  OUTPUT="/tmp/$(echo ${GPU_ASIC} | tr '[:upper:]' '[:lower:]')-diagram.png"
  OUTPUT="/tmp/${GPU_ASIC}-diagram.png"
  convert -background white -fill black -family "Dejavu Sans Mono" -density 144 label:"$(_diagram_draw_func)" ${OUTPUT}
  IMAGE_PID="$(echo $!)"
  wait ${IMAGE_PID}
  printf "\noutput image to ${OUTPUT}\n\n"
fi
TOIMAGE

if [ "${NO_INFO}" != 1 ]; then
  _info_list_func
fi

if [ "${NO_DIAGRAM}" != 1 ]; then
  _diagram_draw_func
fi
