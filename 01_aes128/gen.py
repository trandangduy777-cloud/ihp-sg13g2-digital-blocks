import os
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
# sbox tu dinh nghia GF(2^8)
def xt(b): 
    b<<=1
    return (b^0x11b)&0xff if b&0x100 else b
def mul(a,b):
    r=0
    while b:
        if b&1: r^=a
        a=xt(a) if False else (((a<<1)^0x11b) if a&0x80 else (a<<1))&0xff
        b>>=1
    return r
def inv(a):
    if a==0: return 0
    for x in range(1,256):
        if mul(a,x)==1: return x
def rotl(x,n): return ((x<<n)|(x>>(8-n)))&0xff
S=[]
for a in range(256):
    b=inv(a)
    S.append(b^rotl(b,1)^rotl(b,2)^rotl(b,3)^rotl(b,4)^0x63)
assert S[0]==0x63 and S[1]==0x7c and S[0x53]==0xed
IS=[0]*256
for i,v in enumerate(S): IS[v]=i
def mod(name,T):
    s="module %s(input [7:0] a, output reg [7:0] y);\n  always @* begin\n    case (a)\n"%name
    for i,v in enumerate(T): s+="      8'h%02x: y = 8'h%02x;\n"%(i,v)
    s+="      default: y = 8'h00;\n    endcase\n  end\nendmodule\n"
    return s
open("aes_sbox.v","w").write("// Sinh tu gen.py: S-box FIPS-197 tinh tu nghich dao GF(2^8) + bien doi affine\n"+mod("aes_sbox",S)+"\n"+mod("aes_inv_sbox",IS))
import random
random.seed(20261011)
vec=[("000102030405060708090a0b0c0d0e0f","00112233445566778899aabbccddeeff"),
     ("2b7e151628aed2a6abf7158809cf4f3c","3243f6a8885a308d313198a2e0370734"),
     ("00"*16,"00"*16),("ff"*16,"ff"*16)]
for _ in range(300): vec.append((os.urandom(16).hex(),os.urandom(16).hex()))
with open("vectors.hex","w") as f:
    for k,p in vec:
        e=Cipher(algorithms.AES(bytes.fromhex(k)),modes.ECB()).encryptor()
        c=(e.update(bytes.fromhex(p))+e.finalize()).hex()
        f.write(k+p+c+"\n")
        if (k,p)==vec[0]: assert c=="69c4e0d86a7b0430d8cdb78070b4c55a"
        if (k,p)==vec[1]: assert c=="3925841d02dc09fbdc118597196a0b32"
print(len(vec))
