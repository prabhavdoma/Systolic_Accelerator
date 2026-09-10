
module systolic_array #(
    parameter int N = 16  //size
)(
    input  logic        clk, rst,
    input  logic        en_i, clr_i,
    input  logic signed [7:0] a_in [0:N-1],  // 16 rows of A enter from left
    input  logic signed [7:0] b_in [0:N-1],  // 16 cols of B enter from top
    output logic signed [31:0] out [0:N-1][0:N-1] // 16x16 result matrix CXX (tiling ctrl)
);
    // Internal wires connecting PEs
    logic signed [7:0] wire_a [0:N-1][0:N]; // horizontal flow
    logic signed [7:0] wire_b [0:N][0:N-1]; // vertical flow

    // Hook up left and top edges to inputs
    genvar i, j;
    generate
        for (i = 0; i < N; i++) begin : edges
            assign wire_a[i][0] = a_in[i];  // A enters from left
            assign wire_b[0][i] = b_in[i];  // B enters from top
        end
    endgenerate

    // Instantiate 256 (N^2) PEs
    generate
        for (i = 0; i < N; i++) begin : rows
            for (j = 0; j < N; j++) begin : cols
                pe pe_inst (
                    .clk   (clk),
                    .rst   (rst),
                    .a_i   (wire_a[i][j]),
                    .b_i   (wire_b[i][j]),
		    .en_i  (en_i),
		    .clr_i (clr_i),
                    .a_o   (wire_a[i][j+1]),  // passes right
                    .b_o   (wire_b[i+1][j]),  // passes down
                    .acc   (out[i][j])
                );
            end
        end
    endgenerate

endmodule 
