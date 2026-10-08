
// CSR register block. AXI4-Lite i/o interface

// REGISTER MAP (byte addresses, 32-bit registers)
// 0x00        CTRL    [0] start  write 1 to launch; self-clearing, reads 0
// 0x04        STATUS  [0] done   read-only; set by DMA job_done, cleared on start
// 0x14        SCALE   [15:0] m, [21:16] s (valid 0..48), [22] relu
// 0x30        K       [12:0] k
// 0x34        A_BASE  DRAM byte address of packed A (512-byte aligned)
// 0x38        B_BASE  DRAM byte address of packed B (512-byte aligned)
// 0x3C        C_BASE  DRAM byte address for the 256-byte result
// 0x40-0x7C   BIAS[0..15]

module csr(
    //cpu/accel_top wrapper
    input  logic clk, rst,

    input  logic job_done,     //1 cycle pulse to DRAM (FROM DMA)

    //AXI4-LITE Pins
    //-----------------------------------------------------------
    //WRITE ADDRESS CHANNEL
    input  logic [31:0] s_axil_awaddr,
    input  logic        s_axil_awvalid,
    output logic        s_axil_awready,
    
    //WRITE DATA CHANNEL
    input  logic [31:0] s_axil_wdata,
    input  logic [3:0]  s_axil_wstrb,
    input  logic        s_axil_wvalid,
    output logic        s_axil_wready,

    //WRITE RESPONSE (B) CHANNEL
    input  logic        s_axil_bready,
    output logic [1:0]  s_axil_bresp,
    output logic        s_axil_bvalid,
    
    //READ ADDRESS CHANNEL
    input  logic [31:0] s_axil_araddr,
    input  logic        s_axil_arvalid,
    output logic        s_axil_arready,

    //READ DATA CHANNEL
    input  logic        s_axil_rready,
    output logic [31:0] s_axil_rdata,
    output logic [1:0]  s_axil_rresp,
    output logic        s_axil_rvalid,
    //-----------------------------------------------------------

    //REQUANT CONFIG (csr -> tile_top -> compute_core -> requant)
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
    logic r_en;
    logic w_en;
    logic [31:0] rdata_next;

        //Byte indexed addresses
    assign wslot = s_axil_awaddr[6:2];
    assign rslot = s_axil_araddr[6:2];


    //AXI4-LITE HANDSHAKES
    //---------------------------------------------------------
    always_comb begin
        //WRITE
        //allow write only when write data, address are both ready, AND not waiting for previous write complete
        w_en = s_axil_awvalid && s_axil_wvalid && !s_axil_bvalid;
        s_axil_wready = w_en;
        s_axil_awready = w_en;
        s_axil_bresp = 2'b00;   //OKAY signal

        //READ
        //accept AR only if valid and not still reading old
        r_en = s_axil_arvalid && !s_axil_rvalid;
        s_axil_arready = r_en;
        s_axil_rresp = 2'b00;   //OKAY signal
    end

    //(READ AND WRITE DELAY)
    always_ff @(posedge clk) begin
        if (rst) begin
            s_axil_bvalid <= 0;
            s_axil_rvalid <= 0;
        end else begin
            //write
            if (w_en) s_axil_bvalid <= 1;
            if (s_axil_bready && s_axil_bvalid) s_axil_bvalid <= 0;

            //read
            if (r_en) s_axil_rvalid <= 1;
            if (s_axil_rready && s_axil_rvalid) s_axil_rvalid <= 0;
        end

   //---------------------------------------------------------

    end



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

            //check for handshake, and full 4 byte strobe selection
            if (w_en && s_axil_wstrb == 4'b1111) begin
                if (wslot[4]) begin
                    bias[wslot[3:0]] <= s_axil_wdata;
                end else begin

                    case (wslot)
                        0:  start <= s_axil_wdata[0];
                        5:  begin
                                   m    <= s_axil_wdata[15:0];
                                   s    <= s_axil_wdata[21:16];
                                   relu <= s_axil_wdata[22];
                               end
                        12: k      <= s_axil_wdata[12:0];
                        13: a_base <= s_axil_wdata;
                        14: b_base <= s_axil_wdata;
                        15: c_base <= s_axil_wdata;
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

    //requant config
    always_ff @(posedge clk) begin
        if (rst) begin
            rounding_const <= 0;
            lo             <= -128;
        end else begin
            rounding_const  <= (s > 0) ? (50'd1 << (s - 1)) : 0;
            lo              <= relu ? 0 : -128;
        end
    end

    //read
    always_comb begin
        rdata_next = 0;
        //rslot[4] if 1 means bias region
        if (rslot[4]) begin
            rdata_next = bias[rslot[3:0]];
        end else begin
            case (rslot)
                1:  rdata_next = done_r;
                5:  rdata_next = {relu, s, m};
                12: rdata_next = k;
                13: rdata_next = a_base;
                14: rdata_next = b_base;
                15: rdata_next = c_base;
                default: ;
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (rst)        s_axil_rdata <= 0;
        else if (r_en) s_axil_rdata <= rdata_next; 
    end

endmodule
