#!/bin/bash
# Chay LibreLane (trong container UNIC-CASS) cho tung du an va in so lieu chinh.
# Dung: ./run_flow.sh 01_aes128      (hoac khong tham so de chay het)
cd "$(dirname "$0")"
list=${1:-$(ls -d [0-9][0-9]_* | tr '\n' ' ')}
for d in $list; do
  echo "===== $d ====="
  (cd $d && librelane --pdk-root /opt/pdks --manual-pdk --pdk ihp-sg13g2 --run-tag run1 config.yaml \
   && grep -E 'design__instance__count"|design__instance__area"|timing__setup__ws"|timing__hold__ws"|route__drc_errors"|antenna|lvs' runs/run1/final/metrics.json)
done
