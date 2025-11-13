#!/bin/bash
# Validate Bethe-Tait Benchmark Progression
# Tests stability as reactivity is gradually increased

set -e

echo "=== Bethe-Tait Benchmark Progression Validation ==="
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

# Test configurations
declare -a configs=(
    "benchmarks/bethe_tait_tuned.deck:10.0:10 pcm"
    "benchmarks/bethe_tait_tuned_rho20.deck:20.0:20 pcm"
    "benchmarks/bethe_tait_tuned_rho50.deck:50.0:50 pcm"
)

TESTS_PASSED=0
TESTS_FAILED=0

echo "Testing stability with increasing reactivity insertion..."
echo ""

for config in "${configs[@]}"; do
    IFS=':' read -r deck_file rho_value rho_label <<< "$config"
    
    echo "Testing: Reactivity insertion = $rho_label"
    
    # Check if deck file exists
    if [ ! -f "$deck_file" ]; then
        echo -e "${YELLOW}⚠${NC} Deck file not found: $deck_file"
        continue
    fi
    
    # Run simulation
    output_log="/tmp/bethe_tait_${rho_value}.log"
    if ./ax1 "$deck_file" > "$output_log" 2>&1; then
        echo -e "${GREEN}✓${NC} Simulation completed"
        
        # Extract output file name from deck
        output_file=$(grep "output_file" "$deck_file" | awk '{print $2}')
        if [ -z "$output_file" ]; then
            output_file="bethe_tait_tuned_output_time.csv"
        else
            output_file="${output_file}_time.csv"
        fi
        
        # Check for NaN values
        if [ -f "$output_file" ]; then
            if grep -q "NaN" "$output_file"; then
                echo -e "${RED}✗${NC} NaN values found in output"
                TESTS_FAILED=$((TESTS_FAILED + 1))
            else
                echo -e "${GREEN}✓${NC} No NaN values found"
                
                # Extract final values
                final_line=$(tail -1 "$output_file" 2>/dev/null)
                if [ ! -z "$final_line" ]; then
                    echo "  Final values: $final_line"
                fi
                
                # Check if values are reasonable
                if echo "$final_line" | grep -qE "[0-9]+\.[0-9]+"; then
                    echo -e "${GREEN}✓${NC} Values are finite and reasonable"
                    TESTS_PASSED=$((TESTS_PASSED + 1))
                else
                    echo -e "${YELLOW}⚠${NC} Values may not be reasonable"
                    TESTS_FAILED=$((TESTS_FAILED + 1))
                fi
            fi
        else
            echo -e "${YELLOW}⚠${NC} Output file not found: $output_file"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        echo -e "${RED}✗${NC} Simulation failed"
        echo "  Check $output_log for details"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    echo ""
done

echo "=== Validation Summary ==="
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    echo "Benchmark is stable with increasing reactivity insertion."
    exit 0
else
    echo -e "${YELLOW}Some tests failed${NC}"
    echo "This may indicate parameter tuning is needed for higher reactivity."
    exit 1
fi

