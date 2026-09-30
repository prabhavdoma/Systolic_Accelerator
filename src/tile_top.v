module array (
	clk,
	rst,
	en_i,
	clr_i,
	drain_en,
	a_i,
	b_i,
	out
);
	parameter signed [31:0] N = 16;
	input wire clk;
	input wire rst;
	input wire [0:N - 1] en_i;
	input wire [0:N - 1] clr_i;
	input wire drain_en;
	input wire signed [(N * 8) - 1:0] a_i;
	input wire signed [(N * 8) - 1:0] b_i;
	output wire signed [(N * 32) - 1:0] out;
	wire signed [7:0] wire_a [0:N - 1][0:N];
	wire signed [7:0] wire_b [0:N][0:N - 1];
	wire signed [31:0] wire_psum [0:N][0:N - 1];
	wire wire_en [0:N - 1][0:N];
	wire wire_clr [0:N - 1][0:N];
	genvar _gv_i_1;
	genvar _gv_j_1;
	generate
		for (_gv_i_1 = 0; _gv_i_1 < N; _gv_i_1 = _gv_i_1 + 1) begin : edges
			localparam i = _gv_i_1;
			assign wire_a[i][0] = a_i[((N - 1) - i) * 8+:8];
			assign wire_b[0][i] = b_i[((N - 1) - i) * 8+:8];
			assign wire_psum[0][i] = 1'sb0;
			assign out[((N - 1) - i) * 32+:32] = wire_psum[N][i];
			assign wire_en[i][0] = en_i[i];
			assign wire_clr[i][0] = clr_i[i];
		end
		for (_gv_i_1 = 0; _gv_i_1 < N; _gv_i_1 = _gv_i_1 + 1) begin : rows
			localparam i = _gv_i_1;
			for (_gv_j_1 = 0; _gv_j_1 < N; _gv_j_1 = _gv_j_1 + 1) begin : cols
				localparam j = _gv_j_1;
				pe #(
					.ROW(i),
					.COL(j)
				) pe_inst(
					.clk(clk),
					.rst(rst),
					.a_i(wire_a[i][j]),
					.b_i(wire_b[i][j]),
					.en_i(wire_en[i][j]),
					.en_o(wire_en[i][j + 1]),
					.clr_i(wire_clr[i][j]),
					.clr_o(wire_clr[i][j + 1]),
					.drain_en(drain_en),
					.psum_i(wire_psum[i][j]),
					.a_o(wire_a[i][j + 1]),
					.b_o(wire_b[i + 1][j]),
					.acc(wire_psum[i + 1][j])
				);
			end
		end
	endgenerate
endmodule
module compute_core (
	clk,
	rst,
	a_word,
	b_word,
	en_i,
	clr_i,
	drain_en,
	bias,
	m,
	s,
	relu_en,
	out_word
);
	reg _sv2v_0;
	input wire clk;
	input wire rst;
	input wire [127:0] a_word;
	input wire [127:0] b_word;
	input wire en_i;
	input wire clr_i;
	input wire drain_en;
	input wire signed [511:0] bias;
	input wire signed [31:0] m;
	input wire signed [7:0] s;
	input wire relu_en;
	output reg [127:0] out_word;
	reg signed [127:0] a_i;
	reg signed [127:0] b_i;
	wire signed [127:0] out_8;
	always @(*) begin : bit_to_bytes
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < 16; i = i + 1)
				begin
					a_i[(15 - i) * 8+:8] = a_word[i * 8+:8];
					b_i[(15 - i) * 8+:8] = b_word[i * 8+:8];
					out_word[i * 8+:8] = out_8[(15 - i) * 8+:8];
				end
		end
	end
	wire signed [127:0] a_sk;
	wire signed [127:0] b_sk;
	wire signed [511:0] out_32;
	wire [0:15] en_sk;
	wire [0:15] clr_sk;
	skew_regs skew_inst(
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
	array array_inst(
		.clk(clk),
		.rst(rst),
		.a_i(a_sk),
		.b_i(b_sk),
		.en_i(en_sk),
		.clr_i(clr_sk),
		.drain_en(drain_en),
		.out(out_32)
	);
	requant requant_inst(
		.m(m),
		.s(s),
		.bias(bias),
		.relu_en(relu_en),
		.out_32(out_32),
		.out_8(out_8)
	);
	initial _sv2v_0 = 0;
endmodule
module controller (
	clk,
	rst,
	start,
	dma_wptr_a,
	dma_wptr_b,
	k,
	out_free,
	en_q,
	clr_q,
	drain_en,
	a_raddr,
	b_raddr,
	in_ren,
	out_waddr,
	out_wen,
	rptr,
	done
);
	reg _sv2v_0;
	parameter signed [31:0] IN_DEPTH = 32;
	parameter signed [31:0] OUT_DEPTH = 16;
	parameter signed [31:0] SKEW_WIDTH = 15;
	parameter signed [31:0] ARRAY_WIDTH = 16;
	input wire clk;
	input wire rst;
	input wire start;
	input wire [$clog2(IN_DEPTH):0] dma_wptr_a;
	input wire [$clog2(IN_DEPTH):0] dma_wptr_b;
	input wire [12:0] k;
	input wire out_free;
	output reg en_q;
	output reg clr_q;
	output reg drain_en;
	output wire [$clog2(IN_DEPTH) - 1:0] a_raddr;
	output wire [$clog2(IN_DEPTH) - 1:0] b_raddr;
	output reg in_ren;
	output wire [$clog2(OUT_DEPTH) - 1:0] out_waddr;
	output reg out_wen;
	output reg [$clog2(IN_DEPTH):0] rptr;
	output reg done;
	reg [1:0] state;
	reg [1:0] next_state;
	reg [16:0] word_ctr;
	reg [4:0] flush_ctr;
	reg [$clog2(OUT_DEPTH) - 1:0] row_ctr;
	wire data_ready;
	reg en;
	reg clr;
	localparam signed [31:0] FLUSH_MAX = SKEW_WIDTH + ARRAY_WIDTH;
	assign data_ready = (rptr != dma_wptr_a) && (rptr != dma_wptr_b);
	assign a_raddr = rptr[$clog2(IN_DEPTH) - 1:0];
	assign b_raddr = rptr[$clog2(IN_DEPTH) - 1:0];
	assign out_waddr = row_ctr;
	always @(posedge clk)
		if (rst) begin
			en_q <= 1'b0;
			clr_q <= 1'b0;
		end
		else begin
			en_q <= en;
			clr_q <= clr;
		end
	always @(posedge clk)
		if (rst)
			state <= 2'd0;
		else
			state <= next_state;
	always @(*) begin
		if (_sv2v_0)
			;
		next_state = state;
		case (state)
			2'd0:
				if (start)
					next_state = 2'd1;
			2'd1:
				if (data_ready && (word_ctr == (k - 1)))
					next_state = 2'd2;
			2'd2:
				if ((flush_ctr >= FLUSH_MAX) && out_free)
					next_state = 2'd3;
			2'd3:
				if (row_ctr == 0)
					next_state = 2'd0;
		endcase
	end
	always @(*) begin
		if (_sv2v_0)
			;
		en = 1'b0;
		clr = 1'b0;
		drain_en = 1'b0;
		in_ren = 1'b0;
		out_wen = 1'b0;
		case (state)
			2'd1:
				if (data_ready) begin
					if (word_ctr == 0)
						clr = 1'b1;
					en = 1'b1;
					in_ren = 1'b1;
				end
			2'd3: begin
				drain_en = 1'b1;
				out_wen = 1'b1;
			end
		endcase
	end
	always @(posedge clk)
		if (rst) begin
			word_ctr <= 1'sb0;
			flush_ctr <= 1'sb0;
			row_ctr <= 1'sb0;
			rptr <= 1'sb0;
			done <= 1'b0;
		end
		else
			case (state)
				2'd0: begin
					word_ctr <= 1'sb0;
					flush_ctr <= 1'sb0;
					row_ctr <= 15;
					if (start)
						done <= 1'b0;
				end
				2'd1:
					if (data_ready) begin
						word_ctr <= word_ctr + 1'b1;
						rptr <= rptr + 1'b1;
					end
				2'd2:
					if (flush_ctr < FLUSH_MAX)
						flush_ctr <= flush_ctr + 1'b1;
				2'd3:
					if (!row_ctr)
						done <= 1'b1;
					else
						row_ctr <= row_ctr - 1'b1;
			endcase
	initial _sv2v_0 = 0;
endmodule
module pe (
	clk,
	rst,
	a_i,
	b_i,
	en_i,
	clr_i,
	drain_en,
	psum_i,
	a_o,
	b_o,
	en_o,
	clr_o,
	acc
);
	parameter signed [31:0] ROW = 0;
	parameter signed [31:0] COL = 0;
	input wire clk;
	input wire rst;
	input wire signed [7:0] a_i;
	input wire signed [7:0] b_i;
	input wire en_i;
	input wire clr_i;
	input wire drain_en;
	input wire signed [31:0] psum_i;
	output reg signed [7:0] a_o;
	output reg signed [7:0] b_o;
	output reg en_o;
	output reg clr_o;
	output reg signed [31:0] acc;
	wire signed [15:0] prod;
	assign prod = a_i * b_i;
	always @(posedge clk) begin
		if (rst) begin
			a_o <= 1'sb0;
			b_o <= 1'sb0;
			en_o <= 1'sb0;
			clr_o <= 1'sb0;
		end
		else begin
			a_o <= a_i;
			b_o <= b_i;
			en_o <= en_i;
			clr_o <= clr_i;
		end
		if (drain_en)
			acc <= psum_i;
		else if (en_i && clr_i)
			acc <= prod;
		else if (en_i)
			acc <= acc + prod;
	end
endmodule
module requant (
	out_32,
	bias,
	m,
	s,
	relu_en,
	out_8
);
	reg _sv2v_0;
	input wire signed [511:0] out_32;
	input wire signed [511:0] bias;
	input wire signed [31:0] m;
	input wire [7:0] s;
	input wire relu_en;
	output reg signed [127:0] out_8;
	wire signed [63:0] rounding_const;
	wire signed [7:0] lo;
	assign lo = (relu_en ? 0 : -128);
	assign rounding_const = (s > 0 ? 64'd1 << (s - 1) : 0);
	genvar _gv_i_2;
	generate
		for (_gv_i_2 = 0; _gv_i_2 < 16; _gv_i_2 = _gv_i_2 + 1) begin : lanes
			localparam i = _gv_i_2;
			reg signed [63:0] out_64;
			always @(*) begin : ops
				if (_sv2v_0)
					;
				out_64 = out_32[(15 - i) * 32+:32];
				out_64 = out_64 + bias[(15 - i) * 32+:32];
				out_64 = out_64 * m;
				out_64 = out_64 + rounding_const;
				out_64 = out_64 >>> s;
				if (out_64 > 127)
					out_8[(15 - i) * 8+:8] = 127;
				else if (out_64 < lo)
					out_8[(15 - i) * 8+:8] = lo;
				else
					out_8[(15 - i) * 8+:8] = out_64;
			end
		end
	endgenerate
	initial _sv2v_0 = 0;
endmodule
module scratchpad (
	clk,
	w_en,
	r_en,
	waddr,
	raddr,
	wdata,
	rdata
);
	parameter signed [31:0] WORD_WIDTH = 128;
	parameter signed [31:0] DEPTH = 0;
	parameter signed [31:0] BANKS = 4;
	parameter signed [31:0] R_WIDTH = 0;
	parameter signed [31:0] W_WIDTH = 0;
	input wire clk;
	input wire w_en;
	input wire r_en;
	input wire [$clog2(DEPTH / (W_WIDTH / WORD_WIDTH)) - 1:0] waddr;
	input wire [$clog2(DEPTH / (R_WIDTH / WORD_WIDTH)) - 1:0] raddr;
	input wire [W_WIDTH - 1:0] wdata;
	output reg [R_WIDTH - 1:0] rdata;
	localparam signed [31:0] BANK_DEPTH = DEPTH / BANKS;
	localparam signed [31:0] BSEL = $clog2(BANKS);
	localparam signed [31:0] W_SLOTS = W_WIDTH / WORD_WIDTH;
	localparam signed [31:0] R_SLOTS = R_WIDTH / WORD_WIDTH;
	reg [WORD_WIDTH - 1:0] mem [0:BANKS - 1][0:BANK_DEPTH - 1];
	generate
		if (W_SLOTS == BANKS) begin : g_wide_write
			always @(posedge clk)
				if (w_en) begin : sv2v_autoblock_1
					reg signed [31:0] b;
					for (b = 0; b < BANKS; b = b + 1)
						mem[b][waddr] <= wdata[b * WORD_WIDTH+:WORD_WIDTH];
				end
		end
		else begin : g_narrow_write
			always @(posedge clk)
				if (w_en)
					mem[waddr[BSEL - 1:0]][waddr[$clog2(DEPTH) - 1:BSEL]] <= wdata;
		end
		if (R_SLOTS == BANKS) begin : g_wide_read
			always @(posedge clk)
				if (r_en) begin : sv2v_autoblock_2
					reg signed [31:0] b;
					for (b = 0; b < BANKS; b = b + 1)
						rdata[b * WORD_WIDTH+:WORD_WIDTH] <= mem[b][raddr];
				end
		end
		else begin : g_narrow_read
			always @(posedge clk)
				if (r_en)
					rdata <= mem[raddr[BSEL - 1:0]][raddr[$clog2(DEPTH) - 1:BSEL]];
		end
	endgenerate
endmodule
module skew_regs (
	clk,
	a_i,
	b_i,
	en_i,
	clr_i,
	a_o,
	b_o,
	en_o,
	clr_o
);
	input wire clk;
	input wire signed [127:0] a_i;
	input wire signed [127:0] b_i;
	input wire en_i;
	input wire clr_i;
	output wire signed [127:0] a_o;
	output wire signed [127:0] b_o;
	output wire [0:15] en_o;
	output wire [0:15] clr_o;
	reg signed [7:0] a_delay [0:15][0:15];
	reg signed [7:0] b_delay [0:15][0:15];
	reg en_delay [0:15][0:15];
	reg clr_delay [0:15][0:15];
	genvar _gv_i_3;
	genvar _gv_j_2;
	generate
		for (_gv_i_3 = 0; _gv_i_3 < 16; _gv_i_3 = _gv_i_3 + 1) begin : index
			localparam i = _gv_i_3;
			wire [8:1] sv2v_tmp_94145;
			assign sv2v_tmp_94145 = a_i[(15 - i) * 8+:8];
			always @(*) a_delay[i][0] = sv2v_tmp_94145;
			wire [8:1] sv2v_tmp_30405;
			assign sv2v_tmp_30405 = b_i[(15 - i) * 8+:8];
			always @(*) b_delay[i][0] = sv2v_tmp_30405;
			wire [1:1] sv2v_tmp_99F48;
			assign sv2v_tmp_99F48 = en_i;
			always @(*) en_delay[i][0] = sv2v_tmp_99F48;
			wire [1:1] sv2v_tmp_2F7AA;
			assign sv2v_tmp_2F7AA = clr_i;
			always @(*) clr_delay[i][0] = sv2v_tmp_2F7AA;
			for (_gv_j_2 = 0; _gv_j_2 < i; _gv_j_2 = _gv_j_2 + 1) begin : buffers
				localparam j = _gv_j_2;
				always @(posedge clk) begin
					a_delay[i][j + 1] <= a_delay[i][j];
					b_delay[i][j + 1] <= b_delay[i][j];
					en_delay[i][j + 1] <= en_delay[i][j];
					clr_delay[i][j + 1] <= clr_delay[i][j];
				end
			end
			assign a_o[(15 - i) * 8+:8] = a_delay[i][i];
			assign b_o[(15 - i) * 8+:8] = b_delay[i][i];
			assign en_o[i] = en_delay[i][i];
			assign clr_o[i] = clr_delay[i][i];
		end
	endgenerate
endmodule
module tile_top (
	clk,
	rst,
	dma_data_i,
	a_waddr,
	b_waddr,
	out_raddr,
	a_wen,
	b_wen,
	out_ren,
	bias,
	m,
	s,
	relu_en,
	start,
	dma_wptr_a,
	dma_wptr_b,
	k,
	out_free,
	done,
	rptr,
	dma_data_o
);
	parameter signed [31:0] IN_DEPTH = 32;
	parameter signed [31:0] OUT_DEPTH = 16;
	parameter signed [31:0] SKEW_WIDTH = 15;
	parameter signed [31:0] ARRAY_WIDTH = 16;
	parameter signed [31:0] WORD_WIDTH = 128;
	parameter signed [31:0] BANKS = 4;
	input wire clk;
	input wire rst;
	input wire [511:0] dma_data_i;
	input wire [$clog2(IN_DEPTH / BANKS) - 1:0] a_waddr;
	input wire [$clog2(IN_DEPTH / BANKS) - 1:0] b_waddr;
	input wire [$clog2(OUT_DEPTH / BANKS) - 1:0] out_raddr;
	input wire a_wen;
	input wire b_wen;
	input wire out_ren;
	input wire signed [511:0] bias;
	input wire signed [31:0] m;
	input wire signed [7:0] s;
	input wire relu_en;
	input wire start;
	input wire [$clog2(IN_DEPTH):0] dma_wptr_a;
	input wire [$clog2(IN_DEPTH):0] dma_wptr_b;
	input wire [12:0] k;
	input wire out_free;
	output wire done;
	output wire [$clog2(IN_DEPTH):0] rptr;
	output wire [511:0] dma_data_o;
	wire en;
	wire clr;
	wire drain_en;
	wire [$clog2(IN_DEPTH) - 1:0] a_raddr;
	wire [$clog2(IN_DEPTH) - 1:0] b_raddr;
	wire in_ren;
	wire [$clog2(OUT_DEPTH) - 1:0] out_waddr;
	wire out_wen;
	wire [WORD_WIDTH - 1:0] rdata_a;
	wire [WORD_WIDTH - 1:0] rdata_b;
	wire [127:0] compute_o;
	controller #(
		.IN_DEPTH(IN_DEPTH),
		.OUT_DEPTH(OUT_DEPTH),
		.SKEW_WIDTH(SKEW_WIDTH),
		.ARRAY_WIDTH(ARRAY_WIDTH)
	) controller_inst(
		.clk(clk),
		.rst(rst),
		.start(start),
		.dma_wptr_a(dma_wptr_a),
		.dma_wptr_b(dma_wptr_b),
		.k(k),
		.out_free(out_free),
		.en_q(en),
		.clr_q(clr),
		.drain_en(drain_en),
		.a_raddr(a_raddr),
		.b_raddr(b_raddr),
		.in_ren(in_ren),
		.out_waddr(out_waddr),
		.out_wen(out_wen),
		.rptr(rptr),
		.done(done)
	);
	scratchpad #(
		.WORD_WIDTH(WORD_WIDTH),
		.DEPTH(IN_DEPTH),
		.BANKS(BANKS),
		.R_WIDTH(128),
		.W_WIDTH(512)
	) spad_a(
		.clk(clk),
		.w_en(a_wen),
		.r_en(in_ren),
		.waddr(a_waddr),
		.raddr(a_raddr),
		.wdata(dma_data_i),
		.rdata(rdata_a)
	);
	scratchpad #(
		.WORD_WIDTH(WORD_WIDTH),
		.DEPTH(IN_DEPTH),
		.BANKS(BANKS),
		.R_WIDTH(128),
		.W_WIDTH(512)
	) spad_b(
		.clk(clk),
		.w_en(b_wen),
		.r_en(in_ren),
		.waddr(b_waddr),
		.raddr(b_raddr),
		.wdata(dma_data_i),
		.rdata(rdata_b)
	);
	scratchpad #(
		.WORD_WIDTH(WORD_WIDTH),
		.DEPTH(OUT_DEPTH),
		.BANKS(BANKS),
		.R_WIDTH(512),
		.W_WIDTH(128)
	) spad_out(
		.clk(clk),
		.w_en(out_wen),
		.r_en(out_ren),
		.waddr(out_waddr),
		.raddr(out_raddr),
		.wdata(compute_o),
		.rdata(dma_data_o)
	);
	compute_core compute_core_inst(
		.clk(clk),
		.rst(rst),
		.a_word(rdata_a),
		.b_word(rdata_b),
		.en_i(en),
		.clr_i(clr),
		.drain_en(drain_en),
		.bias(bias),
		.m(m),
		.s(s),
		.relu_en(relu_en),
		.out_word(compute_o)
	);
endmodule
