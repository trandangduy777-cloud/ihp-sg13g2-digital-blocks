`timescale 1ns/1ps
// Testbench tu kiem cho aes_modes: doc modes_vectors.hex (NIST SP 800-38A + ngau nhien tu OpenSSL).
module aes_modes_tb;
  reg clk = 0, rst_n = 0, start = 0, decrypt = 0, load_iv = 0;
  reg [1:0] mode = 0;
  reg [127:0] iv = 0, key = 0, din = 0;
  wire busy, done;
  wire [127:0] dout;

  aes_modes dut (.clk(clk), .rst_n(rst_n), .mode(mode), .decrypt(decrypt), .load_iv(load_iv),
                 .iv(iv), .start(start), .key(key), .din(din), .busy(busy), .done(done), .dout(dout));
  always #5 clk = ~clk;

  integer fd, r, n, errs, cyc, hit;
  reg [3:0]   m_, d_, l_;
  reg [127:0] iv_, key_, din_, exp_;

  initial begin
    errs = 0; n = 0;
    fd = $fopen("modes_vectors.hex", "r");
    if (fd == 0) begin $display("FAIL: khong mo duoc modes_vectors.hex"); $finish; end
    #22 rst_n = 1; @(posedge clk);
    while (!$feof(fd)) begin
      r = $fscanf(fd, "%h %h %h %h %h %h %h\n", m_, d_, l_, iv_, key_, din_, exp_);
      if (r == 7) begin
        mode = m_[1:0]; decrypt = d_[0]; key = key_;
        if (l_[0]) begin iv = iv_; load_iv = 1; @(posedge clk); #1 load_iv = 0; end
        din = din_; start = 1; @(posedge clk); #1 start = 0;
        // thu start khi dang ban voi du lieu khac: phai bi bo qua
        din = ~din_; start = 1; @(posedge clk); #1 start = 0;
        cyc = 2; hit = 0;
        while (!hit && cyc < 100) begin
          @(posedge clk); #1 cyc = cyc + 1;
          if (done) hit = 1;
        end
        if (!hit) begin errs = errs + 1; $display("FAIL: khong thay done, vector %0d", n); end
        else begin
          if (dout !== exp_) begin
            errs = errs + 1;
            if (errs < 5) $display("FAIL vector %0d mode %0d dec %0d: got %h exp %h", n, m_, d_, dout, exp_);
          end
          if (busy !== 1'b0) begin errs = errs + 1; $display("FAIL: busy van cao sau done"); end
        end
        @(posedge clk);
        n = n + 1;
      end
    end
    if (errs == 0) $display("PASS: %0d vector (ECB/CBC/CTR, NIST SP 800-38A + ngau nhien)", n);
    else           $display("FAIL: %0d loi / %0d vector", errs, n);
    $finish;
  end
endmodule
