# AX-1 (1959)

This is a reproduction of the 1959 AX-1 coupled neutronics-hydrodynamics code
documented in Argonne National Laboratory report ANL-5977. The code solves
prompt supercritical reactor transients using S4 discrete ordinates transport,
Lagrangian hydrodynamics with von Neumann-Richtmyer artificial viscosity, and
a linear equation of state. It was written in modern Fortran 90+ while
preserving the original algorithms.

## Requirements

The code requires a Fortran compiler supporting Fortran 2008 and GNU Make.
On Debian or Ubuntu systems, install these with:

    sudo apt install gfortran make

On macOS with Homebrew:

    brew install gcc make

## Building

To compile the 1959 reproduction:

    make -f Makefile.1959

This produces the executable `ax1_1959`.

## Running

Run the Geneva 10 benchmark with:

    ./ax1_1959 inputs/geneve10_transient.inp

The simulation writes time series data to `output_time_series.csv` and spatial
profiles to files named `output_spatial_t*.csv`. A summary is printed to
standard output.

To generate comparison plots against the 1959 reference data, run:

    python3 analysis/compare_geneva10.py

This reads the simulation output and the digitized reference data from
`validation/reference_data/` and produces figures in `analysis/figures/`.

## Documentation

The LaTeX document `AX1_Code_Analysis.tex` describes the physics, the
correspondence between the modern code and the original 1959 order numbers,
and the validation results. Compile it with:

    pdflatex AX1_Code_Analysis.tex

## References

H. H. Hummel et al., "AX-1, A Computing Program for Coupled
Neutronics-Hydrodynamics Calculations on the IBM-704," ANL-5977,
Argonne National Laboratory, January 1959.

