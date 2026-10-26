#!/bin/bash
# Mo phong gate-level: netlist sau dinh tuyen cua LibreLane + mo hinh cell IHP, chay lai aes_tb.v (304 vector).
# Chay trong container, thu muc 01_aes128:   bash run_gls.sh
# Mac dinh kiem hai lan chay 20 ns: run1 (S-box bang tra) va comp (S-box composite).
cd "$(dirname "$0")"
LIB=/opt/pdks/ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog/sg13g2_stdcell.v
out=gls_results.txt
: > $out
[ -f $LIB ] || { echo "khong thay $LIB" | tee -a $out; exit 1; }
for tag in ${TAGS:-run1 comp}; do
  nl=$(ls runs/$tag/final/nl/*.nl.v 2>/dev/null | head -1)
  if [ -z "$nl" ]; then echo "$tag: khong thay netlist trong runs/$tag/final/nl" | tee -a $out; continue; fi
  ok=0
  for flags in "-DFUNCTIONAL" ""; do
    if iverilog -g2012 $flags -o gls_$tag aes_tb.v $nl $LIB 2> gls_$tag.err; then ok=1; break; fi
  done
  if [ $ok = 0 ]; then echo "$tag: loi bien dich, xem gls_$tag.err" | tee -a $out; head -5 gls_$tag.err | tee -a $out; continue; fi
  res=$(timeout 3000 vvp gls_$tag | grep -E "PASS|FAIL" | head -1)
  echo "$tag ($(basename $nl)): ${res:-khong co ket qua (het gio hoac loi)}" | tee -a $out
done
echo "--- xong, ket qua trong $out ---"
