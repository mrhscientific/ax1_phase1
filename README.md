# AX-1 (Modern Fortran) — Phase 3: Toward Research/Engineering Use

This release implements **Phase 3** features for research and engineering applications:

## Phase 3 Features

- **Reactivity feedback**: Doppler, fuel expansion, and void feedback mechanisms
- **Time-dependent reactivity**: Static and time-dependent reactivity insertion
- **Time history output**: P(t), R(t), U(t), α(t), keff(t) and spatial histories
- **Checkpoint/restart**: Save and restore simulation state
- **Uncertainty quantification**: Monte Carlo sampling framework for parameter uncertainties
- **Sensitivity analysis**: Finite difference sensitivity coefficients (∂k/∂Σ, ∂α/∂Σ)
- **Validation framework**: Bethe-Tait benchmark and code-to-code comparison tools

## Phase 2 Features (Previous Release)

- **S_n quadrature**: Support for S4, S6, and S8 angular discretization
- **DSA acceleration**: Diffusion Synthetic Acceleration to speed up transport iterations
- **Upscatter control**: Configurable upscatter treatment (allow/neglect/scale)
- **HLLC-like hydro**: Replaced artificial viscosity with Riemann-solver-inspired interface pressure
- **HDF5 XS stub**: Framework for temperature-dependent cross sections from NJOY/OpenMC

## Build & Run

```bash
make
./ax1 inputs/sample_phase2.deck
```

For Phase 3 features, specify in the deck:
- `run_uq true` to enable uncertainty quantification
- `run_sensitivity true` to enable sensitivity analysis
- `checkpoint_file file.chk` to enable checkpointing
- `restart_file file.chk` to restart from checkpoint
- `output_file output` to specify output file prefix
- `t_end 0.01` to set simulation end time
- `rho_insert 100.0` to insert reactivity (pcm)

For Phase 2 features, specify in the deck:
- `Sn 8` (or 4, 6) for angular order
- `use_dsa true` to enable DSA acceleration
- `upscatter allow|neglect|scale` for scattering treatment

## Phase 2 Enhancements

### Transport
- **S_n quadrature**: Flexible S4/S6/S8 angular discretization with Gauss-Legendre points
- **DSA**: Tridiagonal diffusion correction to accelerate transport sweeps
- **Upscatter control**: Neglect or scale upscatter in multi-group scattering

### Hydrodynamics  
- **Interface pressure**: HLLC-inspired PVRS (Primitive Variable Riemann Solver) approach for cell interfaces
- **Slope limiting**: Minmod limiter for gradient-based reconstruction at interfaces (prevents oscillations)
- **Removed artificial viscosity**: Replaced by pressure-based flux evaluation

### Data
- **HDF5 framework**: Stub reader for NJOY/OpenMC temperature-dependent cross sections
- **Input deck**: New `[xslib]` section to specify HDF5 paths

## Phase 3 Enhancements

### Reactivity Feedback
- **Doppler feedback**: Temperature-dependent reactivity feedback
- **Fuel expansion**: Density-dependent reactivity feedback
- **Void feedback**: Void-dependent reactivity feedback
- **Reactivity calculation**: From k_eff and feedback mechanisms

### Time History Output
- **Time history**: P(t), R(t), U(t), α(t), keff(t)
- **Spatial history**: Radius, velocity, pressure, temperature
- **CSV format**: Easy to parse and analyze
- **Configurable frequency**: Output every N steps

### Checkpoint/Restart
- **Binary format**: Efficient storage
- **State save/load**: Complete state restoration
- **Time history support**: Checkpoint includes history
- **Restart capability**: Continue from checkpoint

### Uncertainty Quantification
- **Monte Carlo sampling**: Uniform distribution
- **Parameter perturbation**: Cross sections, EOS, delayed neutrons
- **Statistics**: Mean, std, min, max, CI
- **Results output**: CSV format

### Sensitivity Analysis
- **Finite differences**: Central difference method
- **Sensitivity coefficients**: ∂k/∂Σ, ∂α/∂Σ
- **Multiple parameters**: Cross sections, EOS, delayed neutrons
- **Results output**: CSV format

### Validation Framework
- **Bethe-Tait benchmark**: Fast reactor transient problem
- **Code-to-code comparison**: Framework for comparing with other codes
- **Standardized format**: Easy comparison

## Tests

Run the comprehensive test suite:

```bash
make
./tests/smoke_test.sh           # Phase 1 compatibility
./tests/phase2_attn.sh          # Phase 2 attenuation test (S8, DSA)
./tests/phase2_shocktube.sh     # Phase 2 hydrodynamics test
./tests/test_phase3.sh          # Phase 3 feature tests
./tests/test_uq_sensitivity.sh  # UQ and sensitivity tests
./validation/validate_bethe_tait.sh  # Bethe-Tait validation
./validation/code_to_code_comparison.sh  # Code-to-code comparison
```

## Notes

- The DSA correction applies a single Gauss-Seidel sweep on the scalar flux per energy group
- HLLC interface pressure uses PVRS (Primitive Variable Riemann Solver) for pressure estimation at cell faces
- Slope limiting uses the minmod function to compute limited gradients for second-order accurate interface reconstruction
- Upscatter control allows suppression (`neglect`) or scaling (`scale`) of upward energy transfers
- S_n quadrature uses Gauss-Legendre abscissae optimized for slab geometry

## Benchmarks

A comprehensive benchmark suite is available in `benchmarks/`:

- **Godiva Criticality**: Fast reactor criticality problem
- **SOD Shock Tube**: Riemann problem for hydrodynamics validation
- **Upscatter Treatment**: Tests upscatter control feature
- **DSA Convergence**: Demonstrates acceleration effectiveness

Run all benchmarks:
```bash
./benchmarks/run_benchmarks.sh
```

See `benchmarks/README.md` for detailed descriptions and expected results.

## Testing

For comprehensive testing instructions, see `TESTING_PHASE2.md`.

## Phase 1 Features (Retained)

- **α‑eigenvalue solver** via root‑finding on k(α)
- **Delayed neutrons** (6 groups)
- **Controls**: W‑criterion + CFL stability
- **EOS tables**: CSV tables with bilinear interpolation