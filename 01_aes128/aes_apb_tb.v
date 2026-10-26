`timescale 1ns/1ps
// Testbench tu kiem cho aes_apb: lai bus APB4 bang cac task, dung vector cua modes_vectors.hex (NIST SP 800-38A + OpenSSL).
module aes_apb_tb;
  reg PCLK = 0, PRESETn = 0, PSEL = 0, PENABLE = 0, PWRITE = 0;
  reg [7:0] PADDR = 0; reg [31:0] PWDATA = 0;
  wire [31:0] PRDATA; wire PREADY, PSLVERR, irq;
  aes_apb dut (.PCLK(PCLK), .PRESETn(PRESETn), .PSEL(PSEL), .PENABLE(PENABLE), .PWRITE(PWRITE),
               .PADDR(PADDR), .PWDATA(PWDATA), .PRDATA(PRDATA), .PREADY(PREADY), .PSLVERR(PSLVERR), .irq(irq));
  always #5 PCLK = ~PCLK;

  integer errs = 0, n = 0, i, polls, fd, r;
  reg        slverr;
  reg [31:0] rdata;

  task apb_write(input [7:0] a, input [31:0] d);
    begin
      @(posedge PCLK); #1 PSEL = 1; PENABLE = 0; PWRITE = 1; PADDR = a; PWDATA = d;
      @(posedge PCLK); #1 PENABLE = 1;
      @(posedge PCLK); slverr = PSLVERR; #1 PSEL = 0; PENABLE = 0; PWRITE = 0;
    end
  endtask
  task apb_read(input [7:0] a);
    begin
      @(posedge PCLK); #1 PSEL = 1; PENABLE = 0; PWRITE = 0; PADDR = a;
      @(posedge PCLK); #1 PENABLE = 1;
      @(posedge PCLK); rdata = PRDATA; slverr = PSLVERR; #1 PSEL = 0; PENABLE = 0;
    end
  endtask
  task check(input cond, input [255:0] msg);
    begin if (!cond) begin errs = errs + 1; if (errs < 8) $display("LOI: %0s (vector %0d)", msg, n); end end
  endtask
  task wr128(input [7:0] base, input [127:0] v);
    begin
      apb_write(base,        v[127:96]); apb_write(base + 8'h4, v[95:64]);
      apb_write(base + 8'h8, v[63:32]);  apb_write(base + 8'hC, v[31:0]);
    end
  endtask
  task rd128(input [7:0] base, output [127:0] v);
    begin
      apb_read(base);        v[127:96] = rdata; apb_read(base + 8'h4); v[95:64] = rdata;
      apb_read(base + 8'h8); v[63:32]  = rdata; apb_read(base + 8'hC); v[31:0]  = rdata;
    end
  endtask
  task wait_done;
    begin
      polls = 0; rdata = 0;
      while (!rdata[1] && polls < 200) begin apb_read(8'h04); polls = polls + 1; end
      check(rdata[1], "khong thay DONE");
    end
  endtask

  reg [3:0] m_, d_, l_;
  reg [127:0] iv_, key_, din_, exp_, got;
  reg [31:0] ctl;
  reg use_irq;

  initial begin
    #23 PRESETn = 1;
    fd = $fopen("modes_vectors.hex", "r");
    if (fd == 0) begin $display("FAIL: khong mo duoc modes_vectors.hex"); $finish; end
    while (!$feof(fd)) begin
      r = $fscanf(fd, "%h %h %h %h %h %h %h\n", m_, d_, l_, iv_, key_, din_, exp_);
      if (r == 7) begin
        use_irq = n[0];
        ctl = (m_[1:0] << 2) | (d_[0] << 1) | (use_irq << 5);
        wr128(8'h10, key_);
        if (l_[0]) begin
          wr128(8'h20, iv_);
          apb_write(8'h00, ctl | 32'h10);               // LOAD_IV
          check(!slverr, "PSLVERR khi ghi CTRL");
        end
        wr128(8'h30, din_);
        apb_write(8'h00, ctl | 32'h1);                  // START
        apb_read(8'h04);
        check(rdata[0] | rdata[1], "sau START phai thay BUSY hoac DONE");
        wait_done;
        if (use_irq) check(irq === 1'b1, "irq phai len khi DONE va IRQ_EN");
        else         check(irq === 1'b0, "irq phai thap khi IRQ_EN = 0");
        rd128(8'h40, got);
        check(got === exp_, "DOUT sai");
        if (got !== exp_ && errs < 8) $display("  got %h exp %h", got, exp_);
        apb_write(8'h04, 32'h2);                        // xoa DONE
        apb_read(8'h04);
        check(rdata[1] == 1'b0 && rdata[0] == 1'b0, "DONE khong xoa");
        check(irq === 1'b0, "irq phai ve 0 sau khi xoa DONE");
        n = n + 1;
      end
    end

    // --- kiem tra rieng ---
    apb_read(8'h50);  check(slverr, "doc dia chi ngoai ban do phai PSLVERR");
    apb_write(8'h60, 32'h1); check(slverr, "ghi dia chi ngoai ban do phai PSLVERR");
    apb_write(8'h40, 32'h1); check(slverr, "ghi vao DOUT phai PSLVERR");
    apb_read(8'h40);  check(!slverr, "doc DOUT khong duoc PSLVERR");
    apb_read(8'h10);  check(rdata == 32'd0 && !slverr, "KEY phai doc ra 0");
    apb_read(8'h20);  check(rdata == 32'd0, "IV phai doc ra 0");
    apb_write(8'h00, 32'h2C); apb_read(8'h00);          // dec=0 mode=3 irq_en=1 -> thu doc lai CTRL
    check(rdata == 32'h2C, "doc lai CTRL");
    apb_write(8'h00, 32'h0);

    // START lai khi DONE cu con: START phai xoa DONE, STATUS ngay sau do phai thay BUSY
    apb_write(8'h00, 32'h1); wait_done;
    apb_write(8'h00, 32'h1);
    apb_read(8'h04);
    check(rdata[1] == 1'b0, "START phai xoa DONE cu");
    check(rdata[0] == 1'b1, "sau START lai phai thay BUSY");
    wait_done; apb_write(8'h04, 32'h2);

    // START khi dang ban: ERR bat len, ket qua khong bi hong
    wr128(8'h10, 128'h000102030405060708090a0b0c0d0e0f);
    wr128(8'h30, 128'h00112233445566778899aabbccddeeff);
    apb_write(8'h00, 32'h1);
    apb_write(8'h00, 32'h1);
    wait_done;
    apb_read(8'h04);  check(rdata[2], "START khi ban phai bat ERR");
    rd128(8'h40, got);
    check(got === 128'h69c4e0d86a7b0430d8cdb78070b4c55a, "ket qua bi hong boi START khi ban");
    apb_write(8'h04, 32'h6); apb_read(8'h04);
    check(rdata[2:1] == 2'b00, "xoa ERR/DONE");

    if (errs == 0) $display("PASS: aes_apb %0d vector + kiem tra rieng (APB4, ECB/CBC/CTR)", n);
    else           $display("FAIL: %0d loi", errs);
    $finish;
  end
  initial begin #200000000; $display("FAIL: treo"); $finish; end
endmodule
