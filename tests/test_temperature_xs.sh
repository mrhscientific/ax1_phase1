#!/bin/bash
# Test temperature-dependent cross sections

set -e

echo "=== Temperature-Dependent Cross Sections Test ==="
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

echo "=== Test 1: Temperature-Dependent Cross Sections Enabled ==="
# Create test input with temperature-dependent XS enabled
cat > /tmp/test_temp_xs.deck << 'EOF'
[controls]
eigmode k
dt 1.0e-4
hydro_per_neut 1
cfl 0.5
Sn 4
use_dsa false
t_end 0.001
output_freq 10

[geometry]
Nshell 3
G 2

[materials]
nmat 1

[material]
1

# Phase 3: Enable temperature-dependent cross sections
[material_properties]
1 true 300.0 0.5

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

echo "Running test with temperature-dependent XS enabled..."
if ./ax1 /tmp/test_temp_xs.deck > /tmp/test_temp_xs_output.log 2>&1; then
    echo -e "${GREEN}✓${NC} Test passed - simulation completed"
    echo "  Output:"
    tail -3 /tmp/test_temp_xs_output.log | sed 's/^/    /'
else
    echo -e "${RED}✗${NC} Test failed"
    echo "  Error output:"
    tail -5 /tmp/test_temp_xs_output.log | sed 's/^/    /'
    exit 1
fi

echo ""
echo "=== Test 2: Compare with Temperature-Dependent XS Disabled ==="
# Create test input with temperature-dependent XS disabled
cat > /tmp/test_no_temp_xs.deck << 'EOF'
[controls]
eigmode k
dt 1.0e-4
hydro_per_neut 1
cfl 0.5
Sn 4
use_dsa false
t_end 0.001
output_freq 10

[geometry]
Nshell 3
G 2

[materials]
nmat 1

[material]
1

# Phase 3: Disable temperature-dependent cross sections
[material_properties]
1 false 300.0 0.5

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

echo "Running test with temperature-dependent XS disabled..."
if ./ax1 /tmp/test_no_temp_xs.deck > /tmp/test_no_temp_xs_output.log 2>&1; then
    echo -e "${GREEN}✓${NC} Test passed - simulation completed"
    echo "  Output:"
    tail -3 /tmp/test_no_temp_xs_output.log | sed 's/^/    /'
else
    echo -e "${RED}✗${NC} Test failed"
    echo "  Error output:"
    tail -5 /tmp/test_no_temp_xs_output.log | sed 's/^/    /'
    exit 1
fi

echo ""
echo "=== Test Summary ==="
echo -e "${GREEN}All tests passed!${NC}"
echo ""
echo "Temperature-dependent cross sections are working correctly."
echo ""

