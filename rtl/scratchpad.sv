
module scratchpad #(
    parameter int WIDTH = 128,
    parameter int DEPTH,
    parameter int BANKS = 4,
    parameter int BANK_DEPTH = DEPTH/BANKS
)(
    input  logic clk,
    input  logic wr_en, r_en,
    input  logic [$clog2(BANK_DEPTH) - 1:0] waddr,
    input  logic [$clog2(DEPTH) - 1:0] raddr,
    input  logic [3:0][WIDTH - 1:0] wdata,

    output logic [WIDTH - 1:0] rdata
);

    //takes 4 chunks of 128 bit words -> write to 4 banks

    logic [WIDTH - 1:0] mem [0:BANKS - 1][0:BANK_DEPTH - 1];

    always_ff @(posedge clk) begin : WRITE
        if (wr_en) begin
            mem[0][waddr] <= wdata[0];
            mem[1][waddr] <= wdata[1];
            mem[2][waddr] <= wdata[2];
            mem[3][waddr] <= wdata[3];
        end
    end

    always_ff  @(posedge clk) begin : READ
        if (r_en) rdata <= mem[raddr[1:0]][raddr[$clog2(DEPTH) - 1: 2]];
    end

endmodule   