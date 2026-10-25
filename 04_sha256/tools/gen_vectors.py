#!/usr/bin/env python3
"""Sinh vector kiem tra cho tb/tb_sha256.v -> tb/vectors.txt

Nguon dap an doc lap voi RTL:
  - hashlib (thu vien chuan cua Python)
  - 4 vector NIST (FIPS 180-4 / ví du SHA-256) duoc go thang vao day,
    script se bao loi neu hashlib khong khop (de bat sai sot khi go).
Padding duoc lam o day (khong lam trong RTL), ghi trong README.

Moi dong: <init> <check> <khoi 512 bit hex> <digest hex>
  init  = 1 voi khoi dau cua thong diep, 0 voi cac khoi tiep theo
  check = 1 chi o khoi cuoi cua thong diep (digest cuoi moi so sanh duoc voi hashlib)
"""
import hashlib
import os
import random

NIST = {
    b"": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    b"abc": "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq":
        "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1",
    b"abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu":
        "cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1",
}


def pad(msg):
    ml = len(msg) * 8
    msg = msg + b"\x80"
    while len(msg) % 64 != 56:
        msg += b"\x00"
    return msg + ml.to_bytes(8, "big")


def messages():
    rnd = random.Random(20241011)
    msgs = list(NIST.keys())
    # bien cua padding: 55 byte vua du 1 khoi, 56 byte tran sang khoi 2, v.v.
    for n in (1, 2, 54, 55, 56, 57, 63, 64, 65, 119, 120, 121, 127, 128, 129):
        msgs.append(bytes(rnd.getrandbits(8) for _ in range(n)))
    msgs.append(bytes(64))                 # toan 0
    msgs.append(b"\xff" * 64)              # toan 1
    msgs.append(b"a" * 1000)               # nhieu khoi (16 khoi)
    for _ in range(200):                   # ngau nhien 0..300 byte
        n = rnd.randint(0, 300)
        msgs.append(bytes(rnd.getrandbits(8) for _ in range(n)))
    return msgs


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    for m, d in NIST.items():
        assert hashlib.sha256(m).hexdigest() == d, "vector NIST go sai hoac hashlib lech"
    lines, nblocks = [], 0
    for m in messages():
        padded = pad(m)
        blocks = [padded[i:i + 64] for i in range(0, len(padded), 64)]
        dg = hashlib.sha256(m).hexdigest()
        for i, blk in enumerate(blocks):
            last = i == len(blocks) - 1
            lines.append(
                f"{1 if i == 0 else 0} {1 if last else 0} {blk.hex()} "
                f"{dg if last else '0' * 64}"
            )
            nblocks += 1
    with open(os.path.join(root, "tb", "vectors.txt"), "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"gen_vectors: {len(messages())} thong diep, {nblocks} khoi -> tb/vectors.txt")


if __name__ == "__main__":
    main()
