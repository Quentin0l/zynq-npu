# Le GEMM int8 -> int32 en OpenCL : l'hôte en C++17, les kernels en OpenCL C
# (fourni par le parcours, leçons 10 et 11). D'habitude, passe par ./check.sh.
cmake_minimum_required(VERSION 3.18)
project(zynq_npu_opencl LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

# macOS : le framework OpenCL d'Apple. Linux : le chargeur ICD (libOpenCL), qui
# trouve les pilotes installés, PoCL par exemple.
find_package(OpenCL REQUIRED)

# La référence dorée, celle de ref/ : le GEMM naïf en C.
add_library(gemm_ref STATIC ../ref/gemm.c)
target_include_directories(gemm_ref PUBLIC ../ref)

# L'hôte : choisit le device, compile kernels/gemm.cl, lance les kernels.
add_library(gemm_ocl STATIC src/gemm_ocl.cpp)
target_include_directories(gemm_ocl PUBLIC include src)
target_link_libraries(gemm_ocl PUBLIC OpenCL::OpenCL)
target_compile_definitions(gemm_ocl PRIVATE KERNELS_DIR="${CMAKE_CURRENT_SOURCE_DIR}/kernels")
target_compile_options(gemm_ocl PRIVATE -Wall -Wextra)

add_executable(test_gemm tests/test_gemm.cpp)
target_link_libraries(test_gemm PRIVATE gemm_ocl gemm_ref)

add_executable(bench_gemm bench/bench_gemm.cpp)
target_link_libraries(bench_gemm PRIVATE gemm_ocl)
