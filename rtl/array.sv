
module array #(
    parameter int N = 16  //size
)(
    input  logic clk, rst,
    input  logic en_i [0:N-1],
    input  logic clr_i [0:N-1],
    input  logic drain_en,
    input  logic signed [7:0] a_i [0:N-1],  // 16 rows of A enter from left
    input  logic signed [7:0] b_i [0:N-1],  // 16 cols of B enter from top
    output logic signed [31:0] out [0:N-1] // (16 cols; bottom row of result matrix CXX 16x16)
);
    // Internal wires connecting PEs
    logic signed [7:0]  wire_a [0:N-1][0:N]; // horizontal flow
    logic signed [7:0]  wire_b [0:N][0:N-1]; // vertical flow
    logic signed [31:0] wire_psum [0:N][0:N-1]; // vertical flow    
    logic wire_en  [0:N-1][0:N];
    logic wire_clr [0:N-1][0:N];


    // Hook up left and top edges to inputs
    genvar i, j;
    generate
        for (i = 0; i < N; i++) begin : edges
            assign wire_a[i][0] = a_i[i];  // A enters from left
            assign wire_b[0][i] = b_i[i];  // B enters from top
	        assign wire_psum[0][i] = '0;   //row above grid tied to 0
	        assign out[i] = wire_psum[N][i]; //psums read from last row (flow down)
	        assign wire_en[i][0] = en_i[i];
	        assign wire_clr[i][0] = clr_i[i];
        end
    endgenerate 

    // Instantiate 256 (N^2) PEs
    generate
        for (i = 0; i < N; i++) begin : rows
            for (j = 0; j < N; j++) begin : cols
                pe #(.ROW(i), .COL(j)) pe_inst (
                    .clk	(clk),
                    .rst	(rst),
                    .a_i	(wire_a[i][j]),
                    .b_i	(wire_b[i][j]),
		            .en_i	(wire_en[i][j]),
		            .en_o	(wire_en[i][j+1]),
		            .clr_i	(wire_clr[i][j]),
		            .clr_o	(wire_clr[i][j+1]),
		            .drain_en   (drain_en),	    // parallel (16x16) signal
		            .psum_i	(wire_psum[i][j]),  // passes down
                    .a_o	(wire_a[i][j+1]),   // passes right
                    .b_o	(wire_b[i+1][j]),   // passes down
                    .acc	(wire_psum[i+1][j])
                );
            end
        end
    endgenerate

endmodule 
