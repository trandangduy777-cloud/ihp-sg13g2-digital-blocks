// Lop bao quanh aes128_core them che do ECB / CBC / CTR, xu ly tung khoi 128 bit.
// mode: 0 = ECB, 1 = CBC, 2 = CTR.  decrypt bi bo qua o che do CTR (CTR giai ma = CTR ma hoa).
// load_iv: nap IV (CBC) hoac bo dem dau (CTR) khi ranh. Sau moi khoi, thanh ghi chain tu cap nhat.
// Key phai giu on dinh trong suot mot khoi. Bo dem CTR tang 128 bit (dung NIST SP 800-38A).
module aes_modes (
  input          clk,
  input          rst_n,
  input  [1:0]   mode,
  input          decrypt,
  input          load_iv,
  input  [127:0] iv,
  input          start,      // xung 1 chu ky khi busy = 0
  input  [127:0] key,
  input  [127:0] din,
  output         busy,
  output reg     done,       // xung 1 chu ky, dout hop le
  output reg [127:0] dout
);
  localparam ECB = 2'd0, CBC = 2'd1, CTR = 2'd2;

  reg [127:0] chain, din_q;
  reg [1:0]   mode_q;
  reg         dec_q, active;

  wire go = start && !active;

  wire [127:0] core_in = (mode == CBC && !decrypt) ? (din ^ chain) :
                         (mode == CTR)             ? chain : din;
  wire         core_dec = (mode == CTR) ? 1'b0 : decrypt;

  wire         core_busy, core_done;
  wire [127:0] core_out;

  aes128_core u_core (
    .clk(clk), .rst_n(rst_n), .start(go), .decrypt(core_dec),
    .key(key), .din(core_in), .busy(core_busy), .done(core_done), .dout(core_out)
  );

  assign busy = active;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      chain <= 128'd0; din_q <= 128'd0; mode_q <= 2'd0; dec_q <= 1'b0;
      active <= 1'b0; done <= 1'b0; dout <= 128'd0;
    end else begin
      done <= 1'b0;
      if (load_iv && !active) chain <= iv;
      if (go) begin
        active <= 1'b1; din_q <= din; mode_q <= mode; dec_q <= decrypt;
      end
      if (active && core_done) begin
        active <= 1'b0;
        done   <= 1'b1;
        case (mode_q)
          CBC: begin
            if (dec_q) begin dout <= core_out ^ chain; chain <= din_q; end
            else       begin dout <= core_out;         chain <= core_out; end
          end
          CTR: begin dout <= core_out ^ din_q; chain <= chain + 128'd1; end
          default: dout <= core_out;
        endcase
      end
    end
  end
endmodule
