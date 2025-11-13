#!/usr/bin/env bash
set -euo pipefail
tmpdeck=$(mktemp)
trap 'rm -f "$tmpdeck"' EXIT
cat > "$tmpdeck" <<'EOF'
[controls]
eigmode alpha
dt 1.0e-3
hydro_per_neut 1
cfl 0.8
Sn 8
use_dsa true
upscatter neglect

[geometry]
Nshell 10
G 2

[materials]
nmat 1

[material]
1

[xs_group]
1 1  0.5   0.00  1.0
[xs_group]
1 2  0.5   0.00  0.0

[scatter]
1 1 1 0.49
[scatter]
1 2 2 0.49

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
./ax1 "$tmpdeck" | head -n 5
echo "Phase 2 attenuation smoke OK"


