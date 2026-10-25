// AES-128 ma hoa + giai ma, lap 1 vong / chu ky, du lieu 128 bit.
// Ma hoa : 10 chu ky sau start.  Giai ma: 10 chu ky sinh khoa toi vong 10, roi 10 chu ky giai ma
// (khoa vong duoc tinh dan, nguoc lai, khong luu 11 khoa). Byte 0 nam o bit [127:120] (dung FIPS-197).
module aes128_core (
  input          clk,
  input          rst_n,
  input          start,     // xung 1 chu ky khi core ranh
  input          decrypt,   // 0 = ma hoa, 1 = giai ma (chot luc start)
  input  [127:0] key,
  input  [127:0] din,
  output         busy,
  output reg     done,      // xung 1 chu ky, dout hop le
  output [127:0] dout
);
  localparam IDLE = 2'd0, KEYEXP = 2'd1, RUN = 2'd2;

  reg [1:0]   st;
  reg [127:0] state, rk;
  reg [3:0]   rcnt;
  reg         dec;

  assign busy = (st != IDLE);
  assign dout = state;

  function [7:0] rcon(input [3:0] r);
    case (r)
      4'd1: rcon = 8'h01; 4'd2: rcon = 8'h02; 4'd3: rcon = 8'h04; 4'd4: rcon = 8'h08;
      4'd5: rcon = 8'h10; 4'd6: rcon = 8'h20; 4'd7: rcon = 8'h40; 4'd8: rcon = 8'h80;
      4'd9: rcon = 8'h1b; 4'd10: rcon = 8'h36;
      default: rcon = 8'h00;
    endcase
  endfunction

  function [7:0] xt(input [7:0] b);
    xt = {b[6:0], 1'b0} ^ (b[7] ? 8'h1b : 8'h00);
  endfunction

  // ---- khoa vong ----
  wire [31:0] w0 = rk[127:96], w1 = rk[95:64], w2 = rk[63:32], w3 = rk[31:0];
  wire        inv_ks = (st == RUN) && dec;
  wire [31:0] ks_in  = inv_ks ? (w3 ^ w2) : w3;       // dung chung 4 S-box cho 2 chieu
  wire [31:0] ks_rot = {ks_in[23:0], ks_in[31:24]};
  wire [31:0] ks_sub;
  genvar g;
  generate for (g = 0; g < 4; g = g + 1) begin : KS
    aes_sbox u (.a(ks_rot[8*g +: 8]), .y(ks_sub[8*g +: 8]));
  end endgenerate
  wire [31:0] t = ks_sub ^ {rcon(rcnt), 24'h0};

  // tien: khoa vong i -> i+1
  wire [31:0] f0 = w0 ^ t, f1 = w1 ^ f0, f2 = w2 ^ f1, f3 = w3 ^ f2;
  wire [127:0] rk_fwd = {f0, f1, f2, f3};
  // lui: khoa vong i -> i-1
  wire [31:0] p3 = w3 ^ w2, p2 = w2 ^ w1, p1 = w1 ^ w0, p0 = w0 ^ t;
  wire [127:0] rk_bwd = {p0, p1, p2, p3};

  // ---- vong ma hoa ----
  wire [127:0] sb;
  generate for (g = 0; g < 16; g = g + 1) begin : SB
    aes_sbox u (.a(state[127-8*g -: 8]), .y(sb[127-8*g -: 8]));
  end endgenerate

  // ShiftRows: byte i = hang i%4, cot i/4. new[r][c] = old[r][(c+r)%4]
  wire [127:0] sr;
  generate for (g = 0; g < 16; g = g + 1) begin : SR
    localparam R = g % 4, C = g / 4, SRC = ((C + R) % 4) * 4 + R;
    assign sr[127-8*g -: 8] = sb[127-8*SRC -: 8];
  end endgenerate

  wire [127:0] mc;
  generate for (g = 0; g < 4; g = g + 1) begin : MC
    wire [7:0] a0 = sr[127-32*g -: 8], a1 = sr[119-32*g -: 8], a2 = sr[111-32*g -: 8], a3 = sr[103-32*g -: 8];
    assign mc[127-32*g -: 8] = xt(a0) ^ (xt(a1) ^ a1) ^ a2 ^ a3;
    assign mc[119-32*g -: 8] = a0 ^ xt(a1) ^ (xt(a2) ^ a2) ^ a3;
    assign mc[111-32*g -: 8] = a0 ^ a1 ^ xt(a2) ^ (xt(a3) ^ a3);
    assign mc[103-32*g -: 8] = (xt(a0) ^ a0) ^ a1 ^ a2 ^ xt(a3);
  end endgenerate

  wire [127:0] enc_next = ((rcnt == 4'd10) ? sr : mc) ^ rk_fwd;

  // ---- vong giai ma ----
  // InvShiftRows: new[r][c] = old[r][(c-r)%4]
  wire [127:0] isr;
  generate for (g = 0; g < 16; g = g + 1) begin : ISR
    localparam R = g % 4, C = g / 4, SRC = ((C + 4 - R) % 4) * 4 + R;
    assign isr[127-8*g -: 8] = state[127-8*SRC -: 8];
  end endgenerate

  wire [127:0] isb;
  generate for (g = 0; g < 16; g = g + 1) begin : ISB
    aes_inv_sbox u (.a(isr[127-8*g -: 8]), .y(isb[127-8*g -: 8]));
  end endgenerate

  wire [127:0] ark = isb ^ rk_bwd;

  function [7:0] m9 (input [7:0] b); reg [7:0] b2, b4, b8; begin b2 = xt(b); b4 = xt(b2); b8 = xt(b4); m9  = b8 ^ b; end endfunction
  function [7:0] m11(input [7:0] b); reg [7:0] b2, b4, b8; begin b2 = xt(b); b4 = xt(b2); b8 = xt(b4); m11 = b8 ^ b2 ^ b; end endfunction
  function [7:0] m13(input [7:0] b); reg [7:0] b2, b4, b8; begin b2 = xt(b); b4 = xt(b2); b8 = xt(b4); m13 = b8 ^ b4 ^ b; end endfunction
  function [7:0] m14(input [7:0] b); reg [7:0] b2, b4, b8; begin b2 = xt(b); b4 = xt(b2); b8 = xt(b4); m14 = b8 ^ b4 ^ b2; end endfunction

  wire [127:0] imc;
  generate for (g = 0; g < 4; g = g + 1) begin : IMC
    wire [7:0] a0 = ark[127-32*g -: 8], a1 = ark[119-32*g -: 8], a2 = ark[111-32*g -: 8], a3 = ark[103-32*g -: 8];
    assign imc[127-32*g -: 8] = m14(a0) ^ m11(a1) ^ m13(a2) ^ m9(a3);
    assign imc[119-32*g -: 8] = m9(a0)  ^ m14(a1) ^ m11(a2) ^ m13(a3);
    assign imc[111-32*g -: 8] = m13(a0) ^ m9(a1)  ^ m14(a2) ^ m11(a3);
    assign imc[103-32*g -: 8] = m11(a0) ^ m13(a1) ^ m9(a2)  ^ m14(a3);
  end endgenerate

  wire [127:0] dec_next = (rcnt == 4'd1) ? ark : imc;

  // ---- dieu khien ----
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      st <= IDLE; state <= 128'h0; rk <= 128'h0; rcnt <= 4'd0; dec <= 1'b0; done <= 1'b0;
    end else begin
      done <= 1'b0;
      case (st)
        IDLE: if (start) begin
          dec  <= decrypt;
          rk   <= key;
          rcnt <= 4'd1;
          if (decrypt) begin state <= din;       st <= KEYEXP; end
          else         begin state <= din ^ key; st <= RUN;    end
        end
        KEYEXP: begin                     // chi giai ma: tinh xuoi toi khoa vong 10
          rk <= rk_fwd;
          if (rcnt == 4'd10) begin
            state <= state ^ rk_fwd;      // AddRoundKey vong 10
            st    <= RUN;
          end else rcnt <= rcnt + 4'd1;
        end
        RUN: begin
          if (!dec) begin
            state <= enc_next; rk <= rk_fwd;
            if (rcnt == 4'd10) begin st <= IDLE; done <= 1'b1; end
            else rcnt <= rcnt + 4'd1;
          end else begin
            state <= dec_next; rk <= rk_bwd;
            if (rcnt == 4'd1) begin st <= IDLE; done <= 1'b1; end
            else rcnt <= rcnt - 4'd1;
          end
        end
        default: st <= IDLE;
      endcase
    end
  end
endmodule
