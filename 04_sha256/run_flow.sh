#!/bin/bash
# Chay LibreLane (IHP SG13G2) cho SHA-256 va in cac so lieu chinh.
# Dung: ./run_flow.sh          (chay trong thu muc 04_sha256, trong container UNIC-CASS, prompt "designer ~")
#       ./run_flow.sh 20       (doi CLOCK_PERIOD thanh 20 ns roi chay)
set -e
cd "$(dirname "$0")"

if [ -n "$1" ]; then
  sed -i "s/^CLOCK_PERIOD:.*/CLOCK_PERIOD: $1/" config.yaml
  echo "CLOCK_PERIOD = $1 ns"
fi

rm -rf runs/run1
librelane --pdk-root /opt/pdks --manual-pdk --pdk ihp-sg13g2 --run-tag run1 config.yaml || echo "LibreLane bao loi, van doc metrics neu co"

M=runs/run1/final/metrics.json
if [ ! -f "$M" ]; then echo "Khong thay $M"; exit 1; fi

python3 - "$M" <<'PY'
import json, re, sys
m = json.load(open(sys.argv[1]))
want = ["design__instance__count", "design__instance__area",
        "timing__setup__ws", "timing__hold__ws"]
print("---- so lieu chinh (khoa dung hai gach duoi) ----")
for k in want:
    print(f"{k:32s} {m.get(k, 'KHONG CO KHOA NAY')}")
print("---- DRC / LVS / antenna (cac khoa khop ten) ----")
for k in sorted(m):
    if re.search(r"(drc|lvs|antenna)", k) and re.search(r"(count|error|violation)", k):
        print(f"{k:55s} {m[k]}")
PY

mkdir -p results
cp "$M" results/metrics.json
G=$(ls runs/run1/final/gds/*.gds 2>/dev/null | head -1)
[ -n "$G" ] && cp "$G" results/ && echo "Da chep $G va metrics.json vao results/"
echo
echo "Xem tren giao dien do hoa:"
echo "  OpenROAD: librelane --pdk-root /opt/pdks --manual-pdk --pdk ihp-sg13g2 --run-tag run1 --last-run --flow OpenInOpenROAD config.yaml"
echo "  KLayout : klayout -l /opt/pdks/ihp-sg13g2/libs.tech/klayout/tech/sg13g2.lyp results/sha256_core.gds"
