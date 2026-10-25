# \# IHP SG13G2 digital blocks

# 

# !\[sim](https://github.com/trandangduy777-cloud/ihp-sg13g2-digital-blocks/actions/workflows/sim.yml/badge.svg)

# 

# Digital designs written in Verilog, checked by self-checking testbenches (PASS/FAIL),

# and taken through the open-source flow LibreLane to GDS on the IHP SG13G2 PDK.

# 

# \## Projects

# 

# | Project | Status |

# |---|---|

# | \[AES-128 encrypt/decrypt](01\_aes128) | done, GDS with DRC, LVS and antenna passed |

# | \[SHA-256](04\_sha256) | folder added |

# | RV32I 5-stage pipeline | planned |

# | Mini SoC | planned |

# | FFT + FIR | planned |

# 

# \## Run the simulations

# 

# &#x20;   bash run\_sim.sh

# 

# Needs Icarus Verilog. Each testbench prints one line, PASS or FAIL.

# 

# \## Limits

# 

# \- Gate-level simulation is not done yet.

# \- Timing uses the default SDC of LibreLane.

