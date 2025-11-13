#!/bin/bash
# Fine-Tune Bethe-Tait Benchmark Parameters
# Systematically adjusts parameters for optimal physical accuracy

set -e

echo "=== Bethe-Tait Benchmark Fine-Tuning ==="
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

echo "Step 1: Establishing critical configuration..."
echo ""

# Run steady-state k-eigenvalue calculation
if ./ax1 benchmarks/bethe_tait_steady_state.deck > /tmp/bethe_tait_steady_state.log 2>&1; then
    echo -e "${GREEN}✓${NC} Steady-state calculation completed"
    
    # Extract keff (try multiple patterns)
    keff=$(grep -E "keff=|k_eff" /tmp/bethe_tait_steady_state.log | tail -1 | awk '{print $NF}' | tr -d ',[]' | grep -oE "[0-9]+\.[0-9]+" | head -1)
    
    if [ -z "$keff" ]; then
        # Try extracting from output file
        if [ -f bethe_tait_steady_state_output_time.csv ]; then
            keff=$(tail -1 bethe_tait_steady_state_output_time.csv | awk '{print $4}')
        fi
    fi
    
    if [ ! -z "$keff" ] && [ "$keff" != "NaN" ]; then
        echo "  keff = $keff"
        
        # Check if critical
        keff_float=$(echo "$keff" | bc -l 2>/dev/null || echo "0")
        if (( $(echo "$keff_float > 0.95 && $keff_float < 1.05" | bc -l 2>/dev/null || echo "0") )); then
            echo -e "${GREEN}✓${NC} Reactor is critical (keff ≈ 1.0)"
        else
            echo -e "${YELLOW}⚠${NC} Reactor is not critical (keff = $keff)"
            echo "  Recommended: Adjust cross sections to achieve keff ≈ 1.0"
            echo "  - If keff < 0.95: Increase nu_sig_f or decrease sig_t"
            echo "  - If keff > 1.05: Decrease nu_sig_f or increase sig_t"
        fi
    else
        echo -e "${YELLOW}⚠${NC} Could not extract keff from output"
        echo "  Check /tmp/bethe_tait_steady_state.log for details"
    fi
else
    echo -e "${RED}✗${NC} Steady-state calculation failed"
    exit 1
fi

echo ""
echo "Step 2: Testing transient stability..."
echo ""

# Test different reactivity insertions
declare -a reactivity_values=(10.0 20.0 50.0)
STABLE_MAX_RHO=0

for rho in "${reactivity_values[@]}"; do
    echo "Testing reactivity insertion: $rho pcm"
    
    # Create temporary deck with reactivity
    temp_deck="/tmp/bethe_tait_rho${rho}.deck"
    sed "s/rho_insert [0-9.]*/rho_insert $rho/" benchmarks/bethe_tait_tuned.deck > "$temp_deck"
    temp_output="bethe_tait_rho${rho}_output_time.csv"
    sed -i '' "s/output_file.*/output_file bethe_tait_rho${rho}_output/" "$temp_deck" 2>/dev/null || \
    sed -i "s/output_file.*/output_file bethe_tait_rho${rho}_output/" "$temp_deck"
    
    if ./ax1 "$temp_deck" > /tmp/bethe_tait_rho${rho}.log 2>&1; then
        if [ -f "$temp_output" ]; then
            if grep -q "NaN" "$temp_output"; then
                echo -e "${RED}✗${NC} NaN values found at rho = $rho pcm"
                break
            else
                echo -e "${GREEN}✓${NC} Stable at rho = $rho pcm"
                STABLE_MAX_RHO=$rho
                
                # Extract final values
                final_line=$(tail -1 "$temp_output" 2>/dev/null)
                if [ ! -z "$final_line" ]; then
                    echo "  Final: $final_line"
                fi
            fi
        else
            echo -e "${YELLOW}⚠${NC} Output file not created"
        fi
    else
        echo -e "${RED}✗${NC} Simulation failed at rho = $rho pcm"
        break
    fi
    
    echo ""
done

echo "Step 3: Validating physical behavior..."
echo ""

# Check if we have stable results
if [ $(echo "$STABLE_MAX_RHO > 0" | bc -l 2>/dev/null || echo "0") -eq 1 ]; then
    echo -e "${GREEN}✓${NC} Maximum stable reactivity: $STABLE_MAX_RHO pcm"
    
    # Validate physical behavior
    stable_output="bethe_tait_rho${STABLE_MAX_RHO}_output_time.csv"
    if [ -f "$stable_output" ]; then
        echo "Analyzing physical behavior from $stable_output..."
        
        # Check power evolution
        power_values=$(awk 'NR>3 {print $2}' "$stable_output" | grep -v "NaN")
        if [ ! -z "$power_values" ]; then
            echo -e "${GREEN}✓${NC} Power values are finite"
            
            # Check if power is increasing (for positive reactivity)
            first_power=$(echo "$power_values" | head -1)
            last_power=$(echo "$power_values" | tail -1)
            if [ ! -z "$first_power" ] && [ ! -z "$last_power" ]; then
                echo "  Initial power: $first_power W"
                echo "  Final power: $last_power W"
            fi
        fi
        
        # Check alpha evolution
        alpha_values=$(awk 'NR>3 {print $3}' "$stable_output" | grep -v "NaN")
        if [ ! -z "$alpha_values" ]; then
            echo -e "${GREEN}✓${NC} Alpha values are finite"
            
            # Check if alpha is positive (for positive reactivity)
            first_alpha=$(echo "$alpha_values" | head -1)
            last_alpha=$(echo "$alpha_values" | tail -1)
            if [ ! -z "$first_alpha" ] && [ ! -z "$last_alpha" ]; then
                echo "  Initial alpha: $first_alpha 1/s"
                echo "  Final alpha: $last_alpha 1/s"
            fi
        fi
    fi
else
    echo -e "${YELLOW}⚠${NC} No stable reactivity found"
    echo "  May need further parameter tuning"
fi

echo ""
echo "=== Fine-Tuning Summary ==="
echo ""
echo "Recommendations:"
echo "1. If keff is not critical, adjust cross sections in bethe_tait_steady_state.deck"
echo "2. If NaN values occur at high reactivity, reduce reactivity or adjust feedback coefficients"
echo "3. For better physical accuracy, compare results with literature values"
echo "4. Consider adjusting time step for better resolution"
echo ""
echo "Next steps:"
echo "1. Establish critical configuration (keff ≈ 1.0)"
echo "2. Test stability with increasing reactivity"
echo "3. Validate physical behavior"
echo "4. Compare with literature values"
echo ""

