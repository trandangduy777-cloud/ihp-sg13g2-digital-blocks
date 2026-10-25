// Sinh tu gen_comp.py. S-box AES dang truong ghep GF((2^4)^2), da kiem chung vet can voi S-box chuan.
// Truong con GF(2^4): y^4+y+1. Truong ghep: z^2+z+LAM, LAM=4'h8. Phan tu: {a1,a0} = a1*z + a0.
module aes_sbox(input [7:0] a, output [7:0] y);
  function [3:0] m4(input [3:0] a, input [3:0] b);
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
      4'h0: inv4 = 4'h0;
      4'h1: inv4 = 4'h1;
      4'h2: inv4 = 4'h9;
      4'h3: inv4 = 4'he;
      4'h4: inv4 = 4'hd;
      4'h5: inv4 = 4'hb;
      4'h6: inv4 = 4'h7;
      4'h7: inv4 = 4'h6;
      4'h8: inv4 = 4'hf;
      4'h9: inv4 = 4'h2;
      4'ha: inv4 = 4'hc;
      4'hb: inv4 = 4'h5;
      4'hc: inv4 = 4'ha;
      4'hd: inv4 = 4'h4;
      4'he: inv4 = 4'h3;
      4'hf: inv4 = 4'h8;
      default: inv4 = 4'h0;
    endcase
  endfunction
  function [7:0] inv_comp(input [7:0] c);
    reg [3:0] a1, a0, d, di;
    begin
      a1 = c[7:4]; a0 = c[3:0];
      d  = m4(a0, a0) ^ m4(a0, a1) ^ m4(4'h8, m4(a1, a1));
      di = inv4(d);
      inv_comp = {m4(a1, di), m4(a0 ^ a1, di)};
    end
  endfunction
  function [7:0] lin_in(input [7:0] x);
    lin_in = {^(x & 8'ha0), ^(x & 8'hac), ^(x & 8'hd2), ^(x & 8'h70), ^(x & 8'h18), ^(x & 8'hfc), ^(x & 8'h04), ^(x & 8'ha1)};
  endfunction
  function [7:0] lin_out(input [7:0] x);
    lin_out = {^(x & 8'h06), ^(x & 8'hd0), ^(x & 8'hee), ^(x & 8'h3b), ^(x & 8'h25), ^(x & 8'h69), ^(x & 8'h3f), ^(x & 8'h45)};
  endfunction
  assign y = lin_out(inv_comp(lin_in(a))) ^ 8'h63;
endmodule

module aes_inv_sbox(input [7:0] a, output [7:0] y);
  function [3:0] m4(input [3:0] a, input [3:0] b);
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
      4'h0: inv4 = 4'h0;
      4'h1: inv4 = 4'h1;
      4'h2: inv4 = 4'h9;
      4'h3: inv4 = 4'he;
      4'h4: inv4 = 4'hd;
      4'h5: inv4 = 4'hb;
      4'h6: inv4 = 4'h7;
      4'h7: inv4 = 4'h6;
      4'h8: inv4 = 4'hf;
      4'h9: inv4 = 4'h2;
      4'ha: inv4 = 4'hc;
      4'hb: inv4 = 4'h5;
      4'hc: inv4 = 4'ha;
      4'hd: inv4 = 4'h4;
      4'he: inv4 = 4'h3;
      4'hf: inv4 = 4'h8;
      default: inv4 = 4'h0;
    endcase
  endfunction
  function [7:0] inv_comp(input [7:0] c);
    reg [3:0] a1, a0, d, di;
    begin
      a1 = c[7:4]; a0 = c[3:0];
      d  = m4(a0, a0) ^ m4(a0, a1) ^ m4(4'h8, m4(a1, a1));
      di = inv4(d);
      inv_comp = {m4(a1, di), m4(a0 ^ a1, di)};
    end
  endfunction
  function [7:0] lin_in(input [7:0] x);
    lin_in = {^(x & 8'hc6), ^(x & 8'h71), ^(x & 8'h78), ^(x & 8'hf7), ^(x & 8'h6f), ^(x & 8'h12), ^(x & 8'h92), ^(x & 8'h62)};
  endfunction
  function [7:0] lin_out(input [7:0] x);
    lin_out = {^(x & 8'hd4), ^(x & 8'h8e), ^(x & 8'h54), ^(x & 8'hca), ^(x & 8'hc2), ^(x & 8'h02), ^(x & 8'hb0), ^(x & 8'h81)};
  endfunction
  assign y = lin_out(inv_comp(lin_in(a ^ 8'h63)));
endmodule
