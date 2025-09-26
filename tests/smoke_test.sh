#!/usr/bin/env bash
set -euo pipefail
FC=${FC:-gfortran}
$FC -std=f2008 -O2 -Wall -Wextra src/*.f90 -o ax1
./ax1 input/sample_phase1.deck | head -n 8
echo "Smoke test OK."
