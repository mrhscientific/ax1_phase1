# Phase 2 Verification Tests

This document describes the verification and validation tests implemented for Phase 2.

## Test Categories

### 1. Method Verification: Manufactured Solutions

#### Exponential Attenuation (Transport)
- **Purpose**: Verify transport solver against analytic solution
- **Setup**: Source-free medium with Σ_t=1.0, pure absorbing
- **Expected**: Flux should decay exponentially as φ(r) ∝ exp(-Σ_t*r)
- **Status**: ✅ Implemented in `phase2_manufactured.sh` (Test 1)

#### Shock Tube (Hydrodynamics) 
- **Purpose**: Verify Riemann solver implementation
- **Setup**: Density/temperature discontinuity at interface
- **Expected**: Proper wave propagation and interface resolution
- **Status**: ✅ Implemented in `phase2_shocktube.sh`

### 2. Performance Tests

#### DSA Acceleration
- **Purpose**: Measure DSA impact on convergence
- **Method**: Run identical problem with DSA on/off, compare iterations
- **Results**:
  - With DSA: 1,238 iterations
  - Without DSA: (runs longer, needs comparison)
- **Status**: ✅ Implemented in `phase2_manufactured.sh` (Test 2)

#### S_n Order Scaling
- **Purpose**: Measure convergence with different angular discretizations
- **Method**: Run S4/S6/S8 on identical problem
- **Results**:
  - S4: 1,631 iterations
  - S6: 1,631 iterations
  - S8: 1,631 iterations
- **Note**: Iteration counts should be similar (timing may differ)
- **Status**: ✅ Implemented in `phase2_manufactured.sh` (Test 3)

### 3. Code-to-Code Comparison

#### Diffusion Approximation
- **Purpose**: Compare transport results against diffusion theory
- **Method**: Run same problem with very high scattering ratio (diffusion-like)
- **Expected**: Transport solution should approach diffusion solution
- **Status**: 🔜 Not yet implemented

#### Monte Carlo Tallies
- **Purpose**: Compare flux and reaction rate tallies
- **Method**: Run OpenMC/MCNP on identical geometry, compare tallies
- **Expected**: Spatial flux distributions should agree within error bars
- **Status**: 🔜 Not yet implemented (requires Monte Carlo solver)

## Running the Tests

```bash
# Run all Phase 2 verification tests
./tests/phase2_manufactured.sh

# Run individual component tests
./tests/phase2_attn.sh      # Attenuation with Phase 2 features
./tests/phase2_shocktube.sh # Hydrodynamics with HLLC

# Original Phase 1 smoke test (regression)
./tests/smoke_test.sh
```

## Iteration Counting

The code now tracks:
- `transport_iterations`: Total number of transport sweep iterations
- `dsa_iterations`: Total number of DSA correction applications

These counters are printed at the end of each run for performance analysis.

## Future Enhancements

1. **Refined manufactured solutions**: Add more sophisticated analytic benchmarks
2. **Convergence rate analysis**: Plot error vs iterations for DSA on/off
3. **Grid convergence**: Measure spatial accuracy with varying shell counts
4. **Temperature-dependent XS**: Test Doppler broadening once HDF5 reader is complete
