# Sinh S-box AES dang truong hop (composite field) GF((2^4)^2), kiem tra bang vet can voi S-box chuan.
import random
def xt(a): return ((a<<1)^0x11b)&0xff if a&0x80 else (a<<1)
def mul8(a,b):
    r=0
    while b:
        if b&1: r^=a
        a=xt(a); b>>=1
    return r
def inv8(a):
    return next((x for x in range(1,256) if mul8(a,x)==1),0) if a else 0
def rotl(x,n): return ((x<<n)|(x>>(8-n)))&0xff
SB=[ (lambda b: b^rotl(b,1)^rotl(b,2)^rotl(b,3)^rotl(b,4)^0x63)(inv8(a)) for a in range(256)]
assert SB[0x53]==0xed
# GF(2^4): y^4+y+1
def m4(a,b):
    r=0
    for i in range(4):
        if (b>>i)&1: r^=a<<i
    for i in range(7,3,-1):
        if (r>>i)&1: r^=0b10011<<(i-4)
    return r&0xf
INV4=[0]+[next(x for x in range(1,16) if m4(a,x)==1) for a in range(1,16)]
# chon lambda de z^2+z+lambda bat kha quy tren GF(2^4)
LAM=next(l for l in range(1,16) if all(m4(z,z)^z^l for z in range(16)))
def mc(a,b): # (a1 z + a0)(b1 z + b0), z^2=z+LAM
    a1,a0=a>>4,a&0xf; b1,b0=b>>4,b&0xf
    t=m4(a1,b1)
    return (((t^m4(a1,b0)^m4(a0,b1))<<4) | (m4(t,LAM)^m4(a0,b0)))
def pw(a,n):
    r=0x01
    for _ in range(n): r=mc(r,a)
    return r
# beta: nghiem cua x^8+x^4+x^3+x+1 trong truong ghep
beta=next(b for b in range(2,256) if pw(b,8)^pw(b,4)^pw(b,3)^b^1==0)
phi_basis=[pw(beta,i) for i in range(8)]
def phi(x):
    r=0
    for i in range(8):
        if (x>>i)&1: r^=phi_basis[i]
    return r
# kiem tra dong cau nhan
for _ in range(500):
    a,b=random.randrange(256),random.randrange(256)
    assert phi(mul8(a,b))==mc(phi(a),phi(b))
PHI_INV=[0]*256
for x in range(256): PHI_INV[phi(x)]=x
def affine(b): return b^rotl(b,1)^rotl(b,2)^rotl(b,3)^rotl(b,4)
AFF_INV=[0]*256
for x in range(256): AFF_INV[affine(x)]=x
def lin_mat(f): return [f(1<<i) for i in range(8)]   # anh cua tung bit co so
def mask_rows(cols):  # hang j: mat na bit vao anh huong toi bit ra j
    rows=[]
    for j in range(8):
        m=0
        for i in range(8):
            if (cols[i]>>j)&1: m|=1<<i
        rows.append(m)
    return rows
def check_lin(f,cols):
    for x in range(256):
        r=0
        for i in range(8):
            if (x>>i)&1: r^=cols[i]
        assert r==f(x)
f_in1=lambda x: phi(x)                       # sbox: vao
f_out1=lambda c: affine(PHI_INV[c])          # sbox: ra (them 0x63 sau)
f_in2=lambda t: phi(AFF_INV[t])              # inv sbox: vao (sau khi xor 0x63)
f_out2=lambda c: PHI_INV[c]                  # inv sbox: ra
M={}
for name,f in (('in1',f_in1),('out1',f_out1),('in2',f_in2),('out2',f_out2)):
    cols=lin_mat(f); check_lin(f,cols); M[name]=mask_rows(cols)
def lin_fn(fname,rows):
    s="  function [7:0] %s(input [7:0] x);\n    %s = {"%(fname,fname)
    s+=", ".join("^(x & 8'h%02x)"%rows[j] for j in range(7,-1,-1))
    return s+"};\n  endfunction\n"
v="// Sinh tu gen_comp.py. S-box AES dang truong ghep GF((2^4)^2), da kiem chung vet can voi S-box chuan.\n"
v+="// Truong con GF(2^4): y^4+y+1. Truong ghep: z^2+z+LAM, LAM=4'h%x. Phan tu: {a1,a0} = a1*z + a0.\n"%LAM
common='''  function [3:0] m4(input [3:0] a, input [3:0] b);
    reg [6:0] r; integer i;
    begin
      r = 7'd0;
      for (i = 0; i < 4; i = i + 1) if (b[i]) r = r ^ ({3'b000, a} << i);
      for (i = 6; i >= 4; i = i - 1) if (r[i]) r = r ^ (7'b0010011 << (i - 4));
      m4 = r[3:0];
    end
  endfunction
  function [3:0] inv4(input [3:0] a);
    case (a)
'''
for a in range(16): common+="      4'h%x: inv4 = 4'h%x;\n"%(a,INV4[a])
common+='''      default: inv4 = 4'h0;
    endcase
  endfunction
  function [7:0] inv_comp(input [7:0] c);
    reg [3:0] a1, a0, d, di;
    begin
      a1 = c[7:4]; a0 = c[3:0];
      d  = m4(a0, a0) ^ m4(a0, a1) ^ m4(4'h%x, m4(a1, a1));
      di = inv4(d);
      inv_comp = {m4(a1, di), m4(a0 ^ a1, di)};
    end
  endfunction
'''%LAM
v+="module aes_sbox(input [7:0] a, output [7:0] y);\n"+common+lin_fn('lin_in',M['in1'])+lin_fn('lin_out',M['out1'])
v+="  assign y = lin_out(inv_comp(lin_in(a))) ^ 8'h63;\nendmodule\n\n"
v+="module aes_inv_sbox(input [7:0] a, output [7:0] y);\n"+common+lin_fn('lin_in',M['in2'])+lin_fn('lin_out',M['out2'])
v+="  assign y = lin_out(inv_comp(lin_in(a ^ 8'h63)));\nendmodule\n"
open('aes_sbox_comp.v','w').write(v)
open('sbox_ref.txt','w').write(" ".join("%02x"%x for x in SB))
print("LAM",LAM,"beta",hex(beta))
