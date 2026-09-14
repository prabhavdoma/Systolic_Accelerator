
module requant(
    input  logic signed [31:0] out_32 [0:15],
    input  logic signed [31:0] bias [0:15],
    input  logic signed [31:0] m,
    input  logic [7:0] s,
    input logic relu_en,

    output logic signed [7:0] out_8 [0:15]
);

    logic signed [63:0] rounding_const;
    logic signed [7:0] lo;
    
    
    assign lo = relu_en ? 0 : -128;
    assign rounding_const = (s > 0) ? (64'd1 << (s-1)) : 0;

    genvar i;
    generate
        for (i = 0; i < 16; i++) begin : lanes

            logic signed [63:0] out_64;

            always_comb begin : ops
                out_64 = out_32[i];
                out_64 += bias[i];
                out_64 *= m;
                out_64 += rounding_const;
                out_64 = (out_64 >>> s);

                if (out_64 > 127) out_8[i]= 127;
                else if (out_64 < lo) out_8[i] = lo;
                else out_8[i] = out_64;
            end
        end
    endgenerate
endmodule