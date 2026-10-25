`timescale 1ns/1ps
// Testbench tu kiem tra cho sha256_core.
// Doc tb/vectors.txt (do tools/gen_vectors.py sinh tu hashlib + vector NIST).
// In dung mot dong ket qua cuoi: "SHA256: PASS" hoac "SHA256: FAIL".
module tb_sha256;

    reg          clk = 1'b0;
    reg          rst_n = 1'b0;
    reg          start = 1'b0;
    reg          init = 1'b0;
    reg  [511:0] block = 512'd0;
    wire         busy;
    wire         done;
    wire [255:0] digest;

    sha256_core dut (
        .clk(clk), .rst_n(rst_n), .start(start), .init(init), .block(block),
        .busy(busy), .done(done), .digest(digest)
    );

    always #5 clk = ~clk;

    integer errors = 0;
    integer nblocks = 0;
    integer nchecks = 0;
    integer lat_min = 1000, lat_max = 0;
    integer seed = 12345;

    // Chay mot khoi: tra ve so canh clock tu canh nhan start den canh done = 1.
    // glitch = 1: ban them mot xung start voi du lieu khac khi dang ban (phai bi bo qua).
    task run_block;
        input         i_init;
        input [511:0] i_blk;
        input         glitch;
        output integer cyc;
        begin
            @(negedge clk);
            start = 1'b1; init = i_init; block = i_blk;
            cyc = 0;
            begin : wait_done
                forever begin
                    @(posedge clk);
                    #1;
                    cyc = cyc + 1;
                    if (cyc == 1) begin
                        start = 1'b0;
                        init  = ~i_init;          // doi init/block sau khi da nhan
                        block = ~i_blk;
                    end
                    if (glitch && cyc == 10) begin
                        start = 1'b1; init = 1'b1; block = ~i_blk ^ 512'h1234;
                    end
                    if (glitch && cyc == 11) begin
                        start = 1'b0;
                    end
                    if (done || cyc >= 200) disable wait_done;
                    // trong luc tinh: busy = 1, done = 0
                    if (cyc <= 64) begin
                        if (busy !== 1'b1 || done !== 1'b0) begin
                            errors = errors + 1;
                            if (errors < 6) $display("  loi: busy/done sai o chu ky %0d", cyc);
                        end
                    end
                end
            end
        end
    endtask

    integer fd, r, cyc, k, gap, tries;
    reg  [3:0]   v_init, v_chk;
    reg  [511:0] v_blk;
    reg  [255:0] v_exp;
    reg  [255:0] abc_exp;
    reg  [511:0] abc_blk;

    initial begin
        // ---- reset ----
        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);
        if (busy !== 1'b0 || done !== 1'b0) begin
            errors = errors + 1;
            $display("  loi: sau reset busy/done khac 0");
        end

        // ---- doc vector ----
        fd = $fopen("tb/vectors.txt", "r");
        if (fd == 0) fd = $fopen("vectors.txt", "r");
        if (fd == 0) begin
            $display("  loi: khong mo duoc vectors.txt");
            $display("SHA256: FAIL");
            $finish;
        end

        r = $fscanf(fd, "%h %h %h %h\n", v_init, v_chk, v_blk, v_exp);
        while (r == 4) begin
            // khoang nghi ngau nhien 0..3 chu ky giua cac lan start
            gap = $random(seed) & 3;
            repeat (gap) @(negedge clk);

            run_block(v_init[0], v_blk, 1'b0, cyc);
            nblocks = nblocks + 1;
            if (cyc < lat_min) lat_min = cyc;
            if (cyc > lat_max) lat_max = cyc;
            if (cyc != 65) begin
                errors = errors + 1;
                if (errors < 6) $display("  loi: do tre %0d chu ky (can 65), khoi %0d", cyc, nblocks);
            end
            if (v_chk[0]) begin
                nchecks = nchecks + 1;
                if (digest !== v_exp) begin
                    errors = errors + 1;
                    if (errors < 6) begin
                        $display("  loi: khoi %0d", nblocks);
                        $display("    ra   : %h", digest);
                        $display("    can  : %h", v_exp);
                    end
                end
                // digest phai giu nguyen khi done
                repeat (3) @(negedge clk);
                if (digest !== v_exp || done !== 1'b1 || busy !== 1'b0) begin
                    errors = errors + 1;
                    if (errors < 6) $display("  loi: digest/done khong giu sau khi xong, khoi %0d", nblocks);
                end
            end
            // luu vector "abc" (thong diep 1 khoi dau tien co v_chk = 1 va digest ba7816bf...)
            if (v_chk[0] && v_init[0] && v_exp[255:224] == 32'hba7816bf) begin
                abc_blk = v_blk;
                abc_exp = v_exp;
            end
            r = $fscanf(fd, "%h %h %h %h\n", v_init, v_chk, v_blk, v_exp);
        end
        $fclose(fd);

        // ---- test dac biet 1: start khi dang ban phai bi bo qua ----
        run_block(1'b1, abc_blk, 1'b1, cyc);
        if (cyc != 65 || digest !== abc_exp) begin
            errors = errors + 1;
            $display("  loi: start khi dang ban khong bi bo qua (cyc=%0d)", cyc);
        end
        nchecks = nchecks + 1;
        repeat (2) @(negedge clk);

        // ---- test dac biet 2: reset giua chung roi chay lai ----
        @(negedge clk);
        start = 1'b1; init = 1'b1; block = abc_blk;
        @(negedge clk);
        start = 1'b0;
        repeat (20) @(negedge clk);
        rst_n = 1'b0;
        #2;
        if (busy !== 1'b0 || done !== 1'b0) begin
            errors = errors + 1;
            $display("  loi: reset bat dong bo khong xoa busy/done");
        end
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        repeat (3) @(negedge clk);
        if (busy !== 1'b0) begin
            errors = errors + 1;
            $display("  loi: sau reset giua chung busy khac 0");
        end
        run_block(1'b1, abc_blk, 1'b0, cyc);
        if (cyc != 65 || digest !== abc_exp) begin
            errors = errors + 1;
            $display("  loi: sau reset giua chung ket qua sai (cyc=%0d)", cyc);
        end
        nchecks = nchecks + 1;

        // ---- test dac biet 3: noi tiep (init = 0) khac voi bat dau moi (init = 1) ----
        // Chay "abc" roi chay lai cung khoi voi init = 0: ket qua phai khac (vi noi tu H cu).
        run_block(1'b0, abc_blk, 1'b0, cyc);
        if (digest === abc_exp) begin
            errors = errors + 1;
            $display("  loi: init = 0 van ra ket qua nhu init = 1");
        end

        $display("INFO: %0d khoi, %0d digest kiem, do tre %0d..%0d chu ky/khoi",
                 nblocks, nchecks, lat_min, lat_max);
        if (errors == 0) $display("SHA256: PASS");
        else             $display("SHA256: FAIL");
        $finish;
    end

    // watchdog
    initial begin
        #200000000;
        $display("  loi: qua thoi gian");
        $display("SHA256: FAIL");
        $finish;
    end

endmodule
