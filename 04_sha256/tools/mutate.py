#!/usr/bin/env python3
"""Thu dot bien: moi lan chen mot loi vao RTL, testbench phai bao FAIL.
Loi nao lot qua (van PASS) => tang cuong testbench.

Chay: python3 -I tools/mutate.py   (tu thu muc 04_sha256)
"""
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# (ten, file, doan goc, doan thay)
MUTANTS = [
    ("K[0] sai 1 bit", "sha256_k.v", "6'd0: k = 32'h428a2f98;", "6'd0: k = 32'h428a2f99;"),
    ("K[63] sai 1 bit", "sha256_k.v", "6'd63: k = 32'hc67178f2;", "6'd63: k = 32'hc67178f3;"),
    ("Sigma1 xoay 6 -> 7", "sha256_core.v", "rotr(x, 6) ^ rotr(x, 11) ^ rotr(x, 25)", "rotr(x, 7) ^ rotr(x, 11) ^ rotr(x, 25)"),
    ("Sigma0 xoay 22 -> 21", "sha256_core.v", "rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 22)", "rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 21)"),
    ("sigma0 dich 3 -> xoay 3", "sha256_core.v", "rotr(x, 18) ^ (x >> 3)", "rotr(x, 18) ^ rotr(x, 3)"),
    ("sigma1 dich 10 -> 11", "sha256_core.v", "(x >> 10)", "(x >> 11)"),
    ("Ch sai (thieu ~e)", "sha256_core.v", "(e & f) ^ (~e & g)", "(e & f) ^ (e & g)"),
    ("Maj thieu so hang", "sha256_core.v", "(a & b) ^ (a & c) ^ (b & c)", "(a & b) ^ (a & c)"),
    ("quen cong lai H0 sau 64 vong", "sha256_core.v", "hs[255:224] + na", "na"),
    ("quen cong lai H7 sau 64 vong", "sha256_core.v", "hs[31:0]    + g}", "g}"),
    ("khong nap lai IV khi init", "sha256_core.v", "wire [255:0] base = init ? IV : hs;", "wire [255:0] base = hs;"),
    ("lich W lech: W[t+9] -> W[t+8]", "sha256_core.v", "wire [31:0] w9  = w[223:192];", "wire [31:0] w9  = w[255:224];"),
    ("lich W lech: sigma0(W[t+1]) -> W[t]", "sha256_core.v", "small_sigma0(w1)", "small_sigma0(w0)"),
    ("lich W lech: sigma1(W[t+14]) -> W[t+13]", "sha256_core.v", "small_sigma1(w14)", "small_sigma1(w[95:64])"),
    ("e moi = d + T2 thay vi d + T1", "sha256_core.v", "wire [31:0] ne   = d + t1;", "wire [31:0] ne   = d + t2;"),
    ("thanh ghi c nhan a thay vi b", "sha256_core.v", "b <= a;\n            c <= b;", "b <= a;\n            c <= a;"),
    ("T1 thieu K[t]", "sha256_core.v", "+ kt + w0", "+ w0"),
    ("nap du lieu khi dang ban", "sha256_core.v", "if (!run && start) begin\n            w  <= block;", "if (start) begin\n            w  <= block;"),
    ("so vong 63 thay vi 64", "sha256_core.v", "if (t == 6'd63) begin\n                    run  <= 1'b0;", "if (t == 6'd62) begin\n                    run  <= 1'b0;"),
    ("done khong xoa khi start", "sha256_core.v", "run  <= 1'b1;\n                    done <= 1'b0;", "run  <= 1'b1;"),
    ("reset khong xoa run", "sha256_core.v", "            run  <= 1'b0;\n            done <= 1'b0;\n            t    <= 6'd0;\n        end else begin", "            done <= 1'b0;\n            t    <= 6'd0;\n        end else begin"),
]


def run_one(name, fname, old, new):
    tmp = tempfile.mkdtemp(prefix="mut_")
    try:
        os.makedirs(os.path.join(tmp, "rtl"))
        os.makedirs(os.path.join(tmp, "tb"))
        for f in ("sha256_core.v", "sha256_k.v"):
            shutil.copy(os.path.join(ROOT, "rtl", f), os.path.join(tmp, "rtl", f))
        shutil.copy(os.path.join(ROOT, "tb", "tb_sha256.v"), os.path.join(tmp, "tb"))
        shutil.copy(os.path.join(ROOT, "tb", "vectors.txt"), os.path.join(tmp, "tb"))
        path = os.path.join(tmp, "rtl", fname)
        src = open(path).read()
        if src.count(old) != 1:
            return "KHONG_AP_DUNG", f"doan goc xuat hien {src.count(old)} lan"
        open(path, "w").write(src.replace(old, new))
        vvp = os.path.join(tmp, "m.vvp")
        c = subprocess.run(
            ["iverilog", "-g2012", "-Wno-timescale", "-o", vvp,
             "rtl/sha256_k.v", "rtl/sha256_core.v", "tb/tb_sha256.v"],
            cwd=tmp, capture_output=True, text=True)
        if c.returncode != 0:
            return "LOI_BIEN_DICH", c.stderr.strip()[:200]
        try:
            r = subprocess.run(["vvp", vvp], cwd=tmp, capture_output=True, text=True, timeout=120)
        except subprocess.TimeoutExpired:
            return "BAT_DUOC", "treo (timeout), coi nhu FAIL"
        out = r.stdout
        if "SHA256: FAIL" in out:
            return "BAT_DUOC", ""
        if "SHA256: PASS" in out:
            return "LOT", ""
        return "BAT_DUOC", "khong co dong ket qua"
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main():
    caught, bad = 0, 0
    for name, fname, old, new in MUTANTS:
        status, note = run_one(name, fname, old, new)
        print(f"  [{status:14s}] {name} {('- ' + note) if note else ''}")
        if status == "BAT_DUOC":
            caught += 1
        else:
            bad += 1
    print(f"mutate: {caught}/{len(MUTANTS)} loi bi bat")
    if bad:
        print("mutate: CO LOI LOT HOAC DOT BIEN KHONG HOP LE")
        sys.exit(1)
    print("mutate: OK")


if __name__ == "__main__":
    main()
