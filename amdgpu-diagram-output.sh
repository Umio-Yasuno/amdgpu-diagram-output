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

echo

#  https://gitlab.freedesktop.org/mesa/drm/-/blob/master/include/drm/amdgpu_drm.h#L914


#  https://cgit.freedesktop.org/~agd5f/linux/commit/drivers/gpu/drm/amd?h=amd-staging-drm-next&id=a01dd4fe8e62b18a16edccda840361c022940125

case ${VRAM_TYPE} in
   3)
      DATA_RATE="$(( ${MEMORY_CLOCK} * 2 ))"
      ;;
   5)
      DATA_RATE="$(( ${MEMORY_CLOCK} * 4 ))"
      ;;
   6)
      DATA_RATE="$(( ${MEMORY_CLOCK} * 2 ))"
      ;;
   9)
      DATA_RATE="$(( ${MEMORY_CLOCK} * 2 * 8 ))"
      ;;
   7|8|*)
      DATA_RATE="$(( ${MEMORY_CLOCK} ))"
      ;;
esac

echo "GPU ASIC:\t\t${GPU_ASIC}"

NUM_CU="$(( ${MAX_SHADER_ENGINE} * ${SHADER_ARRAY_PER_SE} * ${CU_PER_SH} ))"
echo "Compute Units:\t\t${NUM_CU} CU"
echo "Peak GFX Clock:\t\t${MAX_SHADER_CLOCK} MHz"

#  MAX_SHADER_CLOCK="1275"
#  GPU_FAMILY="100"

echo

if [ ${GPU_FAMILY} -lt 77 ];then
   echo "Peak FP16:\t$(echo "scale=2;${NUM_CU} * 64 * ${MAX_SHADER_CLOCK} * 2 / 1000 / 1000" | bc ) TFlops"
else 
   echo "Peak FP16:\t$(echo "scale=2;${NUM_CU} * 64 * ${MAX_SHADER_CLOCK} * 2 / 1000 / 1000 * 2" | bc ) TFlops"
fi

echo "Peak FP32:\t$(echo "scale=2;${NUM_CU} * 64 * ${MAX_SHADER_CLOCK} * 2 / 1000 / 1000" | bc ) TFlops"
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
VRAM_MBW="$(echo " ${VRAM_BIT_WIDTH} / 8 * ${DATA_RATE} / 1000" | bc)"
echo "Peak VRAM Bandwidth:\t${VRAM_MBW} GB/s"

echo


for (( se=0; se<${MAX_SHADER_ENGINE}; se++ ))
do

   printf " \u250C\u2500 ShaderEngine(${se}) "
   printf '\u2500\u2500'"%.s" {1..10}
   printf "\u2510\n \u2502"

   for (( sh=0; sh<${SHADER_ARRAY_PER_SE}; sh++ ))
   do

      printf " \u250C\u2500 ShaderArray(${sh}) "
      printf '\u2500\u2500'"%.s" {1..9}
      printf "\u2510\u2502\n"


         for (( cu=0; cu<${CU_PER_SH}; cu++ ))
         do
            printf " \u2502 \u2502  "
#            printf ' '"%.s" {1..13}
            printf '\u2550'"%.s" {1..12}
            printf " CU(${cu}) "
            printf '\u2550'"%.s" {1..12}
            printf "  \u2502\u2502\n"
         done

      printf " \u2502 \u2514"
      printf '\u2500'"%.s" {1..35}
      printf "\u2518\u2502\n"

   done

printf " \u2514"
printf '\u2500\u2500'"%.s" {1..19}
printf "\u2518"
printf "\n"

done

L2C_SIZE="$(echo "${L2_CACHE} / ${NUM_L2_CACHE_BLOCK} / 2^10" | bc )KB"

for (( c=0; c<=2; c++ ))
do
      printf " "
   for (( l2c=0; l2c<${NUM_L2_CACHE_BLOCK}; l2c++ ))
   do
      printf " "
      case ${c} in
      0)
         printf "\u250c\u2500 L2$ \u2500\u2510"
         ;;
      1)
         printf "\u2502 ${L2C_SIZE} \u2502"
         ;;
      2)
         printf "\u2514"
      #   printf '\u2500'"%.s" {1..7}
         printf "\u2500\u2500\u2500"
         printf "\u252c"
         printf "\u2500\u2500\u2500"
         printf "\u2518"
         ;;
      *)
         exit 1
      esac
   done
      printf "\n"
done

for (( c=0; c<=2; c++ ))
do
   for (( rb=0; rb<${NUM_RB}; rb++ ))
   do
      printf "    "
      case ${c} in
      0)
         printf "\u250c"
         printf "\u2500"
         printf "\u2534\u2500\u2500"
         printf "\u2510"
         ;;
      1)
         printf "\u2502 RB \u2502"
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
