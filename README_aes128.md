# 01 - AES-128 ma hoa + giai ma (IHP SG13G2, LibreLane)

Loi AES-128 lap 1 vong / chu ky, du lieu 128 bit, ho tro ca ma hoa va giai ma.

## Kien truc
- Ma hoa: 1 chu ky nap (din xor key) + 10 vong. Tu start den done: 11 chu ky.
- Giai ma: 10 chu ky tinh xuoi khoa toi vong 10, roi 10 vong giai ma. Tu start den done: 21 chu ky.
- Khoa vong tinh "on the fly" (khong luu 11 khoa). Khi giai ma, khoa duoc tinh nguoc:
  w3' = w3 ^ w2, w2' = w2 ^ w1, w1' = w1 ^ w0, w0' = w0 ^ SubWord(RotWord(w3')) ^ Rcon.
  4 S-box cua khoa dung chung cho ca hai chieu (chi doi dau vao w3 hay w3 ^ w2).
- 16 S-box + 16 S-box nghich cho du lieu. S-box sinh tu `gen.py` (nghich dao trong GF(2^8) + affine),
  khong chep bang tu ngoai vao; gen.py kiem tra S[0]=63, S[1]=7c, S[53]=ed.
- Cong: clk, rst_n (async, active low), start, decrypt, key[127:0], din[127:0] -> busy, done, dout[127:0].
  Byte dau tien o bit [127:120] (theo FIPS-197). Key va din chi can giu dung 1 chu ky luc start.

## Kiem tra
- `aes_tb.v`: 304 vector (FIPS-197 phu luc B va C.1, key/plaintext toan 0 va toan 1, 300 vector ngau nhien do
  thu vien Python `cryptography` tinh). Moi vector: ma hoa ra dung ct, giai ma ct ra dung pt, dung do tre,
  busy khong xuong som; them 1 phep thu `start` khi core dang ban phai bi bo qua.
- Thu dot bien (mutation) 9 loi chen co y: sai Rcon, sai ShiftRows, bo MixColumns sai vong, sai he so
  InvMixColumns, sai InvShiftRows, vong cuoi giai ma, khoa nguoc, sai 1 o S-box, bo AddRoundKey vong 10.
  Ca 9 deu bi testbench bat (FAIL).
- Yosys (tong hop generic) khong bao latch hay vong to hop (`check -assert` sach).

## Chay
```
./run_sim.sh          # mo phong, in AES128: PASS
./run_flow.sh 01_aes128   # LibreLane -> GDS (CLOCK_PERIOD 20 ns)
```

## Ket qua LibreLane (IHP SG13G2, CLOCK_PERIOD 20 ns)
| Chi so | Gia tri |
|---|---|
| So instance (gom ca cell filler va tap) | 44061 |
| Dien tich instance | 372451 um2 (khoang 0.37 mm2) |
| Setup slack xau nhat | +6.71 ns (duong tri o chu ky 20 ns, duong toi han khoang 13.3 ns) |
| Hold slack xau nhat | +0.12 ns |
| Vi pham setup / hold / max slew / max cap | khong co |
| DRC / LVS / Antenna | Passed / Passed / Passed |

- Slack lay tu trang thai sau buoc 63 cua flow (sau routing va STA), cac buoc sau khong doi timing.
- Chua chay buoc kiem tra tuong duong (Yosys EQY), buoc nay mac dinh tat.
- Thoi gian chay tren may tac gia: khoang 1 gio 45 phut den het routing (luc do may dang chay nhieu flow cung luc), them khoang 16 phut cho DRC va LVS.
- File GDS va metrics.json nam trong thu muc results.

## Han che (thang that)
- Khong chong tan cong kenh ke (side channel), khong co che do CBC/CTR/GCM, chi ECB 1 khoi.
- S-box dang bang tra (case), khong phai S-box composite-field nen dien tich lon hon ban toi uu.
- Chua mo phong gate-level; SDC mac dinh cua LibreLane (input/output delay 20% chu ky), nen slack duong chua chung minh chip chay duoc tren board that.
- Setup slack du lon cho thay co the tang tan so (thu CLOCK_PERIOD 15 ns), nhung chua chay thu.
