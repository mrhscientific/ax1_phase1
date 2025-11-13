FC = gfortran
FFLAGS ?= -O2 -Wall -Wextra -std=f2008
LDFLAGS ?=

UNAME_S := $(shell uname -s)
SYSROOT_FLAG :=
ifeq ($(UNAME_S),Darwin)
SDKROOT ?= $(shell xcrun --sdk macosx --show-sdk-path 2>/dev/null)
ifneq ($(SDKROOT),)
# Homebrew GCC needs the explicit sysroot when the Command Line Tools are missing
SYSROOT_FLAG := -isysroot $(SDKROOT)
endif
endif

SRC := \
        src/kinds.f90 \
        src/constants.f90 \
        src/types.f90 \
        src/eos_table.f90 \
        src/utils.f90 \
        src/thermo.f90 \
        src/xs_lib.f90 \
        src/controls.f90 \
        src/temperature_xs.f90 \
        src/hydro.f90 \
        src/neutronics_s4_alpha.f90 \
        src/reactivity_feedback.f90 \
        src/history_mod.f90 \
        src/checkpoint_mod.f90 \
        src/io_mod.f90 \
        src/input_parser.f90 \
        src/simulation_mod.f90 \
        src/uq_mod.f90 \
        src/sensitivity_mod.f90 \
        src/main.f90
OBJ := $(SRC:.f90=.o)

ax1: $(OBJ)
	$(FC) $(SYSROOT_FLAG) $(FFLAGS) $(LDFLAGS) -o $@ $(OBJ)

%.o: %.f90
	$(FC) $(SYSROOT_FLAG) $(FFLAGS) -c $< -o $@

clean:
	rm -f src/*.o src/*.mod ax1 *.mod
