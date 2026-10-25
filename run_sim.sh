#!/bin/bash
# Chay mo phong RTL cac du an nang cao bang iverilog. Moi testbench in PASS hoac FAIL.
# Thoat voi ma 1 neu co testbench khong in PASS (de CI bao do).
cd "$(dirname "$0")"
status=0
check() { # nhan  dong_ket_qua
  echo "$1: $2"
  case "$2" in *PASS*) ;; *) status=1 ;; esac
}
sim() { # thu_muc  testbench  nguon...
  d=$1; tb=$2; shift 2
  (cd $d && iverilog -g2012 -o sim_out $tb "$@" 2>&1 && vvp sim_out | grep -E "PASS|FAIL" | head -1)
}
if [ -d 01_aes128 ]; then
  check "AES-128 (S-box bang tra)" "$(sim 01_aes128 aes_tb.v aes128_core.v aes_sbox.v)"
  check "AES-128 (S-box composite field)" "$(sim 01_aes128 aes_tb.v aes128_core.v aes_sbox_comp.v)"
  # so khop vet can giua S-box composite va S-box bang tra (doi ten module de chung song chung)
  tmp=$(mktemp -d)
  sed 's/module aes_sbox/module aes_sbox_c/; s/module aes_inv_sbox/module aes_inv_sbox_c/' 01_aes128/aes_sbox_comp.v > $tmp/c.v
  check "S-box composite vs bang tra" "$(cd 01_aes128 && iverilog -g2012 -o $tmp/sb sbox_tb.v aes_sbox.v $tmp/c.v 2>&1 && vvp $tmp/sb | grep -E 'PASS|FAIL' | head -1)"
  rm -rf $tmp
  # che do ECB/CBC/CTR (vector NIST SP 800-38A + OpenSSL)
  check "AES-128 ECB/CBC/CTR (aes_modes)" "$(sim 01_aes128 aes_modes_tb.v aes_modes.v aes128_core.v aes_sbox.v)"
  check "AES-128 ECB/CBC/CTR (S-box composite)" "$(sim 01_aes128 aes_modes_tb.v aes_modes.v aes128_core.v aes_sbox_comp.v)"
fi
exit $status
