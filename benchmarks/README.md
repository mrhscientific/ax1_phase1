# AX-1 Phase 2 Benchmark Suite

This directory contains benchmark problems to test and validate Phase 2 features.

## Available Benchmarks

### 1. Godiva Criticality (`godiva_criticality.deck`)

**Purpose**: Tests criticality eigenvalue solver with realistic fast reactor parameters

**Features**:
- Alpha-eigenvalue solver
- S8 angular quadrature
- DSA acceleration enabled
- 6-group delayed neutrons
- Fast spectrum (3 energy groups)

**Model**: Bare highly enriched uranium sphere at critical configuration

**Key Physics**:
- Highly fissile material (93.8% U-235)
- Fast neutron spectrum
- No moderation
- Criticality eigenvalue calculation

**Expected Results**:
- Converges to k_eff ≈ 1.0 (critical)
- Demonstrates convergence behavior
- Shows transport iteration counts

### 2. SOD Shock Tube (`sod_shock_tube.deck`)

**Purpose**: Validates HLLC Riemann solver and slope limiting for hydrodynamics

**Features**:
- Slope-limited interface reconstruction
- HLLC-inspired PVRS interface pressure
- Density/temperature discontinuity (Riemann problem)

**Model**: 1D Riemann problem with initial jump at x=0.5

**Initial Conditions**:
- Left: ρ = 1.0, T = 348 K
- Right: ρ = 0.125, T = 278 K

**Expected Results**:
- Shock wave propagates to right
- Rarefaction wave propagates to left
- Contact discontinuity forms
- Should see proper wave structure without oscillations

**Reference**: G.A. Sod, "A Survey of Several Finite Difference Methods for Systems of Nonlinear Hyperbolic Conservation Laws", JCP 1978

### 3. Upscatter Treatment (`upscatter_treatment.deck`)

**Purpose**: Tests upscatter control feature

**Features**:
- S6 angular quadrature
- Multi-group scattering with significant upscatter
- Configurable upscatter treatment (allow/neglect/scale)

**Model**: Thermal reactor with upscatter from thermal to epithermal groups

**Key Physics**:
- Thermal neutron spectrum
- Significant upscatter component
- Three energy groups (fast, epithermal, thermal)

**Usage**:
Run multiple times with different `upscatter` settings:
- `upscatter allow` - Full upscatter included
- `upscatter neglect` - Up ANSCATTERS
- `upscatter scale` - UpANSCATTERS scaled by `upscatter_scale`

### 4. DSA Convergence (`dsa_convergence.deck`)

**Purpose**: Demonstrates DSA acceleration effect

**Features**:
- Configurable DSA on/off
- Transport iteration counting
- Moderately scattering medium

**Model**: Scattering-dominant problem

**Usage**:
Run twice:
1. With `use_dsa true` - Faster convergence
2. With `use_dsa false` - Slower convergence, more iterations

Compare the iteration counts to see DSA effectiveness.

## Running Benchmarks

### Quick Start

Run all benchmarks:
```bash
./benchmarks/run_benchmarks.sh
```

Run individual benchmark:
```bash
./ax1 benchmarks/godiva_criticality.deck
```

### Detailed Analysis

To analyze results, use the output files:
```bash
# View results
cat benchmarks/results/godiva_criticality.out

# Extract iteration counts
grep "Total transport iterations" benchmarks/results/*.out

# Compare DSA effectiveness
diff benchmarks/results/dsa_convergence.out benchmarks/results/dsa_no_dsa.out
```

## Expected Behavior

### Transport
- **Convergence**: keff values should stabilize
- **Iterations**: DSA should reduce iteration counts by ~30-50%
- **Accuracy**: Spatial flux distributions should be smooth

### Hydrodynamics
- **Shock capturing**: Discontinuities resolved without oscillations
- **Conservation**: Mass and momentum conserved
- **Stability**: Solutions remain stable with CFL ≤ 0.5

### Upscatter
- **Allow mode**: Full physics, more accurate
- **Neglect mode**: Faster, approximate for fast reactors
- **Scale mode**: Tunable treatment

## Performance Metrics

The benchmark suite tracks:
- **Transport iterations**: Total sweep iterations
- **DSA iterations**: DSA correction applications
- **Wall-clock time**: Total execution time
- **Convergence behavior**: keff vs iteration

## Validation

These benchmarks serve as:
1. **Correctness checks**: Verify physics implementation
2. **Performance tests**: Measure solver efficiency
3. **Regression tests**: Ensure changes don't break existing functionality
4. **Method verification**: Compare against reference solutions

## Future Benchmarks

Planned additions:
- **Teapot Benchmark**: OECD/NEA criticality problem
- **Analytic attenuation**: Manufactured solution with exact answer
- **Grid convergence**: Spatial accuracy study
- **Reflector assemblies**: Criticality with reflector
- **EOC benchmark**: End-of-cycle eigenvalue shift

## References

- Godiva: Los Alamos National Laboratory critical assembly
- SOD: Sod, JCP 1978, doi:10.1016/0021-9991(78)90123-2
- DSA: Alcouffe et al., NSE 1981
