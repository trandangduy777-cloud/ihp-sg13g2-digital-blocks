# SHA-256 (lõi lặp, 1 vòng mỗi chu kỳ)

Lõi băm SHA-256 viết bằng Verilog, mỗi chu kỳ xử lý một vòng trong 64 vòng của một khối 512 bit. Có testbench tự kiểm tra PASS/FAIL, thử đột biến, và chạy RTL tới GDS bằng LibreLane (IHP SG13G2).

## Giao tiếp

| Cổng | Hướng | Ý nghĩa |
|---|---|---|
| clk | vào | xung clock |
| rst_n | vào | reset bất đồng bộ, tích cực mức thấp |
| start | vào | xung 1 chu kỳ khi busy = 0 (bị bỏ qua khi đang bận) |
| init | vào | 1 = bắt đầu từ IV (khối đầu của thông điệp), 0 = nối tiếp từ khối trước |
| block[511:0] | vào | khối đã đệm sẵn, M0 nằm ở bit [511:480] |
| busy | ra | 1 trong lúc tính |
| done | ra | lên 1 khi xong, giữ tới lần start kế tiếp |
| digest[255:0] | ra | {H0..H7}, hợp lệ khi done = 1 |

Phần đệm (padding) và chia khối nằm ngoài lõi: do `tools/gen_vectors.py` làm, không nằm trong RTL.

## Kiến trúc

- Một vòng mỗi chu kỳ: nạp 1 chu kỳ, rồi 64 vòng. Tính từ cạnh clock nhận start tới cạnh clock đặt done = 1 là **65 chu kỳ** (testbench đo và kiểm tra đúng 65 cho mọi khối).
- Lịch thông điệp W tính dần bằng thanh ghi dịch 16 từ: `W[t+16] = sigma1(W[t+14]) + W[t+9] + sigma0(W[t+1]) + W[t]`. Không lưu cả 64 từ.
- Hằng K (64 giá trị) nằm trong `rtl/sha256_k.v`, **sinh tự động** bởi `tools/gen_k.py` từ căn bậc ba của 64 số nguyên tố đầu tiên bằng số nguyên. Script này cũng kiểm tra K và IV bằng một mô hình SHA-256 viết riêng bằng Python rồi so với `hashlib`.
- Thanh ghi dữ liệu (W, a..h, H) không reset để tiết kiệm diện tích; chỉ các thanh ghi điều khiển (run, done, t) có reset. Vì vậy `digest` không xác định cho tới khi có lần tính đầu tiên.
- Tổng số flip-flop theo yosys generic: 1032 (512 cho W, 256 cho a..h, 256 cho H, 8 điều khiển).

## Kiểm tra

Chạy `./run_sim.sh` (cần Python 3 và iverilog). Kết quả mong đợi: một dòng `SHA256: PASS`.

- Nguồn đáp án độc lập với RTL: `hashlib` và 4 vector NIST gõ trực tiếp trong `tools/gen_vectors.py` (script báo lỗi nếu hashlib không khớp, để bắt lỗi gõ sai).
- 222 thông điệp, 620 khối, 224 lần so sánh digest:
  - 4 vector NIST: chuỗi rỗng, "abc", 448 bit, 896 bit
  - các độ dài biên của padding: 1, 2, 54, 55, 56, 57, 63, 64, 65, 119, 120, 121, 127, 128, 129 byte
  - toàn 0, toàn 1, một thông điệp 1000 byte (16 khối)
  - 200 thông điệp ngẫu nhiên dài 0 đến 300 byte (seed cố định)
- Chỉ so sánh digest ở khối cuối của mỗi thông điệp, vì giá trị trung gian không có đáp án độc lập từ hashlib. Lỗi ở khối giữa vẫn làm sai digest cuối.
- Khoảng nghỉ ngẫu nhiên 0 đến 3 chu kỳ giữa các lần start.
- Ba kiểm tra riêng: start khi đang bận phải bị bỏ qua; reset giữa chừng rồi tính lại; init = 0 phải cho kết quả khác init = 1.
- Mỗi khối còn kiểm tra: busy = 1 và done = 0 trong 64 chu kỳ đầu, độ trễ đúng 65, digest và done giữ nguyên sau khi xong.

## Thử đột biến

`python3 tools/mutate.py` chèn lần lượt 21 lỗi vào RTL (mỗi lần một lỗi). Testbench phải báo FAIL cho từng lỗi. Kết quả: **21/21 lỗi bị bắt**. Các nhóm lỗi:

- sai hằng K (K[0], K[63]), sai phép xoay hoặc dịch trong Sigma và sigma (4 lỗi)
- sai Ch, sai Maj
- quên cộng lại vào H sau 64 vòng (H0, H7)
- không nạp lại IV khi init = 1
- lịch W lệch (ba cách khác nhau)
- sai thanh ghi e hoặc c khi dịch, T1 thiếu K
- nạp dữ liệu khi đang bận, số vòng 63 thay vì 64
- done không xóa khi start, reset không xóa run

Ghi chú: lỗi "reset không xóa run" được bắt vì `run` trở thành X trong mô phỏng, không phải vì hành vi sai thực sự được kiểm tra riêng.

## Kiểm tra tổng hợp generic

`tools/synth_check.sh` chạy yosys (`check -assert` trước và sau `synth`): không latch, không vòng tổ hợp, 0 vấn đề. Số cell trong bước này (6826 cell generic) **không phải** số liệu báo cáo; số liệu thật lấy từ LibreLane bên dưới. Đã tiêm thử một latch vào bản sao RTL để chắc script thực sự bắt được.

## Chạy RTL tới GDS

Trong container UNIC-CASS (prompt `designer ~`), tại thư mục này:

```
./run_flow.sh          # dùng CLOCK_PERIOD trong config.yaml (15 ns)
./run_flow.sh 20       # đổi CLOCK_PERIOD thành 20 ns rồi chạy
```

Script chạy LibreLane, in các số liệu chính và chép GDS cùng metrics.json vào `results/`.

## Kết quả LibreLane (IHP SG13G2)

CLOCK_PERIOD = ___ ns

| Chỉ số | Giá trị | Ghi chú |
|---|---|---|
| Số cell (gồm cả filler) | | design__instance__count |
| Diện tích (um2) | | design__instance__area |
| Setup slack (ns) | | góc chậm, timing__setup__ws |
| Hold slack (ns) | | góc nhanh, timing__hold__ws |
| DRC / LVS / Antenna | | Passed hay không |

## Hạn chế (ghi thẳng)

- Chưa mô phỏng gate-level trên netlist sau LibreLane. Mọi kiểm tra ở trên là mô phỏng RTL.
- Đang dùng SDC mặc định của LibreLane (input/output delay 20% chu kỳ), chưa tinh chỉnh ràng buộc theo giao tiếp thực.
- CLOCK_PERIOD 15 ns là ước lượng ban đầu. Đường tới hạn dự kiến là chuỗi cộng 32 bit tính `e` mới trong một vòng (suy luận), chưa có số đo.
- Phần đệm không có trong RTL; lõi chỉ nhận khối 512 bit đã đệm.
- Không có đáp án độc lập cho giá trị băm trung gian giữa các khối, chỉ kiểm tra digest cuối của thông điệp.
- Bộ nhớ không có trong thiết kế, nhưng lõi tự giữ 1032 flip-flop nên diện tích phần lớn là thanh ghi.

## Cấu trúc thư mục

```
rtl/sha256_core.v    lõi SHA-256
rtl/sha256_k.v       hằng K (sinh tự động)
tb/tb_sha256.v       testbench tự kiểm tra
tb/vectors.txt       vector (sinh bởi tools/gen_vectors.py)
tools/gen_k.py       sinh K, kiểm bằng hashlib
tools/gen_vectors.py sinh vector và padding
tools/mutate.py      thử đột biến
tools/synth_check.sh kiểm tra yosys
config.yaml          cấu hình LibreLane
run_sim.sh           chạy mô phỏng
run_flow.sh          chạy LibreLane
results/             GDS và metrics.json (sau khi chạy flow)
```
