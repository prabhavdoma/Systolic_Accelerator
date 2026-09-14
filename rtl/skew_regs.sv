// set up skew buffers for a,b matrices and 
//en, clr signals
module skew_regs(
    input  logic clk,
    input  logic signed [7:0] a_i [0:15],
    input  logic signed [7:0] b_i [0:15],
    input  logic en_i,
    input  logic clr_i,

    output logic signed [7:0] a_o [0:15],
    output logic signed [7:0] b_o [0:15],
    output logic en_o [0:15],
    output logic clr_o [0:15]
);
    logic signed [7:0] a_delay [0:15][0:15];
    logic signed [7:0] b_delay [0:15][0:15];
    logic en_delay [0:15][0:15];
    logic clr_delay [0:15][0:15];

    genvar i,j;
    generate 
	for (i = 0; i < 16; i++) begin : index

	    assign a_delay[i][0] = a_i[i];
	    assign b_delay[i][0] = b_i[i];
	    assign en_delay[i][0] = en_i;
	    assign clr_delay[i][0] = clr_i;

	    for (j = 0; j < i; j++) begin : buffers
	    	always_ff @(posedge clk) begin
		    a_delay[i][j+1] <= a_delay[i][j];
		    b_delay[i][j+1] <= b_delay[i][j];
		    en_delay[i][j+1] <= en_delay[i][j];
		    clr_delay[i][j+1] <= clr_delay[i][j];
	    	end
	    end
	    assign a_o[i] = a_delay[i][i];
	    assign b_o[i] = b_delay[i][i];
	    assign en_o[i] = en_delay[i][i];
	    assign clr_o[i] = clr_delay[i][i];
	end
    endgenerate
endmodule 
