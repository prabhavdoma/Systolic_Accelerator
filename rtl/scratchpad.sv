
module scratchpad #(
    parameter int WORD_WIDTH = 128,
    parameter int DEPTH,
    parameter int BANKS = 4,
    parameter int R_WIDTH,
    parameter int W_WIDTH
)(
    input  logic clk,
    input  logic w_en, r_en,
    input  logic [$clog2(DEPTH/(W_WIDTH/WORD_WIDTH)) - 1:0] waddr,
    input  logic [$clog2(DEPTH/(R_WIDTH/WORD_WIDTH)) - 1:0] raddr,
    input  logic [W_WIDTH - 1:0] wdata,
    output logic [R_WIDTH - 1:0] rdata
);

    localparam int BANK_DEPTH = DEPTH / BANKS;
    localparam int BSEL       = $clog2(BANKS);
    localparam int W_SLOTS    = W_WIDTH / WORD_WIDTH;
    localparam int R_SLOTS    = R_WIDTH / WORD_WIDTH;

    logic [WORD_WIDTH - 1:0] mem [0:BANKS - 1][0:BANK_DEPTH - 1];

    generate
        //WRITE
        if (W_SLOTS == BANKS) begin :g_wide_write
            always_ff @(posedge clk) begin
                if (w_en) begin
                    for (int b = 0; b < BANKS; b++) 
                        mem[b][waddr] <= wdata[b*WORD_WIDTH +: WORD_WIDTH];
                end
            end
        end else begin : g_narrow_write
            always_ff @(posedge clk) begin
                if (w_en) begin
                    mem[waddr[BSEL - 1:0]][waddr[$clog2(DEPTH)-1:BSEL]] <= wdata;
                end
            end
        end 
        //READ
        if (R_SLOTS == BANKS) begin :g_wide_read
            always_ff @(posedge clk) begin
                if (r_en) begin
                    for (int b = 0; b < BANKS; b++) 
                        rdata[b*WORD_WIDTH +: WORD_WIDTH] <= mem[b][raddr];
                end
            end
        end else begin : g_narrow_read
            always_ff @(posedge clk) begin
                if (r_en) begin
                    rdata <= mem[raddr[BSEL - 1:0]][raddr[$clog2(DEPTH)-1:BSEL]];
                end
            end
        end 
    endgenerate


endmodule   