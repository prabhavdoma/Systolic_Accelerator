`timescale 1ns/1ps
module tb;
    localparam int N = 16, K = 16, CYC = 56;

    logic clk = 0, rst = 1, drain_en = 0;
    logic [N-1:0][7:0]  a_word, b_word, out_word;   // byte i at bits 8i+7:8i
    logic               en_i, clr_i;
    logic signed [31:0] bias [0:N-1];
    logic signed [31:0] m;
    logic signed [7:0]  s;
    logic               relu_en;

    compute_core dut (
        .clk(clk), .rst(rst),
        .a_word(a_word), .b_word(b_word),
        .en_i(en_i), .clr_i(clr_i), .drain_en(drain_en),
        .bias(bias), .m(m), .s(s), .relu_en(relu_en),
        .out_word(out_word));

    always #5 clk = ~clk;

    // hierarchical taps on every PE accumulator
    logic signed [31:0] acc [0:N-1][0:N-1];
    genvar gi, gj;
    generate
        for (gi = 0; gi < N; gi++) begin : tapr
            for (gj = 0; gj < N; gj++) begin : tapc
                always @* acc[gi][gj] = dut.array_inst.rows[gi].cols[gj].pe_inst.acc;
            end
        end
    endgenerate

    logic [7:0]  a_raw [0:K*N-1], b_raw [0:K*N-1];
    logic [31:0] golden [0:N*N-1];
    int total;

    // Reference requant. NOTE: mirrors the RTL's rounding, so it cannot catch
    // a rounding-convention mismatch vs. your software stack. Replace with
    // Python-generated 8-bit goldens once you pick that reference.
    function automatic logic signed [7:0] rq(
        input logic signed [31:0] x, input logic signed [31:0] b,
        input logic signed [31:0] mm, input int sh, input bit relu);
        longint v, lo;
        v  = longint'(x) + longint'(b);
        v  = v * longint'(mm);
        if (sh > 0) v += (64'sd1 <<< (sh-1));
        v  = v >>> sh;
        lo = relu ? 0 : -128;
        if (v > 127)     return 8'sd127;
        else if (v < lo) return lo[7:0];
        else             return v[7:0];
    endfunction

    task automatic run_frame(input string tag);
        int i, j, c, errors, n_hi, n_lo;
        logic signed [7:0] got8 [0:N-1][0:N-1];
        logic signed [7:0] exp8;

        // stimulus: word k packs column k of A / row k of B, byte i = index i
        for (c = 0; c < CYC; c++) begin
            @(posedge clk);
            for (i = 0; i < N; i++) begin
                a_word[i] <= (c < K) ? a_raw[c*N + i] : 8'h00;
                b_word[i] <= (c < K) ? b_raw[c*N + i] : 8'h00;
            end
            en_i  <= (c < K);
            clr_i <= (c == 0);
        end
        a_word <= '0; b_word <= '0; en_i <= 0; clr_i <= 0;
        repeat (4) @(posedge clk);

        // 32-bit accumulator check
        errors = 0;
        for (i=0;i<N;i++) for (j=0;j<N;j++)
            if (acc[i][j] !== $signed(golden[i*N+j])) begin
                if (errors < 8) $display("[%s] COMPUTE [%0d][%0d]: got %0d exp %0d",
                                         tag, i, j, acc[i][j], $signed(golden[i*N+j]));
                errors++;
            end
        if (errors) $display("[%s] COMPUTE FAIL %0d/%0d", tag, errors, N*N);
        else        $display("[%s] COMPUTE PASS", tag);
        total += errors;

        // drain: rows exit 15 down to 0; row 15 valid before first edge
        drain_en = 1'b1;
        #1 for (j=0;j<N;j++) got8[N-1][j] = $signed(out_word[j]);
        for (c = 1; c < N; c++) begin
            @(posedge clk);
            #1 for (j=0;j<N;j++) got8[N-1-c][j] = $signed(out_word[j]);
        end
        @(posedge clk);
        drain_en = 1'b0;

        // 8-bit requant check (bias is per column/lane)
        errors = 0; n_hi = 0; n_lo = 0;
        for (i=0;i<N;i++) for (j=0;j<N;j++) begin
            exp8 = rq($signed(golden[i*N+j]), bias[j], m, int'(s), relu_en);
            if (exp8 == 8'sd127)                     n_hi++;
            if (exp8 == (relu_en ? 8'sd0 : -8'sd128)) n_lo++;
            if (got8[i][j] !== exp8) begin
                if (errors < 8) $display("[%s] DRAIN [%0d][%0d]: got %0d exp %0d",
                                         tag, i, j, got8[i][j], exp8);
                errors++;
            end
        end
        if (errors) $display("[%s] DRAIN FAIL %0d/%0d", tag, errors, N*N);
        else        $display("[%s] DRAIN PASS", tag);
        $display("[%s] coverage: %0d clamped high, %0d clamped low", tag, n_hi, n_lo);
        total += errors;
    endtask

    initial begin
        total = 0;
        $readmemh("a_raw.hex",  a_raw);
        $readmemh("b_raw.hex",  b_raw);
        $readmemh("golden.hex", golden);

        a_word = '0; b_word = '0; en_i = 0; clr_i = 0;
        m = 1; s = 0; relu_en = 0;
        for (int j = 0; j < N; j++) bias[j] = '0;
        repeat (2) @(posedge clk);
        rst = 0;

        // frame 1: ReLU off, mixed-sign bias
        m = 32'sd1; s = 8'd12; relu_en = 1'b0;
        for (int j = 0; j < N; j++) bias[j] = j*1000 - 8000;
        run_frame("relu_off");

        // frame 2: ReLU on, different scale; also checks clr between frames
        m = 32'sd5; s = 8'd14; relu_en = 1'b1;
        for (int j = 0; j < N; j++) bias[j] = -j*500;
        run_frame("relu_on");

        // frame 3: ReLU off, small shift to force saturation both directions
        m = 32'sd1; s = 8'd6; relu_en = 1'b0;
        for (int j = 0; j < N; j++) bias[j] = '0;
        run_frame("saturate");

        if (total) $display("FAIL: %0d errors", total);
        else       $display("ALL PASS");
        $finish;
    end
endmodule
