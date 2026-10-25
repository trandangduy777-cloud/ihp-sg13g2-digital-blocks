#!/bin/bash
# Kiem tra tong hop generic bang yosys: khong latch, khong vong to hop (check -assert).
# Day chi la kiem tra cau truc, KHONG phai so lieu dien tich/timing that (cai do la LibreLane).
# Dung -noabc vi ABC ban wasm khong chay on dinh; so cell o day la cell generic, khong dung de bao cao.
set -o pipefail
cd "$(dirname "$0")/.."
mkdir -p sim_out
if command -v yosys >/dev/null 2>&1; then YOSYS=yosys
elif command -v yowasp-yosys >/dev/null 2>&1; then YOSYS=yowasp-yosys
else echo "synth_check: khong tim thay yosys"; exit 2; fi

LOG=sim_out/yosys_check.log
$YOSYS -p "read_verilog -sv rtl/sha256_k.v rtl/sha256_core.v; hierarchy -check -top sha256_core; proc; flatten; opt; check -assert; synth -top sha256_core -noabc; check -assert; stat" > "$LOG" 2>&1 \
  || { tail -30 "$LOG"; echo "synth_check: LOI"; exit 1; }

# yosys phai chay toi het (da in thong ke)
grep -q -F "Printing statistics" "$LOG" || { echo "synth_check: yosys khong chay toi cuoi"; exit 1; }
# khong duoc co latch
if grep -q -F 'DLATCH' "$LOG" && grep -F 'DLATCH' "$LOG" | grep -v -F 'PROC_DLATCH' | grep -v -F 'No latch inferred' | grep -q .; then
  echo "synth_check: CO LATCH"; exit 1
fi
# moi lan check phai bao 0 van de
if grep -F "Found and reported" "$LOG" | grep -v -F "Found and reported 0 problems" | grep -q .; then
  echo "synth_check: check bao van de"; exit 1
fi
echo "check: $(grep -c -F 'Found and reported 0 problems' "$LOG") lan, deu 0 van de"
sed -n '/Printing statistics/,$p' "$LOG" | grep -E '[0-9]+ +(cells|\$_DFF)' | head -6
echo "synth_check: OK (khong latch, khong vong to hop)"
