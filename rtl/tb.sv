`timescale 1ns/1ps
module tb;
    localparam int N = 16, K = 16, CYC = 56;

    logic clk = 0, rst = 1, drain_en = 0;
    logic signed [7:0]  a_i [0:N-1], b_i [0:N-1];
    logic               en_i, clr_i;
    logic signed [31:0] out [0:N-1];

    compute_core dut (
        .clk(clk), .rst(rst), .en_i(en_i), .clr_i(clr_i),
        .drain_en(drain_en), .a_i(a_i), .b_i(b_i), .out(out));

    always #5 clk = ~clk;

    // hierarchical refs need constant indices, so bind them in a generate
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
    logic signed [31:0] got [0:N-1][0:N-1];
    int i, j, c, errors, total;

    initial begin
        total = 0;
        $readmemh("a_raw.hex",  a_raw);
        $readmemh("b_raw.hex",  b_raw);
        $readmemh("golden.hex", golden);

        for (i=0;i<N;i++) begin a_i[i]='0; b_i[i]='0; end
        en_i = 0; clr_i = 0;
        repeat (2) @(posedge clk);
        rst = 0;

        // flat stimulus: skew_regs does the staggering now
        for (c = 0; c < CYC; c++) begin
            @(posedge clk);
            for (i = 0; i < N; i++) begin
                a_i[i] <= (c < K) ? $signed(a_raw[c*N + i]) : 8'sd0;
                b_i[i] <= (c < K) ? $signed(b_raw[c*N + i]) : 8'sd0;
            end
            en_i  <= (c < K);
            clr_i <= (c == 0);
        end
        for (i=0;i<N;i++) begin a_i[i]='0; b_i[i]='0; end
        en_i <= 0; clr_i <= 0;
        repeat (4) @(posedge clk);

        errors = 0;
        for (i=0;i<N;i++) for (j=0;j<N;j++)
            if (acc[i][j] !== $signed(golden[i*N+j])) begin
                if (errors < 8) $display("COMPUTE [%0d][%0d]: got %0d exp %0d",
                                         i, j, acc[i][j], $signed(golden[i*N+j]));
                errors++;
            end
        if (errors) $display("COMPUTE FAIL %0d/%0d", errors, N*N);
        else        $display("COMPUTE PASS");
        total += errors;

        // drain: out[] taps row N-1, already valid before the first edge
        drain_en = 1'b1;
        #1 for (j=0;j<N;j++) got[N-1][j] = out[j];
        for (c = 1; c < N; c++) begin
            @(posedge clk);
            #1 for (j=0;j<N;j++) got[N-1-c][j] = out[j];
        end
        @(posedge clk);
        drain_en = 1'b0;

        errors = 0;
        for (i=0;i<N;i++) for (j=0;j<N;j++)
            if (got[i][j] !== $signed(golden[i*N+j])) begin
                if (errors < 8) $display("DRAIN [%0d][%0d]: got %0d exp %0d",
                                         i, j, got[i][j], $signed(golden[i*N+j]));
                errors++;
            end
        if (errors) $display("DRAIN FAIL %0d/%0d", errors, N*N);
        else        $display("DRAIN PASS");
        total += errors;

        if (total) $display("FAIL: %0d errors", total);
        else       $display("ALL PASS");
        $finish;
    end
endmodule
