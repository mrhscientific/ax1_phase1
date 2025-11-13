# Validation Framework

This directory contains validation scripts and tools for Phase 3 features.

## Scripts

### `validate_bethe_tait.sh`

Validates the Bethe-Tait benchmark by:
- Running the benchmark problem
- Extracting key metrics (time, power, alpha, keff, reactivity)
- Checking for expected behavior
- Comparing with literature (when available)

**Usage:**
```bash
./validation/validate_bethe_tait.sh
```

**Output:**
- `bethe_tait_output_time.csv` - Time history
- `bethe_tait_output_spatial.csv` - Spatial history
- Validation report

### `code_to_code_comparison.sh`

Code-to-code comparison framework for comparing AX-1 with other codes:
- MCNP (Monte Carlo N-Particle)
- Serpent (Monte Carlo code)
- OpenMC (Monte Carlo code)

**Usage:**
```bash
./validation/code_to_code_comparison.sh
```

**Output:**
- `comparison_results.txt` - Comparison results
- `standardized_output_format.txt` - Standardized output format

**Note:** This is a stub framework. Full implementation requires:
1. Running reference codes
2. Parsing their output
3. Converting to standardized format
4. Comparing results

## Validation Tests

### Bethe-Tait Benchmark

The Bethe-Tait benchmark tests:
- Fast reactor transient response
- Reactivity feedback effects
- Power and reactivity evolution over time

**Expected Results:**
- Fast reactor criticality (keff ≈ 1.0)
- Reactivity insertion effects
- Temperature and density feedback
- Power transient response

**Literature References:**
- Bethe-Tait analysis for fast reactor safety
- Historical experiments (Godiva, Jezebel)

### Code-to-Code Comparison

Comparison metrics:
- k_eff (multiplication factor)
- Flux distribution (spatial and energy)
- Reaction rates (fission, capture, scattering)
- Power distribution
- Alpha (reactivity eigenvalue)

**Standardized Format:**
- CSV format with consistent units
- Time, keff, alpha, power, flux, reaction rates
- Easy to parse and compare

## Running Validation

### Quick Validation

```bash
# Run Bethe-Tait validation
./validation/validate_bethe_tait.sh

# Run code-to-code comparison
./validation/code_to_code_comparison.sh
```

### Full Validation Suite

```bash
# Run all validation tests
./tests/test_phase3.sh
./tests/test_uq_sensitivity.sh
./validation/validate_bethe_tait.sh
./validation/code_to_code_comparison.sh
```

## Output Files

### Bethe-Tait Validation
- `bethe_tait_output_time.csv` - Time history
- `bethe_tait_output_spatial.csv` - Spatial history
- `/tmp/bethe_tait_output.log` - Simulation log

### Code-to-Code Comparison
- `comparison_results.txt` - Comparison results
- `standardized_output_format.txt` - Standardized format
- `ax1_output.csv` - AX-1 output
- `reference_output.csv` - Reference code output

## Notes

- Validation requires parameter tuning for some benchmarks
- Code-to-code comparison requires reference codes to be installed
- Full validation requires comparison with published results
- Some benchmarks may need cross-section adjustments

## References

- Bethe-Tait analysis for fast reactor safety
- Historical experiments (Godiva, Jezebel)
- MCNP, Serpent, OpenMC documentation
- Validation datasets from literature

