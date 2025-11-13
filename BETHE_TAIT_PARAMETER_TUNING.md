# Bethe-Tait Benchmark Parameter Tuning Guide

## Problem Statement

The Bethe-Tait benchmark is currently producing NaN values for power, alpha, and keff. This guide explains how to tune the parameters to achieve physically meaningful results.

## Root Cause Analysis

### Current Issues

1. **NaN values from start**: Alpha and keff are NaN from the first time step
2. **No power generated**: Power values are NaN throughout the simulation
3. **Potential causes**:
   - Cross sections not critical (keff far from 1.0)
   - Zero initial power causing division by zero
   - Reactivity insertion too large
   - Initial conditions not physically consistent
   - Time step too small or too large

## Parameter Tuning Strategy

### Step 1: Establish Critical Configuration

**Goal**: Get a critical reactor (keff ≈ 1.0) before applying reactivity insertion.

#### 1.1. Tune Cross Sections

**Current cross sections**:
```
[xs_group]
1 1  2.5   0.40  0.99
1 2  3.0   0.30  0.01
1 3  4.5   0.20  0.00
```

**Issues**:
- Total cross sections (sig_t) are large (2.5, 3.0, 4.5)
- Fission cross sections (nu_sig_f) might not match geometry
- Scattering cross sections might not be balanced

**Tuning approach**:

1. **Start with simpler cross sections** (like sample_phase1.deck):
   ```
   [xs_group]
   1 1  0.6   0.08  0.6
   1 2  0.5   0.04  0.3
   1 3  0.4   0.01  0.1
   ```

2. **Adjust nu_sig_f to achieve criticality**:
   - Run steady-state k-eigenvalue calculation
   - Adjust nu_sig_f until keff ≈ 1.0
   - Scale all groups proportionally

3. **Balance scattering**:
   - Ensure sig_s is less than sig_t
   - Check that scattering is physically reasonable

#### 1.2. Tune Geometry

**Current geometry**:
- 30 shells
- Radius: 0.25 to 7.5 cm
- Density: 18.7 g/cm³ (uranium density)

**Tuning approach**:

1. **Start with smaller geometry** (fewer shells):
   - Use 10-20 shells initially
   - Easier to debug and tune

2. **Adjust radius**:
   - Larger radius → more neutrons escape → lower keff
   - Smaller radius → more neutrons stay → higher keff
   - For fast reactor, typical radius is 5-10 cm

3. **Check density**:
   - Uranium density: ~18.7 g/cm³ is correct
   - Ensure mass calculation is correct

#### 1.3. Run Steady-State k-Eigenvalue Calculation

**Before transient**, run steady-state to check criticality:

1. **Create steady-state deck**:
   ```
   [controls]
   eigmode k
   dt 1.0e-3
   hydro_per_neut 1
   cfl 0.8
   Sn 8
   use_dsa true
   t_end 0.001
   output_freq 100
   ```

2. **Check keff**:
   - Should be close to 1.0 (0.95-1.05)
   - If keff < 0.9, increase nu_sig_f or decrease sig_t
   - If keff > 1.1, decrease nu_sig_f or increase sig_t

3. **Adjust until critical**:
   - Iterate on cross sections
   - Check flux distribution
   - Verify power distribution is reasonable

### Step 2: Set Initial Conditions

**Goal**: Establish stable initial state before reactivity insertion.

#### 2.1. Initial Power

**Issue**: Zero initial power causes division by zero in some calculations.

**Solution**:
- Set initial power to small non-zero value (1.0 W)
- Or initialize from steady-state solution
- Ensure power is physically reasonable

#### 2.2. Initial Temperature

**Current**: 300 K (room temperature)

**Tuning**:
- Should match T_ref in reactivity feedback
- For fast reactor, typical operating temperature is 500-800 K
- Start with T_ref = 300 K, then increase if needed

#### 2.3. Initial Density

**Current**: 18.7 g/cm³ (uranium density)

**Tuning**:
- Should match rho_ref in reactivity feedback
- Calculate from geometry and mass
- Ensure consistency with EOS

### Step 3: Tune Reactivity Insertion

**Goal**: Apply realistic reactivity insertion.

#### 3.1. Reactivity Magnitude

**Current**: rho_insert = 100.0 pcm

**Issues**:
- 100 pcm might be too large for initial transient
- Large reactivity can cause numerical instabilities
- Should start small and increase gradually

**Tuning approach**:

1. **Start with small reactivity**:
   - rho_insert = 10.0 pcm (small insertion)
   - Check that simulation remains stable
   - Gradually increase to 50, 100, 200 pcm

2. **Check reactivity feedback**:
   - Doppler coefficient: -2.0 pcm/K (typical for fast reactor)
   - Expansion coefficient: -1.5 pcm/K (typical for fast reactor)
   - Adjust if needed

3. **Time-dependent reactivity**:
   - Consider gradual insertion instead of step
   - Use reactivity profile if available
   - Check reactivity evolution over time

### Step 4: Tune Time Step and Numerical Parameters

**Goal**: Ensure numerical stability and accuracy.

#### 4.1. Time Step

**Current**: dt = 1.0e-6 s

**Issues**:
- Very small time step (1 μs)
- Might be too small for initial conditions
- Could cause numerical issues

**Tuning approach**:

1. **Start with larger time step**:
   - dt = 1.0e-4 s (100 μs)
   - Check stability
   - Gradually decrease if needed

2. **Use adaptive time step**:
   - Let code adjust time step automatically
   - Check CFL condition
   - Monitor W-criterion

3. **Check hydro_per_neut**:
   - Current: hydro_per_neut = 1
   - Increase if hydrodynamics is unstable
   - Decrease if neutronics is unstable

#### 4.2. CFL Condition

**Current**: cfl = 0.5

**Tuning**:
- Should be < 1.0 for stability
- Typical values: 0.5-0.8
- Increase if simulation is too slow
- Decrease if unstable

#### 4.3. Sn Order and DSA

**Current**: Sn = 8, use_dsa = true

**Tuning**:
- S8 is good for accuracy
- DSA helps convergence
- Can reduce to S4 for faster testing
- DSA should be enabled for stability

### Step 5: Tune Reactivity Feedback

**Goal**: Ensure reactivity feedback is physically reasonable.

#### 5.1. Doppler Coefficient

**Current**: doppler_coef = -2.0 pcm/K

**Typical values**:
- Fast reactor: -1.0 to -3.0 pcm/K
- Thermal reactor: -2.0 to -5.0 pcm/K

**Tuning**:
- Start with -1.0 pcm/K
- Increase magnitude if needed
- Check temperature evolution

#### 5.2. Expansion Coefficient

**Current**: expansion_coef = -1.5 pcm/K

**Typical values**:
- Fast reactor: -0.5 to -2.0 pcm/K
- Thermal reactor: -1.0 to -3.0 pcm/K

**Tuning**:
- Start with -0.5 pcm/K
- Increase magnitude if needed
- Check density evolution

#### 5.3. Void Coefficient

**Current**: enable_void = false

**Tuning**:
- Usually not needed for solid fuel
- Enable if simulating void formation
- Typical values: -100 to -500 pcm/%void

### Step 6: Tune Temperature-Dependent Cross Sections

**Goal**: Ensure temperature-dependent XS is working correctly.

#### 6.1. Reference Temperature

**Current**: T_ref = 300.0 K

**Tuning**:
- Should match initial temperature
- Typical: 300-800 K
- Check that T_ref is consistent with initial conditions

#### 6.2. Doppler Exponent

**Current**: doppler_exponent = 0.5

**Typical values**:
- 0.5 for most materials
- 0.4-0.6 for different materials
- Check literature for specific material

**Tuning**:
- Start with 0.5 (typical)
- Adjust if needed
- Check temperature correction

### Step 7: Systematic Tuning Procedure

**Recommended procedure**:

1. **Step 1: Steady-state criticality**
   - Run k-eigenvalue calculation
   - Tune cross sections until keff ≈ 1.0
   - Check flux and power distributions

2. **Step 2: Small transient**
   - Set rho_insert = 10.0 pcm
   - Run transient with small time step
   - Check that power, alpha, keff are finite

3. **Step 3: Increase reactivity**
   - Gradually increase rho_insert
   - Check stability at each step
   - Monitor power and temperature

4. **Step 4: Tune feedback**
   - Adjust Doppler and expansion coefficients
   - Check reactivity evolution
   - Verify physical behavior

5. **Step 5: Final tuning**
   - Adjust time step for accuracy
   - Check numerical stability
   - Compare with literature

## Example Tuned Configuration

### Simplified Bethe-Tait Deck

```deck
# Bethe-Tait Benchmark - Tuned Configuration
# Start with simpler cross sections and smaller geometry

[controls]
eigmode alpha
dt 1.0e-4
hydro_per_neut 1
cfl 0.5
Sn 8
use_dsa true
upscatter allow
# Phase 3: Small reactivity insertion
rho_insert 10.0
t_end 0.01
output_freq 10
output_file bethe_tait_output

[geometry]
Nshell 20
G 3

[materials]
nmat 1

[material]
1

# Phase 3: Enable temperature-dependent cross sections
[material_properties]
1 true 300.0 0.5

# Simplified cross sections (tuned for criticality)
[xs_group]
1 1  0.8   0.12  0.6
1 2  0.7   0.08  0.3
1 3  0.6   0.04  0.1

# Scattering
[scatter]
1 1 1  0.6
1 1 2  0.1
1 2 2  0.55
1 2 3  0.1
1 3 3  0.45

# Delayed neutrons (6-group Keepin data for 235U)
[delayed]
1 1  0.000230  0.0127
1 2  0.000832  0.0317
1 3  0.000925  0.1150
1 4  0.000279  0.3110
1 5  0.000082  1.4000
1 6  0.000075  3.8700

# Phase 3: Reactivity feedback parameters (reduced coefficients)
[reactivity_feedback]
enable_doppler true
enable_expansion true
enable_void false
doppler_coef -1.0
expansion_coef -0.5
void_coef 0.0
T_ref 300.0
rho_ref 0.0

# EOS: Ideal gas with gamma=1.4
[eos]
1  0 0 287  717 0
10 0 0 287  717 0
20 0 0 287 717 0

[shells]
# Smaller geometry for easier tuning
1 0.5  1 10.0 300
2 1.0  1 10.0 300
3 1.5  1 10.0 300
4 2.0  1 10.0 300
5 2.5  1 10.0 300
6 3.0  1 10.0 300
7 3.5  1 10.0 300
8 4.0  1 10.0 300
9 4.5  1 10.0 300
10 5.0 1 10.0 300
11 5.5 1 10.0 300
12 6.0 1 10.0 300
13 6.5 1 10.0 300
14 7.0 1 10.0 300
15 7.5 1 10.0 300
16 8.0 1 10.0 300
17 8.5 1 10.0 300
18 9.0 1 10.0 300
19 9.5 1 10.0 300
20 10.0 1 10.0 300
```

### Tuning Script

Create a script to systematically tune parameters:

```bash
#!/bin/bash
# Bethe-Tait Parameter Tuning Script

# Step 1: Run steady-state k-eigenvalue
echo "Step 1: Running steady-state k-eigenvalue..."
./ax1 bethe_tait_steady_state.deck > steady_state.log 2>&1
keff=$(grep "keff=" steady_state.log | tail -1 | awk '{print $NF}')
echo "keff = $keff"

# Step 2: Adjust cross sections if not critical
if (( $(echo "$keff < 0.95" | bc -l) )); then
    echo "keff too low, increasing nu_sig_f..."
    # Adjust cross sections
elif (( $(echo "$keff > 1.05" | bc -l) )); then
    echo "keff too high, decreasing nu_sig_f..."
    # Adjust cross sections
else
    echo "keff is critical, proceeding to transient..."
fi

# Step 3: Run transient with small reactivity
echo "Step 2: Running transient with small reactivity..."
./ax1 bethe_tait_transient_small.deck > transient_small.log 2>&1
# Check for NaN values
if grep -q "NaN" bethe_tait_output_time.csv; then
    echo "NaN values found, adjusting parameters..."
else
    echo "No NaN values, simulation is stable!"
fi
```

## Troubleshooting

### Issue 1: NaN from Start

**Symptoms**: Alpha and keff are NaN from the first time step

**Possible causes**:
- Cross sections not balanced
- Zero initial power
- Division by zero in calculations

**Solutions**:
1. Check cross sections are physically reasonable
2. Set initial power to small non-zero value
3. Run steady-state first to establish initial state
4. Check for division by zero in code

### Issue 2: NaN After Some Time

**Symptoms**: Simulation starts OK but becomes NaN later

**Possible causes**:
- Numerical instability
- Time step too large
- Reactivity feedback too strong
- Temperature becoming too high

**Solutions**:
1. Reduce time step
2. Reduce reactivity insertion
3. Reduce feedback coefficients
4. Check temperature limits

### Issue 3: Unphysical Results

**Symptoms**: Results are finite but unphysical

**Possible causes**:
- Wrong cross sections
- Wrong initial conditions
- Wrong reactivity feedback

**Solutions**:
1. Compare with literature values
2. Check units and scaling
3. Verify physical parameters
4. Run code-to-code comparison

## Validation

### Expected Results

For a properly tuned Bethe-Tait benchmark:

1. **Initial state**:
   - keff ≈ 1.0 (critical)
   - Alpha ≈ 0.0 1/s (steady state)
   - Power: finite, positive value

2. **After reactivity insertion**:
   - keff > 1.0 (supercritical)
   - Alpha > 0.0 1/s (power increasing)
   - Power: increasing with time

3. **With feedback**:
   - Reactivity decreases due to feedback
   - Temperature increases
   - Power reaches peak then decreases

### Comparison with Literature

Compare results with:
- Bethe-Tait analysis papers
- Historical experiments (Godiva, Jezebel)
- Other codes (MCNP, Serpent, OpenMC)

## References

1. Bethe-Tait analysis for fast reactor safety
2. Historical experiments (Godiva, Jezebel)
3. Fast reactor transient analysis literature
4. Cross-section data libraries (ENDF/B, JEFF)
5. Reactivity feedback coefficients from literature

## Next Steps

1. **Create tuned deck file**: Start with simplified configuration
2. **Run steady-state**: Establish critical configuration
3. **Run small transient**: Test with small reactivity
4. **Gradually increase**: Increase reactivity and check stability
5. **Compare with literature**: Validate against published results

---

**End of Parameter Tuning Guide**

