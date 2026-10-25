`timescale 1ns/1ps
// Testbench tu kiem: 304 vector (FIPS-197 C.1, B, 2 vector bien, 300 ngau nhien tu thu vien cryptography)
// Do tre tinh tu chu ky nhan start toi chu ky done: ma hoa 11, giai ma 21.
  // Moi vector: ma hoa phai ra ct, giai ma ct phai ra lai pt, kiem tra do tre va co busy/done.
module aes_tb;
  reg clk = 0, rst_n = 0, start = 0, decrypt = 0;
  reg [127:0] key = 0, din = 0;
  wire busy, done; wire [127:0] dout;
  aes128_core dut(.clk(clk), .rst_n(rst_n), .start(start), .decrypt(decrypt), .key(key), .din(din),
                  .busy(busy), .done(done), .dout(dout));
  always #5 clk = ~clk;

  reg [383:0] mem [0:303];
  integer i, errors = 0, cyc, n = 304;
  reg [127:0] k, p, c;

  task run(input d, input [127:0] kk, input [127:0] dd, input [127:0] expect_o, input integer lat);
    begin
      @(negedge clk); key = kk; din = dd; decrypt = d; start = 1;
      @(negedge clk); start = 0; key = 128'hx; din = 128'hx;   // sau start core phai tu giu khoa va du lieu
      cyc = 1;
      while (!done && cyc < 100) begin
        if (!busy) begin errors = errors + 1; $display("busy xuong som"); end
        @(negedge clk); cyc = cyc + 1;
      end
      if (cyc != lat) begin errors = errors + 1; $display("do tre %0d, can %0d", cyc, lat); end
      if (dout !== expect_o) begin
        errors = errors + 1;
        $display("SAI d=%0d key=%h in=%h got=%h exp=%h", d, kk, dd, dout, expect_o);
      end
    end
  endtask

  initial begin
    $readmemh("vectors.hex", mem);
    repeat (3) @(negedge clk); rst_n = 1;
    for (i = 0; i < n; i = i + 1) begin
      k = mem[i][383:256]; p = mem[i][255:128]; c = mem[i][127:0];
      run(0, k, p, c, 11);
      run(1, k, c, p, 21);
    end
    // start khi dang ban phai bi bo qua
    @(negedge clk); key = mem[0][383:256]; din = mem[0][255:128]; decrypt = 0; start = 1;
    @(negedge clk); start = 0;
    repeat (3) @(negedge clk);
    start = 1; key = 128'h1234; din = 128'h5678;      // dang chay vong 4
    @(negedge clk); start = 0;
    while (!done) @(negedge clk);
    if (dout !== mem[0][127:0]) begin errors = errors + 1; $display("start khi ban lam hong ket qua"); end
    if (errors == 0) $display("AES128: PASS (%0d vector, ma hoa + giai ma)", n);
    else             $display("AES128: FAIL (%0d loi)", errors);
    $finish;
  end
  initial begin #50000000; $display("AES128: FAIL (treo)"); $finish; end
endmodule
