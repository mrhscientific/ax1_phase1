#!/usr/bin/env bash
set -euo pipefail
tmpdeck=$(mktemp)
trap 'rm -f "$tmpdeck"' EXIT
cat > "$tmpdeck" <<'EOF'
[controls]
eigmode k
dt 5.0e-4
hydro_per_neut 1
cfl 0.5
Sn 4
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
1 1 1 0.90

[eos]
1 0 0 1 1 0
20 0 0 1 1 0

[shells]
1 0.5 1 1.0 10.0
2 1.0 1 1.0 10.0
3 1.5 1 1.0 10.0
4 2.0 1 1.0 10.0
5 2.5 1 1.0 10.0
6 3.0 1 1.0 10.0
7 3.5 1 1.0 10.0
8 4.0 1 1.0 10.0
9 4.5 1 1.0 10.0
10 5.0 1 1.0 10.0
11 5.5 1 0.5 0.01
12 6.0 1 0.5 0.01
13 6.5 1 0.5 0.01
14 7.0 1 0.5 0.01
15 7.5 1 0.5 0.01
16 8.0 1 0.5 0.01
17 8.5 1 0.5 0.01
18 9.0 1 0.5 0.01
19 9.5 1 0.5 0.01
20 10.0 1 0.5 0.01
EOF
./ax1 "$tmpdeck" | head -n 5
echo "Phase 2 shock tube smoke OK"


