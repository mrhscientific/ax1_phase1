#!/bin/bash
# Bethe-Tait Parameter Tuning Script
# This script helps systematically tune the Bethe-Tait benchmark parameters

set -e

echo "=== Bethe-Tait Parameter Tuning Script ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if ax1 exists
if [ ! -f ./ax1 ]; then
    echo "Building ax1..."
    make clean > /dev/null 2>&1
    make > /dev/null 2>&1
fi

echo "Step 1: Running steady-state k-eigenvalue calculation..."
echo "  This establishes the critical configuration before transient"
echo ""

# Run steady-state
if ./ax1 benchmarks/bethe_tait_steady_state.deck > /tmp/bethe_tait_steady_state.log 2>&1; then
    echo -e "${GREEN}✓${NC} Steady-state calculation completed"
    
    # Extract keff
    keff=$(grep -E "keff=|k_eff" /tmp/bethe_tait_steady_state.log | tail -1 | awk '{print $NF}' | tr -d ',')
    
    if [ -z "$keff" ]; then
        echo -e "${YELLOW}⚠${NC} Could not extract keff from output"
        echo "  Check /tmp/bethe_tait_steady_state.log for details"
    else
        echo "  keff = $keff"
        
        # Check if critical
        if (( $(echo "$keff > 0.95 && $keff < 1.05" | bc -l 2>/dev/null || echo "0") )); then
            echo -e "${GREEN}✓${NC} Reactor is critical (keff ≈ 1.0)"
            echo "  Proceeding to transient calculation..."
        else
            echo -e "${YELLOW}⚠${NC} Reactor is not critical (keff = $keff)"
            echo "  Recommended: Adjust cross sections to achieve keff ≈ 1.0"
            echo "  - If keff < 0.95: Increase nu_sig_f or decrease sig_t"
            echo "  - If keff > 1.05: Decrease nu_sig_f or increase sig_t"
        fi
    fi
else
    echo -e "${RED}✗${NC} Steady-state calculation failed"
    echo "  Check /tmp/bethe_tait_steady_state.log for details"
    exit 1
fi

echo ""
echo "Step 2: Running transient calculation with small reactivity..."
echo "  Using tuned configuration with small reactivity insertion"
echo ""

# Run transient
if ./ax1 benchmarks/bethe_tait_tuned.deck > /tmp/bethe_tait_tuned.log 2>&1; then
    echo -e "${GREEN}✓${NC} Transient calculation completed"
    
    # Check for NaN values
    if [ -f bethe_tait_tuned_output_time.csv ]; then
        if grep -q "NaN" bethe_tait_tuned_output_time.csv; then
            echo -e "${YELLOW}⚠${NC} NaN values found in output"
            echo "  This indicates parameter tuning is needed"
            echo "  Recommended actions:"
            echo "  1. Reduce reactivity insertion (rho_insert)"
            echo "  2. Reduce feedback coefficients (doppler_coef, expansion_coef)"
            echo "  3. Increase time step (dt)"
            echo "  4. Check cross sections are physically reasonable"
        else
            echo -e "${GREEN}✓${NC} No NaN values found in output"
            echo "  Simulation is stable!"
            
            # Extract final values
            if [ -f bethe_tait_tuned_output_time.csv ]; then
                final_line=$(tail -1 bethe_tait_tuned_output_time.csv)
                echo "  Final values: $final_line"
            fi
        fi
    else
        echo -e "${YELLOW}⚠${NC} Output file not created"
        echo "  Check /tmp/bethe_tait_tuned.log for details"
    fi
else
    echo -e "${RED}✗${NC} Transient calculation failed"
    echo "  Check /tmp/bethe_tait_tuned.log for details"
    exit 1
fi

echo ""
echo "=== Tuning Summary ==="
echo ""
echo "Next steps:"
echo "  1. If keff is not critical, adjust cross sections in bethe_tait_steady_state.deck"
echo "  2. If NaN values are found, adjust parameters in bethe_tait_tuned.deck"
echo "  3. Gradually increase reactivity insertion and check stability"
echo "  4. Compare results with literature values"
echo ""
echo "For detailed tuning instructions, see BETHE_TAIT_PARAMETER_TUNING.md"
echo ""

