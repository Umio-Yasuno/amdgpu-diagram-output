#!/bin/bash
IFS=''
GPUINFO="$(env AMD_DEBUG=info glxinfo -B)"
shopt -s expand_aliases
alias echo="echo -e"

# echo ${GPUINFO}

amdgpu_var () {
   export ${1}=0
   export ${1}="$( echo ${GPUINFO} | grep " ${2} =" | sed -e "s/^.*${2}\ \=\ //g" )"

#   debug
#   eval echo "${1} : "'$'${1}""
}

amdgpu_var "GPU_ASIC" "name"
amdgpu_var "CARD_NAME" "marketing_name"
amdgpu_var "GPU_FAMILY" "family"
amdgpu_var "MAX_SE" "max_se"

if [ $(echo ${GPUINFO} | grep "max_sa_per_se" &> /dev/null ; echo $?) -eq 0 ]; then
   amdgpu_var "SA_PER_SE" "max_sa_per_se"
else
   amdgpu_var "SA_PER_SE" "max_sh_per_se"
fi

amdgpu_var "CU_PER_SA" "max_good_cu_per_sa"
amdgpu_var "MIN_CU_PER_SA" "min_good_cu_per_sa"
amdgpu_var "MAX_SHADER_CLOCK" "max_shader_clock"

if [ $(echo ${GPUINFO} | grep "max_render_backends" &> /dev/null ; echo $?) -eq 0 ]; then
   amdgpu_var "NUM_RB" "max_render_backends"
else
   amdgpu_var "NUM_RB" "num_render_backends"
fi

amdgpu_var "L2_CACHE" "l2_cache_size"
amdgpu_var "NUM_L2_CACHE_BLOCK" "num_tcc_blocks"
amdgpu_var "VRAM_TYPE" "vram_type"
amdgpu_var "VRAM_BIT_WIDTH" "vram_bit_width"
amdgpu_var "VRAM_MAX_SIZE" "vram_size"
amdgpu_var "MEMORY_CLOCK" "max_memory_clock"

amdgpu_var "RB_PLUS" "rbplus_allowed"

amdgpu_var "VRAM_VIS_SIZE" "vram_vis_size"
amdgpu_var "VRAM_ALL_VIS" "all_vram_visible"
amdgpu_var "DEDICATED_VRAM" "has_dedicated_vram"

PCIBUS="/sys/bus/pci/devices/$(echo ${GPUINFO} | grep "pci (domain:bus:dev.func)" | sed -e "s/^.*func):\ //g")"
MESA_DRIVER_VER="$(echo ${GPUINFO} | grep "OpenGL core profile version" | sed -e "s/^.*Core\ Profile)\ //g")"

_debug_spec_func() {
   export GPU_ASIC="NAVI10"
   export CARD_NAME="Navi10 Card"
   export GPU_FAMILY="74"
   export MAX_SE="2"
   export SA_PER_SE="2"

   export CU_PER_SA="5"
   export MIN_CU_PER_SA="4"

   export MAX_SHADER_CLOCK="2000"
   export NUM_RB="16"
   export L2_CACHE="$(( 4096 * 1024 ))"
   export NUM_L2_CACHE_BLOCK="16"
   export VRAM_BIT_WIDTH="256"
   export VRAM_TYPE="9"
   export MEMORY_CLOCK="875"

   export RB_PLUS="0"
}

VRAM_MAX_SIZE="$(echo ${VRAM_MAX_SIZE} | sed -e "s/\ MB//g")"
VRAM_VIS_SIZE="$(echo ${VRAM_VIS_SIZE} | sed -e "s/\ MB//g")"

DEBUG_SPEC="0"
NO_DIAGRAM="0"

for opt in ${@}; do
   case ${opt} in
      "-d")
         DEBUG_SPEC="1" ;;
      "-n")
         NO_DIAGRAM="1" ;;
   esac
done

if [ ${DEBUG_SPEC} == 1 ]; then
   _debug_spec_func
fi

if [ ${DEDICATED_VRAM} == 1 ]; then
   GPU_TYPE="Discrete GPU"
else
   GPU_TYPE="APU"
fi

echo "\n\
Driver Version:\t\t${MESA_DRIVER_VER}\n\n\
GPU ASIC:\t\t${GPU_ASIC}\n\
Marketing Name:\t\t${CARD_NAME}\n\
GPU Type:\t\t${GPU_TYPE}\n\
"

if [ ${GPU_FAMILY} -ge 74 ] && [ ${CU_PER_SA} != ${MIN_CU_PER_SA} ]; then
   NUM_CU="$(( ${MAX_SE} * (${CU_PER_SA} + ${MIN_CU_PER_SA}) * 2 ))"
else
   NUM_CU="$(( ${MAX_SE} * ${SA_PER_SE} * ${CU_PER_SA} ))"
fi

if [ ${GPU_FAMILY} -ge 74 ]; then
   printf "WorkGroup Processors:\t %3d WGP (%d CU)\n" $(( ${NUM_CU} / 2)) ${NUM_CU}
else 
   printf "Compute Units:\t\t%4d CU\n" ${NUM_CU}
fi

printf "\
GFX Clock Range:\t%4d MHz - %4d MHz\n\
Peak GFX Clock:\t\t%4d MHz\n\
\n" $(head -n1 ${PCIBUS}/pp_dpm_sclk | sed -E "s/(^0:\ |Mhz.*$)//g") $(tail -n1 ${PCIBUS}/pp_dpm_sclk | sed -E "s/(^.*:\ |Mhz.*$)//g") ${MAX_SHADER_CLOCK}

#  https://gitlab.freedesktop.org/mesa/mesa/-/blob/master/src/amd/common/amd_family.h

if [ ${GPU_FAMILY} -ge 67 ]; then
   printf "Peak FP16 (Packed):\t%5.2f TFlops\n" $(echo "scale=2;${NUM_CU} * 64 * ${MAX_SHADER_CLOCK} * 2 / 1000 / 1000 * 2" | bc )
else
   printf "Peak FP16:\t\t%5.2f TFlops\n" $(echo "scale=2;${NUM_CU} * 64 * ${MAX_SHADER_CLOCK} * 2 / 1000 / 1000" | bc )
fi

printf "Peak FP32:\t\t%5.2f TFlops\n\n" $(echo "scale=2;${NUM_CU} * 64 * ${MAX_SHADER_CLOCK} * 2 / 1000 / 1000" | bc )

if [ ${RB_PLUS} == 0 ]; then
   printf "RBs (Render Backends):\t\t%3d RB (%d ROP)\n" ${NUM_RB} $(( ${NUM_RB} * 4 ))
else
   printf "RBs (Render Backends):\t\t%3d RB+ (%d ROP)" ${NUM_RB} $(( ${NUM_RB} * 8 ))
fi

printf "\
Peak Pixel Fill-Rate:\t\t%6.2f GP/s\n\
TMUs (Texture Mapping Units):\t%3d TMU\n\
Peak Texture Fill-Rate:\t\t%6.2f GT/s\n\n\
" $(echo "scale=2;${NUM_RB} * 4 * ${MAX_SHADER_CLOCK} / 1000" | bc ) $(( ${NUM_CU} * 4 )) $(echo "scale=2;${NUM_CU} * 4 * ${MAX_SHADER_CLOCK} / 1000" | bc)

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

printf "\
VRAM Type:\t\t%9s\n\
VRAM Size:\t\t%6d MB\n\
VRAM Bit Width:\t\t%6d-bit\n\
" ${VRAM_MODULE} ${VRAM_MAX_SIZE} ${VRAM_BIT_WIDTH}

if [ ${VRAM_TYPE} -le 2 ] || [ ${VRAM_TYPE} -eq 4 ]; then
   VRAM_MBW="Unknown"
else
   VRAM_MBW="$(( ${VRAM_BIT_WIDTH} / 8 * ${DATA_RATE} / 1000 ))"
fi

printf "\
Memory Clock Range:\t%6d MHz - %4d MHz\n\
Peak Memory Clock:\t%6d MHz\n\
Peak VRAM Bandwidth:\t%9.2f GB/s\n\
\n" $(head -n1 ${PCIBUS}/pp_dpm_mclk | sed -E "s/(^0:\ |Mhz.*$)//g") $(tail -n1 ${PCIBUS}/pp_dpm_mclk | sed -E "s/(^.*:\ |Mhz.*$)//g") ${MEMORY_CLOCK} ${VRAM_MBW}

printf "\
L2 Cache Blocks:\t%3d Block\n\
L2 Cache Size:\t\t%3d MB (%d KB)\n\n\
" ${NUM_L2_CACHE_BLOCK} $(( ${L2_CACHE} / 1024 / 1024 )) $(( ${L2_CACHE} / 1024 ))

if [ ${VRAM_MAX_SIZE} == ${VRAM_VIS_SIZE} ] || [ ${VRAM_ALL_VIS} == 1 ]; then
   echo "AMD Smart Access Memory\n"
fi

_diagram_draw_func () {

echo "\n## AMD GPU Diagram\n"

for (( se=0; se<${MAX_SE}; se++ )); do

   printf " +- ShaderEngine(${se}) -"
   printf -- '--'"%.s" {1..10}
   printf "+\n"

   for (( sh=0; sh<${SA_PER_SE}; sh++ )); do

      printf " | "
      printf -- ' '"%.s" {1..37}
      printf " | "
      printf "\n"
      printf " | +- ShaderArray(${sh}) "
      printf -- '--'"%.s" {1..9}
      printf "+ |\n"

      TMP_CU="${CU_PER_SA}"

      if [ ${sh} == 0 ] && [ ${CU_PER_SA} != ${MIN_CU_PER_SA} ]; then
         TMP_CU="${MIN_CU_PER_SA}"
      fi

      if [ ${GPU_FAMILY} -ge 74 ]; then
         for (( wgp=0; wgp<${TMP_CU}; wgp++ )); do
            printf " | | "
            printf '='"%.s" {1..5}
            printf " "
            printf '='"%.s" {1..5}
            printf "  WGP(%02d)  " ${wgp}
            printf '='"%.s" {1..5}
            printf " "
            printf '='"%.s" {1..5}
            printf " | |\n"
         done
      else
         for (( cu=0; cu<${CU_PER_SA}; cu++ )); do
            printf " | |  "
            printf '='"%.s" {1..4}
            printf "  "
            printf '='"%.s" {1..4}
            printf "  CU(%02d)  " ${cu}
            printf '='"%.s" {1..4}
            printf "  "
            printf '='"%.s" {1..4}
            printf "   | |\n"
         done
      fi
         printf " | |"


RB_PER_SA="$(( ${NUM_RB} / ${MAX_SE} / ${SA_PER_SE} ))"
RBF="${RB_PER_SE}"

      printf "   "

      while [ ${RB_PER_SA} -gt 0 ]; do

         if [ ${RB_PER_SA} -gt 4 ]; then
            RBTMP="4"
         else
            RBTMP="${RB_PER_SA}"
         fi

         for (( rbc=0; rbc<${RBTMP}; rbc++ )); do
            printf "[ RB ]"
            printf ' '"%.s" {1..2}
         done

         for (( fill=${RBTMP}; fill<4; fill++ )); do
            printf ' '"%.s" {1..8}
         done

         printf "| |\n"

         RB_PER_SA=$(( ${RB_PER_SA} - 4))
      done # RB end


RDNA_L1C_SIZE="128"

if [ ${GPU_FAMILY} -ge 74 ]; then
   printf " | |"
   printf ' '"%.s" {1..10}
   printf "[-  L1$ ${RDNA_L1C_SIZE}KB  -]"
   printf ' '"%.s" {1..8}
   printf "| |\n"
fi

   printf " | |  "
   printf "[- Rasterizer /Primitive Unit -]"
   printf " | |\n"

   # ShaderArray last line
      printf " | +"
      printf -- '-'"%.s" {1..35}
      printf "+ |\n"

   done # ShaderArray end

printf " |"
printf ' '"%.s" {1..8}
printf "[- Geometry Processor -]"
printf ' '"%.s" {1..7}
printf "|\n"

printf " +"
printf -- '-'"%.s" {1..39}
printf "+\n\n"

done # ShaderEngine end

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

L2C_SIZE="$(( ${L2_CACHE} / ${NUM_L2_CACHE_BLOCK} / 1024 ))"
L2CBF="${NUM_L2_CACHE_BLOCK}"

while [ ${L2CBF} -gt 0 ]; do

   if [ ${L2CBF} -gt 4 ]; then
      L2CB_TMP="4"
   else
      L2CB_TMP="${L2CBF}"
   fi

   for (( l2c=0; l2c<${L2CB_TMP}; l2c++ )); do
      printf "[L2$ ${L2C_SIZE}K] "
   done
      printf "\n"

   L2CBF="$(( ${L2CBF} - 4 ))"

done # L2cache end

echo
}

if [ ${NO_DIAGRAM} != 1 ]; then
   _diagram_draw_func
fi
