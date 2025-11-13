# Testing Phase 2 - Comprehensive Guide

This document describes how to test and verify Phase 2 implementations in AX-1.

## Quick Start

```bash
# Build the code
make

# Run all Phase 2 tests
./tests/phase2_manufactured.sh
./benchmarks/run_benchmarks.sh

# Run Phase 1 regression test
./tests/smoke_test.sh
```

## Test Suite Overview

### 1. Unit Tests (`tests/`)

#### `smoke_test.sh` - Phase 1 Regression
Verifies that Phase 2 doesn't break Phase 1 functionality.

```bash
./tests/smoke_test.sh
```

**Expected**: All Phase 1 features work, keff ≈ 0.02236

#### `phase2_manufactured.sh` - Phase 2 Verification
Comprehensive test of Phase 2 features with instrumentation.

```bash
./tests/phase2_manufactured.sh
```

**Tests**:
- Exponential attenuation manufactured solution
- DSA performance comparison
- S_n order scaling (S4/S6/S8)

**Expected**: All tests pass with iteration counts reported

#### `phase2_attn.sh` - Attenuation Test
Quick test with Phase 2 features enabled.

```bash
./tests/phase2_attn.sh
```

#### `phase2_shocktube.sh` - Hydrodynamics Test
Tests HLLC Riemann solver and slope limiting.

```bash
./tests/phase2_shocktube.sh
```

### 2. Benchmarks (`benchmarks/`)

#### Running All Benchmarks

```bash
./benchmarks/run_benchmarks.sh
```

This runs all benchmark problems and generates a report in `benchmarks/results/`.

#### Individual Benchmarks

**Godiva Criticality** (Fast reactor)
```bash
./ax1 benchmarks/godiva_criticality.deck
```

**SOD Shock Tube** (Hydrodynamics)
```bash
./ax1 benchmarks/sod_shock_tube.deck
```

**Upscatter Treatment** (Upscatter control)
```bash
./ax1 benchmarks/upscatter_treatment.deck
```

**DSA Convergence** (Acceleration)
```bash
./ax1 benchmarks/dsa_convergence.deck
```

## Testing Individual Phase 2 Features

### 1. S_n Quadrature (S4/S6/S8)

Create a custom deck with different quadrature orders:

```ini
[controls]
Sn 8          # Try 4, 6, or 8
use_dsa false
```

Compare iteration counts and accuracy. S8 should be more accurate but slower.

**Expected**: All orders run successfully, higher orders use more quadrature points.

### 2. DSA Acceleration

Test with DSA enabled and disabled:

```ini
[controls]
use_dsa true   # Try true or false
```

**Expected**: DSA enabled should show reduced iteration counts (30-50% reduction).

**Procedure**:
1. Run with `use_dsa true`
2. Note transport iteration count
3. Edit deck, set `use_dsa false`
4. Run again
5. Compare: more iterations without DSA

### 3. Upscatter Control

Test different upscatter modes:

```ini
[controls]
upscatter allow   # Try: allow, neglect, scale
upscatter_scale 0.5   # Only used if upscatter=scale
```

**Expected**:
- `allow`: Full physics, most accurate
- `neglect`: Faster, approximately correct for fast reactors
- `scale`: Tunable intermediate behavior

**Procedure**:
```bash
# Run with each mode
sed 's/upscatter allow/upscatter neglect/' sample.deck > test_neglect.deck
./ax1 test_neglect.deck
```

### 4. HLLC Riemann Solver and Slope Limiting

The hydrodynamics improvements are automatically used. To verify they work:

1. Look for smooth solutions without oscillations
2. Check that discontinuities are captured correctly
3. Verify conservation (mass, momentum, energy)

**Shock tube test**:
```bash
./ax1 benchmarks/sod_shock_tube.deck
```

**Expected**: 
- Sharp shock front without oscillations
- Proper wave structure (shock, rarefaction, contact)
- No Gibbs phenomena near discontinuities

### 5. Performance Instrumentation

All runs now report iteration counts:

```
Total transport iterations: XXXX
DSA iterations: YYYY
```

Use these to:
- Measure DSA effectiveness
- Compare S_n orders
- Track convergence behavior

## Validation Tests

### Method Verification

Manufactured solutions test against known analytic results:

```bash
./tests/phase2_manufactured.sh
```

### Code-to-Code Comparison

For future implementation:
1. Run same problem with diffusion approximation
2. Compare flux distributions
3. Verify transport approaches diffusion in diffusive limit

### Performance Benchmarks

Measure:
- Iteration counts (transport, DSA)
- Wall-clock time
- Memory usage
- Convergence rates

Compare DSA on vs off:
```bash
# With DSA
./ax1 benchmarks/dsa_convergence.deck

# Without DSA (edit deck first)
sed -i.bak 's/use_dsa true/use_dsa false/' benchmarks/dsa_convergence.deck
./ax1 benchmarks/dsa_convergence.deck
```

## Interpretation of Results

### Transport Iterations

- **Good**: < 1000 for simple problems
- **Acceptable**: 1000-10000 for complex problems
- **Concerning**: > 10000 (may indicate convergence issues)

### DSA Effectiveness

Compare iteration counts:
- **Effective DSA**: 30-50% reduction in iterations
- **Marginal**: < 20% reduction
- **Ineffective**: No reduction or slower (requires investigation)

### Convergence

Monitor keff throughout run:
```
t=  0.00000  alpha=  1.000000  keff=  0.02236
t=  0.10000  alpha=  1.000000  keff=  0.02236
t=  0.20000  alpha=  1.000000  keff=  0.02237
```

**Expected**: 
- Stabilizes around target value (typically ≈1.0 for critical)
- Small fluctuations are normal
- Large changes indicate instability

### Hydrodynamics

Check output for:
- **Smooth density**: No oscillations
- **Sharp shocks**: Properly captured discontinuities
- **Conservative**: Physical quantities conserved

## Troubleshooting

### Convergence Failures

**Symptoms**: keff = NaN, diverging values

**Solutions**:
1. Reduce time step
2. Tighten tolerances
3. Check cross sections (physically reasonable?)
4. Try lower S_n order first

### DSA Not Working

**Symptoms**: Same iteration counts with/without DSA

**Check**:
1. `use_dsa true` in deck
2. Look for "DSA iterations" in output
3. Verify it's being called in code

### Oscillations in Hydro

**Symptoms**: Wild fluctuations in density/pressure

**Solutions**:
1. Reduce time step
2. Lower CFL number (try 0.5 instead of 0.8)
3. Verify slope limiting is active
4. Check EOS parameters

### Upscatter Not Taking Effect

**Check**:
1. Multi-group problem? (need 2+ groups)
2. Upscatter present in scattering matrix?
3. Correct mode specified?

## Automated Testing

### CI/CD Integration

The project includes a smoke test that can be used in CI:

```bash
./tests/smoke_test.sh
```

Exit code: 0 = pass, non-zero = fail

### Test Coverage

Current test coverage:
- ✅ Transport solver (attenuation)
- ✅ Alpha-eigenvalue solver
- ✅ DSA acceleration
- ✅ S_n quadrature
- ✅ Upscatter control
- ✅ HLLC hydrodynamics
- ✅ Slope limiting
- ⚠️ EOS tables (basic, needs more)
- ⚠️ Temperature-dependent XS (stub only)

### Regression Testing

Before making changes:
1. Run `./tests/smoke_test.sh`
2. Note keff and iteration counts
3. Make changes
4. Re-run test
5. Compare: Should be identical or better

## Advanced Testing

### Grid Convergence Study

Run same problem with different shell counts:
```bash
# Edit Nshell in deck: 10, 20, 40, 80
./ax1 test_N10.deck
./ax1 test_N20.deck
```

Plot error vs resolution.

### Time Step Study

Vary dt and measure:
- Accuracy (how does solution change?)
- Stability (what's the maximum stable dt?)
- Performance (how does wall time scale?)

### Parametric Studies

Example: Effect of upscatter scale on flux distribution

```bash
for scale in 0.0 0.25 0.5 0.75 1.0; do
    sed "s/upscatter_scale 1.0/upscatter_scale $scale/" deck > tmp.deck
    ./ax1 tmp.deck > results_scale${scale}.out
done
```

## Documentation

See also:
- `README.md` - Project overview
- `benchmarks/README.md` - Benchmark descriptions
- `tests/phase2_verification.md` - Verification details
- `AGENTS.md` - Build and run instructions

## Summary Checklist

Run these tests to verify Phase 2 is working:

- [ ] `./tests/smoke_test.sh` - Regression test passes
- [ ] `./tests/phase2_manufactured.sh` - All verification tests pass
- [ ] `./benchmarks/run_benchmarks.sh` - All benchmarks complete
- [ ] DSA reduces iterations by 30-50%
- [ ] S8 runs successfully (more iterations than S4)
- [ ] Shock tube shows proper wave structure
- [ ] Upscatter modes produce different results
- [ ] No NaN values in output
- [ ] Solutions converge smoothly

If all checks pass, Phase 2 is properly implemented! 🎉
