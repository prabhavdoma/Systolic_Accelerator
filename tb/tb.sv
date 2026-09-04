`timescale 1ns/1ps

module tb;
    logic clk, rst;
    logic signed [7:0]  a_in [0:15];
    logic signed [7:0]  b_in [0:15];
    logic signed [31:0] out  [0:15][0:15];

    systolic_array dut (
        .clk(clk), .rst(rst),
        .a_in(a_in), .b_in(b_in),
        .out(out)
    );

    always #5 clk = ~clk;

    // Flat storage for streams
    logic [7:0]  a_flat [0:767];   // 48 cycles * 16 = 768
    logic [7:0]  b_flat [0:767];
    logic [31:0] golden  [0:255];  // 16*16 = 256

    integer i, j, cycle, errors;

    initial begin
        // Load hex files
        $readmemh("a_stream.hex", a_flat);
        $readmemh("b_stream.hex", b_flat);
        $readmemh("golden.hex",   golden);

        clk = 0; rst = 1;
        for (i = 0; i < 16; i++) begin
            a_in[i] = 0;
            b_in[i] = 0;
        end

        @(posedge clk); @(posedge clk);
        rst = 0;

        // Feed skewed streams cycle by cycle
        for (cycle = 0; cycle < 48; cycle++) begin
            @(posedge clk);
            for (i = 0; i < 16; i++) begin
                a_in[i] <= signed'(a_flat[cycle*16 + i]);
                b_in[i] <= signed'(b_flat[cycle*16 + i]);
            end
        end

        // Let last data drain
        repeat(20) @(posedge clk);

        // Verify
        errors = 0;
        for (i = 0; i < 16; i++) begin
            for (j = 0; j < 16; j++) begin
                if (out[i][j] !== signed'(golden[i*16 + j])) begin
                    $display("MISMATCH [%0d][%0d]: got %0d, expected %0d",
                        i, j, out[i][j], signed'(golden[i*16 + j]));
                    errors++;
                end
            end
        end

        if (errors == 0) $display("ALL 256 PASS");
        else $display("%0d ERRORS", errors);
        $finish;
    end
endmodule