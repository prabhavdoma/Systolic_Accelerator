

module tile_top #(
    parameter int IN_DEPTH = 32,
    parameter int OUT_DEPTH = 16,
    parameter int SKEW_WIDTH = 15,
    parameter int ARRAY_WIDTH = 16,
    parameter int WORD_WIDTH = 128,
    parameter int BANKS = 4
)(
    //dma->scratchpad inputs
    input  logic clk, rst,
    input  logic [511:0] dma_data_i,
    input  logic [$clog2(IN_DEPTH/BANKS) - 1:0] a_waddr,
    input  logic [$clog2(IN_DEPTH/BANKS) - 1:0] b_waddr,
    input  logic [$clog2(OUT_DEPTH/BANKS) - 1:0] out_raddr,
    input  logic a_wen,
    input  logic b_wen,
    input  logic out_ren,

    //csr
	input  logic signed [15:0] m,
    input  logic [5:0] s,
    input  logic signed [31:0] bias [0:15],
    input  logic [49:0] rounding_const,
    input  logic signed [7:0] lo,


    //controller ports
    input  logic start,
    input  logic [$clog2(IN_DEPTH):0] dma_wptr_a,
    input  logic [$clog2(IN_DEPTH):0] dma_wptr_b,
    input  logic [12:0] k,
    input  logic  out_free,

    output logic done,
    output logic [$clog2(IN_DEPTH):0] rptr,
    output logic [511:0] dma_data_o               //4 word port to DMA
);
    //controller internal wires
    logic en;
    logic clr;
    logic drain_en;
    logic [$clog2(IN_DEPTH) - 1:0] a_raddr;
    logic [$clog2(IN_DEPTH) - 1:0] b_raddr;
    logic in_ren;
    logic [$clog2(OUT_DEPTH) - 1:0] out_waddr;
    logic out_wen;

    //scratchpad internal wires
    logic [WORD_WIDTH - 1:0] rdata_a;
    logic [WORD_WIDTH - 1:0] rdata_b;

    //compute_core internal wires
    logic [15:0][7:0] compute_o;    //128 bits

    
    
    //csr csr_inst (
    //.m(m),
    //.s(s),
    //.relu_en(relu_en) or something like ts idrk yet
    //);

    logic done_raw, done_d1;
    logic out_wen_d1, out_wen_d2;
    logic [$clog2(OUT_DEPTH) - 1:0] out_waddr_d1, out_waddr_d2;

    always_ff @(posedge clk) begin
        if (rst) begin
            out_wen_d1 <= 1'b0;
            out_wen_d2 <= 1'b0;
            done_d1    <= 1'b0;
            done       <= 1'b0;
        end else begin
            out_wen_d1 <= out_wen;
            out_wen_d2 <= out_wen_d1;
            done_d1    <= done_raw;
            done       <= done_d1;
        end
        out_waddr_d1 <= out_waddr;
        out_waddr_d2 <= out_waddr_d1;
    end

 
    // ---- controller ----
    controller #(
        .IN_DEPTH    (IN_DEPTH),
        .OUT_DEPTH   (OUT_DEPTH),
        .SKEW_WIDTH  (SKEW_WIDTH),
        .ARRAY_WIDTH (ARRAY_WIDTH)
    ) controller_inst (
        .clk         (clk),
        .rst         (rst),
        .start       (start),
        .dma_wptr_a  (dma_wptr_a),
        .dma_wptr_b  (dma_wptr_b),
        .k           (k),
        .out_free    (out_free),
        .en_q        (en),
        .clr_q       (clr),
        .drain_en    (drain_en),
        .a_raddr     (a_raddr),
        .b_raddr     (b_raddr),
        .in_ren      (in_ren),
        .out_waddr   (out_waddr),
        .out_wen     (out_wen),
        .rptr        (rptr),
        .done        (done_raw)
    );
 
    // ---- scratchpad A ----
    scratchpad #(
        .WORD_WIDTH (WORD_WIDTH),
        .DEPTH      (IN_DEPTH),
        .BANKS      (BANKS),
        .R_WIDTH    (128),
        .W_WIDTH    (512)
    ) spad_a (
        .clk   (clk),
        .w_en  (a_wen),
        .r_en  (in_ren),
        .waddr (a_waddr),
        .raddr (a_raddr),
        .wdata (dma_data_i),
        .rdata (rdata_a)
    );
 
    // ---- scratchpad B ----
    scratchpad #(
        .WORD_WIDTH (WORD_WIDTH),
        .DEPTH      (IN_DEPTH),
        .BANKS      (BANKS),
        .R_WIDTH    (128),
        .W_WIDTH    (512)
    ) spad_b (
        .clk   (clk),
        .w_en (b_wen),
        .r_en  (in_ren),
        .waddr (b_waddr),
        .raddr (b_raddr),
        .wdata (dma_data_i),
        .rdata (rdata_b)
    );
 
    // ---- scratchpad OUT ----
    // DEPTH 16 = single buffer. Bump to 32 for double buffering,
    // but then waddr is 5 bits and something must drive the top bit.
    scratchpad #(
        .WORD_WIDTH (WORD_WIDTH),
        .DEPTH      (OUT_DEPTH),
        .BANKS      (BANKS),
        .R_WIDTH    (512),
        .W_WIDTH    (128)
    ) spad_out (
        .clk   (clk),
        .w_en (out_wen_d2),
        .r_en  (out_ren),
        .waddr (out_waddr_d2),
        .raddr (out_raddr),
        .wdata (compute_o),
        .rdata (dma_data_o)
    );
 
    // ---- compute core ----
    compute_core compute_core_inst (
        .clk      (clk),
        .rst      (rst),
        .a_word   (rdata_a),
        .b_word   (rdata_b),
        .en_i     (en),
        .clr_i    (clr),
        .drain_en (drain_en),
        .bias     (bias),
        .m        (m),s
        .s        (s),
        .relu_en  (relu_en),
        .rounding_const(rounding_const),
        .lo(lo),
        
        .out_word (compute_o)
    );
 
endmodule
 
 
