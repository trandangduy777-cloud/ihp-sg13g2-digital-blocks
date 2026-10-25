module sbox_tb;
  reg [7:0] a; wire [7:0] y1,y2,z1,z2; integer i, err=0;
  aes_sbox u1(a,y1); aes_sbox_c u2(a,y2);
  aes_inv_sbox v1(a,z1); aes_inv_sbox_c v2(a,z2);
  initial begin
    for (i=0;i<256;i=i+1) begin a=i; #1;
      if (y1!==y2) begin err=err+1; $display("sbox sai %h: %h vs %h",a,y1,y2); end
      if (z1!==z2) begin err=err+1; $display("inv sai %h: %h vs %h",a,z1,z2); end
    end
    if (err==0) $display("SBOX_COMP: PASS (256 gia tri, 2 chieu)"); else $display("SBOX_COMP: FAIL (%0d)",err);
  end
endmodule
