
module systolic_array (
    input  logic        clk, rst,
    input  logic signed [7:0] a_in [0:15],  // 16 rows of A enter from left
    input  logic signed [7:0] b_in [0:15],  // 16 cols of B enter from top
    output logic signed [31:0] out [0:15][0:15] // 16x16 result matrix
);
    // Internal wires connecting PEs
    logic signed [7:0] wire_a [0:15][0:16]; // horizontal flow
    logic signed [7:0] wire_b [0:16][0:15]; // vertical flow

    // Hook up left and top edges to inputs
    genvar i, j;
    generate
        for (i = 0; i < 16; i++) begin
            assign wire_a[i][0] = a_in[i];  // A enters from left
            assign wire_b[0][i] = b_in[i];  // B enters from top
        end
    endgenerate

    // Instantiate 256 PEs
    generate
        for (i = 0; i < 16; i++) begin
            for (j = 0; j < 16; j++) begin
                pe pe_inst (
                    .clk   (clk),
                    .rst   (rst),
                    .in_a  (wire_a[i][j]),
                    .in_b  (wire_b[i][j]),
                    .out_a (wire_a[i][j+1]),  // passes right
                    .out_b (wire_b[i+1][j]),  // passes down
                    .acc   (out[i][j])
                );
            end
        end
    endgenerate

endmodule