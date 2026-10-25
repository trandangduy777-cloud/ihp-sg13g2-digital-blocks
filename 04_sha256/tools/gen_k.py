#!/usr/bin/env python3
"""Sinh hang so K (64 gia tri) va IV (8 gia tri) cua SHA-256 bang so nguyen,
ghi rtl/sha256_k.v, roi kiem tra bang mo hinh Python rieng so voi hashlib.

K[i]  = 32 bit dau cua phan thap phan can bac ba cua so nguyen to thu i (64 so dau).
IV[i] = 32 bit dau cua phan thap phan can bac hai cua 8 so nguyen to dau.
Dung so nguyen (khong dung float) de khong bi sai so lam tron.
"""
import hashlib
import os
import sys

MASK = 0xFFFFFFFF


def primes(n):
    out, c = [], 2
    while len(out) < n:
        if all(c % p for p in out if p * p <= c):
            out.append(c)
        c += 1
    return out


def iroot(x, k):
    """Can bac k nguyen (phan nguyen) cua x bang tim kiem nhi phan."""
    lo, hi = 0, 1 << ((x.bit_length() // k) + 1)
    while lo < hi:
        mid = (lo + hi + 1) // 2
        if mid ** k <= x:
            lo = mid
        else:
            hi = mid - 1
    return lo


def consts():
    ps = primes(64)
    # floor(cbrt(p) * 2^32) = iroot(p * 2^96, 3); lay 32 bit thap = phan thap phan
    k = [iroot(p << 96, 3) & MASK for p in ps]
    iv = [iroot(p << 64, 2) & MASK for p in ps[:8]]
    return k, iv


def rotr(x, n):
    return ((x >> n) | (x << (32 - n))) & MASK


def sha256_model(msg, k, iv):
    """Mo hinh SHA-256 viet rieng bang Python (theo FIPS 180-4), dung K, IV da sinh."""
    ml = len(msg) * 8
    msg = msg + b"\x80"
    while len(msg) % 64 != 56:
        msg += b"\x00"
    msg += ml.to_bytes(8, "big")
    h = list(iv)
    for off in range(0, len(msg), 64):
        w = [int.from_bytes(msg[off + 4 * i: off + 4 * i + 4], "big") for i in range(16)]
        for t in range(16, 64):
            s0 = rotr(w[t - 15], 7) ^ rotr(w[t - 15], 18) ^ (w[t - 15] >> 3)
            s1 = rotr(w[t - 2], 17) ^ rotr(w[t - 2], 19) ^ (w[t - 2] >> 10)
            w.append((w[t - 16] + s0 + w[t - 7] + s1) & MASK)
        a, b, c, d, e, f, g, hh = h
        for t in range(64):
            S1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
            ch = (e & f) ^ (~e & g & MASK)
            t1 = (hh + S1 + ch + k[t] + w[t]) & MASK
            S0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
            maj = (a & b) ^ (a & c) ^ (b & c)
            t2 = (S0 + maj) & MASK
            hh, g, f, e, d, c, b, a = g, f, e, (d + t1) & MASK, c, b, a, (t1 + t2) & MASK
        h = [(x + y) & MASK for x, y in zip(h, [a, b, c, d, e, f, g, hh])]
    return b"".join(x.to_bytes(4, "big") for x in h)


def self_check(k, iv):
    # moc da biet tu chuan: K[0], K[63], IV[0], IV[7]
    assert k[0] == 0x428A2F98 and k[63] == 0xC67178F2, "K sai"
    assert iv[0] == 0x6A09E667 and iv[7] == 0x5BE0CD19, "IV sai"
    import random
    rnd = random.Random(1)
    tests = [b"", b"abc", bytes(range(256))] + [
        bytes(rnd.getrandbits(8) for _ in range(rnd.randint(0, 300))) for _ in range(50)
    ]
    for m in tests:
        assert sha256_model(m, k, iv) == hashlib.sha256(m).digest(), "mo hinh Python lech hashlib"


def write_verilog(k, path):
    lines = [
        "// File sinh tu dong boi tools/gen_k.py. Khong sua tay.",
        "// K[t] = 32 bit dau phan thap phan cua can bac ba so nguyen to thu t.",
        "module sha256_k (",
        "    input  wire [5:0]  t,",
        "    output reg  [31:0] k",
        ");",
        "    always @* begin",
        "        case (t)",
    ]
    for i, v in enumerate(k):
        lines.append(f"            6'd{i}: k = 32'h{v:08x};")
    lines += [
        "            default: k = 32'h00000000;",
        "        endcase",
        "    end",
        "endmodule",
        "",
    ]
    with open(path, "w") as f:
        f.write("\n".join(lines))


if __name__ == "__main__":
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    k, iv = consts()
    self_check(k, iv)
    write_verilog(k, os.path.join(root, "rtl", "sha256_k.v"))
    print("IV =", " ".join(f"{x:08x}" for x in iv))
    print("gen_k: OK (K, IV khop hashlib qua mo hinh Python)")
