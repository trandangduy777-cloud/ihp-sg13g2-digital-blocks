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
| Setup slack xau nhat | +6.71 ns tai chu ky 20 ns (so xau nhat trong cac goc timing, suy luan la goc cham) |
| Hold slack xau nhat | +0.12 ns |
| Vi pham setup / hold / max slew / max cap | khong co |
| DRC / LVS / Antenna | Passed / Passed / Passed |

- Slack lay tu trang thai sau buoc 63 cua flow (sau routing va STA), cac buoc sau khong doi timing.
- Chua chay buoc kiem tra tuong duong (Yosys EQY), buoc nay mac dinh tat.
- Thoi gian chay tren may tac gia: khoang 1 gio 45 phut den het routing (luc do may dang chay nhieu flow cung luc), them khoang 16 phut cho DRC va LVS.
- File GDS va metrics.json nam trong thu muc results.

## Bien the: S-box dang truong ghep (composite field)

Ban goc dung S-box bang tra 256 muc. Bien the nay tinh S-box bang so hoc truong ghep GF((2^4)^2):
chuyen byte sang truong ghep bang phep bien doi tuyen tinh, nghich dao nho GF(2^4) (bang 16 muc),
roi chuyen nguoc va ap phep affine. Ca S-box thuan va nghich deu viet theo cach nay.

- Sinh bang `gen_comp.py` (tu tim ma tran chuyen truong, khong chep bang ngoai). Dong cau nhan duoc kiem tra truoc khi sinh Verilog.
- Kiem chung: so khop vet can 256 gia tri, ca hai chieu, voi S-box bang tra; AES van qua 304 vector khi dung S-box nay.
  Dot bien (sai 1 bit ma tran, sai hang so 0x63) deu bi bat.
- Chay flow: `librelane --pdk-root /opt/pdks --manual-pdk --pdk ihp-sg13g2 --run-tag comp config_comp.yaml`

| Chi so | S-box bang tra | S-box composite |
|---|---|---|
| So instance (gom filler va tap) | 44061 | 24883 (giam 43.5%) |
| Dien tich instance (um2) | 372451 | 250039 (giam 32.9%) |
| Setup slack xau nhat (ns, 20 ns) | +6.71 | +3.73 |
| Hold slack xau nhat (ns) | +0.12 | +0.12 |
| DRC / LVS / Antenna | 0 loi, Passed | 0 loi, Passed |

- Ca hai ban chay cung cau hinh LibreLane (CLOCK_PERIOD 20 ns, SDC mac dinh), chi khac file S-box, nen so sanh la cung dieu kien.
- Ket qua: ban composite nho hon ro ret (dien tich giam khoang 1/3) va van sach DRC, LVS, antenna, khong vi pham setup/hold.
  Doi lai setup slack xau nhat giam tu +6.71 xuong +3.73 ns, tuc duong logic cham them khoang 3 ns. Voi chu ky 20 ns slack van duong, con du cho.
- Ly do (suy luan): nghich dao trong GF(2^4) chi can bang 16 muc nen bo bang 256 muc bi thay bang it cong hon, nhung chuoi cong xor/nhan noi tiep dai hon nen cham hon.
- Chua do cong suat va chua thu chu ky ngan hon, nen chua the noi ban nao tot hon ve toc do toi da.

- So +6.71 ns trong bang ket qua la goc xau nhat, nen khac so slack trong anh vi khac goc.
- Buffer chong hold (sg13g2_dlygate4sd3_1) do LibreLane tu chen xuat hien tren duong nay, binh thuong.

## Che do hoat dong: ECB / CBC / CTR

`aes_modes.v` bao quanh `aes128_core` de xu ly nhieu khoi theo ba che do (mode 0 = ECB, 1 = CBC, 2 = CTR).

- Moi lan xu ly mot khoi 128 bit. `load_iv` nap IV (CBC) hoac bo dem dau (CTR). Thanh ghi chain tu cap nhat sau moi khoi.
- CBC ma hoa: XOR ban ro voi chain truoc khi vao core. CBC giai ma: XOR dau ra core voi ban ma truoc, roi luu ban ma cua khoi hien tai lam chain moi.
- CTR: ma hoa bo dem roi XOR voi du lieu; bo dem tang 128 bit; giai ma cung la phep ma hoa nen chan `decrypt` o che do nay.
- Xung `start` luc dang ban bi bo qua.
- Kiem chung: `aes_modes_tb.v` doc `modes_vectors.hex` (283 vector) gom dap an NIST SP 800-38A (F.1.1, F.2.1, F.5.1, ma hoa va giai ma) va vector ngau nhien do OpenSSL tinh (nhieu khoa, 1 den 6 khoi, bo dem CTR gan muc tran 64 bit va 128 bit). `gen_modes.py` doi chieu cac hang NIST voi thu vien truoc khi ghi file.
- Dot bien: 11 loi co y (sai chain CBC, thieu XOR, CTR khong tang hoac chi tang 64 bit, bo qua load_iv, nhan start khi ban...) deu bi bat.
- Chua chay lop nay qua LibreLane, nen khong co so dien tich hay timing rieng cho lop bao. So lieu o phan Ket qua la cua `aes128_core`.

## Han che (thang that)
- Khong chong tan cong kenh ke (side channel), khong co GCM. CBC/CTR chi co o lop bao `aes_modes`, chua qua LibreLane.
- Hai bien the S-box (bang tra va composite) da chay flow day du; chua so sanh o chu ky khac 20 ns.
- Chua mo phong gate-level; SDC mac dinh cua LibreLane (input/output delay 20% chu ky), nen slack duong chua chung minh chip chay duoc tren board that.
- Setup slack du lon cho thay co the thu CLOCK_PERIOD nho hon (vi du 15 ns), nhung chua chay thu. Luu y input/output delay cua SDC mac dinh la 20% chu ky nen cung doi theo chu ky, vi vay slack khong giam tuyen tinh.
