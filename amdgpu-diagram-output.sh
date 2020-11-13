#!/bin/bash

IFS=''
GPUINFO="$(env AMD_DEBUG=info glxinfo -B)"
shopt -s expand_aliases
alias echo="echo -e"

# echo ${GPUINFO}

amdgpu_var() {
   export ${1}="$( echo ${GPUINFO} | grep " ${2} =" | sed -e "s/^.*${2}\ \=\ //g" )"

#   debug
#   eval echo "${1} : "'$'${1}""
}

amdgpu_var "GPU_ASIC" "name"
amdgpu_var "CARD_NAME" "marketing_name"
amdgpu_var "GPU_FAMILY" "family"
amdgpu_var "MAX_SE" "max_se"
amdgpu_var "SA_PER_SE" "max_sh_per_se"
amdgpu_var "CU_PER_SH" "max_good_cu_per_sa"
amdgpu_var "MAX_SHADER_CLOCK" "max_shader_clock"
amdgpu_var "NUM_RB" "num_render_backends"
amdgpu_var "L2_CACHE" "l2_cache_size"
amdgpu_var "NUM_L2_CACHE_BLOCK" "num_tcc_blocks"
amdgpu_var "VRAM_BIT_WIDTH" "vram_bit_width"
amdgpu_var "VRAM_TYPE" "vram_type"
amdgpu_var "MEMORY_CLOCK" "max_memory_clock"
amdgpu_var "RB_PLUS" "has_rbplus"

debug_amdgpu_spec() {
   export GPU_ASIC="NAVI10"
   export CARD_NAME="Navi10 Card"
   export GPU_FAMILY="77"
   export MAX_SE="2"
   export SA_PER_SE="2"
   export CU_PER_SH="10"
   export MAX_SHADER_CLOCK="2000"
   export NUM_RB="16"
   export L2_CACHE="$(echo "4096 * 1024" | bc)"
   export NUM_L2_CACHE_BLOCK="16"
   export VRAM_BIT_WIDTH="256"
   export VRAM_TYPE="9"
   export MEMORY_CLOCK="875"
}

if [ ${1} ] && [ ${1} = "--debug" ];then
   debug_amdgpu_spec
fi

echo

echo "GPU ASIC:\t\t${GPU_ASIC}"
echo "Marketing Name:\t\t${CARD_NAME}\n"

NUM_CU="$(( ${MAX_SE} * ${SA_PER_SE} * ${CU_PER_SH} ))"

if [ ${GPU_FAMILY} -ge 77 ];then
   echo "WorkGroup Processors:\t$(( ${NUM_CU} / 2 )) WGP (${NUM_CU} CU)"
else 
   echo "Compute Units:\t\t${NUM_CU} CU"
fi

echo "Peak GFX Clock:\t\t${MAX_SHADER_CLOCK} MHz"

echo

#  https://gitlab.freedesktop.org/mesa/mesa/-/blob/master/src/amd/common/amd_family.h

if [ ${GPU_FAMILY} -ge 77 ];then
   echo "Peak FP16 (Packed):\t$(echo "scale=2;${NUM_CU} * 64 * ${MAX_SHADER_CLOCK} * 2 / 1000 / 1000 * 2" | bc ) TFlops"
fi

echo "Peak FP32:\t\t$(echo "scale=2;${NUM_CU} * 64 * ${MAX_SHADER_CLOCK} * 2 / 1000 / 1000" | bc ) TFlops\n"

if [ ${RB_PLUS} ];then
   echo "RBs (Render Backends):\t${NUM_RB} RB ($(( ${NUM_RB} * 4 )) ROP)"
else
   echo "RBs (Render Backends):\t${NUM_RB} RB+ ($(( ${NUM_RB} * 8 )) ROP)"
fi

echo "Peak Pixel Fill-Rate:\t$(echo "scale=2;${NUM_RB} * 4 * ${MAX_SHADER_CLOCK} / 1000" | bc ) GP/s\n"

echo "TMUs (Texture Mapping Units):\t$(( ${NUM_CU} * 4 )) TMU"
echo "Peak Texture Fill-Rate:\t\t$(echo "scale=2;${NUM_CU} * 4 * ${MAX_SHADER_CLOCK} / 1000" | bc) GT/s\n"

#  https://gitlab.freedesktop.org/mesa/drm/-/blob/2420768d023e0c257d2752a5c212d5dd3528a249/include/drm/amdgpu_drm.h#L938
#  https://cgit.freedesktop.org/~agd5f/linux/commit/drivers/gpu/drm/amd?h=amd-staging-drm-next&id=a01dd4fe8e62b18a16edccda840361c022940125

case ${VRAM_TYPE} in
   1)
      VRAM_MODULE="GDDR1"
      ;;
   2)
      VRAM_MODULE="DDR2"
      ;;
   3)
      #  GDDR3
      VRAM_MODULE="GDDR3"
      DATA_RATE="$(( ${MEMORY_CLOCK} * 2 ))"
      ;;
   4)
      VRAM_MODULE="GDDR4"
      ;;
   5)
      #  GDDR5
      VRAM_MODULE="GDDR5"
      DATA_RATE="$(( ${MEMORY_CLOCK} * 4 ))"
      ;;
   6)
      #  HBM/2
      VRAM_MODULE="HBM"
      DATA_RATE="$(( ${MEMORY_CLOCK} * 2 ))"
      ;;
   9)
      #  GDDR6
      VRAM_MODULE="GDDR6"
      DATA_RATE="$(( ${MEMORY_CLOCK} * 2 * 8 ))"
      ;;
   7)
      #  DDR3/4
      VRAM_MODULE="DDR3"
      DATA_RATE="$(( ${MEMORY_CLOCK} ))"
      ;;
   8)
      #  DDR3/4
      VRAM_MODULE="DDR4"
      DATA_RATE="$(( ${MEMORY_CLOCK} ))"
      ;;
   0|*)
      VRAM_MODULE="Unknown"
      ;;
esac

echo "VRAM Type:\t\t${VRAM_MODULE}"

echo "VRAM Bit Width:\t\t${VRAM_BIT_WIDTH}-bit"
echo "Peak Memory Clock:\t${MEMORY_CLOCK} MHz"

if [ ${VRAM_TYPE} -le 2 ] || [ ${VRAM_TYPE} -eq 4 ];then
   VRAM_MBW="Unknown"
else
   VRAM_MBW="$(echo " ${VRAM_BIT_WIDTH} / 8 * ${DATA_RATE} / 1000" | bc) GB/s"
fi

echo "Peak VRAM Bandwidth:\t${VRAM_MBW}\n"

echo "L2 Cache Blocks:\t${NUM_L2_CACHE_BLOCK} Block"
echo "L2 Cache Size:\t\t$(echo "${L2_CACHE} / 1024 / 1024" | bc ) MB ($(echo "${L2_CACHE} / 1024" | bc) KB)"

printf "\n\n"

echo "## AMD GPU Diagram\n"

for (( se=0; se<${MAX_SE}; se++ ))
do

   printf " \u250C\u2500 ShaderEngine(${se})  "
   printf '\u2500\u2500'"%.s" {1..10}
   printf "\u2510\n"

#      printf " \u2502"
#      printf ' '"%.s" {1..39}
#      printf "\u2502\n"
   for (( sh=0; sh<${SA_PER_SE}; sh++ ))
   do

      printf " \u2502 \u250C\u2500 ShaderArray(${sh}) "
      printf '\u2500\u2500'"%.s" {1..9}
      printf "\u2510 \u2502\n"

      if [ ${GPU_FAMILY} -ge 77 ];then
         for (( wgp=0; wgp<$(( ${CU_PER_SH} /2 )); wgp++ ))
         do
            printf " \u2502 \u2502  "
            printf '\u2550'"%.s" {1..5}
            printf " "
            printf '\u2550'"%.s" {1..5}
            printf "  WGP(${wgp})  "
            printf '\u2550'"%.s" {1..5}
            printf " "
            printf '\u2550'"%.s" {1..5}
            printf " \u2502 \u2502\n"
         done
      else
         for (( cu=0; cu<${CU_PER_SH}; cu++ ))
         do
            printf " \u2502 \u2502"
            printf ' '"%.s" {1..3}
            printf '\u2550'"%.s" {1..4}
            printf "  "
            printf '\u2550'"%.s" {1..4}
            printf "  CU(${cu})  "
            printf '\u2550'"%.s" {1..4}
            printf "  "
            printf '\u2550'"%.s" {1..4}
            printf ' '"%.s" {1..3}
            printf "\u2502 \u2502\n"
         done
      fi
         printf " \u2502 \u2502"


RB_PER_SA="$(( ${NUM_RB} / ${MAX_SE} / ${SA_PER_SE} ))"
RBF="${RB_PER_SE}"

      printf "   "

      while [ ${RB_PER_SA} -gt 0 ]
      do

         if [ ${RB_PER_SA} -gt 4 ];then
            RBTMP="4"
         else
            RBTMP="${RB_PER_SA}"
         fi

         for (( rbc=0; rbc<${RBTMP}; rbc++ ))
         do
            printf "[-RB-]"
            printf ' '"%.s" {1..2}
         done

         for (( fill=${RBTMP}; fill<4; fill++ ))
         do
            printf ' '"%.s" {1..8}
         done

         printf "\u2502 \u2502"
         printf "\n"

         RB_PER_SA=$(( ${RB_PER_SA} - 4))
      done # RB end

#      printf "\n"


RDNA_L1C_SIZE="128KB"

if [ ${GPU_FAMILY} -ge 77 ];then
   printf " \u2502 \u2502"
   printf ' '"%.s" {1..10}
   printf "[-- L1$ ${RDNA_L1C_SIZE} --]"
   printf ' '"%.s" {1..8}
   printf "\u2502 \u2502"
   printf "\n"
fi

   printf " \u2502 \u2502  "
   printf "[- Rasterizer /Primitive Unit -]"
   printf " \u2502 \u2502"
   printf "\n"

   # ShaderArray last line
      printf " \u2502 \u2514"
      printf '\u2500'"%.s" {1..35}
      printf "\u2518 \u2502\n"
   done # ShaderArray end

printf " \u2502"
printf ' '"%.s" {1..8}
printf "[- Geometry Processor -]"
printf ' '"%.s" {1..7}
printf "\u2502"
printf "\n"

printf " \u2514"
printf '\u2500'"%.s" {1..39}
printf "\u2518"
printf "\n"

done # ShaderEngine end

#  correct AMDGPU L2cache Size, maybe (GFX9+)
#  https://gitlab.freedesktop.org/mesa/mesa/-/blob/master/src/amd/common/ac_gpu_info.c

case ${GPU_ASIC} in
   RAVEN2)
      L2_CACHE="$(( 512 * 1024 ))"
      ;;
   RAVEN|RENOIR)
      L2_CACHE="$(( 1024 * 1024 ))"
      ;;
   VEGA12|NAVI14)
      L2_CACHE="$(( 2048 * 1024 ))"
      ;;
   *)
esac

L2C_SIZE="$(echo "${L2_CACHE} / ${NUM_L2_CACHE_BLOCK} / 1024" | bc )K"
L2CBF="${NUM_L2_CACHE_BLOCK}"

while [ ${L2CBF} -gt 0 ]
do

   if [ ${L2CBF} -gt 4 ];then
      L2CB_TMP="4"
   else
      L2CB_TMP="${L2CBF}"
   fi

   for (( l2c=0; l2c<${L2CB_TMP}; l2c++ ))
   do
      printf "[ L2$ ${L2C_SIZE} ]  "
   done
      printf "\n"

   L2CBF="$(( ${L2CBF} - 4 ))"

done # L2cache end

echo
