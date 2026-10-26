#!/bin/bash
# Uoc luong cong suat tu hoat dong chuyen mach that cua phep ma hoa AES.
# Buoc 1: mo phong gate-level (netlist sau dinh tuyen) ghi VCD cho 20 vector dau (aes_tb.v + gls_dump.v).
# Buoc 2: OpenROAD doc netlist, SDC, SPEF, VCD roi bao cao cong suat.
# Chay trong container, thu muc 01_aes128, SAU khi da chay  bash run_gls.sh  (can file gls_lib.v):
#   bash run_power.sh            (mac dinh: run1 va comp, chu ky 20 ns)
#   TAGS="base_p15 comp_p15" bash run_power.sh   (chu ky lay theo ten: _p15 = 15 ns, _p12 = 12 ns)
cd "$(dirname "$0")"
OR=${OPENROAD:-$(ls /nix/store/*-openroad-2026*/bin/openroad 2>/dev/null | head -1)}
D=${PDKV:-/opt/pdks/ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog}
UDP=$(ls $D/*udp*.v 2>/dev/null | head -1)
LIBF=${LIBF:-/opt/pdks/ihp-sg13g2/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib}
[ -f "$LIBF" ] || LIBF=$(find /opt/pdks/ihp-sg13g2/libs.ref/sg13g2_stdcell/lib -name '*typ_1p20V_25C.lib' 2>/dev/null | head -1)
[ -f gls_lib.v ] || { echo "chua co gls_lib.v: chay  bash run_gls.sh  truoc"; exit 1; }
[ -n "$UDP" ] || { echo "khong thay file UDP trong $D"; exit 1; }
out=power_results.txt
: > $out
for tag in ${TAGS:-run1 comp}; do
  case $tag in *_p15) per=15;; *_p12) per=12;; *) per=20;; esac
  half=$(awk "BEGIN{print $per/2}")
  nl=$(ls runs/$tag/final/nl/*.nl.v 2>/dev/null | head -1)
  sdc=$(ls runs/$tag/final/sdc/*.sdc 2>/dev/null | head -1)
  odb=$(ls runs/$tag/final/odb/*.odb 2>/dev/null | head -1)
  spef=$(find runs/$tag/final -name '*.spef' 2>/dev/null | grep -iE 'nom|typ' | head -1)
  lib=$LIBF
  if [ -z "$nl" ] || [ -z "$sdc" ] || [ -z "$odb" ]; then echo "$tag: thieu netlist, sdc hoac odb trong runs/$tag/final" | tee -a $out; continue; fi
  echo "$tag: chu ky $per ns | netlist $nl | sdc $sdc | spef ${spef:-khong co} | lib $lib" | tee -a $out
  if ! iverilog -g2012 -DHALFPERIOD=$half -o pw_$tag aes_tb.v gls_dump.v $nl $UDP gls_lib.v 2> pw_$tag.err; then
    echo "$tag: loi bien dich, xem pw_$tag.err" | tee -a $out; head -5 pw_$tag.err | tee -a $out; continue
  fi
  vvp pw_$tag +vcd=pw_$tag.vcd +dumpns=$((700*per)) > pw_$tag.sim 2>&1
  ls -l pw_$tag.vcd 2>/dev/null | awk '{print "  VCD", $5, "byte"}' | tee -a $out
  cat > pw_$tag.tcl <<TCL
read_liberty $lib
read_db $odb
read_sdc $sdc
if {"$spef" ne ""} { read_spef $spef }
read_vcd -scope aes_tb/dut pw_$tag.vcd
report_power
TCL
  if ! command -v $OR >/dev/null; then echo "$tag: khong thay lenh openroad trong container" | tee -a $out; continue; fi
  $OR -no_splash -exit pw_$tag.tcl > power_$tag.txt 2>&1
  echo "--- $tag ---" | tee -a $out
  grep -iE "^(Sequential|Combinational|Clock|Macro|Pad|Total)|Group +Internal" power_$tag.txt | tee -a $out
done
echo "--- xong, ket qua trong $out (chi tiet: power_<tag>.txt) ---"
