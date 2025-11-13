# Phase 3 Gap Analysis: Capabilities Needed for Research/Engineering Use

This document identifies missing features needed for Bethe-Tait and similar transient/energetics problems, as well as research/engineering validation.

## Current Capabilities (Phase 1 + Phase 2)

### ✅ Implemented
- Alpha-eigenvalue solver (k(α) = 1)
- Delayed neutrons (6 groups)
- S_n quadrature (S4/S6/S8)
- DSA acceleration
- Upscatter control
- HLLC Riemann solver with slope limiting
- EOS tables (CSV, bilinear interpolation)
- CFL-based time stepping
- Adaptive time step control
- Performance instrumentation

## Missing Capabilities for Bethe-Tait / Transient Problems

### 1. Reactivity Feedback Mechanisms ❌

**Needed for**: Temperature feedback, fuel expansion, void feedback

**Missing**:
- **Doppler broadening**: Temperature-dependent cross sections
  - Currently: XS are constant
  - Needed: Σ(T) = Σ(T₀) * sqrt(T₀/T) for Doppler effect
  - Impact: Critical for fast reactor transients

- **Fuel expansion feedback**: Reactivity change due to density changes
  - Currently: Density changes affect hydro but not reactivity
  - Needed: ρ_k = ρ_k₀ * (1 - α_T * ΔT) affects k_eff
  - Impact: Negative feedback mechanism

- **Void feedback**: Reactivity change due to voiding
  - Currently: Not implemented
  - Needed: Reactivity insertion/removal based on density
  - Impact: Important for reactor safety analysis

**Implementation needed**:
```fortran
! In types.f90
type :: ReactivityFeedback
  real(rk) :: doppler_coef = 0.0_rk    ! Doppler coefficient
  real(rk) :: expansion_coef = 0.0_rk  ! Fuel expansion coefficient
  real(rk) :: void_coef = 0.0_rk       ! Void coefficient
  logical :: enable_doppler = .false.
  logical :: enable_expansion = .false.
  logical :: enable_void = .false.
end type
```

### 2. Time-Dependent Reactivity Insertion ❌

**Needed for**: Bethe-Tait, reactivity insertion accidents, control rod movement

**Missing**:
- **Reactivity insertion**: Ability to add/subtract reactivity as function of time
  - Currently: No way to insert reactivity
  - Needed: ρ(t) = ρ₀ + ρ_insert(t)
  - Impact: Required for transient analysis

- **Time-dependent boundary conditions**: Reactivity changes over time
  - Currently: Static reactivity (only alpha-eigenvalue)
  - Needed: ρ(t), k(t) as inputs
  - Impact: Essential for accident analysis

**Implementation needed**:
```fortran
! In Control type
real(rk) :: rho_insert = 0.0_rk        ! Reactivity insertion
character(len=256) :: rho_profile = "" ! File with rho(t) profile
logical :: use_rho_profile = .false.
```

### 3. Data Output and Time Histories ❌

**Needed for**: Validation, code-to-code comparison, analysis

**Missing**:
- **Time history output**: P(t), R(t), U(t), alpha(t), keff(t)
  - Currently: Only console output
  - Needed: CSV/HDF5 files with time series
  - Impact: Required for validation

- **Spatial output**: Flux, power, temperature, density distributions
  - Currently: No spatial output
  - Needed: Shell-by-shell data at each time step
  - Impact: Required for detailed analysis

- **Standardized formats**: HDF5/NetCDF for code-to-code comparison
  - Currently: No file output
  - Needed: Standard formats matching MCNP/Serpent/OpenMC
  - Impact: Essential for validation

**Implementation needed**:
```fortran
! New module: output_mod.f90
subroutine write_time_history(st, ctrl, filename)
subroutine write_spatial_data(st, ctrl, filename, time)
subroutine write_hdf5_output(st, ctrl, filename)
```

### 4. Restart/Checkpoint Capability ❌

**Needed for**: Long-running simulations, crash recovery, parametric studies

**Missing**:
- **Checkpoint files**: Save state periodically
  - Currently: No restart capability
  - Needed: Save full state to file, restart from file
  - Impact: Critical for production runs

- **State serialization**: Save/load State type
  - Currently: No serialization
  - Needed: Binary or HDF5 checkpoint format
  - Impact: Required for long simulations

**Implementation needed**:
```fortran
! In io_mod.f90 or new checkpoint_mod.f90
subroutine write_checkpoint(st, ctrl, filename)
subroutine read_checkpoint(st, ctrl, filename, iostat)
```

### 5. Temperature-Dependent Cross Sections ❌

**Needed for**: Doppler broadening, realistic physics

**Missing**:
- **HDF5 XS reader**: Full implementation (currently stub)
  - Currently: xs_lib.f90 is stub only
  - Needed: Read NJOY/OpenMC HDF5 files with temperature dependence
  - Impact: Required for realistic simulations

- **XS interpolation**: Temperature interpolation of cross sections
  - Currently: Constant XS
  - Needed: Σ(T) interpolation from HDF5 tables
  - Impact: Essential for temperature feedback

- **Doppler broadening**: Fast on-the-fly broadening
  - Currently: Not implemented
  - Needed: Σ(T) = Σ(T₀) * sqrt(T₀/T) * correction_factor
  - Impact: Critical for fast reactor transients

**Implementation needed**:
```fortran
! Complete xs_lib.f90 implementation
subroutine read_hdf5_xs(path, material, temperature, xs_data)
subroutine interpolate_xs_temperature(xs_data, T, xs_out)
subroutine apply_doppler_broadening(xs, T_ref, T_current, xs_broadened)
```

### 6. Uncertainty Quantification Framework ❌

**Needed for**: Phase 3 requirement - quantify impact of XS/EOS uncertainties

**Missing**:
- **Uncertainty propagation**: Monte Carlo or polynomial chaos
  - Currently: No UQ capability
  - Needed: Propagate XS/EOS uncertainties to outputs
  - Impact: Required for Phase 3

- **Sensitivity analysis**: Calculate sensitivity coefficients
  - Currently: No sensitivity calculations
  - Needed: ∂k/∂Σ, ∂α/∂Σ, etc.
  - Impact: Required for Phase 3

- **Parameter sampling**: Latin Hypercube, Sobol sequences
  - Currently: No sampling framework
  - Needed: Generate parameter sets for UQ
  - Impact: Required for uncertainty propagation

**Implementation needed**:
```fortran
! New module: uq_mod.f90
type :: UncertaintyParameters
  real(rk) :: xs_uncertainty = 0.05_rk  ! 5% uncertainty
  real(rk) :: eos_uncertainty = 0.02_rk ! 2% uncertainty
end type

subroutine propagate_uncertainties(st, ctrl, uq_params, n_samples, results)
subroutine calculate_sensitivities(st, ctrl, sensitivities)
```

### 7. Validation Datasets and Comparisons ❌

**Needed for**: Phase 3 requirement - reproduce classic cases

**Missing**:
- **Bethe-Tait benchmark**: Implementation and validation
  - Currently: No Bethe-Tait problem
  - Needed: Classic Bethe-Tait transient
  - Impact: Required for Phase 3 validation

- **Historical experiments**: Reproduction of known results
  - Currently: No validation cases
  - Needed: Godiva, Jezebel, etc.
  - Impact: Required for validation

- **Code-to-code comparison**: MCNP/Serpent/OpenMC
  - Currently: No comparison tools
  - Needed: Compare k, α(t), P(t), R(t), U(t)
  - Impact: Required for Phase 3

**Implementation needed**:
```fortran
! New module: validation_mod.f90
subroutine run_bethe_tait_benchmark()
subroutine compare_with_reference(reference_file, results_file)
subroutine generate_validation_report()
```

### 8. CI/CD and Testing Infrastructure ❌

**Needed for**: Phase 3 requirement - full test matrix, CI

**Missing**:
- **Test matrix**: Comprehensive test suite
  - Currently: Basic smoke tests
  - Needed: Full test matrix covering all features
  - Impact: Required for Phase 3

- **Continuous Integration**: Automated testing
  - Currently: Basic CI setup
  - Needed: Full CI with test matrix
  - Impact: Required for Phase 3

- **Documentation**: Research/engineering documentation
  - Currently: Basic README
  - Needed: Comprehensive documentation
  - Impact: Required for research use

**Implementation needed**:
- GitHub Actions workflows
- Comprehensive test suite
- API documentation
- User manual

### 9. Output Variables for Validation ❌

**Needed for**: Compare with literature (k, α(t), P(t), R(t), U(t))

**Missing**:
- **Power history**: P(t) output
  - Currently: total_power tracked but not output to file
  - Needed: P(t) time series
  - Impact: Required for validation

- **Radius history**: R(t) output (fuel expansion)
  - Currently: Shell radii tracked but not output
  - Needed: R(t) time series
  - Impact: Required for Bethe-Tait

- **Velocity history**: U(t) output
  - Currently: Shell velocities tracked but not output
  - Needed: U(t) time series
  - Impact: Required for validation

- **Alpha history**: α(t) output
  - Currently: alpha tracked but not output to file
  - Needed: α(t) time series
  - Impact: Required for validation

- **Pressure history**: Pressure vs time
  - Currently: Pressure tracked but not output
  - Needed: P(t) time series
  - Impact: Required for validation

**Implementation needed**:
```fortran
! In State type, add output arrays
real(rk), allocatable :: time_history(:)
real(rk), allocatable :: power_history(:)
real(rk), allocatable :: alpha_history(:)
real(rk), allocatable :: radius_history(:,:)  ! (Nshell, nsteps)
real(rk), allocatable :: velocity_history(:,:)
real(rk), allocatable :: pressure_history(:,:)
```

### 10. Reactivity Calculation ❌

**Needed for**: Transient analysis, reactivity feedback

**Missing**:
- **Reactivity from k**: ρ = (k - 1) / k
  - Currently: k_eff calculated but ρ not explicitly tracked
  - Needed: ρ(t) calculation and output
  - Impact: Required for transient analysis

- **Reactivity worth**: Contribution of each feedback mechanism
  - Currently: Not calculated
  - Needed: ρ_doppler, ρ_expansion, ρ_void
  - Impact: Required for analysis

**Implementation needed**:
```fortran
! In State type
real(rk) :: reactivity = 0.0_rk
real(rk) :: rho_doppler = 0.0_rk
real(rk) :: rho_expansion = 0.0_rk
real(rk) :: rho_void = 0.0_rk
```

## Summary: Critical Missing Features

### Must Have for Bethe-Tait:
1. ✅ **Temperature-dependent cross sections** (Doppler broadening)
2. ✅ **Reactivity feedback** (Doppler, expansion, void)
3. ✅ **Time-dependent reactivity insertion**
4. ✅ **Data output** (time histories: P(t), R(t), U(t), α(t))
5. ✅ **Restart capability**

### Must Have for Phase 3 Validation:
6. ✅ **Uncertainty quantification framework**
7. ✅ **Sensitivity analysis**
8. ✅ **Validation datasets** (Bethe-Tait, historical experiments)
9. ✅ **Code-to-code comparison tools**
10. ✅ **CI/CD infrastructure**

### Nice to Have:
11. ✅ **Standardized output formats** (HDF5/NetCDF)
12. ✅ **Advanced time stepping** (implicit, adaptive order)
13. ✅ **Parallelization** (for UQ studies)
14. ✅ **Visualization tools**

## Implementation Priority

### Phase 3.1 (Core Transient Capabilities):
1. Temperature-dependent cross sections
2. Reactivity feedback mechanisms
3. Time-dependent reactivity insertion
4. Data output (time histories)
5. Restart capability

### Phase 3.2 (Validation):
6. Bethe-Tait benchmark
7. Validation datasets
8. Code-to-code comparison tools
9. Output standardization

### Phase 3.3 (UQ & Sensitivity):
10. Uncertainty quantification framework
11. Sensitivity analysis
12. Parameter sampling
13. UQ results analysis

### Phase 3.4 (Infrastructure):
14. CI/CD enhancement
15. Test matrix
16. Documentation
17. User manual

## Recommendations

Before implementing Phase 3, ensure:
1. ✅ Phase 2 code is merged into phase3 branch
2. ✅ All Phase 2 features are tested and working
3. ✅ Basic infrastructure is in place (output, restart)
4. ✅ Temperature-dependent XS framework is ready

Then implement in priority order:
1. **Core transient capabilities** (3.1) - Essential for Bethe-Tait
2. **Validation** (3.2) - Required for Phase 3
3. **UQ & Sensitivity** (3.3) - Required for Phase 3
4. **Infrastructure** (3.4) - Required for research use

## References

- Bethe-Tait analysis: Classic fast reactor transient
- Reactivity feedback: Doppler, fuel expansion, void
- Validation: Historical experiments (Godiva, Jezebel)
- UQ: Uncertainty quantification in reactor physics
- Sensitivity: Sensitivity analysis methods

