// Ngoai vi AES-128 co giao dien APB4 (slave), boc aes_modes (ECB / CBC / CTR). 1 khoi 128 bit moi lan.
// Ban do thanh ghi (32 bit, word dau la phan co trong so cao nhat, tuc byte 0 cua FIPS-197 nam o bit 31:24 cua word 0):
//   0x00 CTRL    ghi: [0] START (xung), [1] DECRYPT, [3:2] MODE (0 ECB, 1 CBC, 2 CTR), [4] LOAD_IV (xung), [5] IRQ_EN
//                doc : {26'b0, IRQ_EN, 0, MODE, DECRYPT, 0}
//   0x04 STATUS  doc : [0] BUSY, [1] DONE (dung tu khi ket thuc khoi, xoa khi START hoac ghi 1), [2] ERR (START/LOAD_IV luc ban)
//                ghi 1 vao bit 1 hoac 2 de xoa
//   0x10..0x1C KEY0..KEY3    chi ghi (doc ra 0)
//   0x20..0x2C IV0..IV3      chi ghi (doc ra 0); nap bang LOAD_IV, khi ranh
//   0x30..0x3C DIN0..DIN3    ghi
//   0x40..0x4C DOUT0..DOUT3  chi doc
// START va LOAD_IV phai ghi o hai lan truy cap rieng. Dia chi ngoai ban do hoac ghi vao DOUT: PSLVERR = 1.
// irq = DONE & IRQ_EN (muc cao).
module aes_apb (
  input             PCLK,
  input             PRESETn,
  input             PSEL,
  input             PENABLE,
  input             PWRITE,
  input      [7:0]  PADDR,
  input      [31:0] PWDATA,
  output reg [31:0] PRDATA,
  output            PREADY,
  output            PSLVERR,
  output            irq
);
  reg [31:0] key_r [0:3];
  reg [31:0] iv_r  [0:3];
  reg [31:0] din_r [0:3];
  reg [1:0]  mode_r;
  reg        dec_r, irq_en, done_s, err_s, start_q, liv_q;

  wire        m_busy, m_done;
  wire [127:0] m_dout;

  aes_modes u_modes (
    .clk(PCLK), .rst_n(PRESETn), .mode(mode_r), .decrypt(dec_r),
    .load_iv(liv_q), .iv({iv_r[0], iv_r[1], iv_r[2], iv_r[3]}),
    .start(start_q), .key({key_r[0], key_r[1], key_r[2], key_r[3]}),
    .din({din_r[0], din_r[1], din_r[2], din_r[3]}),
    .busy(m_busy), .done(m_done), .dout(m_dout)
  );

  wire access = PSEL & PENABLE;
  wire wr = access & PWRITE;
  wire rd = access & ~PWRITE;
  wire busy_v = m_busy | start_q;

  wire [3:0] widx = PADDR[3:2];
  wire in_key  = (PADDR[7:4] == 4'h1);
  wire in_iv   = (PADDR[7:4] == 4'h2);
  wire in_din  = (PADDR[7:4] == 4'h3);
  wire in_dout = (PADDR[7:4] == 4'h4);
  wire in_ctrl = (PADDR == 8'h00);
  wire in_stat = (PADDR == 8'h04);
  wire mapped  = in_ctrl | in_stat | in_key | in_iv | in_din | in_dout;

  assign PREADY  = 1'b1;
  assign PSLVERR = access & (~mapped | (PWRITE & in_dout));
  assign irq     = done_s & irq_en;

  wire ctrl_start = wr & in_ctrl & PWDATA[0];
  wire ctrl_liv   = wr & in_ctrl & PWDATA[4];

  always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      key_r[0] <= 0; key_r[1] <= 0; key_r[2] <= 0; key_r[3] <= 0;
      iv_r[0]  <= 0; iv_r[1]  <= 0; iv_r[2]  <= 0; iv_r[3]  <= 0;
      din_r[0] <= 0; din_r[1] <= 0; din_r[2] <= 0; din_r[3] <= 0;
      mode_r <= 0; dec_r <= 0; irq_en <= 0; done_s <= 0; err_s <= 0; start_q <= 0; liv_q <= 0;
    end else begin
      start_q <= 1'b0;
      liv_q   <= 1'b0;
      if (wr) begin
        if (in_key) key_r[widx[1:0]] <= PWDATA;
        if (in_iv)  iv_r [widx[1:0]] <= PWDATA;
        if (in_din) din_r[widx[1:0]] <= PWDATA;
        if (in_ctrl) begin
          dec_r  <= PWDATA[1];
          mode_r <= PWDATA[3:2];
          irq_en <= PWDATA[5];
        end
        if (in_stat) begin
          if (PWDATA[1]) done_s <= 1'b0;
          if (PWDATA[2]) err_s  <= 1'b0;
        end
      end
      if (ctrl_start) begin
        if (busy_v) err_s <= 1'b1;
        else begin start_q <= 1'b1; done_s <= 1'b0; end
      end
      if (ctrl_liv) begin
        if (busy_v) err_s <= 1'b1;
        else liv_q <= 1'b1;
      end
      if (m_done) done_s <= 1'b1;
    end
  end

  always @* begin
    PRDATA = 32'd0;
    if (rd) begin
      if (in_ctrl)      PRDATA = {26'd0, irq_en, 1'b0, mode_r, dec_r, 1'b0};
      else if (in_stat) PRDATA = {29'd0, err_s, done_s, busy_v};
      else if (in_dout) PRDATA = m_dout[127 - 32*widx[1:0] -: 32];
    end
  end
endmodule
