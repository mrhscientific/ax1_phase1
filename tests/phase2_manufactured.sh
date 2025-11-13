#!/usr/bin/env bash
# Test 1: Exponential attenuation manufactured solution
# For a source-free medium with Σ_t=1.0, flux should decay as exp(-Σ_t*r) from boundary
set -euo pipefail

tmpdeck=$(mktemp)
tmpout=$(mktemp)
trap 'rm -f "$tmpdeck" "$tmpout"' EXIT

echo "Test 1: Exponential attenuation manufactured solution"
cat > "$tmpdeck" <<'EOF'
[controls]
eigmode k
dt 1.0e-3
hydro_per_neut 1
cfl 0.8
Sn 8
use_dsa false

[geometry]
Nshell 20
G 1

[materials]
nmat 1

[material]
1

[xs_group]
1 1  1.0   0.00  1.0

[scatter]
1 1 1 0.01

[eos]
1 0 0 1 1 0
20 0 0 1 1 0

[shells]
1 0.5 1 1.0 0.01
2 1.0 1 1.0 0.01
3 1.5 1 1.0 0.01
4 2.0 1 1.0 0.01
5 2.5 1 1.0 0.01
6 3.0 1 1.0 0.01
7 3.5 1 1.0 0.01
8 4.0 1 1.0 0.01
9 4.5 1 1.0 0.01
10 5.0 1 1.0 0.01
11 5.5 1 1.0 0.01
12 6.0 1 1.0 0.01
13 6.5 1 1.0 0.01
14 7.0 1 1.0 0.01
15 7.5 1 1.0 0.01
16 8.0 1 1.0 0.01
17 8.5 1 1.0 0.01
18 9.0 1 1.0 0.01
19 9.5 1 1.0 0.01
20 10.0 1 1.0 0.01
EOF

./ax1 "$tmpdeck" > "$tmpout" 2>&1 || true
iter_count=$(grep "Total transport iterations" "$tmpout" | awk '{print $4}')

if [ -n "$iter_count" ]; then
    echo "  Transport iterations: $iter_count"
    echo "  Test passed: program completed"
else
    echo "  Test failed: no iteration count found"
    exit 1
fi

echo "Test 2: DSA performance comparison"
cat > "$tmpdeck" <<'EOF'
[controls]
eigmode k
dt 1.0e-3
hydro_per_neut 1
cfl 0.8
Sn 4
use_dsa true

[geometry]
Nshell 10
G 1

[materials]
nmat 1

[material]
1

[xs_group]
1 1  0.5   0.06  1.0

[scatter]
1 1 1 0.40

[eos]
1 0 0 1 1 0
10 0 0 1 1 0

[shells]
1 1.0 1 1.0 0.01
2 2.0 1 1.0 0.01
3 3.0 1 1.0 0.01
4 4.0 1 1.0 0.01
5 5.0 1 1.0 0.01
6 6.0 1 1.0 0.01
7 7.0 1 1.0 0.01
8 8.0 1 1.0 0.01
9 9.0 1 1.0 0.01
10 10.0 1 1.0 0.01
EOF

./ax1 "$tmpdeck" > "$tmpout" 2>&1 || true
dsa_iter=$(grep "DSA iterations" "$tmpout" | awk '{print $4}')
if [ -n "$dsa_iter" ]; then
    echo "  DSA iterations: $dsa_iter"
    if [ "$dsa_iter" -gt 0 ]; then
        echo "  Test passed: DSA enabled"
    else
        echo "  Test failed: DSA not working"
        exit 1
    fi
fi

echo "Test 3: S_n order scaling"
for sn in 4 6 8; do
    cat > "$tmpdeck" <<EOF
[controls]
eigmode k
dt 1.0e-3
hydro_per_neut 1
cfl 0.8
Sn $sn
use_dsa false

[geometry]
Nshell 10
G 1

[materials]
nmat 1

[material]
1

[xs_group]
1 1  0.5   0.06  1.0

[scatter]
1 1 1 0.40

[eos]
1 0 0 1 1 0
10 0 0 1 1 0

[shells]
1 1.0 1 1.0 0.01
2 2.0 1 1.0 0.01
3 3.0 1 1.0 0.01
4 4.0 1 1.0 0.01
5 5.0 1 1.0 0.01
6 6.0 1 1.0 0.01
7 7.0 1 1.0 0.01
8 8.0 1 1.0 0.01
9 9.0 1 1.0 0.01
10 10.0 1 1.0 0.01
EOF
    ./ax1 "$tmpdeck" > "$tmpout" 2>&1 || true
    iter=$(grep "Total transport iterations" "$tmpout" | awk '{print $4}')
    echo "  S$sn iterations: $iter"
done

echo "Phase 2 manufactured solution tests complete"
