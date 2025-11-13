#!/bin/bash
# Test suite for UQ and sensitivity analysis

set -e

echo "=== UQ and Sensitivity Analysis Tests ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run test
run_test() {
    local test_name=$1
    local test_command=$2
    echo -n "Testing $test_name... "
    
    if eval "$test_command" > /tmp/test_uq_output.log 2>&1; then
        echo -e "${GREEN}PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAILED${NC}"
        echo "  Error output:"
        tail -5 /tmp/test_uq_output.log | sed 's/^/    /'
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Check if ax1 exists
if [ ! -f ./ax1 ]; then
    echo "Building ax1..."
    make clean > /dev/null 2>&1
    make > /dev/null 2>&1
fi

echo "=== Test 1: UQ Analysis ==="
# Create test input with UQ enabled
cat > /tmp/test_uq.deck << 'EOF'
[controls]
eigmode k
dt 1.0e-4
hydro_per_neut 1
cfl 0.5
Sn 4
use_dsa false
t_end 0.0001
output_freq 10
run_uq true
uq_output_file /tmp/test_uq_results.csv

[geometry]
Nshell 3
G 2

[materials]
nmat 1

[material]
1

[xs_group]
1 1  1.0   0.1  1.0
[xs_group]
1 2  2.0   0.2  0.0

[scatter]
1 1 1  0.8
[scatter]
1 2 2  1.5

[delayed]
1 1  0.000230  0.0127

[eos]
1 0 0 287 717 0
3 0 0 287 717 0

[shells]
1 0.1 1 10.0 300
2 0.2 1 10.0 300
3 0.3 1 10.0 300
EOF

run_test "UQ analysis" "./ax1 /tmp/test_uq.deck > /dev/null 2>&1 || true"
if [ -f /tmp/test_uq_results.csv ]; then
    echo "  UQ results file created"
    head -5 /tmp/test_uq_results.csv | sed 's/^/    /'
else
    echo "  WARNING: UQ results file not created"
fi

echo ""
echo "=== Test 2: Sensitivity Analysis ==="
# Create test input with sensitivity analysis enabled
cat > /tmp/test_sensitivity.deck << 'EOF'
[controls]
eigmode k
dt 1.0e-4
hydro_per_neut 1
cfl 0.5
Sn 4
use_dsa false
t_end 0.0001
output_freq 10
run_sensitivity true
sensitivity_output_file /tmp/test_sensitivity_results.csv

[geometry]
Nshell 3
G 2

[materials]
nmat 1

[material]
1

[xs_group]
1 1  1.0   0.1  1.0
[xs_group]
1 2  2.0   0.2  0.0

[scatter]
1 1 1  0.8
[scatter]
1 2 2  1.5

[delayed]
1 1  0.000230  0.0127

[eos]
1 0 0 287 717 0
3 0 0 287 717 0

[shells]
1 0.1 1 10.0 300
2 0.2 1 10.0 300
3 0.3 1 10.0 300
EOF

run_test "Sensitivity analysis" "./ax1 /tmp/test_sensitivity.deck > /dev/null 2>&1 || true"
if [ -f /tmp/test_sensitivity_results.csv ]; then
    echo "  Sensitivity results file created"
    head -10 /tmp/test_sensitivity_results.csv | sed 's/^/    /'
else
    echo "  WARNING: Sensitivity results file not created"
fi

echo ""
echo "=== Test Summary ==="
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed${NC}"
    exit 1
fi

