
module scratchpad #(
    parameter int WIDTH = 128,
    parameter int DEPTH = 32
)(
    input  logic clk,
    input  logic wr_en, r_en,
    input  logic [$clog2(DEPTH) - 1:0] waddr,
    input  logic [$clog2(DEPTH) - 1:0] raddr,
    input  logic [WIDTH - 1:0] wdata,

    output logic [WIDTH - 1:0] rdata
);
    logic [WIDTH - 1:0] mem [0:DEPTH - 1];

    always_ff @(posedge clk) begin : WRITE
        if (wr_en) mem[waddr] <= wdata;
    end

    always_ff  @(posedge clk) begin : READ
        if (r_en) rdata <= mem[raddr];
    end

endmodule   