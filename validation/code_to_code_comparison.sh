#!/bin/bash
# Code-to-code comparison framework
# Compares AX-1 results with other codes (MCNP, Serpent, OpenMC)
# This is a stub framework - full implementation would require:
#  - Running other codes
#  - Parsing their output
#  - Comparing results

set -e

echo "=== Code-to-Code Comparison Framework ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AX1_OUTPUT="ax1_output.csv"
REFERENCE_OUTPUT="reference_output.csv"
COMPARISON_OUTPUT="comparison_results.txt"

# Check if ax1 exists
if [ ! -f ./ax1 ]; then
    echo "Building ax1..."
    make clean > /dev/null 2>&1
    make > /dev/null 2>&1
fi

echo "=== Step 1: Run AX-1 ==="
echo ""

# Run AX-1 with test case
TEST_DECK="inputs/sample_phase1.deck"
if [ -f "$TEST_DECK" ]; then
    echo "Running AX-1 with: $TEST_DECK"
    ./ax1 "$TEST_DECK" > /tmp/ax1_output.log 2>&1
    echo -e "${GREEN}✓${NC} AX-1 simulation completed"
else
    echo -e "${RED}✗${NC} Test deck not found: $TEST_DECK"
    exit 1
fi

echo ""
echo "=== Step 2: Extract AX-1 Results ==="
echo ""

# Extract key metrics from AX-1 output
if [ -f "$AX1_OUTPUT" ]; then
    echo "AX-1 output file found: $AX1_OUTPUT"
    echo "  Lines: $(wc -l < $AX1_OUTPUT)"
else
    echo "AX-1 output file not found (using log file)"
    # Extract from log file
    grep -i "keff" /tmp/ax1_output.log | tail -1 > "$AX1_OUTPUT" || true
fi

echo ""
echo "=== Step 3: Comparison Framework ==="
echo ""

# Create comparison results file
cat > "$COMPARISON_OUTPUT" << EOF
# Code-to-Code Comparison Results
# Generated: $(date)
#
# Comparison between AX-1 and reference codes (MCNP, Serpent, OpenMC)
#
# Note: This is a stub framework. Full implementation would:
#   1. Run reference codes (MCNP, Serpent, OpenMC)
#   2. Parse their output files
#   3. Compare key metrics (keff, flux, reaction rates)
#   4. Calculate differences and statistics
#
EOF

echo "Comparison framework created: $COMPARISON_OUTPUT"
echo ""

echo "=== Step 4: Comparison Metrics ==="
echo ""

# Define comparison metrics
echo "Key metrics for comparison:"
echo "  1. k_eff (multiplication factor)"
echo "  2. Flux distribution (spatial and energy)"
echo "  3. Reaction rates (fission, capture, scattering)"
echo "  4. Power distribution"
echo "  5. Alpha (reactivity eigenvalue)"
echo ""

# Create comparison template
cat >> "$COMPARISON_OUTPUT" << EOF
# Comparison Metrics
#
# Metric                    AX-1        Reference   Difference   Relative Error
# ----------------------------------------------------------------------------
# k_eff                     [TBD]       [TBD]       [TBD]        [TBD]
# Flux (group 1)            [TBD]       [TBD]       [TBD]        [TBD]
# Flux (group 2)            [TBD]       [TBD]       [TBD]        [TBD]
# Power                     [TBD]       [TBD]       [TBD]        [TBD]
# Alpha                     [TBD]       [TBD]       [TBD]        [TBD]
#
# Note: [TBD] = To Be Determined (requires running reference codes)
#
EOF

echo ""
echo "=== Step 5: Reference Code Integration ==="
echo ""

# Check for reference codes
REFERENCE_CODES=("mcnp" "serpent" "openmc")
FOUND_CODES=()

for code in "${REFERENCE_CODES[@]}"; do
    if command -v "$code" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $code found: $(which $code)"
        FOUND_CODES+=("$code")
    else
        echo -e "${YELLOW}⚠${NC} $code not found (optional)"
    fi
done

echo ""
if [ ${#FOUND_CODES[@]} -eq 0 ]; then
    echo "No reference codes found."
    echo "  To enable full comparison, install:"
    echo "    - MCNP (Monte Carlo N-Particle)"
    echo "    - Serpent (Monte Carlo code)"
    echo "    - OpenMC (Monte Carlo code)"
    echo ""
    echo "  Or provide reference output files in standardized format."
else
    echo "Found ${#FOUND_CODES[@]} reference code(s): ${FOUND_CODES[*]}"
    echo "  Full comparison can be enabled by:"
    echo "    1. Creating input files for reference codes"
    echo "    2. Running reference codes"
    echo "    3. Parsing their output"
    echo "    4. Comparing results"
fi

echo ""
echo "=== Step 6: Output Format Standardization ==="
echo ""

# Create standardized output format
cat > standardized_output_format.txt << EOF
# Standardized Output Format for Code-to-Code Comparison
#
# This format should be used for all codes to enable easy comparison.
#
# Format: CSV with the following columns:
#   time, keff, alpha, power, flux_g1, flux_g2, ..., reaction_rate_1, reaction_rate_2, ...
#
# Example:
#   time,keff,alpha,power,flux_g1,flux_g2,fission_rate,capture_rate
#   0.0,1.0,0.0,1.0,1.0,1.0,1.0,1.0
#   0.1,1.01,0.01,1.01,1.01,1.01,1.01,1.01
#
# Notes:
#   - All values should be in consistent units
#   - Time in seconds
#   - keff dimensionless
#   - alpha in 1/s
#   - power in W
#   - flux in 1/(cm^2 s)
#   - reaction rates in 1/s
#
EOF

echo "Standardized output format created: standardized_output_format.txt"
echo ""

echo "=== Summary ==="
echo ""
echo "Comparison framework created:"
echo "  - Comparison results: $COMPARISON_OUTPUT"
echo "  - Standardized format: standardized_output_format.txt"
echo ""
echo "Next steps:"
echo "  1. Run reference codes (MCNP, Serpent, OpenMC)"
echo "  2. Parse their output files"
echo "  3. Convert to standardized format"
echo "  4. Compare results with AX-1"
echo "  5. Generate comparison report"
echo ""

echo -e "${GREEN}Code-to-code comparison framework ready!${NC}"
echo ""

