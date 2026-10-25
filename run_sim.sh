#!/bin/bash
# Chay mo phong RTL cac du an nang cao bang iverilog. Moi testbench in PASS hoac FAIL.
cd "$(dirname "$0")"
run() { # thu_muc  testbench  nguon...
  d=$1; tb=$2; shift 2
  (cd $d && iverilog -g2012 -o sim_out $tb "$@" && vvp sim_out | grep -E "PASS|FAIL" | head -1)
}
[ -d 01_aes128 ] && run 01_aes128 aes_tb.v aes128_core.v aes_sbox.v
