#!/bin/bash
# Chay mo phong RTL cac du an nang cao bang iverilog. Moi testbench in PASS hoac FAIL.
# Thoat voi ma 1 neu co testbench khong in PASS (de CI bao do).
cd "$(dirname "$0")"
status=0
run() { # thu_muc  testbench  nguon...
  d=$1; tb=$2; shift 2
  out=$(cd $d && iverilog -g2012 -o sim_out $tb "$@" 2>&1 && vvp sim_out | grep -E "PASS|FAIL" | head -1)
  echo "$out"
  case "$out" in *PASS*) ;; *) status=1 ;; esac
}
[ -d 01_aes128 ] && run 01_aes128 aes_tb.v aes128_core.v aes_sbox.v
exit $status
