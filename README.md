# IHP SG13G2 digital blocks

[![sim](https://github.com/trandangduy777-cloud/ihp-sg13g2-digital-blocks/actions/workflows/sim.yml/badge.svg)](https://github.com/trandangduy777-cloud/ihp-sg13g2-digital-blocks/actions/workflows/sim.yml)

Digital designs written in Verilog, checked by self-checking testbenches (PASS/FAIL),
and taken through the open-source flow LibreLane to GDS on the IHP SG13G2 PDK.

## Projects

| Project | Status |
|---|---|
| [AES-128 encrypt/decrypt](01_aes128) | Done: 304-vector testbench (FIPS-197 + random), mutation test, ECB/CBC/CTR modes, APB4 slave, GDS with DRC, LVS and antenna passed, gate-level simulation, power analysis |
| [SHA-256](04_sha256) | RTL and self-checking testbench done, flow results not filled in yet |
| RV32I / RV32IM 5-stage pipeline | Done, in its own repository: [rv32i-single-cycle](https://github.com/trandangduy777-cloud/rv32i-single-cycle) |
| Mini SoC | Planned |
| FFT + FIR | Planned |

## Run the simulations

```
bash run_sim.sh
```

Needs Icarus Verilog. Runs the AES-128 testbenches (core with both S-box versions, ECB/CBC/CTR, APB4);
each prints one line, PASS or FAIL. SHA-256 has its own `04_sha256/run_sim.sh`.

## Limits

- Gate-level simulation is done for AES-128 only, and it is functional (no SDF timing).
- Timing uses the default SDC of LibreLane.
