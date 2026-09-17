
module compute_core(
    input  logic clk, rst,
    input  logic [15:0][7:0] a_word,
    input  logic [15:0][7:0] b_word,
    input  logic en_i,
    input  logic clr_i,
    input  logic drain_en,
	input  logic signed [31:0] bias [0:15],
	input  logic signed [31:0] m,
	input  logic signed [7:0] s,
	input  logic relu_en,
    
    output logic [15:0][7:0] out_word
);

	//convert 128 bit words into 16 chunks
	logic signed [7:0] a_i [0:15];
	logic signed [7:0] b_i [0:15];
	logic signed [7:0] out_8 [0:15];

	always_comb begin : bit_to_bytes
		for (int i = 0; i < 16; i++) begin
			a_i[i] = a_word[i];
			b_i[i] = b_word[i];
			out_word[i] = out_8[i];

		end
	end

    //skew wires
    logic signed [7:0] a_sk [0:15];
    logic signed [7:0] b_sk [0:15];
	logic signed [31:0] out_32 [0:15];
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
		.out(out_32)
    );

	requant requant_inst (
		.m(m),
		.s(s),
		.bias(bias),
		.relu_en(relu_en),
		.out_32(out_32),
		.out_8(out_8)
	);

endmodule
