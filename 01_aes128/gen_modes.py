# Sinh vector cho aes_modes_tb.v bang thu vien cryptography (OpenSSL), khong tu tinh.
# Dong: mode dec load_iv iv key din expected   (so hex)
import os, random
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

random.seed(38)
def blocks(b): return [b[i:i+16] for i in range(0, len(b), 16)]
def enc(key, mode, data):
    c = Cipher(algorithms.AES(key), mode).encryptor(); return c.update(data) + c.finalize()
def dec(key, mode, data):
    c = Cipher(algorithms.AES(key), mode).decryptor(); return c.update(data) + c.finalize()

K = bytes.fromhex("2b7e151628aed2a6abf7158809cf4f3c")
PT = bytes.fromhex("6bc1bee22e409f96e93d7e117393172a" "ae2d8a571e03ac9c9eb76fac45af8e51"
                   "30c81c46a35ce411e5fbc1191a0a52ef" "f69f2445df4f9b17ad2b417be66c3710")
IV = bytes.fromhex("000102030405060708090a0b0c0d0e0f")
CTR0 = bytes.fromhex("f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff")
# dap an NIST SP 800-38A (F.1.1, F.2.1, F.5.1): doi chieu voi thu vien de chac gia tri chep dung
NIST = {
 "ECB": "3ad77bb40d7a3660a89ecaf32466ef97f5d3d58503b9699de785895a96fdbaaf43b1cd7f598ece23881b00e3ed0306887b0c785e27e8ad3f8223207104725dd4",
 "CBC": "7649abac8119b246cee98e9b12e9197d5086cb9b507219ee95db113a917678b273bed6b8e3c1743b7116e69e222295163ff1caa1681fac09120eca307586e1a7",
 "CTR": "874d6191b620e3261bef6864990db6ce9806f66b7970fdff8617187bb9fffdff5ae4df3edbd5d35e5b4f09020db03eab1e031dda2fbe03d1792170a0f3009cee",
}
assert enc(K, modes.ECB(), PT).hex() == NIST["ECB"]
assert enc(K, modes.CBC(IV), PT).hex() == NIST["CBC"]
assert enc(K, modes.CTR(CTR0), PT).hex() == NIST["CTR"]

lines = []
def msg(mode, d, key, iv, inp, out):
    for i, (a, b) in enumerate(zip(blocks(inp), blocks(out))):
        lines.append(f"{mode:x} {d:x} {1 if i == 0 else 0:x} {iv.hex()} {key.hex()} {a.hex()} {b.hex()}")

# NIST: ECB/CBC/CTR, ma hoa va giai ma
ct = {m: bytes.fromhex(v) for m, v in NIST.items()}
msg(0, 0, K, bytes(16), PT, ct["ECB"]); msg(0, 1, K, bytes(16), ct["ECB"], PT)
msg(1, 0, K, IV, PT, ct["CBC"]);        msg(1, 1, K, IV, ct["CBC"], PT)
msg(2, 0, K, CTR0, PT, ct["CTR"]);      msg(2, 1, K, CTR0, ct["CTR"], PT)

# ngau nhien: moi che do, moi chieu, nhieu khoa va do dai
specials = [b"\xff"*16, bytes(8) + b"\xff"*8, bytes(15) + b"\xff", b"\xff"*8 + bytes(8)]
for _ in range(12):
    for mode in (0, 1, 2):
        for d in (0, 1):
            key = bytes(random.getrandbits(8) for _ in range(16))
            iv = random.choice(specials) if (mode == 2 and random.random() < 0.6) else bytes(random.getrandbits(8) for _ in range(16))
            n = random.randint(1, 6)
            data = bytes(random.getrandbits(8) for _ in range(16*n))
            if mode == 0:   out = (enc if d == 0 else dec)(key, modes.ECB(), data)
            elif mode == 1: out = (enc if d == 0 else dec)(key, modes.CBC(iv), data)
            else:           out = enc(key, modes.CTR(iv), data)   # CTR: giai ma = ma hoa
            msg(mode, d, key, iv, data, out)

open("modes_vectors.hex", "w").write("\n".join(lines) + "\n")
print(len(lines), "vectors")
