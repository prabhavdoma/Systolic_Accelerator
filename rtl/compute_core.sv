module compute_core(
    input  logic clk, rst,
    input  logic signed [7:0] a_i [0:15],
    input  logic signed [7:0] b_i [0:15],
    input  logic en_i;
    input  logic clr_i;
    input  logic drain_en;
    
    output logic signed [7:0] out [0:15],
);
    //skew wires
    logic signed [7:0] a_sk [0:15];
    logic signed [7:0] b_sk [0:15];
    logic en_sk [0:15];
    logic clr_sk [0:15];

    skew_regs skew_inst (
	.clk(clk),
	.a_i(a_i),
	.b_i(b_i),
	.en_i(en_i),
	.clr_i(clr_i),
	.a_o(a_sk),
	.b_o(b_sk),
	.en_o(en_sk),
	.clr_o(clr_sk)
    );

    array array_inst (
	.clk(clk),
	.rst(rst),
	.a_i(a_sk),
	.b_i(b_sk),
	.en_i(en_sk),
	.clr_i(clr_sk),
	.drain_en(drain_en),
	.out(out)
    );


endmodule
