#!/usr/bin/env bash
set -euo pipefail
FC=${FC:-gfortran}
$FC -std=f2008 -O2 -Wall -Wextra src/*.f90 -o ax1
./ax1 "$@"
