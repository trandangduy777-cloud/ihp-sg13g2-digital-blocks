// SHA-256 loi lap: moi chu ky mot vong, mot khoi 512 bit.
//
// Giao tiep:
//   start : xung 1 chu ky khi dang ranh (busy = 0); bo qua neu dang ban
//   init  : 1 = bat dau tu IV (khoi dau cua thong diep), 0 = noi tiep tu khoi truoc
//   block : khoi 512 bit da duoc dem (padding), tu dau tien M0 nam o bit [511:480]
//   busy  : 1 trong luc dang tinh
//   done  : len 1 khi xong, giu den lan start nhan duoc ke tiep
//   digest: gia tri bam 256 bit {H0..H7}, hop le khi done = 1
//
// Do tre: canh clock nhan start la chu ky nap, 64 canh tiep theo la 64 vong,
// tong 65 canh clock tu canh nhan start den canh dat done = 1.

module sha256_core (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire         init,
    input  wire [511:0] block,
    output wire         busy,
    output reg          done,
    output wire [255:0] digest
);

    // IV (FIPS 180-4)
    localparam [255:0] IV = {32'h6a09e667, 32'hbb67ae85, 32'h3c6ef372, 32'ha54ff53a,
                             32'h510e527f, 32'h9b05688c, 32'h1f83d9ab, 32'h5be0cd19};

    // ---------------- ham logic ----------------
    function [31:0] rotr;
        input [31:0] x;
        input integer n;
        begin
            rotr = (x >> n) | (x << (32 - n));
        end
    endfunction

    function [31:0] big_sigma0;
        input [31:0] x;
        begin
            big_sigma0 = rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 22);
        end
    endfunction

    function [31:0] big_sigma1;
        input [31:0] x;
        begin
            big_sigma1 = rotr(x, 6) ^ rotr(x, 11) ^ rotr(x, 25);
        end
    endfunction

    function [31:0] small_sigma0;
        input [31:0] x;
        begin
            small_sigma0 = rotr(x, 7) ^ rotr(x, 18) ^ (x >> 3);
        end
    endfunction

    function [31:0] small_sigma1;
        input [31:0] x;
        begin
            small_sigma1 = rotr(x, 17) ^ rotr(x, 19) ^ (x >> 10);
        end
    endfunction

    // ---------------- thanh ghi ----------------
    reg         run;
    reg  [5:0]  t;                 // chi so vong 0..63
    reg  [511:0] w;                // thanh ghi dich 16 tu: tu thu i la W[t+i], W[t] o bit [511:480]
    reg  [31:0] a, b, c, d, e, f, g, h;
    reg  [255:0] hs;               // gia tri bam trung gian H0..H7

    wire [31:0] kt;
    sha256_k u_k (.t(t), .k(kt));

    // ---------------- lich thong diep ----------------
    wire [31:0] w0  = w[511:480];  // W[t]
    wire [31:0] w1  = w[479:448];  // W[t+1]
    wire [31:0] w9  = w[223:192];  // W[t+9]
    wire [31:0] w14 = w[63:32];    // W[t+14]
    // W[t+16] = sigma1(W[t+14]) + W[t+9] + sigma0(W[t+1]) + W[t]
    wire [31:0] w_new = small_sigma1(w14) + w9 + small_sigma0(w1) + w0;

    // ---------------- mot vong ----------------
    wire [31:0] ch   = (e & f) ^ (~e & g);
    wire [31:0] maj  = (a & b) ^ (a & c) ^ (b & c);
    wire [31:0] t1   = h + big_sigma1(e) + ch + kt + w0;
    wire [31:0] t2   = big_sigma0(a) + maj;
    wire [31:0] na   = t1 + t2;
    wire [31:0] ne   = d + t1;

    wire [255:0] base = init ? IV : hs;

    assign busy   = run;
    assign digest = hs;

    // ---------------- dieu khien (co reset) ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            run  <= 1'b0;
            done <= 1'b0;
            t    <= 6'd0;
        end else begin
            if (!run) begin
                if (start) begin
                    run  <= 1'b1;
                    done <= 1'b0;
                    t    <= 6'd0;
                end
            end else begin
                t <= t + 6'd1;
                if (t == 6'd63) begin
                    run  <= 1'b0;
                    done <= 1'b1;
                end
            end
        end
    end

    // ---------------- duong du lieu (khong reset de tiet kiem dien tich) ----------------
    always @(posedge clk) begin
        if (!run && start) begin
            w  <= block;
            hs <= base;
            a  <= base[255:224];
            b  <= base[223:192];
            c  <= base[191:160];
            d  <= base[159:128];
            e  <= base[127:96];
            f  <= base[95:64];
            g  <= base[63:32];
            h  <= base[31:0];
        end else if (run) begin
            w <= {w[479:0], w_new};
            a <= na;
            b <= a;
            c <= b;
            d <= c;
            e <= ne;
            f <= e;
            g <= f;
            h <= g;
            if (t == 6'd63) begin
                hs <= {hs[255:224] + na, hs[223:192] + a, hs[191:160] + b, hs[159:128] + c,
                       hs[127:96]  + ne, hs[95:64]   + e, hs[63:32]   + f, hs[31:0]    + g};
            end
        end
    end

endmodule
