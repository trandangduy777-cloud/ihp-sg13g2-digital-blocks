`timescale 1ns/1ps
// Ghi VCD hoat dong chuyen mach cua DUT trong cua so thoi gian dau (de uoc luong cong suat). Dung cung aes_tb.v.
// Chay: vvp sim +vcd=ten.vcd +dumpns=13500
module gls_dump;
  reg [255:0] f;
  integer w;
  initial begin
    if ($value$plusargs("vcd=%s", f)) begin
      $dumpfile(f);
      $dumpvars(0, aes_tb.dut);
      if (!$value$plusargs("dumpns=%d", w)) w = 13500;
      #(w) $dumpoff;
      $finish;
    end
  end
endmodule
