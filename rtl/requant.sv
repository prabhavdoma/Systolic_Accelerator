//take 32 bit psum/acc -> convert to INT8 for output
module requant(
    input  logic clk,
    input  logic signed [31:0] out_32 [0:15],
    input  logic signed [31:0] bias [0:15],
    input  logic signed [15:0] m,
    input  logic [5:0] s,
    input  logic relu_en,
    input  logic signed [49:0] rounding_const;
    input  logic signed [7:0] lo;

    output logic signed [7:0] out_8 [0:15]
);    
    genvar i;
    generate
        for (i = 0; i < 16; i++) begin : lanes
            logic signed [32:0] sum_q;
            logic signed [63:0] prod_q;
            logic signed [63:0] shifted;

            always_ff @(posedge clk) begin
                sum_q <= out_32[i] + bias[i];
                prod_q <= sum_q * m;
            end

            always_comb begin
                shifted = (prod_q + rounding_const) >>> s;
                if (shifted > 127)      out_8[i] = 127;
                else if (shifted < lo)  out_8[i] = lo;
                else                    out_8[i] = shifted[7:0];
            end
        end
    endgenerate
endmodule
