#!/bin/bash
IFS=''
GPUINFO="$(env AMD_DEBUG=info glxinfo -B)"
PCIBUS="/sys/bus/pci/devices/$(echo ${GPUINFO} | grep "pci (domain:bus:dev.func)" | sed -e "s/^.*func):\ //g")"
MESA_DRIVER_VER="$(echo ${GPUINFO} | grep "OpenGL core profile version" | sed -e "s/^.*Core\ Profile)\ //g")"

# echo ${GPUINFO}

_repeat_printf () {
   i=0
   while [ ${i} -lt ${2} ]; do
      printf -- "${1}"
      i=$(( ${i} + 1 ))
   done
}

_arg_judge () {
   NUM="$(echo ${1} | grep -c "[^0-9]")"
   if [ ${NUM} -gt 0 ]; then
      printf -- "\n  Error option: ${2}\n"
      exit 1
   fi
}

_debug_spec_func () {
   export GPU_ASIC="NAVI10"
   export CARD_NAME="Navi10 Card"
#   export GPU_FAMILY="74"
   export CHIP_CLASS="12"
   export MAX_SE="2"
   export SA_PER_SE="2"

   export CU_PER_SA="10"
   export MIN_CU_PER_SA="8"

   export MAX_SHADER_CLOCK="2000"
   export NUM_RB="16"
   export L2_CACHE="$(( 4096 * 1024 ))"
   export NUM_L2_CACHE_BLOCK="16"
   export VRAM_BIT_WIDTH="256"
   export VRAM_TYPE="9"
   export MEMORY_CLOCK="875"

   export RB_PLUS="0"
}

amdgpu_var () {
   export ${1}=0
   export ${1}="$( echo ${GPUINFO} | grep " ${2} =" | sed -e "s/^.*${2}\ \=\ //g" )"
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
amdgpu_var "NO_GFX" "has_graphics"

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

DEBUG_SPEC="0"
NO_INFO="0"
NO_DIAGRAM="0"
NO_GFX="0"

for opt in ${@}; do
   case ${opt} in
      "-d")
         DEBUG_SPEC="1"
         _debug_spec_func ;;
      "-noinfo")
         NO_INFO="1" ;;
      "-nodia")
         NO_DIAGRAM="1" ;;
      "-nogfx")
         NO_GFX="1" ;;
      "--arch="*)
         if [ ${opt#--arch=} = "gfx9" ]; then
            GPU_ASIC="VEGA10 pseudo"
            CHIP_CLASS="11"
         elif [ ${opt#--arch=} = "gfx10" ]; then
            GPU_ASIC="NAVI10 pseudo"
            CHIP_CLASS="12"
         elif [ ${opt#--arch=} = "gfx10.3" ]; then
            GPU_ASIC="SIENNA_CICHLID pseudo"
            CHIP_CLASS="13"
            RB_PLUS="1"
         else
            printf -- "\n Error: ${opt}\n"
            exit 1
         fi ;;
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
      "--rb="*)
         _arg_judge ${opt#--rb=} ${opt}
         NUM_RB="${opt#--rb=}" ;;
      "-rbplus")
         RB_PLUS="1" ;;
      *)
         printf -- "\n Error option: ${opt}\n"
         exit 1
   esac
done

if [ ${GPU_ASIC} = "ARCTURUS" ]; then
   NO_GFX="1"
fi

_info_list_func () {

if [ ${DEDICATED_VRAM} = 1 ]; then
   GPU_TYPE="Discrete GPU"
else
   GPU_TYPE="APU"
fi

#  https://gitlab.freedesktop.org/mesa/mesa/-/blob/master/src/amd/common/amd_family.h

case ${CHIP_CLASS} in
   1)
      DEC_CHIP_CLASS="R300" ;;
   2)
      DEC_CHIP_CLASS="R400" ;;
   3)
      DEC_CHIP_CLASS="R500" ;;
   4)
      DEC_CHIP_CLASS="R600" ;;
   5)
      DEC_CHIP_CLASS="R700" ;;
   6)
      DEC_CHIP_CLASS="EVERGREEN" ;;
   7)
      DEC_CHIP_CLASS="CAYMAN" ;;
   8)
      DEC_CHIP_CLASS="GFX6" ;;
   9)
      DEC_CHIP_CLASS="GFX7" ;;
   10)
      DEC_CHIP_CLASS="GFX8" ;;
   11)
      DEC_CHIP_CLASS="GFX9" ;;
   12)
      DEC_CHIP_CLASS="GFX10" ;;
   13)
      DEC_CHIP_CLASS="GFX10_3" ;;
   0|*)
      DEC_CHIP_CLASS="Unknown" ;;
esac

printf "\n\
Driver Version:\t\t${MESA_DRIVER_VER}\n\n\
GPU ASIC:\t\t${GPU_ASIC}\n\
Chip class:\t\t${DEC_CHIP_CLASS}\n\
Marketing Name:\t\t${CARD_NAME}\n\
GPU Type:\t\t${GPU_TYPE}\n\
\n"

if [ ${CHIP_CLASS} -ge 12 ] && [ ${CU_PER_SA} != ${MIN_CU_PER_SA} ]; then
   NUM_CU="$(( ${MAX_SE}  * ${SA_PER_SE} / 2 * ( ${CU_PER_SA} + ${MIN_CU_PER_SA} ) ))"
else
   NUM_CU="$(( ${MAX_SE} * ${SA_PER_SE} * ${CU_PER_SA} ))"
fi

if [ ${CHIP_CLASS} -ge 12 ]; then
   printf "WorkGroup Processors:\t %3d WGP (%d CU)\n" $(( ${NUM_CU} / 2)) ${NUM_CU}
else 
   printf "Compute Units:\t\t%4d CU\n" ${NUM_CU}
fi

printf "\
GFX Clock Range:\t%4d MHz - %4d MHz\n\
Peak GFX Clock:\t\t%4d MHz\n\
\n" \
$(head -n1 ${PCIBUS}/pp_dpm_sclk | sed -E "s/(^0:\ |Mhz.*$)//g") $(tail -n1 ${PCIBUS}/pp_dpm_sclk | sed -E "s/(^.*:\ |Mhz.*$)//g") \
${MAX_SHADER_CLOCK}

PEAK_FP32="$(echo "scale=2;${NUM_CU} * 64 * ${MAX_SHADER_CLOCK} * 2 / 1000 / 1000" | bc )"
if [ ${CHIP_CLASS} -ge 11 ]; then
   PEAK_FP16="$(echo "scale=2; ${PEAK_FP32} * 2" | bc )"
else
   PEAK_FP16="${PEAK_FP32}"
fi

printf "\
Peak FP16:\t\t%5.2f TFlops\n\
Peak FP32:\t\t%5.2f TFlops\n\
\n" \
${PEAK_FP16} \
${PEAK_FP32}

if [ ${RB_PLUS} = 0 ]; then
   NUM_ROP="$(( ${NUM_RB} * 4 ))"
else
   NUM_ROP="$(( ${NUM_RB} * 8 ))"
fi

printf "\
RBs (Render Backends):\t\t%3d RB (%d ROP)\n\
Peak Pixel Fill-Rate:\t\t%6.2f GP/s\n\
TMUs (Texture Mapping Units):\t%3d TMU\n\
Peak Texture Fill-Rate:\t\t%6.2f GT/s\n\
\n" \
${NUM_RB} ${NUM_ROP} \
$(echo "scale=2;${NUM_ROP} * ${MAX_SHADER_CLOCK} / 1000" | bc ) \
$(( ${NUM_CU} * 4 )) \
$(echo "scale=2;${NUM_CU} * 4 * ${MAX_SHADER_CLOCK} / 1000" | bc) \

#  https://gitlab.freedesktop.org/mesa/drm/-/blob/2420768d023e0c257d2752a5c212d5dd3528a249/include/drm/amdgpu_drm.h#L938
#  https://cgit.freedesktop.org/~agd5f/linux/commit/drivers/gpu/drm/amd?h=amd-staging-drm-next&id=a01dd4fe8e62b18a16edccda840361c022940125

case ${VRAM_TYPE} in
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

if [ ${VRAM_TYPE} -le 2 ] || [ ${VRAM_TYPE} = 4 ]; then
   VRAM_MBW="Unknown"
else
   VRAM_MBW="$(( ${VRAM_BIT_WIDTH} / 8 * ${DATA_RATE} / 1000 ))"
fi

printf "\
VRAM Type:\t\t%9s\n\
VRAM Size:\t\t%6d MB\n\
VRAM Bit Width:\t\t%6d-bit\n\
Memory Clock Range:\t%6d MHz - %4d MHz\n\
Peak Memory Clock:\t%6d MHz\n\
Peak VRAM Bandwidth:\t%9.2f GB/s\n\
\n" \
${VRAM_MODULE} \
${VRAM_MAX_SIZE} \
${VRAM_BIT_WIDTH} \
$(head -n1 ${PCIBUS}/pp_dpm_mclk | sed -E "s/(^0:\ |Mhz.*$)//g") $(tail -n1 ${PCIBUS}/pp_dpm_mclk | sed -E "s/(^.*:\ |Mhz.*$)//g") \
${MEMORY_CLOCK} \
${VRAM_MBW}

#  correct AMDGPU L2cache Size, maybe (GFX9+)
#  https://gitlab.freedesktop.org/mesa/mesa/-/blob/master/src/amd/common/ac_gpu_info.c

case ${GPU_ASIC} in
   RAVEN2)
      L2_CACHE="$(( 512 * 1024 ))"  ;;
   RAVEN|RENOIR)
      L2_CACHE="$(( 1024 * 1024 ))" ;;
   VEGA12|NAVI14)
      L2_CACHE="$(( 2048 * 1024 ))" ;;
   *)
esac

printf "\
L2 Cache Blocks:\t%3d Block\n\
L2 Cache Size:\t\t%3d MB (%d KB)\n\n\
" ${NUM_L2_CACHE_BLOCK} $(( ${L2_CACHE} / 1024 / 1024 )) $(( ${L2_CACHE} / 1024 ))

if [ ${VRAM_MAX_SIZE} = ${VRAM_VIS_SIZE} ] || [ ${VRAM_ALL_VIS} = 1 ]; then
   printf "AMD Smart Access Memory\n"
fi
}

_diagram_draw_func () {

printf "\n## ${GPU_ASIC} Diagram\n\n"

se=0
while [ ${se} -lt ${MAX_SE} ]; do

   printf " +- ShaderEngine(%02d) " ${se}
   _repeat_printf "--" "10"
   printf "+\n"

   sh=0
   while [ ${sh} -lt ${SA_PER_SE} ]; do

  #   printf " | "
  #   _repeat_printf " " "37"
  #   printf " | \n"
      printf " | +- ShaderArray(%02d) " ${sh}
      _repeat_printf "-" "17"
      printf "+ |\n"

      if [ ${CHIP_CLASS} -ge 12 ]; then
         UNIT_NAME="WGP"
         TMP_UNIT_COUNT="$(( ${CU_PER_SA} / 2 ))"
      else
         UNIT_NAME="CU"
         TMP_UNIT_COUNT="${CU_PER_SA}"
      fi

      if [ ${sh} = 0 ] && [ ${CU_PER_SA} != ${MIN_CU_PER_SA} ]; then
         TMP_UNIT_COUNT="$(( ${MIN_CU_PER_SA} / 2 ))"
      fi

      unit_count=0
      while [ ${unit_count} -lt ${TMP_UNIT_COUNT} ]; do
         printf " | |  "
         _repeat_printf "=" "4"
         printf "  "
         _repeat_printf "=" "4"
         printf "  %3s(%02d)  " ${UNIT_NAME} ${unit_count}
         _repeat_printf "=" "4"
         printf "  "
         _repeat_printf "=" "4"
         printf "  | |\n"
         unit_count=$(( ${unit_count} + 1 ))
      done


RB_PER_SA="$(( ${NUM_RB} / ${MAX_SE} / ${SA_PER_SE} ))"
RBF="${RB_PER_SE}"

   if ! [ ${RB_PER_SA} -lt 1 ] && [ ${NO_GFX} != 1 ] && ! [ $(( ${NUM_RB} % (${MAX_SE} * ${SA_PER_SE}) )) -gt 0 ]; then
      while [ ${RB_PER_SA} -gt 0 ]; do
         printf " | |  "

         if [ ${RB_PER_SA} -gt 4 ]; then
            RBTMP="4"
         else
            RBTMP="${RB_PER_SA}"
         fi

         rbcount=0
      if [ ${RB_PLUS} = 1 ]; then
         while [ ${rbcount} -lt ${RBTMP} ]; do
            printf "[ RB+ ]"
            printf " "
            rbcount=$(( ${rbcount} + 1 ))
         done
      else
         while [ ${rbcount} -lt ${RBTMP} ]; do
            printf "[ RB ]"
            printf "  "
            rbcount=$(( ${rbcount} + 1 ))
         done
      fi

         fill=${RBTMP}
         while [ ${fill} -lt 4 ]; do
            _repeat_printf " " "8"
            fill=$(( ${fill} + 1 ))
         done

         printf " | |\n"

         RB_PER_SA=$(( ${RB_PER_SA} - 4))
      done # RB end
   fi

if [ ${CHIP_CLASS} -ge 12 ]; then
RDNA_L1C_SIZE="128"
   printf " | |"
   _repeat_printf " " "9"
   printf "[-  L1$ ${RDNA_L1C_SIZE}KB  -]"
   _repeat_printf " " "9"
   printf "| |\n"
fi

if [ ${NO_GFX} != 1 ]; then
   printf " | | "
   printf "[-  Rasterizer/Primitive Unit  -]"
   printf " | |\n"
fi

   # ShaderArray last line
      printf " | +"
      _repeat_printf "-" "35"
      printf "+ |\n"

      sh=$(( ${sh} + 1 ))
   done # ShaderArray end

if [ ${NO_GFX} != 1 ]; then
   printf " |"
   _repeat_printf " " "8"
   printf "[- Geometry Processor -]"
   _repeat_printf " " "7"
   printf "|\n"
fi

printf " +"
_repeat_printf "-" "39"
printf "+\n\n"

se=$(( ${se} + 1 ))

done # ShaderEngine end

L2C_SIZE="$(( ${L2_CACHE} / ${NUM_L2_CACHE_BLOCK} / 1024 ))"
L2CBF="${NUM_L2_CACHE_BLOCK}"
while [ ${L2CBF} -gt 0 ]; do

   if [ ${L2CBF} -gt 4 ]; then
      L2CB_TMP="4"
   else
      L2CB_TMP="${L2CBF}"
   fi

   l2c=0
   while [ ${l2c} -lt ${L2CB_TMP} ]; do
      printf "[L2$ %3dK] " ${L2C_SIZE}
      l2c=$(( ${l2c} + 1 ))
   done
      printf "\n"

   L2CBF="$(( ${L2CBF} - 4 ))"

done # L2cache end

printf "\n"
}

if [ ${NO_INFO} != 1 ]; then
   _info_list_func
fi

if [ ${NO_DIAGRAM} != 1 ]; then
   _diagram_draw_func
fi
