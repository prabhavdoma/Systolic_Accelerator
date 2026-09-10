
module pe #(
    parameter int ROW = 0,
    parameter int COL = 0

)(
    input  logic               clk, rst,
    input  logic signed [7:0]  in_a, in_b,
    input  logic               in_en, in_clear, 
    input  logic               drain_en,
    input  logic signed [31:0] psum_in,

    output logic signed [7:0]  out_a, out_b,
    output logic               out_en, out_clear,

    output logic signed [31:0] acc
);
    //multiply
    logic signed [15:0] prod;
    assign prod = in_a * in_b;

    //accumulate
    always_ff @(posedge clk) begin
        if (rst) begin
            out_a <= '0; out_b <= '0; out_en <= '0; out_clear <= '0;
        end else begin
            out_a <= in_a;
            out_b <= in_b;
	    out_en <= in_en;
	    out_clear <= in_clear;
	end
	
	if (drain_en) begin
	    acc <= psum_in;
	    
	end else if (in_en && in_clear) acc <= prod;
	else if (in_en) acc <= acc + prod;
    end
endmodule 