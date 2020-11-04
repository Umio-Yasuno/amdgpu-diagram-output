#!/bin/bash

IFS=''
GPUINFO="$(env AMD_DEBUG=info glxinfo -B)"
shopt -s expand_aliases
alias echo="echo -e"

# echo ${GPUINFO}

amdgpu_var() {
   export ${1}="$( echo ${GPUINFO} | grep " ${2} =" | sed -e "s/^.*${2}\ \=\ //g" )"

#  debug
#   eval echo "${1} : "'$'${1}""
}

amdgpu_var "GPU_ASIC" "name"
amdgpu_var "GPU_FAMILY" "family"
amdgpu_var "MAX_SHADER_ENGINE" "max_se"
amdgpu_var "SHADER_ARRAY_PER_SE" "max_sh_per_se"
amdgpu_var "CU_PER_SH" "max_good_cu_per_sa"
amdgpu_var "MAX_SHADER_CLOCK" "max_shader_clock"
amdgpu_var "NUM_RB" "num_render_backends"
amdgpu_var "L2_CACHE" "l2_cache_size"
amdgpu_var "NUM_L2_CACHE_BLOCK" "num_tcc_blocks"
amdgpu_var "VRAM_BIT_WIDTH" "vram_bit_width"
amdgpu_var "VRAM_TYPE" "vram_type"
amdgpu_var "MEMORY_CLOCK" "max_memory_clock"

debug_amdgpu_spec() {
   export GPU_ASIC="NAVI10"
   export GPU_FAMILY="77"
   export MAX_SHADER_ENGINE="2"
   export SHADER_ARRAY_PER_SE="2"
   export CU_PER_SH="10"
   export MAX_SHADER_CLOCK="2000"
   export NUM_RB="16"
   export L2_CACHE="4194304"
   export NUM_L2_CACHE_BLOCK="16"
   export VRAM_BIT_WIDDH="256"
   export VRAM_TYPE="9"
   export MEMORY_CLOCK="875"
}

# debug_amdgpu_spec

echo

#  https://gitlab.freedesktop.org/mesa/drm/-/blob/master/include/drm/amdgpu_drm.h#L914
#  https://cgit.freedesktop.org/~agd5f/linux/commit/drivers/gpu/drm/amd?h=amd-staging-drm-next&id=a01dd4fe8e62b18a16edccda840361c022940125

case ${VRAM_TYPE} in
   3)
      #  GDDR3
      DATA_RATE="$(( ${MEMORY_CLOCK} * 2 ))"
      ;;
   5)
      #  GDDR5
      DATA_RATE="$(( ${MEMORY_CLOCK} * 4 ))"
      ;;
   6)
      #  HBM/2
      DATA_RATE="$(( ${MEMORY_CLOCK} * 2 ))"
      ;;
   9)
      #  GDDR6
      DATA_RATE="$(( ${MEMORY_CLOCK} * 2 * 8 ))"
      ;;
   7|8|*)
      #  DDR3/4
      DATA_RATE="$(( ${MEMORY_CLOCK} ))"
      ;;
esac

echo "GPU ASIC:\t\t${GPU_ASIC}"

NUM_CU="$(( ${MAX_SHADER_ENGINE} * ${SHADER_ARRAY_PER_SE} * ${CU_PER_SH} ))"
echo "Compute Units:\t\t${NUM_CU} CU"
echo "Peak GFX Clock:\t\t${MAX_SHADER_CLOCK} MHz"

echo

#  https://gitlab.freedesktop.org/mesa/mesa/-/blob/master/src/amd/common/amd_family.h

if [ ${GPU_FAMILY} -ge 77 ];then
   echo "FP16 Packed"
   echo "Peak FP16:\t$(echo "scale=2;${NUM_CU} * 64 * ${MAX_SHADER_CLOCK} * 2 / 1000 / 1000 * 2" | bc ) TFlops"
fi

echo "Peak FP32:\t$(echo "scale=2;${NUM_CU} * 64 * ${MAX_SHADER_CLOCK} * 2 / 1000 / 1000" | bc ) TFlops"
echo

echo "Peak Pixel Fill-Rate:\t$(echo "scale=2;${NUM_RB} * 4 * ${MAX_SHADER_CLOCK} / 1000" | bc ) GP/s"
echo "Peak Texture Fill-Rate:\t$(echo "scale=2;${NUM_CU} * 4 * ${MAX_SHADER_CLOCK} / 1000" | bc) GT/s"

echo

printf "VRAM Type:\t\t"
case ${VRAM_TYPE} in
   1)
      printf "GDDR1"
      ;;
   2)
      printf "DDR2"
      ;;
   3)
      printf "GDDR3"
      ;;
   4)
      printf "GDDR4"
      ;;
   5)
      printf "GDDR5"
      ;;
   6)
      printf "HBM"
      ;;
   7)
      printf "DDR3"
      ;;
   8)
      printf "DDR4"
      ;;
   9)
      printf "GDDR6"
      ;;
esac
printf "\n"

echo "VRAM Bit Width:\t\t${VRAM_BIT_WIDTH}-bit"
echo "Peak Memory Clock:\t${MEMORY_CLOCK} MHz"

VRAM_MBW="$(echo " ${VRAM_BIT_WIDTH} / 8 * ${DATA_RATE} / 1000" | bc)"
echo "Peak VRAM Bandwidth:\t${VRAM_MBW} GB/s"

printf "\n\n"

for (( se=0; se<${MAX_SHADER_ENGINE}; se++ ))
do

   printf "\u00a0\u250C\u2500\u00a0ShaderEngine(${se})\u00a0\u00a0"
   printf '\u2500\u2500'"%.s" {1..10}
   printf "\u2510\n"

   for (( sh=0; sh<${SHADER_ARRAY_PER_SE}; sh++ ))
   do

      printf "\u00a0\u2502"
      printf '\u00a0'"%.s" {1..39}
      printf "\u2502\n"

      printf "\u00a0\u2502\u00a0\u250C\u2500 ShaderArray(${sh})\u00a0"
      printf '\u2500\u2500'"%.s" {1..9}
      printf "\u2510\u00a0\u2502\n"

         for (( cu=0; cu<${CU_PER_SH}; cu++ ))
         do
            printf "\u00a0\u2502\u00a0\u2502\u00a0\u00a0"
            printf '\u2550'"%.s" {1..12}
            printf "\u00a0CU(${cu})\u00a0"
            printf '\u2550'"%.s" {1..12}
            printf "\u00a0\u00a0\u2502\u00a0\u2502\n"
         done

      printf "\u00a0\u2502\u00a0\u2514"
      printf '\u2500'"%.s" {1..35}
      printf "\u2518\u00a0\u2502\n"

   done

<<OUT
      printf "\u00a0\u2502"
      printf '\u00a0'"%.s" {1..39}
      printf "\u2502\n"
OUT


RB_PER_SE="$(( ${NUM_RB} / ${MAX_SHADER_ENGINE}))"

<<OUT

if [ ${RB_PER_SE} -le 4 ];then

   for (( c=0; c<=2; c++ ))
   do
         printf "\u00a0\u2502\u2001\u2001\u2001"
      for (( rbc=0; rbc<${RB_PER_SE}; rbc++ ))
      do
         case ${c} in
            0)
               printf "\u250c\u2500\u2500\u2500\u2500\u2510"
               ;;
            1)
               printf "\u2502\u00a0RB\u00a0\u2502"
               ;;
            2)
               printf "\u2514"
               printf '\u2500'"%.s" {1..4}
               printf "\u2518"
               ;;
            *)
               exit 1
         esac

         printf '\u00a0'"%.s" {1..3}

      done

         for (( fill=${RB_PER_SE}; fill<4; fill++ ))
         do
            printf '\u00a0'"%.s" {1..9}
         done

         printf "\u2502"

      printf "\n"
   done
#      if [ ${NUM_RB} -le 4 ];then
#      fi
else
OUT

RBF="${RB_PER_SE}"

while [ ${RBF} -gt 0 ]
do

   for (( c=0; c<=2; c++ ))
   do
         printf "\u00a0\u2502\u2001\u2001\u2001"

   if [ ${RBF} -gt 4 ];then
      RBTMP="4"
   else
      RBTMP="${RBF}"
   fi

      for (( rbc=0; rbc<${RBTMP}; rbc++ ))
      do
         case ${c} in
            0)
               printf "\u250c\u2500\u2500\u2500\u2500\u2510"
               ;;
            1)
               printf "\u2502\u00a0RB\u00a0\u2502"
               ;;
            2)
               printf "\u2514"
               printf '\u2500'"%.s" {1..4}
               printf "\u2518"
               ;;
            *)
               exit 1
         esac

         printf '\u00a0'"%.s" {1..3}

      done

         for (( fill=${RBTMP}; fill<4; fill++ ))
         do
            printf '\u00a0'"%.s" {1..9}
         done

         printf "\u2502"

      printf "\n"
   done

   RBF=$(( ${RBF} - 4))

done

# fi

printf "\u00a0\u2514"
printf '\u2500'"%.s" {1..39}
printf "\u2518"
printf "\n\n"

done

printf "\n"

L2C_SIZE="$(echo "${L2_CACHE} / ${NUM_L2_CACHE_BLOCK} / 2^10" | bc )KB"

L2CBF="${NUM_L2_CACHE_BLOCK}"

while [ ${L2CBF} -gt 0 ]
do

   if [ ${L2CBF} -gt 4 ];then
      L2CB_TMP="4"
   else
      L2CB_TMP="${L2CBF}"
   fi

for (( c=0; c<=2; c++ ))
do
     printf "\u2000"
   for (( l2c=0; l2c<${L2CB_TMP}; l2c++ ))
   do
      printf "\u2001"
      case ${c} in
      0)
         printf "\u250c\u2500\u00a0L2$\u00a0\u2500\u2510"
         ;;
      1)
         printf "\u2502\u00a0${L2C_SIZE}\u00a0\u2502"
         ;;
      2)
         printf "\u2514" 
         printf '\u2500'"%.s" {1..7}
         printf "\u2518"
         ;;
      *)
         exit 1
      esac
   done
      printf "\n"
done

   L2CBF="$(( ${L2CBF} - 4 ))"

done

<<OUT

RB_PER_SE="$(( ${NUM_RB} / ${MAX_SHADER_ENGINE}))"

for (( c=0; c<=2; c++ ))
do
   for (( rb=0; rb<${NUM_RB}; rb++ ))
   do
      printf "\u2001\u2001\u2001\u2001"
      case ${c} in
      0)
         printf "\u250c\u2500\u2500\u2500\u2500\u2510"
         ;;
      1)
         printf "\u2502\u00a0RB\u00a0\u2502"
         ;;
      2)
         printf "\u2514"
         printf '\u2500'"%.s" {1..4}
         printf "\u2518"
         ;;
      *)
         exit 1
      esac
   done
      printf "\n"
done
OUT

