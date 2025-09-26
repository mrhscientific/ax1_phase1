cmake_minimum_required(VERSION 3.18)
project(ax1 LANGUAGES Fortran)
enable_language(Fortran)
set(CMAKE_Fortran_STANDARD 2008)
set(CMAKE_Fortran_STANDARD_REQUIRED ON)

file(GLOB SRC "src/*.f90")
add_executable(ax1 ${SRC})
target_compile_options(ax1 PRIVATE -Wall -Wextra)
