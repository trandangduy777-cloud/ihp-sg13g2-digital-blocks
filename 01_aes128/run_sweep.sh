#!/bin/bash
# Quet chu ky xung nhip cho hai bien the S-box. Chay TUNG flow mot (khong song song).
# Dung trong container, thu muc 01_aes128:   bash run_sweep.sh
# Ket qua gom vao sweep_results.txt. Moi flow khoang 30 phut - 1 gio.
cd "$(dirname "$0")"
PERIODS="${PERIODS:-15 12}"
out=sweep_results.txt
echo "tag | instance | dien tich um2 | setup ws ns | hold ws ns | drc | lvs | antenna" > $out
get() { grep -o "\"$2\": [^,}]*" "$1" | head -1 | sed 's/.*: //'; }
for v in base comp; do
  [ $v = base ] && src=config.yaml || src=config_comp.yaml
  for p in $PERIODS; do
    tag=${v}_p${p}
    sed "s/^CLOCK_PERIOD:.*/CLOCK_PERIOD: $p/" $src > config_${tag}.yaml
    echo "=== chay $tag ==="
    librelane --pdk-root /opt/pdks --manual-pdk --pdk ihp-sg13g2 --run-tag $tag config_${tag}.yaml > ${tag}.log 2>&1
    echo "flow $tag ket thuc voi ma $?"
    m=runs/$tag/final/metrics.json
    if [ ! -f $m ]; then   # flow dung giua chung (vi du checker bao vi pham timing): lay state moi nhat
      m=$(ls -d runs/$tag/*/state_out.json 2>/dev/null | sort | tail -1)
      note=" (flow khong chay het, so lieu tu $m)"
    else note=""; fi
    if [ -z "$m" ] || [ ! -f "$m" ]; then echo "$tag | khong co so lieu" >> $out; continue; fi
    echo "$tag | $(get $m design__instance__count) | $(get $m design__instance__area) | $(get $m timing__setup__ws) | $(get $m timing__hold__ws) | $(get $m magic__drc_error__count) | $(get $m design__lvs_error__count) | $(get $m antenna__violating__nets)$note" >> $out
  done
done
echo; cat $out
