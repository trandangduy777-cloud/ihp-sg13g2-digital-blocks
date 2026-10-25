#!/bin/bash
# Chay mo phong SHA-256: sinh hang so + vector, bien dich, chay testbench.
# Dung: ./run_sim.sh   (chay trong thu muc 04_sha256)
set -e
cd "$(dirname "$0")"
mkdir -p sim_out
python3 -I tools/gen_k.py
python3 -I tools/gen_vectors.py
iverilog -g2012 -Wall -Wno-timescale -o sim_out/tb_sha256.vvp rtl/sha256_k.v rtl/sha256_core.v tb/tb_sha256.v
vvp sim_out/tb_sha256.vvp | tee sim_out/sim.log
grep -q "^SHA256: PASS" sim_out/sim.log
