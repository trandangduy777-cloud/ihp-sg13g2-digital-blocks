#!/bin/bash
# Mo phong gate-level: netlist sau dinh tuyen cua LibreLane + mo hinh cell IHP, chay lai aes_tb.v (304 vector).
# Chay trong container, thu muc 01_aes128:   bash run_gls.sh
# Mac dinh kiem hai lan chay 20 ns: run1 (S-box bang tra) va comp (S-box composite).
cd "$(dirname "$0")"
D=${PDKV:-/opt/pdks/ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog}
LIB=$D/sg13g2_stdcell.v
UDP=$(ls $D/*udp*.v 2>/dev/null | head -1)
out=gls_results.txt
: > $out
[ -f $LIB ] || { echo "khong thay $LIB" | tee -a $out; exit 1; }
[ -n "$UDP" ] || { echo "khong thay file UDP trong $D" | tee -a $out; exit 1; }
# iverilog khong hieu khoi specify va $setuphold cua thu vien. Tao ban sao: bo specify,
# noi cac tin hieu delayed_* thang vao chan goc, dat notifier = 0. Chi giu phan chuc nang.
perl -0pe 's/^[ \t]*specify\b.*?^[ \t]*endspecify\b[^\n]*\n//msg; s/(wire\s+[^;\n]*\bdelayed_\w+[^;\n]*;)/my $l=$1; my @n=($l=~m#delayed_(\w+)#g); $l."\n".join("",map{"\tassign delayed_$_ = $_;\n"}@n)/ge; s/reg notifier;/reg notifier = 1\x27b0;/g' $LIB > gls_lib.v
if grep -q specify gls_lib.v; then echo "canh bao: van con specify trong gls_lib.v" | tee -a $out; fi
for tag in ${TAGS:-run1 comp}; do
  nl=$(ls runs/$tag/final/nl/*.nl.v 2>/dev/null | head -1)
  if [ -z "$nl" ]; then echo "$tag: khong thay netlist trong runs/$tag/final/nl" | tee -a $out; continue; fi
  if ! iverilog -g2012 -o gls_$tag aes_tb.v $nl $UDP gls_lib.v 2> gls_$tag.err; then
    echo "$tag: loi bien dich, xem gls_$tag.err" | tee -a $out; head -5 gls_$tag.err | tee -a $out; continue
  fi
  res=$(timeout 3000 vvp gls_$tag | grep -E "PASS|FAIL" | head -1)
  echo "$tag ($(basename $nl)): ${res:-khong co ket qua (het gio hoac loi)}" | tee -a $out
done
echo "--- xong, ket qua trong $out ---"
