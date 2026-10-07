// CSR register block. Simple register interface; an AXI4-Lite wrapper sits on top.
//
// REGISTER MAP (byte addresses, 32-bit registers)
// 0x00        CTRL    [0] start  write 1 to launch; self-clearing, reads 0
// 0x04        STATUS  [0] done   read-only; set by DMA job_done, cleared on start
// 0x14        SCALE   [15:0] m, [21:16] s (valid 0..48), [22] relu
// 0x30        K       [12:0] k
// 0x34        A_BASE  DRAM byte address of packed A (512-byte aligned)
// 0x38        B_BASE  DRAM byte address of packed B (512-byte aligned)
// 0x3C        C_BASE  DRAM byte address for the 256-byte result
// 0x40-0x7C   BIAS[0..15]
//

module csr(

    input  logic clk, rst,

    input  logic job_done,     //1 cycle pulse to DRAM (FROM DMA)

    //register interface
    input  logic w_en,
    input  logic [6:0] csr_waddr,
    input  logic [31:0] csr_wdata,
    input  logic [6:0] csr_raddr,
    output logic [31:0] csr_rdata,

    //to tile (requant)
    output logic signed [15:0] m,
    output logic [5:0] s,
    output logic signed [31:0] bias [0:15],
    output logic [49:0] rounding_const,
    output logic signed [7:0] lo,



    // to controller and DMA
    output logic start,
    output logic [31:0] a_base,
    output logic [31:0] b_base,
    output logic [31:0] c_base,
    output logic [12:0] k
);
    logic relu;
    logic done_r;
    logic [4:0] wslot, rslot;

    assign wslot = csr_waddr[6:2];
    assign rslot = csr_raddr[6:2];

    //write
    always_ff @(posedge clk) begin
        if (rst) begin
            start <= 0;
            m <= 0;
            s <= 0;
            relu <= 0;
            k <= 0;
            a_base <= 0;
            b_base <= 0;
            c_base <= 0;
            for (int i = 0; i < 16; i++) bias[i] <= 0;
        end else begin
            start <= 0;
            if (w_en)   begin
                if (wslot[4]) begin
                    bias[wslot[3:0]] <= csr_wdata;
                end else begin
                    case (wslot)
                        0:  start <= csr_wdata[0];
                        5:  begin
                                   m    <= csr_wdata[15:0];
                                   s    <= csr_wdata[21:16];
                                   relu <= csr_wdata[22];
                               end
                        12: k      <= csr_wdata[12:0];
                        13: a_base <= csr_wdata;
                        14: b_base <= csr_wdata;
                        15: c_base <= csr_wdata;
                        default: ;   
                    endcase
                end
            end
        end
    end

    //done
    always_ff @(posedge clk) begin
        if (rst)            done_r <= 0;
        else if (start)     done_r <= 0; //clear for new job
        else if (job_done)  done_r <= 1; //wait for DMA to finish DRAM write
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            rounding_const <= 0;
            lo             <= -128;
        end else begin
            rounding_const  <= (s > 0) ? (50'd1 << (s - 1)) : 0;
            lo              <= relu ? 0 : -128;
        end
    end

    always_comb begin
        csr_rdata = 0;
        //rslot[4] if 1 means bias region
        if (rslot[4]) begin
            csr_rdata = bias[rslot[3:0]];
        end else begin
            case (rslot)
                1:  csr_rdata = done_r;
                5:  csr_rdata = {relu, s, m};
                12: csr_rdata = k;
                13: csr_rdata = a_base;
                14: csr_rdata = b_base;
                15: csr_rdata = c_base;
                default: ;
            endcase
        end

    end

endmodule
