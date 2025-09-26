FC ?= gfortran
FFLAGS ?= -O2 -Wall -Wextra -std=f2008

SRC := $(wildcard src/*.f90)
OBJ := $(SRC:.f90=.o)

ax1: $(OBJ)
	$(FC) $(FFLAGS) -o $@ $(OBJ)

%.o: %.f90
	$(FC) $(FFLAGS) -c $< -o $@

clean:
	rm -f src/*.o src/*.mod ax1
