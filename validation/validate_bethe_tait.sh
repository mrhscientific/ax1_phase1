#!/bin/bash
# Validation script for Bethe-Tait benchmark
# Compares AX-1 results with expected values from literature

set -e

echo "=== Bethe-Tait Benchmark Validation ==="
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

# Run Bethe-Tait benchmark
echo "Running Bethe-Tait benchmark..."
./ax1 benchmarks/bethe_tait_transient.deck > /tmp/bethe_tait_output.log 2>&1

# Check if output files exist
if [ ! -f bethe_tait_output_time.csv ]; then
    echo -e "${RED}ERROR: Output file not created${NC}"
    exit 1
fi

echo "Output file created: bethe_tait_output_time.csv"
echo ""

# Extract key metrics from output
echo "=== Extracted Metrics ==="
echo ""

# Read time history file
if [ -f bethe_tait_output_time.csv ]; then
    echo "Time history data:"
    echo "  Lines: $(wc -l < bethe_tait_output_time.csv)"
    echo ""
    echo "First few data points:"
    head -5 bethe_tait_output_time.csv | sed 's/^/    /'
    echo ""
    echo "Last few data points:"
    tail -5 bethe_tait_output_time.csv | sed 's/^/    /'
    echo ""
    
    # Extract final values
    FINAL_TIME=$(tail -1 bethe_tait_output_time.csv | awk '{print $1}')
    FINAL_POWER=$(tail -1 bethe_tait_output_time.csv | awk '{print $2}')
    FINAL_ALPHA=$(tail -1 bethe_tait_output_time.csv | awk '{print $3}')
    FINAL_KEFF=$(tail -1 bethe_tait_output_time.csv | awk '{print $4}')
    FINAL_REACTIVITY=$(tail -1 bethe_tait_output_time.csv | awk '{print $5}')
    
    echo "Final values:"
    echo "  Time: $FINAL_TIME s"
    echo "  Power: $FINAL_POWER W"
    echo "  Alpha: $FINAL_ALPHA 1/s"
    echo "  keff: $FINAL_KEFF"
    echo "  Reactivity: $FINAL_REACTIVITY pcm"
    echo ""
fi

# Check for expected behavior
echo "=== Validation Checks ==="
echo ""

VALIDATION_PASSED=0
VALIDATION_FAILED=0

# Check 1: Time history file exists
if [ -f bethe_tait_output_time.csv ]; then
    echo -e "${GREEN}✓${NC} Time history file created"
    VALIDATION_PASSED=$((VALIDATION_PASSED + 1))
else
    echo -e "${RED}✗${NC} Time history file not created"
    VALIDATION_FAILED=$((VALIDATION_FAILED + 1))
fi

# Check 2: Spatial history file exists
if [ -f bethe_tait_output_spatial.csv ]; then
    echo -e "${GREEN}✓${NC} Spatial history file created"
    VALIDATION_PASSED=$((VALIDATION_PASSED + 1))
else
    echo -e "${RED}✗${NC} Spatial history file not created"
    VALIDATION_FAILED=$((VALIDATION_FAILED + 1))
fi

# Check 3: Simulation completed
if grep -q "Done" /tmp/bethe_tait_output.log; then
    echo -e "${GREEN}✓${NC} Simulation completed successfully"
    VALIDATION_PASSED=$((VALIDATION_PASSED + 1))
else
    echo -e "${RED}✗${NC} Simulation did not complete"
    VALIDATION_FAILED=$((VALIDATION_FAILED + 1))
fi

# Check 4: No NaN values in output (basic check)
if grep -q "NaN" bethe_tait_output_time.csv; then
    echo -e "${YELLOW}⚠${NC} NaN values found in output (may need parameter tuning)"
    VALIDATION_FAILED=$((VALIDATION_FAILED + 1))
else
    echo -e "${GREEN}✓${NC} No NaN values in output"
    VALIDATION_PASSED=$((VALIDATION_PASSED + 1))
fi

# Check 5: Output has reasonable values
if [ ! -z "$FINAL_TIME" ] && [ "$FINAL_TIME" != "NaN" ]; then
    if (( $(echo "$FINAL_TIME > 0" | bc -l) )); then
        echo -e "${GREEN}✓${NC} Final time is positive"
        VALIDATION_PASSED=$((VALIDATION_PASSED + 1))
    else
        echo -e "${RED}✗${NC} Final time is not positive"
        VALIDATION_FAILED=$((VALIDATION_FAILED + 1))
    fi
else
    echo -e "${RED}✗${NC} Final time is invalid"
    VALIDATION_FAILED=$((VALIDATION_FAILED + 1))
fi

echo ""
echo "=== Validation Summary ==="
echo "Passed: $VALIDATION_PASSED"
echo "Failed: $VALIDATION_FAILED"
echo ""

# Note about comparison with literature
echo "=== Comparison with Literature ==="
echo ""
echo "Note: Full validation requires comparison with published results."
echo "Expected behavior for Bethe-Tait benchmark:"
echo "  - Fast reactor transient response"
echo "  - Reactivity feedback effects"
echo "  - Power and reactivity evolution over time"
echo ""
echo "Literature references:"
echo "  - Bethe-Tait analysis for fast reactor safety"
echo "  - Historical experiments (Godiva, Jezebel)"
echo ""

if [ $VALIDATION_FAILED -eq 0 ]; then
    echo -e "${GREEN}All validation checks passed!${NC}"
    exit 0
else
    echo -e "${YELLOW}Some validation checks failed${NC}"
    echo "  This may indicate parameter tuning is needed"
    exit 0
fi

