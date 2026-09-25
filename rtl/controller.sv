module controller#(
    parameter int DEPTH = 32,
    parameter int OUT_DEPTH = 16,
    parameter int SKEW_WIDTH = 15,
    parameter int ARRAY_WIDTH = 16
)(
    input  logic clk, rst,
    input  logic start,
    input  logic [$clog2(DEPTH):0] dma_wptr_a,
    input  logic [$clog2(DEPTH):0] dma_wptr_b,
    input  logic [12:0] k, //covers until 8191 bits
    input  logic out_free,

    //en and clr output delayed (_q)
    output logic en_q,
    output logic clr_q,
    output logic drain_en,
    output logic [$clog2(DEPTH) - 1:0] a_raddr,
    output logic [$clog2(DEPTH) - 1:0] b_raddr,
    output logic in_ren, 
    output logic [$clog2(OUT_DEPTH) - 1:0] out_waddr,
    output logic out_wen,
    output logic [$clog2(DEPTH):0] rptr,
    output logic done
);
    //STATE REGISTER
    typedef enum logic [1:0] {IDLE, ACC, WAIT, DRAIN} state_t;
    state_t state, next_state;

    //counters
    logic [16:0] word_ctr;
    logic [4:0] flush_ctr;
    logic [$clog2(DEPTH) - 1:0] row_ctr;
    logic data_ready;
    logic en;
    logic clr;
    
    localparam int FLUSH_MAX = SKEW_WIDTH + ARRAY_WIDTH;

    assign data_ready = (rptr != dma_wptr_a);

    //assign outside cases and blocks because if false (nothing assign and infers a latch
    //which is bad for synthesis (broken timing))
    assign a_raddr = rptr[$clog2(DEPTH)-1:0];
    assign b_raddr = rptr[$clog2(DEPTH)-1:0];
    assign out_waddr = row_ctr;

    //delay en and clr by one cycle to match initial read injection cycle
    always_ff @(posedge clk) begin
        if (rst) begin
            en_q <= 1'b0;
            clr_q <= 1'b0;
        end else begin
            en_q <= en;
            clr_q <= clr;
        end
    end

    //state register
    always_ff @(posedge clk) begin
        if (rst) state <= IDLE;
        else    state <= next_state;
    end 

    //define state change conditions
    always_comb begin
        next_state = state;
        case (state)
            IDLE:  if (start) next_state = ACC;
            ACC:   if (word_ctr == k - 1) next_state = WAIT;
            WAIT:  if (flush_ctr >= FLUSH_MAX && out_free) next_state = DRAIN;
            DRAIN: if (row_ctr == 0) next_state = IDLE;
        endcase
    end

    //Outputs held per state
    always_comb begin
        en = 1'b0; clr = 1'b0; drain_en = 1'b0;
        in_ren = 1'b0; out_wen = 1'b0;

        case (state)
            ACC: begin
                if (data_ready) begin
                    if (word_ctr == 0) clr = 1'b1;
                    en = 1'b1;
                    in_ren = 1'b1;
                end
            end
            DRAIN : begin
                drain_en = 1'b1;
                out_wen = 1'b1;
            end
        endcase
    end

    //counters
    always_ff @(posedge clk) begin
        if (rst) begin
            word_ctr <= '0;
            flush_ctr <= '0;
            row_ctr <= '0;
            rptr <= '0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE : begin 
                    word_ctr <= '0;
                    flush_ctr <= '0;
                    row_ctr <= 15;
                    if (start) done <= 1'b0;
                end
                ACC : if (data_ready) begin 
                    word_ctr <= word_ctr + 1'b1;
                    rptr <= rptr + 1'b1;
                end
                WAIT :  if (flush_ctr < FLUSH_MAX) flush_ctr <= flush_ctr + 1'b1;
                DRAIN : begin 
                    if (!row_ctr) begin
                        done <= 1'b1;
                    end else begin
                        row_ctr <= row_ctr - 1'b1;
                    end
                end

            endcase
        end
    end


endmodule
