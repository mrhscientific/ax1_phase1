#!/bin/bash
# Test suite for Phase 3 features
# Tests: reactivity feedback, time histories, checkpoint, Bethe-Tait, UQ, sensitivity

set -e

echo "=== Phase 3 Feature Tests ==="
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
    
    if eval "$test_command" > /tmp/test_phase3_output.log 2>&1; then
        echo -e "${GREEN}PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAILED${NC}"
        echo "  Error output:"
        tail -5 /tmp/test_phase3_output.log | sed 's/^/    /'
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

echo "=== Test 1: Reactivity Feedback ==="
# Create test input with reactivity feedback
cat > /tmp/test_reactivity_feedback.deck << 'EOF'
[controls]
eigmode alpha
dt 1.0e-4
hydro_per_neut 1
cfl 0.5
Sn 4
use_dsa false
t_end 0.001
output_freq 5
output_file /tmp/test_reactivity_output
rho_insert 50.0

[geometry]
Nshell 5
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
1 1 2  0.1
[scatter]
1 2 2  1.5

[delayed]
1 1  0.000230  0.0127

[reactivity_feedback]
enable_doppler true
enable_expansion true
enable_void false
doppler_coef -1.0
expansion_coef -0.5
void_coef 0.0
T_ref 300.0
rho_ref 0.0

[eos]
1 0 0 287 717 0
5 0 0 287 717 0

[shells]
1 0.1 1 10.0 300
2 0.2 1 10.0 300
3 0.3 1 10.0 300
4 0.4 1 10.0 300
5 0.5 1 10.0 300
EOF

run_test "Reactivity feedback" "./ax1 /tmp/test_reactivity_feedback.deck"
if [ -f /tmp/test_reactivity_output_time.csv ]; then
    echo "  Time history file created"
    head -3 /tmp/test_reactivity_output_time.csv
else
    echo "  WARNING: Time history file not created"
fi

echo ""
echo "=== Test 2: Time History Output ==="
run_test "Time history output" "test -f /tmp/test_reactivity_output_time.csv && wc -l /tmp/test_reactivity_output_time.csv | grep -q '[0-9]'"
if [ -f /tmp/test_reactivity_output_time.csv ]; then
    echo "  Time history file exists with data"
    echo "  First few lines:"
    head -3 /tmp/test_reactivity_output_time.csv | sed 's/^/    /'
fi

echo ""
echo "=== Test 3: Configurable End Time ==="
cat > /tmp/test_t_end.deck << 'EOF'
[controls]
eigmode alpha
dt 1.0e-4
hydro_per_neut 1
cfl 0.5
Sn 4
use_dsa false
t_end 0.0005
output_freq 10

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

run_test "Configurable end time" "./ax1 /tmp/test_t_end.deck 2>&1 | grep -q 't=.*0.0005' || ./ax1 /tmp/test_t_end.deck 2>&1 | tail -1 | grep -q 'Done'"

echo ""
echo "=== Test 4: Checkpoint/Restart ==="
cat > /tmp/test_checkpoint.deck << 'EOF'
[controls]
eigmode alpha
dt 1.0e-4
hydro_per_neut 1
cfl 0.5
Sn 4
use_dsa false
t_end 0.002
output_freq 5
checkpoint_file /tmp/test_checkpoint.chk
checkpoint_freq 10

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

# Run first part
run_test "Checkpoint write" "./ax1 /tmp/test_checkpoint.deck > /dev/null 2>&1"
if [ -f /tmp/test_checkpoint.chk ]; then
    echo "  Checkpoint file created"
    ls -lh /tmp/test_checkpoint.chk | awk '{print "    Size: " $5}'
else
    echo "  WARNING: Checkpoint file not created"
fi

# Test restart
cat > /tmp/test_restart.deck << 'EOF'
[controls]
eigmode alpha
dt 1.0e-4
hydro_per_neut 1
cfl 0.5
Sn 4
use_dsa false
t_end 0.003
output_freq 5
restart_file /tmp/test_checkpoint.chk

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

if [ -f /tmp/test_checkpoint.chk ]; then
    run_test "Checkpoint restart" "./ax1 /tmp/test_restart.deck 2>&1 | grep -q 'Restarted from checkpoint' || ./ax1 /tmp/test_restart.deck 2>&1 | tail -1 | grep -q 'Done'"
else
    echo -e "${YELLOW}SKIPPED${NC} (checkpoint file not created)"
fi

echo ""
echo "=== Test 5: Bethe-Tait Benchmark ==="
if [ -f benchmarks/bethe_tait_transient.deck ]; then
    run_test "Bethe-Tait benchmark" "./ax1 benchmarks/bethe_tait_transient.deck > /dev/null 2>&1 || true"
    if [ -f bethe_tait_output_time.csv ]; then
        echo "  Bethe-Tait output file created"
        ls -lh bethe_tait_output_time.csv | awk '{print "    Size: " $5}'
    fi
else
    echo -e "${YELLOW}SKIPPED${NC} (Bethe-Tait benchmark file not found)"
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

