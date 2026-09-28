
module pe #(
    parameter int ROW = 0,
    parameter int COL = 0

)(
    input  logic               clk, rst,
    input  logic signed [7:0]  a_i, b_i,
    input  logic               en_i, clr_i, 
    input  logic               drain_en,
    input  logic signed [31:0] psum_i,

    output logic signed [7:0]  a_o, b_o,
    output logic               en_o, clr_o,

    output logic signed [31:0] acc
);
    //multiply
    logic signed [15:0] prod;
    assign prod = a_i * b_i;

    //accumulate
    always_ff @(posedge clk) begin
        if (rst) begin
            a_o <= '0; b_o <= '0; en_o <= '0; clr_o <= '0;
        end else begin
            a_o <= a_i;
            b_o <= b_i;
	    en_o <= en_i;
	    clr_o <= clr_i;
	end
	
	if (drain_en) begin
	    acc <= psum_i;
	    
	end else if (en_i && clr_i) acc <= prod;
	else if (en_i) acc <= acc + prod;
    end
endmodule
